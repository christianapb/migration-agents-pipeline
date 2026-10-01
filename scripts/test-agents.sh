#!/usr/bin/env bash
# Corre las pruebas con agentes en paralelo, cada una en su propio workspace.
#
# Uso: scripts/test-agents.sh [agente ...]
#   Sin argumentos corre todas. Con nombres de agente (migration-tl-specs, ...)
#   corre solo las pruebas que tocan esos agentes.
#
# Cada prueba es un script tests/test-*.sh o una comprobación de etapa
# (stage:<etapa>): restaurar la instantánea de esa etapa y pasar su verificador.
# Antes de empezar construye las instantáneas (scripts/snapshot.sh build pm);
# solo se rehacen las etapas cuyos prompts cambiaron.
#
# Variables: JOBS (pruebas simultáneas, por defecto 3), LOG_DIR (por defecto
# .work/logs), WS_DIR (por defecto .work/ws), DRY_RUN=1 (solo lista),
# SKIP_BUILD=1 (no construye instantáneas), TESTS_DIR y RESTORE_CMD (para
# probar este script).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TESTS="${TESTS_DIR:-$ROOT/scripts}"
RESTORE="${RESTORE_CMD:-bash $ROOT/scripts/snapshot.sh restore}"
LOGS="${LOG_DIR:-$ROOT/.work/logs}"
WSS="${WS_DIR:-$ROOT/.work/ws}"
JOBS="${JOBS:-3}"

declare -A MAP=(
  [migration-indexer]="test-indexer-claude"
  [migration-analyst]="stage:analyst test-analyst"
  [migration-tl-adrs]="stage:tl-adrs"
  [migration-tl-specs]="stage:tl-specs test-tl-specs"
  [migration-tl-tasks]="stage:tl-tasks test-tl-tasks"
  [migration-qa]="stage:qa"
  [migration-pm]="stage:pm"
  [migration-tl-resolver]="test-resolver"
  [migration-orchestrator]="test-orchestrator"
  [migration-auditor]="test-auditor"
)
ORDER=(migration-indexer migration-analyst migration-tl-adrs migration-tl-specs migration-tl-tasks migration-qa migration-pm migration-tl-resolver migration-orchestrator migration-auditor)

agents=("$@")
[ "${#agents[@]}" -gt 0 ] || agents=("${ORDER[@]}")
selected=()
for a in "${agents[@]}"; do
  [ -n "${MAP[$a]+x}" ] || { echo "ERROR: agente desconocido: $a (conocidos: ${ORDER[*]})" >&2; exit 1; }
  for t in ${MAP[$a]}; do
    case " ${selected[*]:-} " in *" $t "*) ;; *) selected+=("$t") ;; esac
  done
done

if [ "${DRY_RUN:-0}" = 1 ]; then printf '%s\n' "${selected[@]}"; exit 0; fi

if [ "${SKIP_BUILD:-0}" != 1 ]; then
  echo "Construyendo instantáneas (solo lo que cambió)..."
  bash "$ROOT/scripts/snapshot.sh" build pm || { echo "ERROR: no se pudieron construir las instantáneas" >&2; exit 1; }
fi

mkdir -p "$LOGS" "$WSS"
run_one() {
  local t="$1" ws log
  ws="$WSS/${t//:/-}"
  log="$LOGS/${t//:/-}.log"
  if [[ "$t" == stage:* ]]; then
    local s="${t#stage:}"
    { $RESTORE "$s" "$ws" && WORKDIR="$ws" bash "$TESTS/verify-$s.sh"; } > "$log" 2>&1
  else
    WORKDIR="$ws" bash "$TESTS/$t.sh" > "$log" 2>&1
  fi
  echo $? > "$log.rc"
}

start=$(date +%s)
for t in "${selected[@]}"; do
  while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do wait -n; done
  echo "iniciada: $t"
  run_one "$t" &
done
wait

echo
echo "Resultado ($(( $(date +%s) - start )) s):"
failed=0
for t in "${selected[@]}"; do
  log="$LOGS/${t//:/-}.log"
  rc="$(cat "$log.rc" 2>/dev/null || echo 1)"
  if [ "$rc" = 0 ]; then
    echo "  OK    $t"
  else
    echo "  FAIL  $t (código $rc, log: $log)"
    grep -E '^(FAIL|ERROR)' "$log" | head -5 | sed 's/^/          /'
    failed=$((failed+1))
  fi
done
[ "$failed" -eq 0 ] || { echo "$failed prueba(s) fallaron."; exit 1; }
echo "Todas las pruebas pasaron."
