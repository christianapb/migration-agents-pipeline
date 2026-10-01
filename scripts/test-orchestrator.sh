#!/usr/bin/env bash
# Caso 9 del spec v2 y Review Focus 4. Prepara sus propios estados.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
export WORKDIR="$W"
SNAP_TMP="$(mktemp -d)"
trap 'rm -rf "$SNAP_TMP"' EXIT
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
run() { bash "$ROOT/scripts/run-agent.sh" "$@"; rc=$?; [ $rc -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }; return $rc; }
snap() { find "$W" -path "$W/*/.git" -prune -o -type f -print0 | sort -z | xargs -0 md5sum; }
orq() {
  snap > "$SNAP_TMP/snap-a.txt"
  out="$(run migration-orchestrator)"
  snap > "$SNAP_TMP/snap-b.txt"
  diff -q "$SNAP_TMP/snap-a.txt" "$SNAP_TMP/snap-b.txt" >/dev/null || fail "$1: el orquestador escribió archivos"
  for s in '## Estado' '## Pendiente de revisión' '## Desactualizado' '## Siguiente paso'; do
    printf '%s' "$out" | grep -q "^$s" || fail "$1: falta '$s'"
  done
  next="$(printf '%s' "$out" | awk '/^## Siguiente paso/{f=1;next} f')"
}

# RF4: carpeta sin CLAUDE.md
bash "$ROOT/scripts/snapshot.sh" restore fixture "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa fixture"; exit 1; }
orq "sin indexar"
printf '%s' "$next" | grep -q 'migration-indexer' || fail "sin indexar: no recomienda migration-indexer"

# Estado 1: tras el indexador
bash "$ROOT/scripts/snapshot.sh" restore indexer "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa indexer"; exit 1; }
orq "tras indexer"
printf '%s' "$next" | grep -q 'migration-analyst' || fail "tras indexer: no recomienda migration-analyst"

# Estado 2: ADRs propuestos pendientes
bash "$ROOT/scripts/snapshot.sh" restore tl-adrs "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa tl-adrs"; exit 1; }
P="$(grep -l '^estado: propuesto' "$M"/adr/*.md | head -n1 | xargs basename | cut -c1-4)"
orq "ADRs propuestos"
printf '%s' "$out" | grep -q "$P" || fail "ADRs propuestos: no lista el ADR $P"
printf '%s' "$next" | grep -Eq 'migration-tl-resolver|migration-tl-specs' || fail "ADRs propuestos: siguiente paso inesperado"

# Estado 3: plan más antiguo que su spec
bash "$ROOT/scripts/snapshot.sh" restore qa "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa qa"; exit 1; }
S="$(ls "$M"/specs | grep -v '^_' | head -n1 | sed 's/\.md$//')"
sleep 2; touch "$M/specs/$S.md"
orq "plan desactualizado"
printf '%s' "$out" | awk '/^## Desactualizado/{f=1;next} /^## /{f=0} f' | grep -q "$S" || fail "plan desactualizado: no marca $S"
grep -rqE '^(- )?MJ-[0-9]+:' "$M"/specs/[!_]*.md || fail "paridad: el workspace no tiene mejoras MJ-n para probar al orquestador"
printf '%s' "$out" | awk '/^## Pendiente de revisión/{f=1;next} /^## /{f=0} f' | grep -q 'MJ-[0-9]' && fail "paridad: el orquestador lista mejoras MJ-n como pendientes de revisión"

[ "$fails" -eq 0 ] && { echo "OK: orchestrator"; exit 0; }
exit 1
