#!/usr/bin/env bash
# Verifica el mapa de capacidades.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
W="${WORKDIR:-$PWD}"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

F="$M/specs/_capacidades.md"
[ -f "$F" ] || { echo "FAIL: _capacidades.md no existe"; exit 1; }
grep -q '^# Capacidades' "$F" || fail "_capacidades.md sin título"
slugs="$(grep -oE '^\| [a-z0-9-]+ \|' "$F" | sed -E 's/^\| //; s/ \|$//')"
n="$(printf '%s\n' "$slugs" | grep -c . || true)"
[ "$n" -ge 1 ] || fail "_capacidades.md sin filas"
excl="$(sed -n 's/^excluir:[[:space:]]*\[\(.*\)\]/\1/p' "$M/README.md" 2>/dev/null | head -n1 | tr ',' '\n' | tr -d ' "'"'" | tr '[:upper:]' '[:lower:]')"
for x in $excl; do
  printf '%s\n' "$slugs" | grep -qx "$x" && fail "la capacidad excluida '$x' aparece en el mapa"
done
# El mínimo de 3 es propio del fixture (FIXTURE=1); en un proyecto real basta una.
MIN="${MIN_CAPACIDADES:-1}"
[ -z "${MIN_CAPACIDADES:-}" ] && [ "${FIXTURE:-0}" = 1 ] && MIN=3
total=$((n + $(printf '%s\n' $excl | grep -c . || true)))
[ "$total" -ge "$MIN" ] || fail "$n capacidades (+ excluidas) < $MIN"

[ "$fails" -eq 0 ] && { echo "OK: analyst"; exit 0; }
exit 1
