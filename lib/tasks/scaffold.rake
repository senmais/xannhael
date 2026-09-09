# frozen_string_literal: true

require "fileutils"
require "shellwords"

# =============================================================================
#  scaffold:rename — rename THIS clone for a new project (in place)
# =============================================================================
#
# This repo is a working template: a Rails 8 web app + a Hotwire Native Android
# client that talk to each other. To start a new project (blog, ecommerce, SaaS,
# CRM, ...) you clone this repo, run this task, and it renames the clone in
# place so it works as the new project. Then you point it at your own repo.
#
# FLOW (recommended):
#   git clone <this-template-url>           # fresh clone of the template
#   cd <clone>
#   bin/rails scaffold:rename SLUG=blog PACKAGE=com.acme.blog
#   git remote add origin <your-new-repo-url>
#   git add -A && git commit                # records the rename
#   ... develop ...
#
# The OLD identifiers are DETECTED from the repo content (the Android namespace
# and the Rails application module), not from the folder name, so the task
# works no matter what the template was called (sannhael -> xannhael -> yours)
# and no matter what name you cloned the folder as.
#
# USAGE (from the repo root):
#   bin/rails scaffold:rename SLUG=blog
#   bin/rails scaffold:rename SLUG=blog PACKAGE=com.acme.blog
#   bin/rails scaffold:rename            # SLUG defaults to the folder name
#
# OPTIONS:
#   SLUG         new project slug (lowercase, e.g. "blog"). Used for DB names,
#                rootProject, URLs, etc. Defaults to the current folder name.
#   PACKAGE      new Android applicationId/namespace, e.g. "com.acme.blog".
#                Defaults to "com.example.<slug>".
#   STRIP_SECRETS=1   also delete config/master.key + credentials.yml.enc.
#                     Default: kept (required to boot in the devcontainer).
#
# WHAT IT RENAMES (both Android and Rails):
#   * Android package:        com.creadix.<old> -> com.acme.blog
#     (applicationId, namespace, package dirs, imports, test assertions)
#   * App class/theme/label:  Xannhael -> Blog
#     (XannhaelApplication.kt, Theme.Xannhael, app_name, strings)
#   * Slugs & names:          xannhael -> blog
#     (DB names, rootProject.name, module name, README, locales, devcontainer,
#      ENV["XANNHAEL_DATABASE_PASSWORD"])
#
# REQUIRED CREDENTIALS (to run in the devcontainer; kept by default):
#   * config/master.key + config/credentials.yml.enc with a `database` key
#     (host, port, username, password). In development, DB_HOST (set by the
#     devcontainer) makes config/database.yml read
#     Rails.application.credentials.database. Without it the app cannot
#     connect to the shared postgres-db container.
#     Generate/refresh with:  bin/rails credentials:edit
#   * The shared postgres-db container running:  docker start postgres-db
#   * Env vars the devcontainer sets itself (no action needed): DB_HOST,
#     PGHOST/PGPORT/PGUSER/PGPASSWORD, SELENIUM_HOST, CAPYBARA_SERVER_PORT.
#   * Optional, not needed to run the app: OPENAI_API_KEY, OPENCODE_API_KEY
#     (codex/opencode auth), KAMAL_REGISTRY_PASSWORD (deploy),
#     XANNHAEL_DATABASE_PASSWORD (production DB only).
#
# WHAT IT SKIPS (never touched):
#   * .git                    (history kept; the 'origin' remote IS removed)
#   * local / generated       (local.properties, build/, .gradle/, .idea/,
#                              log/, tmp/, storage/, .ruby-lsp/)
#   * secrets                 (master.key + credentials.yml.enc, only when
#                              STRIP_SECRETS=1). If stripped, run
#                              bin/rails credentials:edit in the new project.
#
# AFTER RUNNING:
#   1. git remote add origin <your-new-repo-url>
#   2. git add -A && git commit              (records the rename)
#   3. bin/dev + run the Android app from mobile/android (Android Studio
#      recreates its own local.properties)
# =============================================================================

namespace :scaffold do
  desc "Rename this clone in place for a new project and drop the origin remote"
  task :rename do
    repo_root = File.expand_path("../..", __dir__)

    old_slug, old_camel, old_pkg = detect_current_name(repo_root)

    slug    = ENV.fetch("SLUG", File.basename(repo_root)).to_s.strip.downcase
    slug    = slug.gsub(/[^a-z0-9_]/, "_")
    abort "SLUG is empty after sanitising" if slug.empty?
    camel   = slug.split("_").map(&:capitalize).join
    package = ENV.fetch("PACKAGE", "com.example.#{slug}").to_s.strip
    abort "PACKAGE must end with .#{slug} (got #{package})" unless package.end_with?(".#{slug}")

    puts "Renaming #{old_camel} (#{old_pkg}) -> #{camel} (#{package})"

    # Most-specific first, so the package string is replaced before the bare slug.
    content_repls = [
      [ old_pkg,  package ],
      [ old_slug.upcase, slug.upcase ], # e.g. ENV["XANNHAEL_DATABASE_PASSWORD"]
      [ old_slug, slug ],
      [ old_camel, camel ]
    ]
    path_repls = [
      [ old_pkg.tr(".", "/"),  package.tr(".", "/") ],
      [ old_slug, slug ],
      [ old_camel, camel ]
    ]

    strip_secrets = ENV["STRIP_SECRETS"] == "1"

    excluded = %w[
      .git log tmp storage .ruby-lsp
      mobile/android/app/build mobile/android/build
      mobile/android/.gradle mobile/android/.idea
      mobile/android/local.properties
    ]
    if strip_secrets
      excluded += %w[config/master.key config/credentials.yml.enc]
    end

    rename_in_place(repo_root, excluded, content_repls, path_repls)

    drop_origin_remote(repo_root)

    puts "\nDone. Next steps:"
    puts "  1. git remote add origin <your-new-repo-url>"
    puts "  2. git add -A && git commit    (records the rename)"
    puts "  3. bin/dev + run the Android app from mobile/android"
    puts "     (Android Studio recreates its own local.properties)"
    if strip_secrets
      puts "  4. bin/rails credentials:edit  (secrets were stripped; the new"
      puts "     project needs a `database` key to boot in the devcontainer)"
    else
      puts "  Credentials were kept (needed to boot). If you stripped/need fresh"
      puts "  ones: bin/rails credentials:edit  (add the `database` key)."
    end
  end

  # Detects the current app identifiers from the repo content.
  def detect_current_name(root)
    gkts = File.read(File.join(root, "mobile/android/app/build.gradle.kts"))
    old_pkg = gkts[/namespace\s*=\s*"([^"]+)"/, 1]
    app_rb = File.read(File.join(root, "config/application.rb"))
    old_camel = app_rb[/module\s+([A-Z]\w*)/, 1]
    abort "Could not detect the current app name. Is this a scaffold clone?" if old_pkg.nil? || old_camel.nil?

    [ old_pkg.split(".").last, old_camel, old_pkg ]
  end

  # Renames paths and rewrites contents in place, then prunes empty directories.
  def rename_in_place(root, excluded, content_repls, path_repls)
    files = Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH).select { |p| File.file?(p) }
    files.each do |src|
      rel = rel_of(root, src)
      next if excluded.any? { |e| rel == e || rel.start_with?("#{e}/") }
      next if binary?(src)

      dst = File.join(root, *rel_path(rel, path_repls).split("/"))
      content = File.read(src, encoding: "UTF-8")
      content_repls.each { |a, b| content = content.gsub(a, b) }

      if dst == src
        File.write(dst, content)
      else
        FileUtils.mkdir_p(File.dirname(dst))
        File.write(dst, content)
        FileUtils.rm(src)
      end
    end
    remove_empty_dirs(root)
  end

  def rel_of(root, path)
    File.expand_path(path).sub(File.expand_path(root), "").sub(%r{\A[/\\]}, "").tr("\\", "/")
  end

  def rel_path(rel, path_repls)
    new_rel = rel.dup
    path_repls.each { |a, b| new_rel = new_rel.sub(a, b) }
    new_rel
  end

  def binary?(path)
    File.binread(path, 8192).include?("\x00")
  rescue StandardError
    true
  end

  # Removes directories left empty by the rename (e.g. the old package dirs),
  # never touching anything inside .git.
  def remove_empty_dirs(root)
    loop do
      removed = false
      Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH)
         .select { |p| File.directory?(p) }
         .sort_by { |p| -p.length }
         .each do |d|
        next if d.include?("/.git/") || d.end_with?("/.git")
        next unless Dir.empty?(d)

        Dir.rmdir(d)
        removed = true
      rescue Errno::ENOTEMPTY, Errno::ENOENT
        nil
      end
      break unless removed
    end
  end

  # Removes the 'origin' remote (a clone of the template points at the template
  # repo); the user adds their own remote afterwards.
  def drop_origin_remote(root)
    if !Dir.exist?(File.join(root, ".git"))
      puts "Not a git clone (.git missing); skipped removing 'origin'."
      return
    end
    remotes = `git -C #{Shellwords.escape(root)} remote`
    if remotes.lines.map(&:strip).include?("origin")
      system("git", "-C", root, "remote", "remove", "origin")
      puts "Removed git remote 'origin' (template repo)."
    else
      puts "No 'origin' remote to remove."
    end
  end
end
