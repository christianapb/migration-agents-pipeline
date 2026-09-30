#!/usr/bin/env bash
# Caso 3 del spec v2: se detiene con ADRs propuestos y continúa forzado.
# Requiere un workspace con specs y al menos un ADR propuesto (tras Task 5).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/.work/sample-workspace"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
run() { bash "$ROOT/scripts/run-agent.sh" "$@"; rc=$?; [ $rc -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }; return $rc; }
snap() { find "$M" -type f -print0 | sort -z | xargs -0 md5sum; }

grep -lq '^estado: propuesto' "$M"/adr/*.md || { echo "FAIL: el workspace no tiene ADRs propuestos"; exit 1; }
rm -rf "$M/tasks"
snap > "$ROOT/.work/snap-a.txt"
out="$(run migration-tl-tasks "Ejecútalo con destino Kotlin.")"
snap > "$ROOT/.work/snap-b.txt"
diff -q "$ROOT/.work/snap-a.txt" "$ROOT/.work/snap-b.txt" >/dev/null || fail "escribió tareas con ADRs propuestos"
printf '%s' "$out" | grep -q 'migration-tl-resolver' || fail "no dio el prompt para migration-tl-resolver"

run migration-tl-tasks "Ejecútalo con destino Kotlin, aunque haya ADRs propuestos." >/dev/null
bash "$ROOT/scripts/verify-tl-tasks.sh" || fail "verify-tl-tasks falla en la corrida forzada"

[ "$fails" -eq 0 ] && { echo "OK: tl-tasks (parada y forzado)"; exit 0; }
exit 1
