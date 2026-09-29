#!/usr/bin/env bash
# Caso 9 del spec v2 y Review Focus 4. Prepara sus propios estados.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/.work/sample-workspace"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
run() { bash "$ROOT/scripts/run-agent.sh" "$@"; rc=$?; [ $rc -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }; return $rc; }
snap() { find "$W" -path "$W/*/.git" -prune -o -type f -print0 | sort -z | xargs -0 md5sum; }
orq() {
  snap > "$ROOT/.work/snap-a.txt"
  out="$(run migration-orchestrator)"
  snap > "$ROOT/.work/snap-b.txt"
  diff -q "$ROOT/.work/snap-a.txt" "$ROOT/.work/snap-b.txt" >/dev/null || fail "$1: el orquestador escribió archivos"
  for s in '## Estado' '## Pendiente de revisión' '## Desactualizado' '## Siguiente paso'; do
    printf '%s' "$out" | grep -q "^$s" || fail "$1: falta '$s'"
  done
  next="$(printf '%s' "$out" | awk '/^## Siguiente paso/{f=1;next} f')"
}

# RF4: carpeta sin CLAUDE.md
bash "$ROOT/scripts/fixture-reset.sh" >/dev/null
orq "sin indexar"
printf '%s' "$next" | grep -q 'migration-indexer' || fail "sin indexar: no recomienda migration-indexer"

# Estado 1: tras el indexador
run migration-indexer >/dev/null
orq "tras indexer"
printf '%s' "$next" | grep -q 'migration-analyst' || fail "tras indexer: no recomienda migration-analyst"

# Estado 2: ADRs propuestos pendientes
run migration-analyst >/dev/null
run migration-tl-adrs "Ejecútalo con destino Kotlin." >/dev/null
P="$(grep -l '^estado: propuesto' "$M"/adr/*.md | head -n1 | xargs basename | cut -c1-4)"
orq "ADRs propuestos"
printf '%s' "$out" | grep -q "$P" || fail "ADRs propuestos: no lista el ADR $P"
printf '%s' "$next" | grep -Eq 'migration-tl-resolver|migration-tl-specs' || fail "ADRs propuestos: siguiente paso inesperado"

# Estado 3: plan más antiguo que su spec
run migration-tl-specs >/dev/null
run migration-tl-tasks "Ejecútalo con destino Kotlin, aunque haya ADRs propuestos." >/dev/null
run migration-qa >/dev/null
S="$(ls "$M"/specs | grep -v '^_' | head -n1 | sed 's/\.md$//')"
sleep 2; touch "$M/specs/$S.md"
orq "plan desactualizado"
printf '%s' "$out" | awk '/^## Desactualizado/{f=1;next} /^## /{f=0} f' | grep -q "$S" || fail "plan desactualizado: no marca $S"

[ "$fails" -eq 0 ] && { echo "OK: orchestrator"; exit 0; }
exit 1
