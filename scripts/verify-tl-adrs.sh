#!/usr/bin/env bash
# Verifica los ADRs.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
W="${WORKDIR:-$PWD}"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
# shellcheck source=lib-rev.sh
. "$HERE/lib-rev.sh"
# shellcheck source=lib-destino.sh
. "$HERE/lib-destino.sh"
while IFS= read -r prob; do [ -n "$prob" ] && fail "$prob"; done <<< "$(destino_problemas "$W")"
conservados="$(destino_conservados "$W")"

adrs=()
for f in "$M"/adr/*.md; do [ -f "$f" ] && adrs+=("$f"); done
[ "${#adrs[@]}" -gt 0 ] || { echo "FAIL: no hay ADRs"; exit 1; }
grep -lq '^estado: observado' "${adrs[@]}" || grep -lq '^estado: revisado' "${adrs[@]}" || fail "no hay ADR observado"
# Propia del fixture (FIXTURE=1): recién generados, siempre hay algún ADR propuesto.
# En un proyecto real dejan de existir en cuanto se deciden.
if [ "${REQUIRE_PROPUESTO:-${FIXTURE:-0}}" = 1 ]; then
  grep -lq '^estado: propuesto' "${adrs[@]}" || fail "no hay ADR propuesto"
fi
for a in "${adrs[@]}"; do
  n="$(basename "$a")"
  echo "$n" | grep -Eq '^[0-9]{4}-[a-z0-9-]+\.md$' || fail "$n: nombre no sigue NNNN-slug.md"
  id="$(sed -n 's/^id:[[:space:]]*//p' "$a" | head -n1)"
  case "$n" in "$id"-*) ;; *) fail "$n: id '$id' no coincide con el archivo";; esac
  grep -q '^titulo: .\+' "$a" || fail "$n: sin titulo"
  grep -q '^repos: \[' "$a" || fail "$n: sin repos en el frontmatter"
  es_rev "$(campo "$a" rev)" || fail "$n: rev ausente o no es un entero mayor que 0 ('$(campo "$a" rev)')"
  if grep -q '^estado: propuesto' "$a"; then
    arepos="$(sed -n 's/^repos:[[:space:]]*\[\(.*\)\]/\1/p' "$a" | head -n1 | tr ',' ' ')"
    for r in $arepos; do
      printf '%s\n' "$conservados" | grep -qx "$r" && fail "$n: ADR propuesto sobre el repositorio conservado '$r'"
    done
  fi
  for s in '## Contexto' '## Decisión' '## Evidencia' '## Consecuencias' '## Implicación para la migración'; do
    grep -q "^$s" "$a" || fail "$n: falta '$s'"
  done
  if grep -q '^estado: propuesto' "$a"; then
    grep -q '\*\*Recomendación:\*\*' "$a" || fail "$n: propuesto sin recomendación"
  fi
  if grep -q '^estado: observado' "$a"; then
    grep -Eq '^implicacion_migracion: (conservar|reemplazar|reevaluar)$' "$a" || fail "$n: observado sin implicacion_migracion válida"
  fi
done
dup="$(grep -h '^titulo:' "${adrs[@]}" | sort | uniq -d)"
[ -z "$dup" ] || fail "títulos de ADR duplicados: $dup"

[ "$fails" -eq 0 ] && { echo "OK: tl-adrs"; exit 0; }
exit 1
