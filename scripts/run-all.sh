#!/usr/bin/env bash
# Flujo completo sobre el fixture: reset, cuatro agentes, cuatro verificadores.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
bash scripts/check-agent.sh
bash scripts/fixture-reset.sh
bash scripts/run-agent.sh migration-indexer
bash scripts/verify-indexer.sh
bash scripts/run-agent.sh migration-techlead "Ejecútalo con destino Kotlin."
bash scripts/verify-techlead.sh
bash scripts/run-agent.sh migration-qa
bash scripts/verify-qa.sh
bash scripts/run-agent.sh migration-pm
bash scripts/verify-pm.sh
echo "OK: flujo completo"
