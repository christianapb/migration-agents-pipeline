#!/usr/bin/env bash
# Ejecuta un agente en el workspace de prueba con claude -p, arrancando la
# sesión directamente como ese agente (--agent), sin sesión intermedia.
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
PROMPT="Ejecuta tu tarea sobre la carpeta actual. ${EXTRA:+$EXTRA }Termina con tu resumen final."
out="$(claude -p "$PROMPT" --agent "$AGENT" --no-session-persistence \
  --dangerously-skip-permissions < /dev/null 2>&1)"
status=$?
printf '%s\n' "$out"
# Solo el aviso propio de Claude ("You've hit your weekly limit · resets ...") al inicio de una
# línea y en una respuesta corta; un resumen legítimo que mencione "rate limit" no dispara.
if [ "${#out}" -lt 600 ] && printf '%s\n' "$out" | grep -Eq "^You('ve| have)? hit your [a-z ]*limit"; then
  echo "ERROR: claude respondió con un aviso de límite de uso; la corrida de $AGENT no se ejecutó." >&2
  exit 2
fi
exit "$status"
