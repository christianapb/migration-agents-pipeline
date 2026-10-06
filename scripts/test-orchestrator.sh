#!/usr/bin/env bash
# Diagnóstico del orquestador en estados preparados por la propia prueba.
#
# Las comprobaciones leen la sección "## Datos" de la respuesta (agente, motivo,
# alcance, paralelo, faltan, desactualizado, sin-version), no su prosa: la
# redacción cambia de una corrida a otra y los datos no deben hacerlo.
# (Datos incluye además sin-numerar.)
# Cada caso deja el workspace en un estado que no depende de lo que el modelo
# generó en esa instantánea (preguntas abiertas, hallazgos, destino).
#
# Variables: CASOS (lista de casos a ejecutar, separados por espacio; por
# defecto todos), ORQ_LOG (carpeta donde guardar la respuesta de cada caso).
set -uo pipefail
# Activa las comprobaciones de los verificadores propias del fixture
export FIXTURE="${FIXTURE:-1}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
export WORKDIR="$W"
SNAP_TMP="$(mktemp -d)"
trap 'rm -rf "$SNAP_TMP"' EXIT
M="$W/migration"
. "$ROOT/scripts/lib-rev.sh"
fails=0
CASO=""
fail() { echo "FAIL: $CASO: $*"; fails=$((fails+1)); }
run() { bash "$ROOT/scripts/run-agent.sh" "$@"; rc=$?; [ $rc -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }; return $rc; }
snap() { find "$W" -path "$W/*/.git" -prune -o -type f -print0 | sort -z | xargs -0 md5sum; }
quiere() { [ -z "${CASOS:-}" ] || case " $CASOS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
etapa() { bash "$ROOT/scripts/snapshot.sh" restore "$1" "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa $1"; exit 1; }; }

# Ejecuta el orquestador y deja su respuesta en $out. Comprueba que no escribió
# nada y que la respuesta tiene las secciones y los siete datos.
orq() {
  CASO="$1"
  snap > "$SNAP_TMP/snap-a.txt"
  out="$(run migration-orchestrator)"
  snap > "$SNAP_TMP/snap-b.txt"
  [ -n "${ORQ_LOG:-}" ] && { mkdir -p "$ORQ_LOG"; printf '%s\n' "$out" > "$ORQ_LOG/${CASO// /-}.md"; }
  diff -q "$SNAP_TMP/snap-a.txt" "$SNAP_TMP/snap-b.txt" >/dev/null || fail "el orquestador escribió archivos"
  for s in '## Estado' '## Pendiente de revisión' '## Desactualizado' '## Siguiente paso' '## Datos'; do
    printf '%s' "$out" | grep -q "^$s" || fail "falta la sección '$s'"
  done
  datos="$(printf '%s' "$out" | awk '/^## Datos/{f=1;next} /^## /{f=0} f' | tr -d '\r' | sed -E 's/^[[:space:]`*-]+//; s/[[:space:]`*]+$//')"
  for k in agente motivo alcance paralelo faltan desactualizado sin-version sin-numerar; do
    printf '%s\n' "$datos" | grep -q "^$k:" || fail "la sección Datos no tiene la línea '$k:'"
  done
  next="$(printf '%s' "$out" | awk '/^## Siguiente paso/{f=1;next} /^## /{f=0} f')"
}
dato() { printf '%s\n' "$datos" | sed -n "s/^$1:[[:space:]]*//p" | head -n1 | sed -E 's/[[:space:].]+$//'; }
# Valor de una lista como elementos ordenados y separados por espacio; "nada" queda vacío
lista_dato() { dato "$1" | tr ',' '\n' | sed -E 's/^[[:space:]`]+//; s/[[:space:]`]+$//' | grep -v '^$' | grep -vix 'nada' | sort | paste -sd' ' -; }
ordena() { tr ' ' '\n' | grep -v '^$' | sort | paste -sd' ' -; }
es() { # <clave> <valor esperado>
  [ "$(dato "$1")" = "$2" ] || fail "$1 es '$(dato "$1")', se esperaba '$2'"
}
lista_es() { # <clave> <elementos esperados, separados por espacio>
  local got exp; got="$(lista_dato "$1")"; exp="$(printf '%s' "$2" | ordena)"
  [ "$got" = "$exp" ] || fail "$1 es '${got:-nada}', se esperaba '${exp:-nada}'"
}
contiene() { # <clave> <elemento>
  lista_dato "$1" | tr ' ' '\n' | grep -qx -- "$2" || fail "$1 no contiene '$2' (es '$(dato "$1")')"
}
motivo_tiene() { dato motivo | tr ',' '\n' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | grep -qx "$1" || fail "motivo no incluye '$1' (es '$(dato motivo)')"; }

# --- Preparación de estados
caps() { ls "$M"/specs | grep -v '^_' | sed 's/\.md$//'; }
fija_destino() { sed -i 's/^destino:.*/destino: Kotlin/' "$M/README.md"; }
decide_adrs() { sed -i 's/^estado: propuesto/estado: revisado/' "$M"/adr/*.md; }
# Marca como resueltos los hallazgos de QA que haya generado el modelo
resuelve_hallazgos() {
  local p
  for p in "$M"/test-plans/[!_]*.md; do
    [ -f "$p" ] && sed -i -E '/^- \*\*H-[0-9]+\*\*/{/\(resuelto/!s/$/ (resuelto: decidido en la prueba)/}' "$p"
  done
  return 0
}
# Auditoría mínima y válida, al día con cada spec
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
ids_de() { xargs -r -n1 basename | grep -oE '^T-[0-9]+' | sort -u; }
tareas_de() { grep -l "^spec: $1$" "$M"/tasks/T-*.md | ids_de | sed 's/^/tarea:/' | paste -sd' ' -; }
# Etapa con specs, planes y tareas, sin backlog; destino fijado, ADRs decididos y
# hallazgos resueltos, para que solo cuente lo que cada caso cambia
completo_sin_backlog() { etapa tl-tasks; fija_destino; decide_adrs; resuelve_hallazgos; }

# ============================================================ Paso 1
if quiere sin-indexar; then
  etapa fixture
  orq "sin-indexar"
  es agente migration-indexer
  es motivo indexar
  es paralelo sí
  lista_es alcance "bff frontend"
fi

if quiere tras-indexer; then
  etapa indexer
  orq "tras-indexer"
  es agente migration-analyst
  es paralelo no
fi

if quiere indice-incompleto; then
  etapa indexer
  printf '> Índice incompleto: falta desde src/routes\n' >> "$W/bff/index.md"
  orq "indice-incompleto"
  es agente migration-indexer
  es motivo indexar
  es paralelo no
  printf '%s' "$out" | grep -q 'bff' || fail "no nombra el repositorio bff"
fi

# ============================================================ Puertas y pasos por capacidad
if quiere destino-antes-de-adrs; then
  etapa analyst
  orq "destino-antes-de-adrs"
  es agente migration-tl-resolver
  es motivo destino
fi

if quiere specs-en-paralelo; then
  # Mapa y ADRs hechos, ningún spec. Destino vacío y ADRs propuestos: no frenan a los specs
  etapa tl-adrs
  P="$(grep -l '^estado: propuesto' "$M"/adr/*.md | head -n1 | xargs basename | cut -c1-4)"
  orq "specs-en-paralelo"
  es agente migration-tl-specs
  es motivo falta
  es paralelo sí
  lista_es alcance "$(grep -oE '^\| [a-z0-9-]+ \|' "$M/specs/_capacidades.md" | sed -E 's/^\| //; s/ \|$//' | paste -sd' ' -)"
  printf '%s' "$out" | awk '/^## Pendiente de revisión/{f=1;next} /^## /{f=0} f' | grep -q "$P" || fail "no lista el ADR propuesto $P como pendiente de revisión"
fi

if quiere auditar-antes-de-qa; then
  # Specs hechos, sin auditoría, sin planes ni tareas
  etapa tl-specs
  orq "auditar-antes-de-qa"
  es agente migration-auditor
  es motivo auditar
  es paralelo no
fi

if quiere qa-con-adrs-propuestos; then
  # Specs auditados, ADRs propuestos y destino vacío: nada de eso frena a QA
  etapa tl-specs
  grep -lq '^estado: propuesto' "$M"/adr/*.md || fail "el workspace no tiene ADRs propuestos"
  planta_auditoria
  orq "qa-con-adrs-propuestos"
  es agente migration-qa
  es motivo falta
  es paralelo sí
  lista_es alcance "$(caps | paste -sd' ' -)"
  for c in $(caps); do contiene faltan "planes:$c"; done
fi

if quiere decidir-antes-de-tareas; then
  # Planes hechos, ADRs propuestos: ahora sí toca decidirlos
  etapa qa
  ls "$M"/tasks/T-*.md >/dev/null 2>&1 && fail "la etapa qa contiene tareas; el orden de etapas no es el nuevo"
  planta_auditoria; fija_destino; resuelve_hallazgos
  orq "decidir-antes-de-tareas"
  es agente migration-tl-resolver
  es motivo decidir
fi

if quiere hallazgos-antes-de-tareas; then
  # Planes hechos, destino y ADRs decididos, un hallazgo de QA sin resolver
  etapa qa
  planta_auditoria; fija_destino; decide_adrs; resuelve_hallazgos
  S="$(caps | head -n1)"
  sed -i 's/^## Hallazgos para el tech lead.*/&\n- **H-90**: sección 7: el spec no dice qué responde el sistema con la cabecera de traza vacía./' "$M/test-plans/$S.md"
  orq "hallazgos-antes-de-tareas"
  es agente migration-tl-resolver
  es motivo hallazgos
fi

if quiere tareas-en-serie; then
  # Planes hechos y nada pendiente de decidir: migration-tl-tasks, una sola corrida
  etapa qa
  planta_auditoria; fija_destino; decide_adrs; resuelve_hallazgos
  orq "tareas-en-serie"
  es agente migration-tl-tasks
  es motivo falta
  es alcance todo
  es paralelo no
  printf '%s' "$next" | grep -q 'migration-tl-tasks, solo la capacidad' && fail "reparte migration-tl-tasks por capacidad"
fi

# ============================================================ Versiones
if quiere sin-cambios || quiere mejoras-no-pendientes; then
  completo_sin_backlog
  S="$(caps | head -n1)"
  orq "sin-cambios"
  lista_es desactualizado ""
  lista_es sin-version ""
  lista_es sin-numerar ""
  lista_es faltan ""
  es agente migration-pm
  # Paridad: las mejoras MJ-n no son pendientes de revisión
  grep -rqE '^(- )?MJ-[0-9]+:' "$M"/specs/[!_]*.md || fail "el workspace no tiene mejoras MJ-n para probar al orquestador"
  printf '%s' "$out" | awk '/^## Pendiente de revisión/{f=1;next} /^## /{f=0} f' | grep -q 'MJ-[0-9]' && fail "lista mejoras MJ-n como pendientes de revisión"
fi

if quiere touch-de-un-spec; then
  # Cambia la fecha de modificación de un spec, no su contenido
  completo_sin_backlog
  S="$(caps | head -n1)"
  sleep 2; touch "$M/specs/$S.md"
  orq "touch-de-un-spec"
  lista_es desactualizado ""
  es agente migration-pm
fi

if quiere rev-de-un-spec; then
  # Sube el rev de un spec: su plan y sus tareas, y nada de otros specs
  completo_sin_backlog
  S="$(caps | head -n1)"
  sed -i "s/^rev: .*/rev: $(( $(rev_de "$M/specs/$S.md") + 1 ))/" "$M/specs/$S.md"
  orq "rev-de-un-spec"
  lista_es desactualizado "plan:$S $(tareas_de "$S")"
  # La regeneración empieza por el plan: planes antes que tareas
  es agente migration-qa
  es motivo desactualizado
  es alcance "$S"
  es paralelo no
fi

if quiere solo-cambio-de-estado; then
  completo_sin_backlog
  S="$(caps | head -n1)"
  sed -i 's/^estado: generado/estado: revisado/' "$M/specs/$S.md"
  orq "solo-cambio-de-estado"
  lista_es desactualizado ""
  es agente migration-pm
fi

if quiere rev-de-un-adr; then
  # Sube el rev de un ADR: solo las tareas que lo citan
  completo_sin_backlog
  total="$(ls "$M"/tasks/T-*.md | wc -l)"; ADR=""
  for a in "$M"/adr/*.md; do
    id="$(campo "$a" id)"
    n="$(grep -lE "^adrs:.*\b$id\b" "$M"/tasks/T-*.md 2>/dev/null | wc -l)"
    if [ "$n" -gt 0 ] && [ "$n" -lt "$total" ]; then ADR="$a"; break; fi
  done
  if [ -z "$ADR" ]; then
    CASO="rev-de-un-adr"; fail "ningún ADR está citado por una parte de las tareas"
  else
    id="$(campo "$ADR" id)"
    sed -i "s/^rev: .*/rev: $(( $(rev_de "$ADR") + 1 ))/" "$ADR"
    orq "rev-de-un-adr"
    lista_es desactualizado "$(grep -lE "^adrs:.*\b$id\b" "$M"/tasks/T-*.md | ids_de | sed 's/^/tarea:/' | paste -sd' ' -)"
    es agente migration-tl-tasks
    es motivo desactualizado
    es paralelo no
  fi
fi

if quiere capacidad-sin-tareas; then
  # Completitud por capacidad: sin tareas para una capacidad, el paso 6 no está completo
  completo_sin_backlog
  S="$(caps | head -n1)"
  grep -l "^spec: $S$" "$M"/tasks/T-*.md | while IFS= read -r f; do rm -- "$f"; done
  orq "capacidad-sin-tareas"
  lista_es faltan "tareas:$S"
  es agente migration-tl-tasks
  es motivo falta
  es alcance "$S"
  printf '%s' "$out" | grep -E '^Faltan:' | grep -q "$S" || fail "la línea Faltan de Estado no nombra $S"
fi

if quiere spec-sin-version; then
  completo_sin_backlog
  S="$(caps | head -n1)"
  sed -i '/^rev:/d' "$M/specs/$S.md"
  orq "spec-sin-version"
  contiene sin-version "specs/$S.md"
  es agente migration-tl-resolver
  es motivo sin-version
  es alcance versiones
  printf '%s' "$next" | grep -q 'registra las versiones' || fail "el prompt no es 'registra las versiones'"
fi

if quiere plan-revisado-atrasado; then
  # Un plan revisado cuyo spec cambió: su agente no lo sobrescribe. Dos salidas, ambas con el resolver
  completo_sin_backlog
  S="$(caps | head -n1)"
  sed -i 's/^estado: generado/estado: revisado/' "$M/test-plans/$S.md"
  sed -i "s/^rev: .*/rev: $(( $(rev_de "$M/specs/$S.md") + 1 ))/" "$M/specs/$S.md"
  orq "plan-revisado-atrasado"
  contiene desactualizado "plan:$S"
  es agente migration-tl-resolver
  motivo_tiene revisado
  printf '%s' "$next" | grep "migration-tl-resolver: reabre " | grep -q "$S" || fail "no ofrece reabrir el plan de $S"
  printf '%s' "$next" | grep "migration-tl-resolver: registra las versiones de " | grep -q "$S" || fail "no ofrece registrar las versiones del plan de $S"
fi

if quiere specs-sin-numerar; then
  # Un spec del formato anterior, con preguntas sin id: pendiente de numerar; no cambia el siguiente paso
  completo_sin_backlog
  S="$(caps | head -n1)"
  awk '/^## 12\. /{print; print "- ¿Qué responde el proveedor externo si el pedido está duplicado?"; print "- ¿Qué zona horaria usa el sistema externo de facturación?"; print ""; s=1; next} /^## /{s=0} !s{print}' "$M/specs/$S.md" > "$M/specs/$S.md.tmp" && mv "$M/specs/$S.md.tmp" "$M/specs/$S.md"
  orq "specs-sin-numerar"
  lista_es sin-numerar "$S"
  lista_es desactualizado ""
  es agente migration-pm
  printf '%s' "$out" | grep -q 'numera las preguntas' || fail "no ofrece 'numera las preguntas'"
fi

if quiere tarea-nueva-en-un-spec; then
  # Añadir una tarea a un spec no desactualiza su plan
  completo_sin_backlog
  S="$(caps | head -n1)"
  T0="$(grep -l "^spec: $S$" "$M"/tasks/T-*.md | head -n1)"
  sed -e 's/^id: T-[0-9]*/id: T-900/' -e 's/^titulo: .*/titulo: Tarea añadida a mano/' -e 's/^# T-[0-9]*:.*/# T-900: Tarea añadida a mano/' "$T0" > "$M/tasks/T-900-tarea-anadida-a-mano.md"
  orq "tarea-nueva-en-un-spec"
  lista_es desactualizado ""
  es agente migration-pm
fi

if quiere tareas-sin-planes; then
  # Proyecto del orden anterior: tareas y ningún plan. Se propone QA y no se regeneran las tareas
  completo_sin_backlog
  rm -rf "$M/test-plans"
  orq "tareas-sin-planes"
  es agente migration-qa
  es motivo falta
  es paralelo sí
  lista_es alcance "$(caps | paste -sd' ' -)"
  lista_es desactualizado ""
  lista_es faltan "$(caps | sed 's/^/planes:/' | paste -sd' ' -)"
fi

if quiere backlog-desactualizado; then
  # Flujo completo y después cambia una tarea: solo el backlog
  etapa pm
  fija_destino; decide_adrs; resuelve_hallazgos
  sed -i 's/^bloqueada_por:.*/bloqueada_por: []/' "$M"/tasks/T-*.md
  T0="$(ls "$M"/tasks/T-*.md | head -n1)"
  sed -i "s/^rev: .*/rev: $(( $(rev_de "$T0") + 1 ))/" "$T0"
  orq "backlog-desactualizado"
  lista_es desactualizado "backlog"
  es agente migration-pm
  es motivo desactualizado
fi

# ============================================================ Destino
if quiere destino-en-el-readme; then
  # Con el destino ya en el README, los prompts no lo repiten
  etapa qa
  planta_auditoria; decide_adrs; resuelve_hallazgos
  sed -i 's/^destino:.*/destino: Kotlin/' "$M/README.md"
  orq "destino-en-el-readme"
  es agente migration-tl-tasks
  printf '%s' "$next" | grep -q 'con destino' && fail "el prompt recomendado repite 'con destino'"
fi

[ "$fails" -eq 0 ] && { echo "OK: orchestrator"; exit 0; }
exit 1
