#!/usr/bin/env bash
# Paralelo real: varias corridas con alcance a la vez en el mismo workspace.
# 1. migration-tl-specs para las tres capacidades del fixture.
# 2. migration-qa para las tres capacidades y, después, solo la cobertura.
set -uo pipefail
# Activa las comprobaciones de los verificadores propias del fixture
export FIXTURE="${FIXTURE:-1}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
export WORKDIR="$W"
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
hash_dir() { find "$1" -type f -print0 | sort -z | xargs -0 md5sum | md5sum; }

# Lanza el agente una vez por capacidad, todas a la vez, y espera.
paralelo() { # <agente> <capacidades...>
  local agente="$1" s; shift
  for s in "$@"; do
    ( bash "$ROOT/scripts/run-agent.sh" "$agente" "Solo la capacidad $s." > "$TMPD/$agente-$s.out" 2>&1; echo $? > "$TMPD/$agente-$s.rc" ) &
  done
  wait
  for s in "$@"; do
    [ "$(cat "$TMPD/$agente-$s.rc" 2>/dev/null)" = 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }
  done
  return 0
}

# --- 1. Specs en paralelo
bash "$ROOT/scripts/snapshot.sh" restore tl-adrs "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa tl-adrs"; exit 1; }
mapfile -t CAPS < <(grep -oE '^\| [a-z0-9-]+ \|' "$M/specs/_capacidades.md" | sed -E 's/^\| //; s/ \|$//')
[ "${#CAPS[@]}" -ge 2 ] || { echo "FAIL: el mapa tiene menos de dos capacidades"; exit 1; }
ls "$M"/specs/[!_]*.md >/dev/null 2>&1 && { echo "FAIL: la etapa tl-adrs ya tiene specs"; exit 1; }
h_mapa="$(md5sum < "$M/specs/_capacidades.md")"; h_adr="$(hash_dir "$M/adr")"
echo "--- lanzando migration-tl-specs a la vez para: ${CAPS[*]}"
paralelo migration-tl-specs "${CAPS[@]}"
for s in "${CAPS[@]}"; do [ -f "$M/specs/$s.md" ] || fail "specs: falta specs/$s.md"; done
[ "$(ls "$M"/specs/[!_]*.md 2>/dev/null | wc -l)" -eq "${#CAPS[@]}" ] || fail "specs: hay $(ls "$M"/specs/[!_]*.md 2>/dev/null | wc -l) specs para ${#CAPS[@]} capacidades"
[ "$(md5sum < "$M/specs/_capacidades.md")" = "$h_mapa" ] || fail "specs: alguna corrida modificó _capacidades.md"
[ "$(hash_dir "$M/adr")" = "$h_adr" ] || fail "specs: alguna corrida modificó los ADRs"
bash "$ROOT/scripts/verify-tl-specs.sh" || fail "specs: verify-tl-specs falla tras el paralelo"

# --- 2. Planes en paralelo y cobertura consolidada
# Etapa tl-specs: specs sin planes ni tareas. QA no necesita tareas.
bash "$ROOT/scripts/snapshot.sh" restore tl-specs "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa tl-specs"; exit 1; }
rm -rf "$M/test-plans"
mapfile -t CAPS < <(ls "$M"/specs | grep -v '^_' | sed 's/\.md$//')
h_specs="$(hash_dir "$M/specs")"
echo "--- lanzando migration-qa a la vez para: ${CAPS[*]}"
paralelo migration-qa "${CAPS[@]}"
for s in "${CAPS[@]}"; do [ -f "$M/test-plans/$s.md" ] || fail "qa: falta test-plans/$s.md"; done
[ -f "$M/test-plans/_cobertura.md" ] && fail "qa: una corrida con alcance escribió _cobertura.md"
[ "$(hash_dir "$M/specs")" = "$h_specs" ] || fail "qa: alguna corrida modificó los specs"
ls "$M"/tasks/T-*.md >/dev/null 2>&1 && fail "qa: alguna corrida escribió tareas"
grep -lE '^tareas:|^- Tareas:' "$M"/test-plans/[!_]*.md >/dev/null 2>&1 && fail "qa: algún plan cita tareas"
rm -f "$M/test-plans/_cobertura.md"
h_planes="$(hash_dir "$M/test-plans")"
bash "$ROOT/scripts/run-agent.sh" migration-qa "Solo la cobertura." >/dev/null
[ $? -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }
[ -f "$M/test-plans/_cobertura.md" ] || fail "cobertura: 'solo la cobertura' no escribió _cobertura.md"
cp "$M/test-plans/_cobertura.md" "$TMPD/cob.md" 2>/dev/null; rm -f "$M/test-plans/_cobertura.md"
[ "$(hash_dir "$M/test-plans")" = "$h_planes" ] || fail "cobertura: 'solo la cobertura' modificó algún plan"
cp "$TMPD/cob.md" "$M/test-plans/_cobertura.md" 2>/dev/null
bash "$ROOT/scripts/verify-qa.sh" || fail "qa: verify-qa falla tras el paralelo y la consolidación"

[ "$fails" -eq 0 ] && { echo "OK: paralelo (specs y planes)"; exit 0; }
exit 1
