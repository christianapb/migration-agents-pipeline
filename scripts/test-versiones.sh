#!/usr/bin/env bash
# Versiones de artefactos: cada generador sube `rev` al reescribir un artefacto
# existente y anota la versión de sus insumos; migration-pm no sube el `rev` de
# las tareas. Parte de la instantánea qa y repite la cadena sobre ella.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
export WORKDIR="$W"
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
run() { bash "$ROOT/scripts/run-agent.sh" "$@"; rc=$?; [ $rc -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }; return $rc; }
. "$ROOT/scripts/lib-rev.sh"

bash "$ROOT/scripts/snapshot.sh" restore qa "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa qa"; exit 1; }

# Guarda "archivo md5 rev" de cada archivo de una carpeta.
foto() { # <carpeta> <salida>
  : > "$2"
  local f
  for f in "$1"/*.md; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in _*) continue ;; esac
    printf '%s %s %s\n' "$(basename "$f")" "$(md5sum < "$f" | cut -d' ' -f1)" "$(campo "$f" rev)" >> "$2"
  done
}
# Tras una corrida: reescrito => rev anterior + 1; intacto => mismo rev; nuevo => rev válido.
comprobar() { # <etiqueta> <carpeta> <foto anterior>
  local f n antes md5a reva revd sub=0 igual=0 mal=0
  for f in "$2"/*.md; do
    [ -f "$f" ] || continue
    n="$(basename "$f")"; case "$n" in _*) continue ;; esac
    revd="$(campo "$f" rev)"
    antes="$(grep "^$n " "$3" || true)"
    if [ -z "$antes" ]; then
      es_rev "$revd" || { fail "$1: $n es nuevo y no tiene rev válido ('$revd')"; mal=$((mal+1)); }
      continue
    fi
    md5a="$(printf '%s' "$antes" | cut -d' ' -f2)"; reva="$(printf '%s' "$antes" | cut -d' ' -f3)"
    if [ "$(md5sum < "$f" | cut -d' ' -f1)" = "$md5a" ]; then
      igual=$((igual+1))
    elif [ "$revd" = "$((reva+1))" ]; then
      sub=$((sub+1))
    else
      fail "$1: $n se reescribió y su rev pasó de $reva a '$revd' (se esperaba $((reva+1)))"; mal=$((mal+1))
    fi
  done
  echo "--- $1: $sub reescritos con rev subido, $igual intactos, $mal sin subir"
  [ "$sub" -ge 1 ] || fail "$1: la corrida no reescribió ningún artefacto; no se pudo probar la subida"
}

S="$(ls "$M"/specs | grep -v '^_' | head -n1 | sed 's/\.md$//')"

# 1. migration-tl-adrs reescribe los ADRs
foto "$M/adr" "$TMPD/adr.txt"
run migration-tl-adrs "Ejecútalo con destino Kotlin." >/dev/null
comprobar "tl-adrs" "$M/adr" "$TMPD/adr.txt"
bash "$ROOT/scripts/verify-tl-adrs.sh" >/dev/null || fail "tl-adrs: los ADRs no pasan el verificador tras la segunda corrida"

# 2. migration-tl-specs reescribe un spec
foto "$M/specs" "$TMPD/specs.txt"
run migration-tl-specs "Solo la capacidad $S." >/dev/null
comprobar "tl-specs" "$M/specs" "$TMPD/specs.txt"
srev="$(rev_de "$M/specs/$S.md")"
otros="$(grep -v "^$S.md " "$TMPD/specs.txt" | while read -r n m r; do [ "$(campo "$M/specs/$n" rev)" = "$r" ] || echo "$n"; done)"
[ -z "$otros" ] || fail "tl-specs: cambió el rev de specs fuera del alcance: $otros"

# 3. migration-tl-tasks reescribe las tareas de ese spec y anota las versiones nuevas
foto "$M/tasks" "$TMPD/tasks.txt"
run migration-tl-tasks "Ejecútalo con destino Kotlin, solo la capacidad $S, aunque haya ADRs propuestos." >/dev/null
comprobar "tl-tasks" "$M/tasks" "$TMPD/tasks.txt"
for t in $(grep -l "^spec: $S$" "$M"/tasks/T-*.md); do
  [ "$(campo "$t" spec_rev)" = "$srev" ] || fail "tl-tasks: $(basename "$t") anota spec_rev '$(campo "$t" spec_rev)' y el spec tiene rev $srev"
done
bash "$ROOT/scripts/verify-tl-tasks.sh" >/dev/null || fail "tl-tasks: las tareas no pasan el verificador tras la segunda corrida"

# 4. migration-qa anota el spec y las tareas en el plan
run migration-qa "Solo la capacidad $S." >/dev/null
p="$M/test-plans/$S.md"
[ "$(campo "$p" spec_rev)" = "$srev" ] || fail "qa: el plan $S anota spec_rev '$(campo "$p" spec_rev)' y el spec tiene rev $srev"
esperadas="$(grep -l "^spec: $S$" "$M"/tasks/T-*.md | xargs -r -n1 basename | grep -oE '^T-[0-9]+' | sort | paste -sd' ' -)"
anotadas="$(lista "$(campo "$p" tareas)" | sort | paste -sd' ' -)"
[ "$esperadas" = "$anotadas" ] || fail "qa: el plan $S anota tareas '$anotadas' y las del spec son '$esperadas'"
bash "$ROOT/scripts/verify-qa.sh" >/dev/null || fail "qa: los planes no pasan el verificador"

# 5. migration-pm registra el rev de cada tarea y no lo sube
foto "$M/tasks" "$TMPD/tasks2.txt"
run migration-pm >/dev/null
cambiaron="$(while read -r n m r; do [ "$(campo "$M/tasks/$n" rev)" = "$r" ] || echo "$n"; done < "$TMPD/tasks2.txt")"
[ -z "$cambiaron" ] || fail "pm: cambió el rev de tareas al rellenar fase y prioridad: $cambiaron"
bash "$ROOT/scripts/verify-pm.sh" >/dev/null || fail "pm: el backlog no pasa el verificador (columna Rev)"
echo "--- pm: $(wc -l < "$TMPD/tasks2.txt") tareas con el mismo rev tras planificar"

[ "$fails" -eq 0 ] && { echo "OK: versiones"; exit 0; }
exit 1
