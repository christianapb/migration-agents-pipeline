#!/usr/bin/env bash
# Caso 3 del spec v2: se detiene con ADRs propuestos y continúa forzado.
# Requiere un workspace con specs y al menos un ADR propuesto (tras Task 5).
set -uo pipefail
# Activa las comprobaciones de los verificadores propias del fixture
export FIXTURE="${FIXTURE:-1}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
export WORKDIR="$W"
SNAP_TMP="$(mktemp -d)"
trap 'rm -rf "$SNAP_TMP"' EXIT
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
run() { bash "$ROOT/scripts/run-agent.sh" "$@"; rc=$?; [ $rc -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }; return $rc; }
bash "$ROOT/scripts/snapshot.sh" restore tl-specs "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa tl-specs"; exit 1; }
snap() { find "$M" -type f -print0 | sort -z | xargs -0 md5sum; }

grep -lq '^estado: propuesto' "$M"/adr/*.md || { echo "FAIL: el workspace no tiene ADRs propuestos"; exit 1; }
rm -rf "$M/tasks"
snap > "$SNAP_TMP/snap-a.txt"
out="$(run migration-tl-tasks "Ejecútalo con destino Kotlin.")"
snap > "$SNAP_TMP/snap-b.txt"
diff -q "$SNAP_TMP/snap-a.txt" "$SNAP_TMP/snap-b.txt" >/dev/null || fail "escribió tareas con ADRs propuestos"
printf '%s' "$out" | grep -q 'migration-tl-resolver' || fail "no dio el prompt para migration-tl-resolver"

run migration-tl-tasks "Ejecútalo con destino Kotlin, aunque haya ADRs propuestos." >/dev/null
bash "$ROOT/scripts/verify-tl-tasks.sh" || fail "verify-tl-tasks falla en la corrida forzada"

[ "$fails" -eq 0 ] && { echo "OK: tl-tasks (parada y forzado)"; exit 0; }
exit 1
