#!/usr/bin/env bash
# Caso 1 del spec v2: el bloque se reemplaza y el texto ajeno se conserva.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/.work/sample-workspace"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

bash "$ROOT/scripts/fixture-reset.sh" >/dev/null
printf '# Notas del equipo\n\nTexto previo del equipo.\n\n<!-- migration-flow:begin -->\nCONTENIDO-VIEJO\n<!-- migration-flow:end -->\n\n## Final del equipo\nTexto posterior del equipo.\n' > "$W/CLAUDE.md"
# README en formato v1: el indexador debe actualizarlo (hallazgo 3 de la revisión)
mkdir -p "$W/migration"
printf -- '---\ndestino: Kotlin\ngenerado: 2026-09-28\n---\n# Migración\n\n## Flujo\n1. [x] migration-indexer\n2. [ ] migration-techlead\n\n## Repos detectados\n- bff: viejo\n\n## Cómo continuar\nUsa el subagente migration-techlead con destino Kotlin.\n' > "$W/migration/README.md"
bash "$ROOT/scripts/run-agent.sh" migration-indexer >/dev/null
rc=$?; [ $rc -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }

pre="$(awk '/^<!-- migration-flow:begin -->$/{exit} {print}' "$W/CLAUDE.md")"
post="$(awk 'f{print} /^<!-- migration-flow:end -->$/{f=1}' "$W/CLAUDE.md")"
[ "$pre" = "$(printf '# Notas del equipo\n\nTexto previo del equipo.\n')" ] || fail "texto previo al bloque alterado"
[ "$post" = "$(printf '\n## Final del equipo\nTexto posterior del equipo.')" ] || fail "texto posterior al bloque alterado"
grep -q 'CONTENIDO-VIEJO' "$W/CLAUDE.md" && fail "el contenido viejo del bloque no se reemplazó"
bash "$ROOT/scripts/verify-indexer.sh" || fail "verify-indexer falla tras reemplazar el bloque"
RM="$W/migration/README.md"
grep -q '^## Flujo' "$RM" && fail "README v1: conserva ## Flujo"
grep -q 'migration-techlead' "$RM" && fail "README v1: sigue mencionando migration-techlead"
grep -q '^excluir:' "$RM" || fail "README v1: no añadió excluir"
grep -q '^destino: Kotlin$' "$RM" || fail "README v1: perdió destino"
grep -qF -- '- bff: viejo' "$RM" || fail "README v1: tocó Repos detectados"

[ "$fails" -eq 0 ] && { echo "OK: bloque de CLAUDE.md"; exit 0; }
exit 1
