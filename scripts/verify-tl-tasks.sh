#!/usr/bin/env bash
# Verifica las tareas.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
# shellcheck source=scripts/lib-rev.sh
. "$ROOT/scripts/lib-rev.sh"
# shellcheck source=scripts/lib-destino.sh
. "$ROOT/scripts/lib-destino.sh"
while IFS= read -r prob; do [ -n "$prob" ] && fail "$prob"; done <<< "$(destino_problemas "$W")"
conservados="$(destino_conservados "$W")"

tasks=()
for f in "$M"/tasks/T-*.md; do [ -f "$f" ] && tasks+=("$f"); done
[ "${#tasks[@]}" -gt 0 ] || { echo "FAIL: no hay tareas"; exit 1; }
fund=0
for t in "${tasks[@]}"; do
  n="$(basename "$t")"
  echo "$n" | grep -Eq '^T-[0-9]{3}-[a-z0-9-]+\.md$' || fail "$n: nombre no sigue T-NNN-slug.md"
  id="$(sed -n 's/^id:[[:space:]]*//p' "$t" | head -n1)"
  case "$n" in "$id"-*) ;; *) fail "$n: id '$id' no coincide con el archivo";; esac
  grep -q '^estado: ' "$t" || fail "$n: sin estado"
  grep -q '^depende_de: ' "$t" || fail "$n: sin depende_de"
  grep -q '^tamaño: [SML]$' "$t" || fail "$n: tamaño inválido"
  grep -q '^## Criterios de aceptación' "$t" || fail "$n: sin criterios de aceptación"
  tipo="$(sed -n 's/^tipo:[[:space:]]*//p' "$t" | head -n1)"
  case "$tipo" in implementacion|adaptacion) ;; *) fail "$n: tipo ausente o inválido ('$tipo')" ;; esac
  # Versión propia y versión anotada de los insumos
  es_rev "$(campo "$t" rev)" || fail "$n: rev ausente o no es un entero mayor que 0 ('$(campo "$t" rev)')"
  tspec="$(campo "$t" spec)"; srev="$(campo "$t" spec_rev)"
  if [ -n "$tspec" ]; then
    if ! es_rev "$srev"; then
      fail "$n: spec_rev ausente o no numérico ('$srev')"
    else
      actual="$(rev_de "$M/specs/$tspec.md")"
      [ -z "$actual" ] || [ "$srev" -le "$actual" ] || fail "$n: spec_rev $srev es mayor que el rev $actual del spec $tspec"
    fi
  else
    [ -z "$srev" ] || fail "$n: tarea fundacional con spec_rev"
  fi
  grep -q '^adrs_rev: {' "$t" || fail "$n: sin adrs_rev en el frontmatter"
  pares="$(mapa_pares "$(campo "$t" adrs_rev)")"
  for a in $(lista "$(campo "$t" adrs)"); do
    arev="$(printf '%s\n' "$pares" | awk -v k="$a" '$1==k {print $2}')"
    es_rev "$arev" || { fail "$n: el ADR $a de adrs no tiene versión en adrs_rev"; continue; }
    actual="$(rev_de "$(adr_file "$M" "$a")")"
    [ -z "$actual" ] || [ "$arev" -le "$actual" ] || fail "$n: adrs_rev anota $arev para el ADR $a, cuyo rev es $actual"
  done
  rd="$(sed -n 's/^repo_destino:[[:space:]]*//p' "$t" | head -n1)"
  if [ -n "$rd" ] && printf '%s\n' "$conservados" | grep -qx "$rd" && [ "$tipo" != "adaptacion" ]; then
    fail "$n: tarea de implementación en el repositorio conservado '$rd'"
  fi
  grep -qi 'paridad provisional' "$t" && fail "$n: usa 'paridad provisional'; bajo la política de paridad los criterios afirman el comportamiento actual"
  spec="$(sed -n 's/^spec:[[:space:]]*//p' "$t" | head -n1)"
  if [ -z "$spec" ]; then fund=$((fund+1)); else [ -f "$M/specs/$spec.md" ] || fail "$n: spec '$spec' no existe"; fi
  bp="$(sed -n 's/^bloqueada_por:[[:space:]]*\[\(.*\)\]/\1/p' "$t" | head -n1 | tr ',' ' ')"
  for x in $bp; do
    x="$(printf '%s' "$x" | tr -d ' "'"'")"
    case "$x" in
      PA:*)
        s="$(printf '%s' "$x" | cut -d: -f2)"; k="$(printf '%s' "$x" | cut -d: -f3)"
        [ -f "$M/specs/$s.md" ] || { fail "$n: $x cita un spec inexistente"; continue; }
        np="$(awk '/^## 12\. /{f=1;next} /^## /{f=0} f' "$M/specs/$s.md" | grep -c '^- ' || true)"
        [ "$k" -le "$np" ] 2>/dev/null || fail "$n: $x cita una pregunta inexistente"
        ;;
      [0-9][0-9][0-9][0-9])
        a=("$M"/adr/"$x"-*.md)
        [ -f "${a[0]}" ] || { fail "$n: bloqueada por ADR inexistente $x"; continue; }
        grep -q '^estado: propuesto' "${a[0]}" || fail "$n: bloqueada por ADR $x que ya no está propuesto"
        ;;
      "") ;;
      *) fail "$n: elemento no reconocido en bloqueada_por: $x" ;;
    esac
  done
done
[ "$fund" -ge 1 ] || fail "no hay tareas fundacionales (spec vacío)"
dup="$(grep -h '^titulo:' "${tasks[@]}" | sort | uniq -d)"
[ -z "$dup" ] || fail "títulos de tarea duplicados: $dup"

[ "$fails" -eq 0 ] && { echo "OK: tl-tasks"; exit 0; }
exit 1
