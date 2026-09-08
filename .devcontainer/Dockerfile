# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=4.0.2
FROM ghcr.io/rails/devcontainer/images/ruby:$RUBY_VERSION

# Ensure binding is always 0.0.0.0
# Binds the server to all IP addresses of the container, so it can be accessed from outside the container.
ENV BINDING="0.0.0.0"

# Make mise-managed Ruby tooling (ruby/gem/bundle shims) reachable in non-login
# shells so the devcontainer feature stage and scripts find gem during build.
# HOME is pinned too: build steps run as root, and mise otherwise looks in
# /root/.local/share/mise, finding no tools.
ENV HOME="/home/vscode" \
    PATH="/home/vscode/.local/bin:/home/vscode/.local/share/mise/shims:${PATH}"

# gawk required: the codex installer breaks on Debian's mawk
# tmux is a runtime dependency of overmind (it runs the Procfile in a tmux session)
USER root
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y gawk tmux && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Pin bundler to the version used to generate Gemfile.lock (BUNDLED WITH).
# Without this, the first `bundle` run on a fresh container self-installs the
# matching bundler and prints "Installing Bundler ... and restarting".
RUN gem install bundler -v "4.0.7" --no-document

# Overmind: runs Procfile.dev in a tmux session, replacing foreman
RUN curl -fsSL https://github.com/DarthSim/overmind/releases/download/v2.5.1/overmind-v2.5.1-linux-amd64.gz | \
    gzip -d > /usr/local/bin/overmind && \
    chmod +x /usr/local/bin/overmind && \
    test -x /usr/local/bin/overmind

# Codex CLI (standalone binary, no Node). CODEX_HOME pins the package under the persistent volume.
RUN curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_HOME=/home/vscode/.codex CODEX_INSTALL_DIR=/usr/local/bin sh && \
    test -x /usr/local/bin/codex

# OpenCode CLI: installer hardcodes $HOME/.opencode/bin, so symlink it onto /usr/local/bin
RUN export HOME=/home/vscode && \
    curl -fsSL https://opencode.ai/install | bash && \
    ln -sf /home/vscode/.opencode/bin/opencode /usr/local/bin/opencode && \
    test -x /usr/local/bin/opencode

# Pre-create persistent state dirs owned by vscode so the named volumes stay writable
RUN mkdir -p /home/vscode/.codex \
             /home/vscode/.config/opencode \
             /home/vscode/.local/share/opencode && \
    chown -R vscode:vscode /home/vscode/.codex \
                           /home/vscode/.config/opencode \
                           /home/vscode/.local/share/opencode

USER vscode