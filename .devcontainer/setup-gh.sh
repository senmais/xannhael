#!/usr/bin/env bash
# Configura Git + gh CLI de forma idempotente (seguro correrlo en cada rebuild).
set -euo pipefail

WORKSPACE_DIR="${WORKSPACE_DIR:-/workspaces/project}"

# 0. Preparar directorios persistentes.
mkdir -p \
  /home/vscode/.config/git \
  /home/vscode/.config/gh \
  /home/vscode/.local/share/gh/extensions

# 1. El workspace viene bind-mounteado desde el host: evitar "dubious ownership".
if ! git config --global --get-all safe.directory 2>/dev/null | grep -qFx "$WORKSPACE_DIR"; then
  git config --global --add safe.directory "$WORKSPACE_DIR"
fi

command -v gh >/dev/null 2>&1 || {
  echo "[setup-gh] gh CLI no instalado, salto configuracion"
  exit 0
}

# 2. Dentro del devcontainer usamos siempre HTTPS.
#    Evita depender de claves SSH del host.
gh config set git_protocol https --host github.com

git config --global --unset-all url.git@github.com:.insteadOf 2>/dev/null || true
git config --global --unset-all url."ssh://git@github.com/".insteadOf 2>/dev/null || true

if ! git config --global --get-all url."https://github.com/".insteadOf 2>/dev/null | grep -qFx "git@github.com:"; then
  git config --global --add url."https://github.com/".insteadOf "git@github.com:"
fi

if ! git config --global --get-all url."https://github.com/".insteadOf 2>/dev/null | grep -qFx "ssh://git@github.com/"; then
  git config --global --add url."https://github.com/".insteadOf "ssh://git@github.com/"
fi

# 3. Extensiones GitHub CLI.
#    Son repos publicos y deben instalarse aunque todavia no exista autenticacion.
if gh extension list 2>/dev/null | awk '{print $1}' | grep -qFx "dlvhdr/gh-dash"; then
  echo "[setup-gh] gh-dash ya instalado"
else
  echo "[setup-gh] instalando gh-dash..."
  gh extension install https://github.com/dlvhdr/gh-dash
fi

if gh extension list 2>/dev/null | awk '{print $1}' | grep -qFx "basecamp/gh-signoff"; then
  echo "[setup-gh] gh-signoff ya instalado"
else
  echo "[setup-gh] instalando gh-signoff..."
  gh extension install https://github.com/basecamp/gh-signoff
fi

# 4. Autenticacion GitHub.
#    GITHUB_TOKEN/GH_TOKEN llegan via compose env_file desde el .env del proyecto.
if gh auth status --hostname github.com >/dev/null 2>&1; then
  echo "[setup-gh] gh autenticado: $(gh api user --jq .login 2>/dev/null || echo ok)"

  # Usa gh como credential-helper para operaciones Git HTTPS.
  gh auth setup-git --hostname github.com || true
else
  echo "[setup-gh] GitHub CLI sin autenticacion"
  echo "[setup-gh] rellena GITHUB_TOKEN o GH_TOKEN en .env o ejecuta: gh auth login"
fi

echo "[setup-gh] listo"
