#!/usr/bin/env bash
# El recorrido que abarata poner QA antes que las tareas: resolver un hallazgo
# de QA cuando todavía no hay tareas solo obliga a repetir el plan de esa
# capacidad. Parte de la etapa qa, que no tiene tareas.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
export WORKDIR="$W"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
run() { bash "$ROOT/scripts/run-agent.sh" "$@"; rc=$?; [ $rc -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }; return $rc; }
. "$ROOT/scripts/lib-rev.sh"
ids() { grep -oE '^(- )?(RN|CB)-[0-9]+:' "$1" | sed -E 's/^- //; s/:$//' | sort -u; }

bash "$ROOT/scripts/snapshot.sh" restore qa "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa qa"; exit 1; }
ls "$M"/tasks/T-*.md >/dev/null 2>&1 && { echo "FAIL: la etapa qa contiene tareas; el orden de etapas no es el nuevo"; exit 1; }
grep -lE '^tareas:|^- Tareas:' "$M"/test-plans/[!_]*.md >/dev/null 2>&1 && fail "la etapa qa tiene planes que citan tareas"

# Hallazgos sin resolver por capacidad: el dato que dice cuánto se ahorra
echo "--- hallazgos H-n por capacidad en la etapa qa:"
C=""
for p in "$M"/test-plans/[!_]*.md; do
  n="$(grep -E '^- \*\*H-[0-9]+\*\*' "$p" | grep -vc '(resuelto' || true)"
  echo "    $(basename "$p" .md): $n"
  [ -z "$C" ] && [ "$n" -gt 0 ] && C="$(basename "$p" .md)"
done

# 1. Cambia el spec: resuelve un hallazgo o, si el fixture no produjo ninguno, añade una regla
if [ -n "$C" ]; then
  H="$(grep -oE '^- \*\*H-[0-9]+\*\*' "$M/test-plans/$C.md" | head -n1 | grep -oE 'H-[0-9]+')"
  antes="$(ids "$M/specs/$C.md")"; v0="$(rev_de "$M/specs/$C.md")"
  run migration-tl-resolver "Resuelve el hallazgo $H del plan $C: se mantiene el comportamiento que hoy tiene el código; regístralo en el spec como un caso borde nuevo." >/dev/null
  echo "--- resuelto $H del plan $C"
  grep -q '^estado: revisado' "$M/test-plans/$C.md" && fail "resolver un hallazgo dejó el plan $C en revisado: migration-qa no podrá regenerarlo"
else
  C="$(ls "$M"/specs | grep -v '^_' | head -n1 | sed 's/\.md$//')"
  antes="$(ids "$M/specs/$C.md")"; v0="$(rev_de "$M/specs/$C.md")"
  echo "--- el fixture no produjo hallazgos; se añade una regla al spec $C"
fi
NUEVA="$(comm -13 <(printf '%s\n' "$antes") <(ids "$M/specs/$C.md") | tail -n1)"
if [ -z "$NUEVA" ]; then
  run migration-tl-resolver "En el spec $C añade un caso borde: una petición con la cabecera X-Trace-Id vacía se procesa igual que sin ella." >/dev/null
  NUEVA="$(comm -13 <(printf '%s\n' "$antes") <(ids "$M/specs/$C.md") | tail -n1)"
fi
[ -n "$NUEVA" ] || { echo "FAIL: el resolver no añadió ninguna regla ni caso borde al spec $C"; exit 1; }
v1="$(rev_de "$M/specs/$C.md")"
[ "$v1" -gt "$v0" ] || fail "el spec $C cambió y su rev no subió ($v0 → $v1)"
echo "--- regla nueva: $NUEVA en $C (rev $v0 → $v1)"

# 2. Repite QA solo para esa capacidad y consolida la cobertura
otros="$(for p in "$M"/test-plans/[!_]*.md; do [ "$(basename "$p" .md)" = "$C" ] || md5sum "$p"; done)"
run migration-qa "Solo la capacidad $C." >/dev/null
run migration-qa "Solo la cobertura." >/dev/null
[ "$(campo "$M/test-plans/$C.md" spec_rev)" = "$v1" ] || fail "el plan $C anota spec_rev '$(campo "$M/test-plans/$C.md" spec_rev)' y el spec tiene rev $v1"
grep -q "\b$NUEVA\b" "$M/test-plans/$C.md" || fail "el plan $C no cubre la regla nueva $NUEVA"
[ "$(for p in "$M"/test-plans/[!_]*.md; do [ "$(basename "$p" .md)" = "$C" ] || md5sum "$p"; done)" = "$otros" ] || fail "repetir QA para $C cambió los planes de otras capacidades"
grep -lE '^tareas:|^- Tareas:' "$M"/test-plans/[!_]*.md >/dev/null 2>&1 && fail "algún plan cita tareas"
ls "$M"/tasks/T-*.md >/dev/null 2>&1 && fail "aparecieron tareas antes de ejecutar migration-tl-tasks"

# 3. Genera las tareas, una sola vez
run migration-tl-tasks "Ejecútalo con destino Kotlin, aunque haya ADRs propuestos." >/dev/null
bash "$ROOT/scripts/verify-tl-tasks.sh" >/dev/null || fail "las tareas no pasan el verificador"
grep -l "^spec: $C$" "$M"/tasks/T-*.md 2>/dev/null | xargs -r grep -l "\b$NUEVA\b" >/dev/null || fail "ninguna tarea de $C cita la regla nueva $NUEVA"
sin_plan="$(grep -L '^## Pruebas' $(grep -lE '^spec: .+' "$M"/tasks/T-*.md) 2>/dev/null | wc -l)"
[ "$sin_plan" -eq 0 ] || fail "$sin_plan tareas de capacidad sin la sección Pruebas que apunta a su plan"
bash "$ROOT/scripts/verify-qa.sh" >/dev/null || fail "los planes no pasan el verificador tras generar las tareas"

# 4. Nada quedó desactualizado
out="$(run migration-orchestrator)"
d="$(printf '%s' "$out" | awk '/^## Desactualizado/{f=1;next} /^## /{f=0} f' | grep -v '^[[:space:]]*$' || true)"
printf '%s\n' "$d" | grep -Eqx -- '-? ?Nada\.?' && [ "$(printf '%s\n' "$d" | grep -c .)" -eq 1 ] \
  || fail "tras el recorrido el orquestador lista desactualizados: $(printf '%s' "$d" | head -n3 | cut -c1-200)"

[ "$fails" -eq 0 ] && { echo "OK: hallazgo resuelto antes de generar tareas"; exit 0; }
exit 1
