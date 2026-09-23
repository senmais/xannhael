# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=4.0.2
# Pinned OpenCode v2 version (https://opencode.ai/v2/docs,
# migration notes: https://opencode.ai/v2/docs/migrate-v1/).
# Override at build time with: docker build --build-arg OPENCODE_VERSION=2.x.y .
ARG OPENCODE_VERSION=2.0.15
FROM ghcr.io/rails/devcontainer/images/ruby:$RUBY_VERSION
ARG OPENCODE_VERSION

# Ensure binding is always 0.0.0.0 so the server is reachable from outside
# the container.
ENV BINDING="0.0.0.0"

# Make mise-managed Ruby tooling (ruby/gem/bundle shims) reachable in non-login
# shells so the devcontainer feature stage and scripts find gem during build.
# HOME is pinned too: build steps run as root, and mise otherwise looks in
# /root/.local/share/mise, finding no tools.
ENV HOME="/home/vscode" \
    PATH="/home/vscode/.local/bin:/home/vscode/.local/share/mise/shims:${PATH}"

# gawk: the codex installer breaks on Debian's mawk.
# tmux: runtime dependency of overmind (runs Procfile.dev in a tmux session).
# libvips: runtime for the ruby-vips gem (image_processing 2.x, FFI — no -dev
#   headers needed).
# libpq-dev + pkg-config: compile the pg gem.
USER root
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y gawk tmux libvips libpq-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Pin bundler to the version used to generate Gemfile.lock (BUNDLED WITH).
# Without this, the first `bundle` run on a fresh container self-installs the
# matching bundler and prints "Installing Bundler ... and restarting".
RUN gem install bundler -v "4.0.7" --no-document

# Overmind: runs Procfile.dev in a tmux session, replacing foreman.
RUN curl -fsSL https://github.com/DarthSim/overmind/releases/download/v2.5.1/overmind-v2.5.1-linux-amd64.gz | \
    gzip -d > /usr/local/bin/overmind && \
    chmod +x /usr/local/bin/overmind && \
    test -x /usr/local/bin/overmind

# Codex CLI (standalone binary, no Node). CODEX_HOME pins the package under
# the persistent volume.
RUN curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_HOME=/home/vscode/.codex CODEX_INSTALL_DIR=/usr/local/bin sh && \
    test -x /usr/local/bin/codex

# OpenCode v2 CLI. V2 replaces the V1 binary at the same path
# ($HOME/.opencode/bin/opencode), so a fresh build is the migration — there is
# no side-by-side install. --no-modify-path keeps the image's shell rc files
# clean; the /usr/local/bin symlink below puts it on PATH instead.
RUN export HOME=/home/vscode && \
    curl -fsSL https://opencode.ai/v2/install | bash -s -- --version "${OPENCODE_VERSION}" --no-modify-path && \
    ln -sf /home/vscode/.opencode/bin/opencode /usr/local/bin/opencode && \
    test -x /usr/local/bin/opencode && /usr/local/bin/opencode --version

# Pre-create state directories owned by vscode.
#
# Docker named volumes are created as root, and the RUN steps above execute as
# root with HOME=/home/vscode, so anything created under $HOME would otherwise
# stay root-owned. A root-owned ~/.local/state/opencode, for example, makes
# the v2 background service fail with "Server process exited with code 1"
# because it cannot write service.json. The postCreateCommand chown covers the
# same paths as a second layer of defence for pre-existing volumes.
RUN mkdir -p /home/vscode/.codex \
             /home/vscode/.config/opencode \
             /home/vscode/.local/share/opencode \
             /home/vscode/.local/state/opencode && \
    chown -R vscode:vscode /home/vscode/.codex \
                           /home/vscode/.config/opencode \
                           /home/vscode/.local/share/opencode \
                           /home/vscode/.local/state

USER vscode
