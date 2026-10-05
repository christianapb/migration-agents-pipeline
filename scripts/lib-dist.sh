#!/usr/bin/env bash
# Scripts que se entregan a quien usa el flujo. Se instalan en
# <proyecto>/.claude/migration/, junto a <proyecto>/.claude/agents/.
# Uso: source scripts/lib-dist.sh

DIST_SCRIPTS=(
  backlog.sh verificar.sh lib-rev.sh lib-destino.sh
  verify-indexer.sh verify-analyst.sh verify-tl-adrs.sh verify-tl-specs.sh
  verify-qa.sh verify-tl-tasks.sh verify-auditor.sh verify-pm.sh
)

# copiar_scripts <carpeta scripts/ de origen> <proyecto>
copiar_scripts() {
  local src="$1" dest="$2/.claude/migration" s
  mkdir -p "$dest"
  for s in "${DIST_SCRIPTS[@]}"; do
    cp "$src/$s" "$dest/$s" || return 1
  done
}
