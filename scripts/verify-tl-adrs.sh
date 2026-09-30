#!/usr/bin/env bash
# Verifica los ADRs.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

adrs=()
for f in "$M"/adr/*.md; do [ -f "$f" ] && adrs+=("$f"); done
[ "${#adrs[@]}" -gt 0 ] || { echo "FAIL: no hay ADRs"; exit 1; }
grep -lq '^estado: observado' "${adrs[@]}" || grep -lq '^estado: revisado' "${adrs[@]}" || fail "no hay ADR observado"
if [ "${REQUIRE_PROPUESTO:-1}" = 1 ]; then
  grep -lq '^estado: propuesto' "${adrs[@]}" || fail "no hay ADR propuesto"
fi
for a in "${adrs[@]}"; do
  n="$(basename "$a")"
  echo "$n" | grep -Eq '^[0-9]{4}-[a-z0-9-]+\.md$' || fail "$n: nombre no sigue NNNN-slug.md"
  id="$(sed -n 's/^id:[[:space:]]*//p' "$a" | head -n1)"
  case "$n" in "$id"-*) ;; *) fail "$n: id '$id' no coincide con el archivo";; esac
  grep -q '^titulo: .\+' "$a" || fail "$n: sin titulo"
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
