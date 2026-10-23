#!/usr/bin/env bash
# Normalize new or existing named volumes once; later rebuilds skip the walk.
set -euo pipefail

initialize_volume() {
  local volume_path="$1"
  local marker="${volume_path}/.xannhael-owner-initialized"
  local owner
  owner="$(id -u):$(id -g)"

  if [[ ! -d "$volume_path" ]]; then
    echo "ERROR: expected mounted volume at $volume_path" >&2
    return 1
  fi

  if [[ -r "$marker" ]] && [[ "$(cat "$marker")" == "$owner" ]]; then
    return 0
  fi

  sudo chown -R vscode:vscode "$volume_path"
  printf '%s\n' "$owner" > "$marker"
  echo "[init-volumes] ownership set for $volume_path"
}

initialize_volume /usr/local/bundle
initialize_volume /home/vscode/.local/share

mkdir -p \
  storage \
  /home/vscode/.local/share/.config/git \
  /home/vscode/.local/share/.config/gh \
  /home/vscode/.local/share/gh/extensions \
  /home/vscode/.local/share/.config/opencode \
  /home/vscode/.local/share/.state/opencode \
  /home/vscode/.local/share/.cache/opencode \
  /home/vscode/.local/share/codex
