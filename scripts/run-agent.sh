#!/usr/bin/env bash
# Ejecuta un subagente en el workspace de prueba con claude -p.
# Uso: scripts/run-agent.sh <nombre-agente> [texto adicional para el prompt]
# Variables: WORKDIR (carpeta donde correr; por defecto .work/sample-workspace)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AGENT="${1:?nombre del agente}"
shift || true
EXTRA="${*:-}"
DIR="${WORKDIR:-$ROOT/.work/sample-workspace}"

cd "$DIR"
claude -p "Invoca el subagente $AGENT con la herramienta Agent, sobre la carpeta actual. $EXTRA Cuando termine, reproduce su resumen final tal cual y no hagas nada más." \
  --dangerously-skip-permissions
