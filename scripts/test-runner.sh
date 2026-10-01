#!/usr/bin/env bash
# Prueba test-agents.sh con pruebas falsas: selección por agente, paralelismo
# acotado por JOBS, un workspace por prueba, logs y código de salida.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

T="$TMP/tests"; mkdir -p "$T"
# Prueba falsa: registra su workspace, marca inicio y fin, dura 2 s.
fake() {
  local name="$1" result="$2"
  cat > "$T/$name.sh" <<EOF
#!/usr/bin/env bash
echo "\$WORKDIR" > "$TMP/$name.wd"
echo "\$(date +%s%N) 1" >> "$TMP/events"
sleep 2
echo "\$(date +%s%N) -1" >> "$TMP/events"
$result
EOF
}
for n in test-indexer-claude test-analyst test-tl-specs test-tl-tasks test-orchestrator test-auditor; do
  fake "$n" 'echo "OK"'
done
fake test-resolver 'echo "FAIL: falla a propósito"; exit 1'
for s in analyst tl-adrs tl-specs tl-tasks qa pm; do
  printf '#!/usr/bin/env bash\necho "OK: %s"\n' "$s" > "$T/verify-$s.sh"
done
export TESTS_DIR="$T" SKIP_BUILD=1 RESTORE_CMD=true LOG_DIR="$TMP/logs" WS_DIR="$TMP/ws"

# 1. Selección por agente
sel="$(DRY_RUN=1 bash "$ROOT/scripts/test-agents.sh" migration-tl-specs | sort | paste -sd, -)"
[ "$sel" = "stage:tl-specs,test-tl-specs" ] || fail "selección de migration-tl-specs incorrecta: $sel"
sel="$(DRY_RUN=1 bash "$ROOT/scripts/test-agents.sh" migration-tl-resolver | paste -sd, -)"
[ "$sel" = "test-resolver" ] || fail "selección de migration-tl-resolver incorrecta: $sel"
DRY_RUN=1 bash "$ROOT/scripts/test-agents.sh" migration-inventado >/dev/null 2>&1 && fail "aceptó un agente desconocido"
n="$(DRY_RUN=1 bash "$ROOT/scripts/test-agents.sh" | grep -c .)"
[ "$n" -eq 13 ] || fail "sin argumentos seleccionó $n pruebas, se esperaban 13"
sel="$(DRY_RUN=1 bash "$ROOT/scripts/test-agents.sh" migration-auditor | paste -sd, -)"
[ "$sel" = "test-auditor" ] || fail "selección de migration-auditor incorrecta: $sel"

# 2. Ejecución: paralela hasta JOBS, un workspace por prueba, falla si alguna falla
out="$(JOBS=3 bash "$ROOT/scripts/test-agents.sh" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || fail "terminó con 0 aunque test-resolver falló"
printf '%s' "$out" | grep -q 'FAIL.*test-resolver' || fail "el resumen no nombra la prueba fallida"
printf '%s' "$out" | grep -q 'OK.*test-analyst' || fail "el resumen no lista las pruebas que pasan"
maxc="$(sort -n "$TMP/events" | awk '{c+=$2; if (c>m) m=c} END {print m+0}')"
[ "$maxc" -ge 2 ] || fail "no corre en paralelo (concurrencia máxima $maxc)"
[ "$maxc" -le 3 ] || fail "supera JOBS=3 (concurrencia máxima $maxc)"
[ -f "$LOG_DIR/test-resolver.log" ] || fail "no dejó log por prueba"
[ "$(cat "$TMP"/test-*.wd | sort -u | grep -c .)" -eq 7 ] || fail "las pruebas no usan workspaces distintos"

[ "$fails" -eq 0 ] && { echo "OK: runner"; exit 0; }
exit 1
