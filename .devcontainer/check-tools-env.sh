#!/usr/bin/env bash
# Falla con mensaje explicito si faltan credenciales de herramientas en .env.
# .env es la unica fuente de verdad (compose lo carga via env_file).
set -uo pipefail

ENV_FILE="${ENV_FILE:-${WORKSPACE_DIR:-/workspaces/project}/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: no existe $ENV_FILE" >&2
  echo "Copia la plantilla con: cp .env.example .env y rellena los valores." >&2
  exit 1
fi

# has_value VAR: true si existe una linea no comentada VAR=<valor no vacio>.
# Acepta prefijo opcional `export ` y rechaza lineas comentadas y
# valores vacios (VAR=, VAR="", VAR='').
has_value() {
  local var="$1" line rest val
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line%$'\r'}
    if [[ "$line" =~ ^[[:space:]]*# ]]; then
      continue
    fi
    if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?$var[[:space:]]*=[[:space:]]*(.*)$ ]]; then
      rest=${BASH_REMATCH[2]}
      rest=$(printf '%s' "$rest" | sed -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//')
      # Valor ausente o solo comentario -> seguir buscando otras lineas.
      if [[ -z "$rest" || "$rest" == \#* ]]; then
        continue
      fi
      # Corta comentario final ` #...` solo si el valor no empieza por comilla.
      if [[ "$rest" != '"'* && "$rest" != "'"* ]]; then
        rest=${rest%%\ #*}
      fi
      val=$(printf '%s' "$rest" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
      if [[ -z "$val" ]]; then
        continue
      fi
      if [[ "$val" == '""' ]]; then
        continue
      fi
      if [[ "$val" == "''" ]]; then
        continue
      fi
      return 0
    fi
  done < "$ENV_FILE"
  return 1
}

fail=0

if ! has_value "OPENAI_API_KEY"; then
  echo "ERROR: falta la variable OPENAI_API_KEY en .env (codex)" >&2
  fail=1
fi

if ! has_value "GITHUB_TOKEN" && ! has_value "GH_TOKEN"; then
  echo "ERROR: falta la variable GITHUB_TOKEN o GH_TOKEN en .env (basta una de las dos para gh CLI)" >&2
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  echo "Rellena las variables en .env y reconstruye el devcontainer." >&2
  exit 1
fi

echo "[check-tools-env] ok: OPENAI_API_KEY y GITHUB_TOKEN/GH_TOKEN presentes en $ENV_FILE"
