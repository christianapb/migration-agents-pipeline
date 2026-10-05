#!/usr/bin/env bash
# Flujo completo v2 sobre el fixture, con una ronda del resolver.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export WORKDIR="$ROOT/.work/sample-workspace" FIXTURE=1
. scripts/lib-dist.sh
M=.work/sample-workspace/migration
bash scripts/check-agent.sh
bash scripts/fixture-reset.sh
copiar_scripts "$ROOT/scripts" "$WORKDIR"
bash scripts/run-agent.sh migration-indexer;   bash scripts/verify-indexer.sh
bash scripts/run-agent.sh migration-analyst;   bash scripts/verify-analyst.sh
bash scripts/run-agent.sh migration-tl-adrs "Ejecútalo con destino Kotlin."; bash scripts/verify-tl-adrs.sh
ids="$(grep -l '^estado: propuesto' "$M"/adr/*.md | xargs -n1 basename | cut -c1-4 | paste -sd, -)"
bash scripts/run-agent.sh migration-tl-resolver "Fija el destino en Kotlin. En los ADRs $ids acepta la recomendación."
REQUIRE_PROPUESTO=0 bash scripts/verify-tl-adrs.sh
bash scripts/run-agent.sh migration-tl-specs;  bash scripts/verify-tl-specs.sh
bash scripts/run-agent.sh migration-qa;        bash scripts/verify-qa.sh
bash scripts/run-agent.sh migration-tl-tasks;  bash scripts/verify-tl-tasks.sh
bash scripts/run-agent.sh migration-pm;        bash scripts/verify-pm.sh
echo "OK: flujo completo"
