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

# Estado 1b: un índice de repositorio incompleto; el paso 1 no está completado
printf '> Índice incompleto: falta desde src/routes\n' >> "$W/bff/index.md"
orq "índice incompleto"
printf '%s' "$next" | grep -q 'migration-indexer' || fail "índice incompleto: el siguiente paso no es migration-indexer"
printf '%s' "$next" | grep -q 'migration-analyst' && fail "índice incompleto: recomienda migration-analyst sobre un índice parcial"
printf '%s' "$out" | grep -q 'bff' || fail "índice incompleto: no nombra el repositorio bff"

# Estado 2: ADRs propuestos pendientes
bash "$ROOT/scripts/snapshot.sh" restore tl-adrs "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa tl-adrs"; exit 1; }
P="$(grep -l '^estado: propuesto' "$M"/adr/*.md | head -n1 | xargs basename | cut -c1-4)"
orq "ADRs propuestos"
printf '%s' "$out" | grep -q "$P" || fail "ADRs propuestos: no lista el ADR $P"
printf '%s' "$next" | grep -Eq 'migration-tl-resolver|migration-tl-specs' || fail "ADRs propuestos: siguiente paso inesperado"
# Con el mapa y los ADRs hechos y ningún spec: propone el paralelo con todas las capacidades
printf '%s' "$next" | grep -qi 'en paralelo' || fail "specs pendientes: no propone lanzarlos en paralelo"
for c in $(grep -oE '^\| [a-z0-9-]+ \|' "$M/specs/_capacidades.md" | sed -E 's/^\| //; s/ \|$//'); do
  printf '%s' "$next" | grep -q "migration-tl-specs, solo la capacidad $c" || fail "specs pendientes: el paralelo no incluye la capacidad $c"
done

# Auditoría mínima y válida, para que el orquestador no recomiende antes el auditor
planta_auditoria() {
  local f s
  {
    printf '# Auditoría de specs\n\nGenerado: 2026-10-04 por migration-auditor.\n\n## Resumen\n\n'
    printf '| Capacidad | Reglas | Respaldadas | Sin respaldo | Contradichas | No localizables | Decisiones | Omitidos |\n|---|---|---|---|---|---|---|---|\n'
    for f in "$M"/specs/[!_]*.md; do printf '| %s | 0 | 0 | 0 | 0 | 0 | 0 | 0 |\n' "$(basename "$f" .md)"; done
    for f in "$M"/specs/[!_]*.md; do
      s="$(basename "$f" .md)"
      printf '\n## %s\n\nAuditada: 2026-10-04. Spec rev: %s.\n\n| Regla | Veredicto | Cita | Nota |\n|---|---|---|---|\n\n### Hallazgos\n\nNinguno.\n' "$s" "$(sed -n 's/^rev:[[:space:]]*//p' "$f" | head -n1)"
    done
  } > "$M/specs/_auditoria.md"
}
caps() { ls "$M"/specs | grep -v '^_' | sed 's/\.md$//'; }

# Estado 2b: specs hechos, ADRs propuestos, sin planes ni tareas: QA no espera a los ADRs
bash "$ROOT/scripts/snapshot.sh" restore tl-specs "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa tl-specs"; exit 1; }
grep -lq '^estado: propuesto' "$M"/adr/*.md || fail "QA antes de ADRs: el workspace no tiene ADRs propuestos"
planta_auditoria
orq "QA con ADRs propuestos"
printf '%s' "$next" | grep -qi 'en paralelo' || fail "QA con ADRs propuestos: no propone lanzar QA en paralelo"
for c in $(caps); do
  printf '%s' "$next" | grep -q "migration-qa, solo la capacidad $c" || fail "QA con ADRs propuestos: el paralelo no incluye la capacidad $c"
done
printf '%s' "$next" | grep -q 'migration-tl-resolver\|ADR' || fail "QA con ADRs propuestos: no menciona decidir los ADRs como camino alternativo"
printf '%s' "$next" | grep -q 'Usa el subagente migration-tl-tasks' && fail "QA con ADRs propuestos: manda a migration-tl-tasks antes que a QA"

# Estado 2c: planes hechos, ADRs propuestos: ahora sí toca decidirlos
bash "$ROOT/scripts/snapshot.sh" restore qa "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa qa"; exit 1; }
ls "$M"/tasks/T-*.md >/dev/null 2>&1 && fail "la etapa qa contiene tareas; el orden de etapas no es el nuevo"
planta_auditoria
orq "planes hechos y ADRs propuestos"
printf '%s' "$next" | grep -q 'Usa el subagente migration-tl-resolver' || fail "planes hechos y ADRs propuestos: el siguiente paso no es decidir los ADRs con el resolver"

# Estado 2d: planes hechos y ADRs decididos: migration-tl-tasks va en serie
sed -i 's/^estado: propuesto/estado: revisado/' "$M"/adr/*.md
sed -i 's/^destino:.*/destino: Kotlin/' "$M/README.md"
orq "tareas pendientes"
printf '%s' "$next" | grep -q 'migration-tl-tasks' || fail "tareas pendientes: el siguiente paso no es migration-tl-tasks"
printf '%s' "$next" | grep -q 'migration-tl-tasks, solo la capacidad' && fail "tareas pendientes: reparte migration-tl-tasks por capacidad"
printf '%s' "$next" | grep -i 'en paralelo' | grep -q 'migration-tl-tasks' && fail "tareas pendientes: propone migration-tl-tasks en paralelo"

# Estado 3: lo desactualizado se decide por versiones, no por fechas
. "$ROOT/scripts/lib-rev.sh"
# Etapa tl-tasks: specs, planes y tareas (los planes van antes que las tareas)
qa_ws() { bash "$ROOT/scripts/snapshot.sh" restore tl-tasks "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa tl-tasks"; exit 1; }; }
desact() { printf '%s' "$out" | awk '/^## Desactualizado/{f=1;next} /^## /{f=0} f' | grep -v '^[[:space:]]*$' || true; }
nada() { # <caso>
  local d; d="$(desact)"
  printf '%s\n' "$d" | grep -Eqx -- '-? ?Nada\.?' && [ "$(printf '%s\n' "$d" | grep -c .)" -eq 1 ] \
    || fail "$1: se esperaba 'Nada' en Desactualizado y dice: $(printf '%s' "$d" | head -n3 | cut -c1-200)"
}
ids_de() { xargs -r -n1 basename | grep -oE '^T-[0-9]+' | sort -u; }
qa_ws
S="$(ls "$M"/specs | grep -v '^_' | head -n1 | sed 's/\.md$//')"
OTROS="$(ls "$M"/specs | grep -v '^_' | sed 's/\.md$//' | grep -vx "$S")"

# 3.1 Sin tocar nada
orq "sin cambios"
nada "sin cambios"
out_base="$out"

# 3.2 Cambia la fecha de modificación de un spec, no su contenido
sleep 2; touch "$M/specs/$S.md"
orq "touch de un spec"
nada "touch de un spec"

# 3.3 Sube el rev de un spec: marca su plan y sus tareas, y nada de otros specs
qa_ws
sed -i "s/^rev: .*/rev: $(( $(rev_de "$M/specs/$S.md") + 1 ))/" "$M/specs/$S.md"
orq "rev de un spec"
d="$(desact)"
printf '%s' "$d" | grep -q "$S" || fail "rev de un spec: no marca el plan de $S"
for t in $(grep -l "^spec: $S$" "$M"/tasks/T-*.md | ids_de); do
  printf '%s' "$d" | grep -q "\b$t\b" || fail "rev de un spec: no marca la tarea $t de $S"
done
for o in $OTROS; do
  printf '%s' "$d" | grep -q "$o" && fail "rev de un spec: marca también $o"
done
for t in $(grep -L "^spec: $S$" "$M"/tasks/T-*.md | ids_de); do
  printf '%s' "$d" | grep -q "\b$t\b" && fail "rev de un spec: marca la tarea $t, que no es de $S"
done
# La regeneración empieza por el plan: planes antes que tareas
printf '%s' "$next" | grep -m1 'Usa el subagente' | grep -q 'migration-qa' || fail "rev de un spec: el primer prompt no regenera el plan con migration-qa"

# 3.4 Cambia solo el estado de un spec a revisado
qa_ws
sed -i 's/^estado: generado/estado: revisado/' "$M/specs/$S.md"
orq "solo cambio de estado"
nada "solo cambio de estado"

# 3.5 Sube el rev de un ADR: marca solo las tareas que lo citan
qa_ws
total="$(ls "$M"/tasks/T-*.md | wc -l)"; ADR=""
for a in "$M"/adr/*.md; do
  id="$(campo "$a" id)"
  n="$(grep -lE "^adrs:.*\b$id\b" "$M"/tasks/T-*.md 2>/dev/null | wc -l)"
  if [ "$n" -gt 0 ] && [ "$n" -lt "$total" ]; then ADR="$a"; break; fi
done
if [ -z "$ADR" ]; then
  fail "rev de un ADR: ningún ADR está citado por una parte de las tareas"
else
  id="$(campo "$ADR" id)"
  sed -i "s/^rev: .*/rev: $(( $(rev_de "$ADR") + 1 ))/" "$ADR"
  orq "rev de un ADR"
  d="$(desact)"
  for t in $(grep -lE "^adrs:.*\b$id\b" "$M"/tasks/T-*.md | ids_de); do
    printf '%s' "$d" | grep -q "\b$t\b" || fail "rev de un ADR: no marca la tarea $t, que cita el ADR $id"
  done
  for t in $(grep -LE "^adrs:.*\b$id\b" "$M"/tasks/T-*.md | ids_de); do
    printf '%s' "$d" | grep -q "\b$t\b" && fail "rev de un ADR: marca la tarea $t, que no cita el ADR $id"
  done
fi

# 3.6 Completitud por capacidad: sin tareas para una capacidad, el paso 6 no está completo
qa_ws
grep -l "^spec: $S$" "$M"/tasks/T-*.md | while IFS= read -r f; do rm -- "$f"; done
orq "capacidad sin tareas"
printf '%s' "$out" | grep -E '^Faltan:' | grep -q "$S" || fail "capacidad sin tareas: la línea Faltan no nombra $S"
printf '%s' "$next" | grep -q 'migration-tl-tasks\|migration-tl-resolver' || fail "capacidad sin tareas: siguiente paso inesperado"

# 3.7 Artefacto sin versión: no se puede determinar
qa_ws
sed -i '/^rev:/d' "$M/specs/$S.md"
orq "spec sin versión"
desact | grep -q 'no se puede determinar' || fail "spec sin versión: no dice 'no se puede determinar'"
printf '%s' "$out" | grep -q 'registra las versiones' || fail "spec sin versión: no ofrece 'registra las versiones'"

# 3.8 Añadir una tarea a un spec no desactualiza su plan
qa_ws
T0="$(grep -l "^spec: $S$" "$M"/tasks/T-*.md | head -n1)"
sed -e 's/^id: T-[0-9]*/id: T-900/' -e 's/^titulo: .*/titulo: Tarea añadida a mano/' -e 's/^# T-[0-9]*:.*/# T-900: Tarea añadida a mano/' "$T0" > "$M/tasks/T-900-tarea-anadida-a-mano.md"
orq "tarea nueva en un spec"
desact | grep -q 'test-plans\|[Pp]lan' && fail "tarea nueva en un spec: marca algún plan como desactualizado: $(desact | head -n2 | cut -c1-200)"
nada "tarea nueva en un spec"

# 3.9 Proyecto del orden anterior: tareas y ningún plan
qa_ws
rm -rf "$M/test-plans"
orq "tareas sin planes"
printf '%s' "$next" | grep -q 'migration-qa' || fail "tareas sin planes: el siguiente paso no es migration-qa"
printf '%s' "$next" | grep -q 'Usa el subagente migration-tl-tasks' && fail "tareas sin planes: pide regenerar las tareas"
desact | grep -q 'T-[0-9]' && fail "tareas sin planes: lista tareas como desactualizadas"

qa_ws
out="$out_base"
grep -rqE '^(- )?MJ-[0-9]+:' "$M"/specs/[!_]*.md || fail "paridad: el workspace no tiene mejoras MJ-n para probar al orquestador"
printf '%s' "$out" | awk '/^## Pendiente de revisión/{f=1;next} /^## /{f=0} f' | grep -q 'MJ-[0-9]' && fail "paridad: el orquestador lista mejoras MJ-n como pendientes de revisión"

# Estado 4: con el destino ya en el README, los prompts no lo repiten
sed -i 's/^destino:.*/destino: {bff: Kotlin, frontend: conservar}/' "$M/README.md"
orq "destino en el README"
printf '%s' "$next" | grep -q 'con destino' && fail "destino en el README: el prompt recomendado repite 'con destino'"
printf '%s' "$out" | awk '/^## Pendiente de revisión/{f=1;next} /^## /{f=0} f' | grep -qi 'destino.*vac' && fail "destino en el README: sigue listando el destino como pendiente"

[ "$fails" -eq 0 ] && { echo "OK: orchestrator"; exit 0; }
exit 1
