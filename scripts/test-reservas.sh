#!/usr/bin/env bash
# Cadena completa sobre el segundo fixture (reservas-workspace: monolito Flask
# con SQLite, páginas en servidor y un proceso programado), con destino Go.
# Verifica cada etapa con su verificador más los hechos y las trampas de
# fixtures/hechos/reservas-workspace.txt, y deja un informe de qué hizo el
# flujo con la base de datos, el esquema y el proceso programado.
#
# Dos tramos: hasta specs y auditor; y, solo si eso sale bien, hasta el backlog.
# Variables: HASTA=specs detiene tras el primer tramo. CONOCIDOS: ids de hechos
# o trampas que se informan como fallo conocido sin hacer fallar la prueba.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export FIXTURE=1 FIXTURE_NAME=reservas-workspace
unset HECHOS
W="${WORKDIR:-$ROOT/.work/ws/test-reservas}"
export WORKDIR="$W"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
snap() { bash "$ROOT/scripts/snapshot.sh" "$@"; }
etapa() { # construye la etapa, la restaura y pasa su verificador
  local s="$1" out
  out="$(snap build "$s" 2>&1)" || {
    printf '%s\n' "$out" | tail -n3
    printf '%s' "$out" | grep -q 'código 2' && { echo "ERROR: límite de uso, repetir"; exit 2; }
    fail "no se pudo construir la etapa $s"; return 1; }
  snap restore "$s" "$W" >/dev/null || { fail "no se pudo restaurar la etapa $s"; return 1; }
  if bash "$ROOT/scripts/verify-$s.sh" > "$W/.verify-$s.log" 2>&1; then
    echo "  OK    $s$(grep -h '^---' "$W/.verify-$s.log" | sed 's/^---/ ·/' | paste -sd' ' -)"
    grep -h '^CONOCIDO' "$W/.verify-$s.log" | sed 's/^/        /'
  else
    echo "  FALLA $s"; grep -hE '^(FAIL|CONOCIDO|---)' "$W/.verify-$s.log" | sed 's/^/        /'
    fails=$((fails+1)); return 1
  fi
}
cuenta() { grep -rliE "$1" "$2" 2>/dev/null | wc -l; }

echo "== Tramo 1: hasta specs y auditor"
for s in indexer analyst tl-adrs tl-specs; do etapa "$s" || true; done

if [ -d "$M/specs" ] && ls "$M"/specs/[!_]*.md >/dev/null 2>&1; then
  snap restore tl-specs "$W" >/dev/null
  bash "$ROOT/scripts/run-agent.sh" migration-auditor >/dev/null; rc=$?
  [ "$rc" -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }
  if bash "$ROOT/scripts/verify-auditor.sh" > "$W/.verify-auditor.log" 2>&1; then echo "  OK    auditor"; else echo "  FALLA auditor"; grep -h '^FAIL' "$W/.verify-auditor.log" | sed 's/^/        /'; fails=$((fails+1)); fi
  echo "--- auditoría:"; awk '/^## Resumen/{f=1;next} /^## /{f=0} f' "$M/specs/_auditoria.md" | grep '^|' | sed 's/^/    /'
  echo "--- hallazgos del auditor: $(grep -c '^- \*\*AU-' "$M/specs/_auditoria.md")"
  grep '^- \*\*AU-' "$M/specs/_auditoria.md" | cut -c1-220 | sed 's/^/    /'
  mkdir -p "$ROOT/.work/reservas-informe"; cp "$M/specs/_auditoria.md" "$ROOT/.work/reservas-informe/_auditoria.md"

  echo "--- capacidades: $(grep -oE '^\| [a-z0-9-]+ \|' "$M/specs/_capacidades.md" | sed -E 's/^\| //; s/ \|$//' | paste -sd' ' -)"
  echo "--- ADRs: $(ls "$M"/adr/*.md | wc -l) ($(grep -l '^estado: propuesto' "$M"/adr/*.md | wc -l) propuestos)"
  grep -h '^titulo:' "$M"/adr/*.md | sed 's/^titulo: /    /' | cut -c1-110
  echo "--- qué hizo el flujo con las piezas que no tiene instrucciones para tratar:"
  for par in "base de datos y esquema:SQLite|esquema|schema\.sql|migraci" "proceso programado:cron|proceso programado|caducar_reservas|planificad" "consulta SQL con regla:mantenimiento"; do
    n="${par%%:*}"; re="${par#*:}"
    echo "    $n: en $(cuenta "$re" "$M/specs/_capacidades.md") mapa, $(cuenta "$re" "$M/adr") ADRs, $(cuenta "$re" "$M/specs") specs"
  done
fi

if [ "$fails" -gt 0 ]; then
  echo "El primer tramo falló: no se continúa hasta el backlog."
  exit 1
fi
[ "${HASTA:-}" = specs ] && { echo "OK: reservas (hasta specs y auditor)"; exit 0; }

echo "== Tramo 2: hasta el backlog"
for s in qa tl-tasks pm; do etapa "$s" || true; done
if [ -d "$M/tasks" ]; then
  echo "--- tareas: $(ls "$M"/tasks/T-*.md 2>/dev/null | wc -l)"
  for par in "base de datos y migración de datos:SQLite|esquema|migraci.n de datos|base de datos" "proceso programado:cron|proceso programado|caduc"; do
    n="${par%%:*}"; re="${par#*:}"
    echo "    $n: en $(cuenta "$re" "$M/tasks") tareas"
  done
  grep -h '^titulo:' "$M"/tasks/T-*.md | sed 's/^titulo: /    /' | cut -c1-110
fi

[ "$fails" -eq 0 ] && { echo "OK: reservas (cadena completa)"; exit 0; }
exit 1
