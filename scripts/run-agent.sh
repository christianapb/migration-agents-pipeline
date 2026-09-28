#!/usr/bin/env bash
# Ejecuta un subagente en el workspace de prueba con claude -p.
# Uso: scripts/run-agent.sh <nombre-agente> [texto adicional para el prompt]
# Variables: WORKDIR (carpeta donde correr; por defecto .work/sample-workspace)
# Sale con 2 si claude responde con un aviso de límite de uso: la corrida no
# se ejecutó y ningún verificador debe darla por buena.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AGENT="${1:?nombre del agente}"
shift || true
EXTRA="${*:-}"
DIR="${WORKDIR:-$ROOT/.work/sample-workspace}"

cd "$DIR"
out="$(claude -p "Invoca el subagente $AGENT con la herramienta Agent, sobre la carpeta actual. $EXTRA Cuando termine, reproduce su resumen final tal cual y no hagas nada más." \
  --dangerously-skip-permissions < /dev/null 2>&1)"
status=$?
printf '%s\n' "$out"
if printf '%s' "$out" | grep -Eqi "hit your (weekly|daily|usage)? ?limit|usage limit|rate limit"; then
  echo "ERROR: claude respondió con un aviso de límite de uso; la corrida de $AGENT no se ejecutó." >&2
  exit 2
fi
exit "$status"
