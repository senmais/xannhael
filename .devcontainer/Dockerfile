# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=4.0.2
FROM ghcr.io/rails/devcontainer/images/ruby:$RUBY_VERSION

# Ensure binding is always 0.0.0.0
ENV BINDING="0.0.0.0"

# Make mise-managed Ruby tooling reachable in non-login shells.
ENV HOME="/home/vscode" \
    PATH="/home/vscode/.local/bin:/home/vscode/.local/share/mise/shims:${PATH}"

USER root
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y gawk tmux libvips-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Pin bundler to the version used to generate Gemfile.lock (BUNDLED WITH).
RUN gem install bundler -v "4.0.7" --no-document

# Overmind: runs Procfile.dev in a tmux session, replacing foreman
RUN curl -fsSL https://github.com/DarthSim/overmind/releases/download/v2.5.1/overmind-v2.5.1-linux-amd64.gz | \
    gzip -d > /usr/local/bin/overmind && \
    chmod +x /usr/local/bin/overmind && \
    test -x /usr/local/bin/overmind

# Codex CLI (standalone binary, no Node). CODEX_HOME pins the package under the persistent volume.
RUN curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_HOME=/home/vscode/.codex CODEX_INSTALL_DIR=/usr/local/bin sh && \
    test -x /usr/local/bin/codex

# OpenCode V2 CLI: dedicated V2 installer. Keep the binary on PATH for all shells.
RUN export HOME=/home/vscode && \
    curl -fsSL https://opencode.ai/v2/install | bash && \
    ln -sf /home/vscode/.opencode/bin/opencode /usr/local/bin/opencode && \
    test -x /usr/local/bin/opencode && /usr/local/bin/opencode --version

# Pre-create persistent state dirs owned by vscode so the named volumes stay writable.
# NOTE: OpenCode uses ~/.local/state/opencode/service.json (XDG state),
# not just config/share, so the state dir must exist and be owned by vscode.
RUN mkdir -p /home/vscode/.codex \
               /home/vscode/.config/opencode \
               /home/vscode/.local/share/opencode \
               /home/vscode/.local/state/opencode && \
      chown -R vscode:vscode /home/vscode/.codex \
                             /home/vscode/.config/opencode \
                             /home/vscode/.local/share/opencode \
                             /home/vscode/.local/state/opencode

USER vscode
