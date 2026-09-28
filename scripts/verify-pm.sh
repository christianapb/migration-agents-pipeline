#!/usr/bin/env bash
# Verifica el backlog y los campos fase/prioridad en .work/sample-workspace/migration.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

[ -f "$M/backlog.md" ] || fail "backlog.md no existe"
grep -q '^### Hito 0' "$M/backlog.md" 2>/dev/null || fail "backlog sin Hito 0"
grep -q '^## Bloqueos' "$M/backlog.md" 2>/dev/null || fail "backlog sin sección Bloqueos"
grep -q '^## Riesgos' "$M/backlog.md" 2>/dev/null || fail "backlog sin sección Riesgos"
grep -q 'migration-pm' "$M/README.md" 2>/dev/null || fail "README no menciona migration-pm"
grep -q 'Cómo empezar a implementar' "$M/README.md" 2>/dev/null || fail "README sin 'Cómo empezar a implementar'"

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
done

# Tareas bloqueadas aparecen en la sección Bloqueos
for t in $(grep -l '^bloqueada_por: \[.\+\]' "$M"/tasks/T-*.md 2>/dev/null); do
  id=$(sed -n 's/^id:[[:space:]]*//p' "$t" | head -n1)
  awk '/^## Bloqueos/{f=1;next} /^## /{f=0} f' "$M/backlog.md" 2>/dev/null | grep -q "$id" || fail "$id está bloqueada pero no aparece en Bloqueos"
done

[ "$fails" -eq 0 ] && { echo "OK: pm"; exit 0; }
exit 1
