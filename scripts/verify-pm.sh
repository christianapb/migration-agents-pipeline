#!/usr/bin/env bash
# Verifica el backlog y los campos fase/prioridad (carpeta: WORKDIR o, por defecto, la actual).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
W="${WORKDIR:-$PWD}"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
# shellcheck source=lib-rev.sh
. "$HERE/lib-rev.sh"

[ -f "$M/backlog.md" ] || fail "backlog.md no existe"
grep -q '^### Hito 0' "$M/backlog.md" 2>/dev/null || fail "backlog sin Hito 0"
grep -q '^## Bloqueos' "$M/backlog.md" 2>/dev/null || fail "backlog sin sección Bloqueos"
grep -q '^## Riesgos' "$M/backlog.md" 2>/dev/null || fail "backlog sin sección Riesgos"
grep -q 'Cómo empezar a implementar' "$M/README.md" 2>/dev/null || fail "README sin 'Cómo empezar a implementar'"
grep -q '^## Flujo' "$M/README.md" 2>/dev/null && fail "README conserva la lista de pasos de v1"

# fase y prioridad rellenados; fase(dep) <= fase(tarea); hito 0 solo fundacionales
declare -A fase spec
for t in "$M"/tasks/T-*.md; do
  [ -f "$t" ] || { fail "no hay tareas"; break; }
  id=$(sed -n 's/^id:[[:space:]]*//p' "$t" | head -n1)
  f=$(sed -n 's/^fase:[[:space:]]*//p' "$t" | head -n1)
  p=$(sed -n 's/^prioridad:[[:space:]]*//p' "$t" | head -n1)
  s=$(sed -n 's/^spec:[[:space:]]*//p' "$t" | head -n1)
  [[ "$f" =~ ^[0-9]+$ ]] || fail "$id: fase vacía o no numérica ('$f')"
  [[ "$p" =~ ^[0-9]+$ ]] || fail "$id: prioridad vacía o no numérica ('$p')"
  fase["$id"]="$f"; spec["$id"]="$s"
  if [ "$f" = "0" ] && [ -n "$s" ]; then fail "$id: está en hito 0 pero tiene spec '$s'"; fi
done
for t in "$M"/tasks/T-*.md; do
  [ -f "$t" ] || break
  id=$(sed -n 's/^id:[[:space:]]*//p' "$t" | head -n1)
  deps=$(sed -n 's/^depende_de:[[:space:]]*\[\(.*\)\]/\1/p' "$t" | head -n1 | tr ',' ' ')
  for d in $deps; do
    d=$(echo "$d" | tr -d ' "'"'")
    [ -n "${fase[$d]:-}" ] || { fail "$id: depende de $d que no existe"; continue; }
    [[ "${fase[$d]}" =~ ^[0-9]+$ && "${fase[$id]}" =~ ^[0-9]+$ ]] || continue
    [ "${fase[$d]}" -le "${fase[$id]}" ] || fail "$id (fase ${fase[$id]}) depende de $d (fase ${fase[$d]})"
  done
  # el backlog lista la tarea
  grep -q "$id" "$M/backlog.md" 2>/dev/null || fail "$id no aparece en el backlog"
  # la fila de la tarea en las tablas de fases registra su rev en la columna siguiente
  brev="$(awk '/^## Bloqueos/{exit} {print}' "$M/backlog.md" 2>/dev/null | sed -nE "s/^\|[^|]*\|[^|]*\b$id\b[^|]*\|[[:space:]]*([0-9]+)[[:space:]]*\|.*/\1/p" | head -n1)"
  trev="$(rev_de "$t")"
  [ -n "$brev" ] || fail "$id: su fila del backlog no tiene columna Rev"
  [ -z "$brev" ] || [ "$brev" = "$trev" ] || fail "$id: el backlog registra rev $brev y la tarea tiene rev '$trev'"
done

# El backlog y las tareas coinciden con lo que calcula backlog.sh: fase,
# prioridad, hito de cada fila y Orden igual a la prioridad.
if [ -f "$HERE/backlog.sh" ]; then
  calc="$(bash "$HERE/backlog.sh" calcular --tsv "$W" 2>&1)"; crc=$?
  if [ "$crc" -ne 0 ]; then
    fail "backlog.sh no puede calcular sobre estas tareas: $(printf '%s' "$calc" | head -n3 | tr '\n' ' ')"
  else
    filas="$(awk '/^## Bloqueos/{exit} /^### Hito [0-9]+/{h=$3; sub(/:.*/, "", h)} /^\|/ && match($0, /T-[0-9]+/) {n=split($0, c, "|"); o=c[2]; gsub(/ /, "", o); print substr($0, RSTART, RLENGTH) "\t" h "\t" o}' "$M/backlog.md" 2>/dev/null)"
    while IFS=$'\t' read -r id cf cp; do
      [ -n "$id" ] || continue
      t="$(ls "$M"/tasks/"$id"-*.md 2>/dev/null | head -n1)"
      [ "$(campo "$t" fase)" = "$cf" ] || fail "$id: fase '$(campo "$t" fase)' en la tarea y backlog.sh calcula $cf"
      [ "$(campo "$t" prioridad)" = "$cp" ] || fail "$id: prioridad '$(campo "$t" prioridad)' en la tarea y backlog.sh calcula $cp"
      fila="$(printf '%s\n' "$filas" | awk -F'\t' -v id="$id" '$1==id' | head -n1)"
      [ -n "$fila" ] || continue
      [ "$(printf '%s' "$fila" | cut -f2)" = "$cf" ] || fail "$id: figura en el hito $(printf '%s' "$fila" | cut -f2) del backlog y su fase es $cf"
      [ "$(printf '%s' "$fila" | cut -f3)" = "$cp" ] || fail "$id: su fila del backlog tiene Orden '$(printf '%s' "$fila" | cut -f3)' y su prioridad es $cp"
    done <<< "$calc"
  fi
fi

# Tareas bloqueadas aparecen en la sección Bloqueos (rutas con espacios: sin word-splitting)
for t in "$M"/tasks/T-*.md; do
  [ -f "$t" ] || break
  grep -q '^bloqueada_por: \[.\+\]' "$t" || continue
  id=$(sed -n 's/^id:[[:space:]]*//p' "$t" | head -n1)
  [ -n "$id" ] || { fail "$(basename "$t"): sin id"; continue; }
  awk '/^## Bloqueos/{f=1;next} /^## /{f=0} f' "$M/backlog.md" 2>/dev/null | grep -Eq "\b${id}\b" || fail "$id está bloqueada pero no aparece en Bloqueos"
done

[ "$fails" -eq 0 ] && { echo "OK: pm"; exit 0; }
exit 1
