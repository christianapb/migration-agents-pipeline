#!/usr/bin/env bash
# Pruebas rápidas y, si pasan, todas las pruebas con agentes en paralelo.
# Para la verificación completa antes de una PR, correr además scripts/run-all.sh.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
bash "$ROOT/scripts/test-fast.sh" || exit 1
bash "$ROOT/scripts/test-agents.sh" "$@"
