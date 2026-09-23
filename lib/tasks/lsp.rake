# frozen_string_literal: true

require "json"
require "open3"

# =============================================================================
#  lsp:check — valida que Ruby LSP funciona de verdad (arranque + sugerencias)
# =============================================================================
#
# Motivación: el fallo real no era el servidor, era la extensión de VS Code
# muriendo al activar por un setting con formato antiguo:
#
#     "rubyLsp.rubyVersionManager": "none"            # ← string: CRASHEA
#     "rubyLsp.rubyVersionManager": { "identifier": "none" }   # ← objeto: OK
#
#     TypeError: Cannot create property 'identifier' on string 'none'
#
# Por eso un "todo verde" en rubocop/tests no te dice nada sobre el LSP: esta
# tarea comprueba las DOS capas.
#
# USO (desde la raíz del repo):
#   bin/rails lsp:check
#
# FASE 1 · estático (milisegundos, no necesita el servidor):
#   - formato del setting en .devcontainer/devcontainer.json (objeto vs string)
#   - mismo setting en ~/.vscode-server/data/Machine/settings.json
#   - .ruby-lsp/Gemfile no declara ruby-lsp en duplicado con el Gemfile principal
#     (bundler aborta con "You cannot specify the same gem twice")
#   - gem ruby-lsp instalada + extensión shopify.ruby-lsp presente
#
# FASE 2 · dinámico (~15 s): arranca `bundle exec ruby-lsp` por stdio y hace un
#   handshake LSP real: initialize -> indexado -> completion (con trigger ".")
#   -> definition -> hover -> documentSymbol sobre un buffer virtual, es decir,
#   exactamente lo que hace el editor cuando escribes.
#
# CÓDIGO DE SALIDA: 0 si todo OK (avisos permitidos), 1 si algo FALLA.
module LspCheck
  PROBE_PATH = "tmp/lsp_check_probe.rb"

  # Buffer virtual: NUNCA se escribe en disco, se pasa por textDocument/didOpen.
  # Las posiciones se calculan a partir de estas líneas, no a mano.
  #
  #   - `"probe".upcase` → completion con trigger "." (el popup clásico)
  #   - `App`             → completion de constante (usa el índice del proyecto)
  #   - `i` (a nivel raíz) → keywords/locales; a nivel raíz el receiver es
  #                          Object, que siempre está indexado
  #   - `ApplicationController` → definition + hover
  PROBE_SOURCE = <<~RUBY
    # frozen_string_literal: true

    class LspCheckProbe < ApplicationController
      def index
        "probe".upcase
        App
      end
    end

    i
  RUBY

  REQUIRED_CAPABILITIES = %w[
    completionProvider hoverProvider definitionProvider documentSymbolProvider
  ].freeze

  class Error < StandardError; end
  class Timeout < Error; end

  # Cliente LSP mínimo: framing Content-Length sobre stdio, sin dependencias.
  class Server
    def initialize(root)
      @root = root
      @buffer = "".b
      @responses = {}
      @stderr = +""
      @last_id = 0
    end

    def start
      env = ENV.to_h
      env.delete("BUNDLE_GEMFILE") # el server debe resolver su propio bundle
      @stdin, @stdout, @reader, @thread = Open3.popen3(
        env, "bundle", "exec", "ruby-lsp", chdir: @root
      )
      @stdin.binmode
      @stdout.binmode
      drain_stderr
    rescue Errno::ENOENT => e
      raise Error, "no se pudo ejecutar `bundle exec ruby-lsp` (#{e.message})"
    end

    def stop
      return unless @stdin && !@stdin.closed?

      @stdin.close
      unless @thread.nil? || @thread.join(5)
        Process.kill("TERM", @thread.pid)
        @thread.join(3)
      end
    rescue IOError, SystemCallError
      nil
    ensure
      close_quietly(@stdout)
      close_quietly(@reader)
      @reader_thread&.kill
    end

    def stderr_tail(limit = 1200)
      @stderr.to_s[-limit..] || ""
    end

    def initialize!
      id = next_id
      send_message(
        {
          "jsonrpc" => "2.0", "id" => id, "method" => "initialize",
          "params" => {
            "processId" => Process.pid,
            "rootUri" => "file://#{@root}",
            "clientInfo" => { "name" => "lsp:check" },
            "capabilities" => {
              "window" => { "workDoneProgress" => true },
              "textDocument" => {
                "completion" => { "completionItem" => { "snippetSupport" => false } },
                "hover" => { "contentFormat" => [ "markdown" ] },
                "documentSymbol" => {},
                "definition" => {}
              },
              "workspace" => { "workspaceFolders" => true }
            },
            "workspaceFolders" => [ { "uri" => "file://#{@root}", "name" => File.basename(@root) } ]
          }
        },
        timeout: 45
      ).fetch("result").fetch("capabilities")
    end

    def notify(method, params)
      send_message({ "jsonrpc" => "2.0", "method" => method, "params" => params }, timeout: 0)
    end

    def request(method, params, timeout: 60)
      id = next_id
      send_message(
        { "jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params },
        timeout: timeout
      )
    end

    # Espera el fin del indexado inicial (notificación $/progress del token
    # "indexing-progress"). Devuelve false si no llegó a tiempo: no es fatal,
    # las features pueden responder con menos resultados.
    def wait_for_indexing(timeout: 45)
      deadline = Time.now + timeout
      loop do
        remaining = deadline - Time.now
        return false if remaining <= 0

        message = read_message(timeout: remaining, what: "indexado")
        next unless message["method"] == "$/progress"

        params = message["params"] || {}
        next unless params["token"] == "indexing-progress"

        return true if params.dig("value", "kind") == "end"
      end
    rescue Timeout
      false
    end

    def open_document(uri, text, version: 1)
      notify("textDocument/didOpen", {
        "textDocument" => { "uri" => uri, "languageId" => "ruby", "version" => version, "text" => text }
      })
    end

    private

    def next_id
      @last_id += 1
    end

    def send_message(message, timeout:)
      body = JSON.generate(message)
      @stdin.write("Content-Length: #{body.bytesize}\r\n\r\n#{body}")
      @stdin.flush

      # Las notificaciones (sin "id") no reciben respuesta: no esperar nunca.
      id = message["id"]
      return nil unless id

      deadline = Time.now + timeout
      until @responses.key?(id)
        remaining = deadline - Time.now
        if remaining <= 0
          raise Timeout, "sin respuesta a `#{message["method"]}` tras #{timeout}s#{stderr_suffix}"
        end
        read_message(timeout: remaining, what: message["method"])
      end

      @responses.delete(id)
    end

    def read_message(timeout:, what:)
      deadline = Time.now + timeout
      loop do
        if (separator = @buffer.index("\r\n\r\n"))
          head = @buffer[0, separator]
          if head =~ /Content-Length:\s*(\d+)/i
            length = Regexp.last_match(1).to_i
            body_start = separator + 4
            if @buffer.bytesize >= body_start + length
              body = @buffer[body_start, length]
              @buffer = @buffer[(body_start + length)..] || "".b
              message = JSON.parse(body.force_encoding(Encoding::UTF_8))
              # Solo las respuestas llevan "id" sin "method"; las peticiones que
              # manda el servidor (p.ej. workDoneProgress/create) se ignoran.
              @responses[message["id"]] = message if message.key?("id") && !message.key?("method")
              return message
            end
          end
        end

        remaining = deadline - Time.now
        raise Timeout, "timeout esperando `#{what}`#{stderr_suffix}" if remaining <= 0

        unless IO.select([ @stdout ], nil, nil, remaining)
          raise Timeout, "timeout esperando `#{what}`#{stderr_suffix}"
        end

        begin
          @buffer << @stdout.readpartial(8192)
        rescue EOFError
          raise Error, "el servidor terminó inesperadamente#{stderr_suffix}"
        end
      end
    end

    def drain_stderr
      @reader_thread = Thread.new do
        loop do
          begin
            @stderr << @reader.readpartial(4096)
          rescue EOFError, IOError
            break
          end
        end
      end
    end

    def close_quietly(io)
      io.close if io && !io.closed?
    rescue IOError, SystemCallError
      nil
    end

    def stderr_suffix
      tail = stderr_tail(400).strip
      tail.empty? ? "" : " | stderr: #{tail.gsub(/\s+/, " ")}"
    end
  end

  class << self
    def run(root)
      puts "== Ruby LSP check =="
      puts

      static_checks(root)
      dynamic_checks(root)

      puts
      if @failures.to_i.zero?
        puts "RESULTADO: OK · #{@total_pass.to_i} comprobaciones#{@warnings.to_i.positive? ? ", #{@warnings} aviso(s)" : ""}"
        0
      else
        puts "RESULTADO: FALLA (#{@failures} error(es), #{@warnings.to_i} aviso(s))"
        1
      end
    end

    private

    @failures = 0
    @warnings = 0
    @total_pass = 0

    # ------------------------------------------------------------------
    # FASE 1 · configuración
    # ------------------------------------------------------------------
    def static_checks(root)
      puts "-- configuración --"
      check_devcontainer_setting(root)
      check_machine_setting
      check_composed_gemfile(root)
      check_ruby_lsp_gem
      check_extension
      puts
    end

    def check_devcontainer_setting(root)
      path = File.join(root, ".devcontainer", "devcontainer.json")
      unless File.exist?(path)
        info ".devcontainer/devcontainer.json no existe (¿fuera del devcontainer?)"
        return
      end

      raw = File.read(path)
      match = raw.match(/"rubyLsp\.rubyVersionManager"\s*:\s*(\{[^}]*\}|"[^"]*")/)
      unless match
        warn "devcontainer.json no define rubyLsp.rubyVersionManager (usará el default `auto`)"
        return
      end

      value = match[1]
      if value.start_with?('"')
        error "devcontainer.json usa el formato string #{value} — la extensión 0.10.x crashea " \
             "con `TypeError: Cannot create property 'identifier' on string ...`. " \
             'Usa { "identifier": "none" }'
      else
        ok "devcontainer.json · rubyLsp.rubyVersionManager = #{value}"
      end
    rescue JSON::ParserError, ArgumentError => e
      error "no se pudo leer devcontainer.json: #{e.message}"
    end

    def check_machine_setting
      path = File.expand_path("~/.vscode-server/data/Machine/settings.json")
      unless File.exist?(path)
        info "Machine/settings.json no existe (este entorno no es un VS Code remoto)"
        return
      end

      # VS Code guarda los settings como claves planas con punto
      # ("rubyLsp.rubyVersionManager"); también aceptamos la forma anidada.
      data = JSON.parse(File.read(path))
      value = data["rubyLsp.rubyVersionManager"] || data.to_h.dig("rubyLsp", "rubyVersionManager")

      case value
      when Hash
        ok "Machine settings · rubyVersionManager = #{JSON.generate(value)}"
      when String
        error "Machine settings aún tiene el formato string #{value.dump} — VS Code lo lee " \
             'antes que devcontainer.json. Cámbialo a { "identifier": "none" } y recarga la ventana'
      else
        info "Machine settings no define rubyVersionManager"
      end
    rescue JSON::ParserError => e
      error "Machine/settings.json no es JSON válido: #{e.message}"
    end

    def check_composed_gemfile(root)
      path = File.join(root, ".ruby-lsp", "Gemfile")
      main = File.join(root, "Gemfile")

      unless File.exist?(path)
        ok ".ruby-lsp/Gemfile no existe (se regenera solo y sin duplicados)"
        return
      end

      declares_lsp = File.read(path).match?(/^\s*gem\s+["']ruby-lsp["']/)
      main_declares_lsp = File.exist?(main) && File.read(main).match?(/^\s*gem\s+["']ruby-lsp["']/)

      if declares_lsp && main_declares_lsp
        error ".ruby-lsp/Gemfile declara `gem \"ruby-lsp\"` en duplicado con el Gemfile principal. " \
             "Bundler aborta: \"You cannot specify the same gem twice\". " \
             "Borra .ruby-lsp/Gemfile y .ruby-lsp/Gemfile.lock (están gitignored)"
      else
        ok ".ruby-lsp/Gemfile sin conflicto con el Gemfile principal"
      end
    end

    def check_ruby_lsp_gem
      spec = Gem::Specification.find_by_name("ruby-lsp")
      ok "gem ruby-lsp #{spec.version} instalada"
    rescue Gem::MissingSpecError
      error "la gem `ruby-lsp` no está instalada — ejecuta `bundle install`"
    end

    def check_extension
      dir = File.expand_path("~/.vscode-server/extensions")
      unless File.directory?(dir)
        info "sin ~/.vscode-server (no hay editor VS Code conectado; solo se valida el servidor)"
        return
      end

      found = Dir.glob(File.join(dir, "shopify.ruby-lsp-*"))
      if found.empty?
        warn "extensión shopify.ruby-lsp no instalada en este entorno"
      else
        ok "extensión #{File.basename(found.max)}"
      end
    end

    # ------------------------------------------------------------------
    # FASE 2 · handshake real con el servidor
    # ------------------------------------------------------------------
    def dynamic_checks(root)
      puts "-- servidor (handshake LSP real, ~15 s) --"

      lines = PROBE_SOURCE.lines.map(&:chomp)
      positions = probe_positions(lines)

      server = Server.new(root)
      started = Time.now
      begin
        server.start
        capabilities = server.initialize!
        missing = REQUIRED_CAPABILITIES.reject { |key| capabilities.key?(key) }
        if missing.empty?
          ok "initialize · #{capabilities.size} capabilities (#{REQUIRED_CAPABILITIES.size} clave(s) requeridas)"
        else
          error "initialize sin capabilities: #{missing.join(", ")}"
          return
        end

        server.notify("initialized", {})

        indexed = server.wait_for_indexing
        if indexed
          ok "indexado inicial completado en #{(Time.now - started).round}s"
        else
          warn "el indexado no terminó a tiempo: las features pueden responder con menos resultados"
        end

        uri = "file://#{File.join(root, PROBE_PATH)}"
        server.open_document(uri, PROBE_SOURCE)

        # 1. completion tras un punto con triggerCharacter "." → el popup clásico
        items = completion_items(server, uri, positions[:dot_line], positions[:dot_char], trigger: ".")
        check_items items, "completion tras `.` en `\"probe\".upcase`", hard: true

        # 2. identificador a nivel raíz sin receiver → keywords y locales
        items = completion_items(server, uri, positions[:prefix_line], positions[:prefix_char])
        check_items items, "completion de `i` (keywords/locales)", hard: true

        # 3. prefijo de constante → requiere el índice del proyecto
        items = completion_items(server, uri, positions[:app_line], positions[:app_char])
        check_items items, "completion de `App` (constantes del proyecto)", hard: false

        target = { "line" => positions[:class_line], "character" => positions[:class_char] }
        definition = server.request("textDocument/definition", {
                                      "textDocument" => { "uri" => uri }, "position" => target
                                    }).fetch("result", nil)
        definition = [] if definition.nil?
        definition = [ definition ] unless definition.is_a?(Array)
        if definition.any?
          where = (definition.first["targetUri"] || definition.first["uri"] || "?").sub("file://#{root}/", "")
          ok "definition sobre `ApplicationController` → #{where}"
        else
          warn "definition sobre `ApplicationController` sin resultado (¿índice incompleto?)"
        end

        hover = server.request("textDocument/hover", {
                                 "textDocument" => { "uri" => uri }, "position" => target
                               }).fetch("result", nil)
        hover_text = hover.is_a?(Hash) ? hover.dig("contents", "value").to_s : ""
        if hover_text.empty?
          warn "hover sobre `ApplicationController` sin resultado"
        else
          ok "hover → #{hover_text.gsub(/\s+/, " ")[0, 80]}"
        end

        symbols = server.request("textDocument/documentSymbol", {
                                   "textDocument" => { "uri" => uri }
                                 }).fetch("result", nil) || []
        names = symbols.filter_map { |symbol| symbol.is_a?(Hash) ? symbol["name"] : nil }
        if names.empty?
          warn "documentSymbol sin resultados"
        else
          ok "documentSymbol → #{names.join(", ")}"
        end
      rescue Error => e
        error "handshake: #{e.message}"
      ensure
        server.stop
      end
    end

    def probe_positions(lines)
      dot_line = lines.index { |line| line.include?(".upcase") } || 0
      app_line = lines.index { |line| line.strip == "App" } || 0
      prefix_line = lines.index { |line| line.strip == "i" } || 0
      class_line = lines.index { |line| line.start_with?("class ") } || 0

      {
        # caret justo DESPUÉS del punto (el server resta 1 para ubicar el nodo)
        dot_line: dot_line,
        dot_char: lines[dot_line].index(".upcase").to_i + 1,
        prefix_line: prefix_line,
        prefix_char: lines[prefix_line].rindex("i").to_i + 1,
        app_line: app_line,
        app_char: lines[app_line].rindex("App").to_i + 3,
        class_line: class_line,
        class_char: lines[class_line].index("ApplicationController").to_i + 5
      }
    end

    def completion_items(server, uri, line, character, trigger: nil)
      params = {
        "textDocument" => { "uri" => uri },
        "position" => { "line" => line, "character" => character },
        "context" => trigger ? { "triggerKind" => 2, "triggerCharacter" => trigger }
                              : { "triggerKind" => 1 }
      }
      result = server.request("textDocument/completion", params).fetch("result", nil)
      return [] if result.nil?

      result.is_a?(Hash) ? (result["items"] || []) : result
    end

    def check_items(items, label, hard:)
      if items.empty?
        hard ? error("#{label} → 0 sugerencias") : warn("#{label} → 0 sugerencias")
      else
        sample = items.first(6).map { |item| item.is_a?(Hash) ? item["label"] : item.to_s }
        ok "#{label} → #{items.size} sugerencias (#{sample.join(", ")}#{items.size > 6 ? ", …" : ""})"
      end
    end

    # ------------------------------------------------------------------
    # reporte
    # ------------------------------------------------------------------
    def ok(message)
      @total_pass = @total_pass.to_i + 1
      puts "  ✅ #{message}"
    end

    def warn(message)
      @warnings = @warnings.to_i + 1
      puts "  ⚠️  #{message}"
    end

    # OJO: `fail`/`error` NO se llama `fail` a propósito: sobrescribiría
    # Kernel#fail (alias de raise) dentro de esta clase y rompería los `raise`.
    def error(message)
      @failures = @failures.to_i + 1
      puts "  ❌ #{message}"
    end

    def info(message)
      puts "  ·  #{message}"
    end
  end
end

namespace :lsp do
  desc "Valida que Ruby LSP arranca y devuelve sugerencias (config + handshake real)"
  task check: :environment do
    exit LspCheck.run(Dir.pwd)
  end
end
