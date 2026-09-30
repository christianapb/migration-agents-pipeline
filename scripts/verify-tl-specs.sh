#!/usr/bin/env bash
# Verifica los specs.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

specs=()
for f in "$M"/specs/[!_]*.md; do [ -f "$f" ] && specs+=("$f"); done
[ "${#specs[@]}" -gt 0 ] || { echo "FAIL: no hay specs"; exit 1; }
slugs="$(grep -oE '^\| [a-z0-9-]+ \|' "$M/specs/_capacidades.md" 2>/dev/null | sed -E 's/^\| //; s/ \|$//')"
preguntas=""
for s in "${specs[@]}"; do
  n="$(basename "$s" .md)"
  printf '%s\n' "$slugs" | grep -qx "$n" || fail "$n: spec sin fila en _capacidades.md"
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    grep -q "^## $i\. " "$s" || fail "$n: falta la sección $i"
  done
  grep -q '^estado: ' "$s" || fail "$n: sin estado"
  grep -Eq '^(- )?RN-1:' "$s" || fail "$n: sin reglas RN-n: al inicio de línea"
  grep -Eq '^(- )?CB-1:' "$s" || fail "$n: sin casos borde CB-n: al inicio de línea"
  if grep -Eq '^\s*(import |export |const |let |function |=> |app\.use|router\.(get|post))' "$s"; then
    fail "$n: contiene código del lenguaje origen"
  fi
  grep -q '```' "$s" && fail "$n: contiene bloques de código"
  preguntas+="$(awk '/^## 12\. Preguntas abiertas/{f=1;next} f' "$s")"$'\n'
done
if [ "${REQUIRE_AMBIGUEDAD:-1}" = 1 ]; then
  printf '%s' "$preguntas" | grep -Eiq '200|vac[ií]o|oculto|hidden' || fail "ninguna pregunta abierta menciona el producto oculto (200 vacío vs 404)"
fi

[ "$fails" -eq 0 ] && { echo "OK: tl-specs"; exit 0; }
exit 1
