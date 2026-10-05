#!/usr/bin/env bash
# Verifica la estructura de migration/specs/_auditoria.md contra los specs.
# No comprueba que los veredictos sean correctos: eso lo hace test-auditor.sh
# con errores plantados.
# Variables: AUDIT_CAPS (lista de capacidades que deben estar auditadas,
# separadas por espacio; por defecto todas las que tienen spec).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
W="${WORKDIR:-$PWD}"
M="$W/migration"
A="$M/specs/_auditoria.md"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
# shellcheck source=lib-rev.sh
. "$HERE/lib-rev.sh"

[ -f "$A" ] || { echo "FAIL: _auditoria.md no existe"; exit 1; }
grep -q '^# Auditoría de specs' "$A" || fail "sin título '# Auditoría de specs'"
grep -q '^## Resumen' "$A" || fail "sin sección '## Resumen'"

caps="${AUDIT_CAPS:-}"
if [ -z "$caps" ]; then
  for f in "$M"/specs/[!_]*.md; do [ -f "$f" ] && caps+="$(basename "$f" .md) "; done
fi
[ -n "$caps" ] || fail "no hay specs que auditar"

VERDICTS='respaldada|sin respaldo|contradicha|cita no localizable|decisión'
for c in $caps; do
  s="$M/specs/$c.md"
  [ -f "$s" ] || { fail "$c: no existe el spec"; continue; }
  sec="$(awk -v h="## $c" '$0==h {f=1; next} /^## /{f=0} f' "$A")"
  [ -n "$sec" ] || { fail "$c: sin sección '## $c' en la auditoría"; continue; }
  arev="$(printf '%s\n' "$sec" | sed -nE 's/^Auditada:.*Spec rev:[[:space:]]*([0-9]+).*/\1/p' | head -n1)"
  if [ -z "$arev" ]; then
    fail "$c: la línea Auditada no registra 'Spec rev: <n>'"
  else
    actual="$(rev_de "$s")"
    [ -z "$actual" ] || [ "$arev" -le "$actual" ] || fail "$c: la auditoría registra Spec rev $arev y el spec tiene rev $actual"
  fi
  rows="$(printf '%s\n' "$sec" | grep -E '^\| (RN|CB)-[0-9]+ \|' || true)"

  # Cada regla no retirada del spec tiene una fila con veredicto válido
  ids="$(grep -E '^(- )?(RN|CB)-[0-9]+:' "$s" | grep -v '(retirado' | grep -oE '^(- )?(RN|CB)-[0-9]+' | sed 's/^- //' | sort -u)"
  for id in $ids; do
    row="$(printf '%s\n' "$rows" | grep -E "^\| $id \|" | head -n1)"
    [ -n "$row" ] || { fail "$c: la regla $id no aparece en la tabla de auditoría"; continue; }
    v="$(printf '%s' "$row" | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}')"
    printf '%s' "$v" | grep -Eqx "$VERDICTS" || fail "$c: $id tiene un veredicto desconocido: '$v'"
  done

  # Hallazgos: numerados AU-n, cada uno con prompt del resolver
  hall="$(printf '%s\n' "$sec" | awk '/^### Hallazgos/{f=1;next} /^### /{f=0} f')"
  nau="$(printf '%s\n' "$hall" | grep -cE '^- \*\*AU-[0-9]+\*\*' || true)"
  nprompt="$(printf '%s\n' "$hall" | grep -c 'Usa el subagente migration-tl-resolver' || true)"
  printf '%s\n' "$sec" | grep -q '^### Hallazgos' || fail "$c: sin subsección '### Hallazgos'"
  [ "$nprompt" -ge "$nau" ] || fail "$c: $nau hallazgos y solo $nprompt prompts del resolver"

  # Toda regla con veredicto negativo tiene un hallazgo que la nombra
  neg="$(printf '%s\n' "$rows" | grep -E '\| (sin respaldo|contradicha|cita no localizable) \|' | grep -oE '^\| (RN|CB)-[0-9]+' | sed 's/^| //' || true)"
  for id in $neg; do
    printf '%s\n' "$hall" | grep -E '^- \*\*AU-[0-9]+\*\*' | grep -Eq "\b$id\b" || fail "$c: $id tiene veredicto negativo y ningún hallazgo AU-n la nombra"
  done

  # El resumen cuadra con la tabla: total de reglas y contradichas
  res="$(awk '/^## Resumen/{f=1;next} /^## /{f=0} f' "$A" | grep -E "^\| $c \|" | head -n1)"
  if [ -z "$res" ]; then
    fail "$c: sin fila en el resumen"
  else
    rt="$(printf '%s' "$res" | awk -F'|' '{gsub(/ /,"",$3); print $3}')"
    rc="$(printf '%s' "$res" | awk -F'|' '{gsub(/ /,"",$6); print $6}')"
    nt="$(printf '%s\n' "$rows" | grep -c . || true)"
    nc="$(printf '%s\n' "$rows" | grep -c '| contradicha |' || true)"
    [ "$rt" = "$nt" ] || fail "$c: el resumen dice $rt reglas y la tabla tiene $nt"
    [ "$rc" = "$nc" ] || fail "$c: el resumen dice $rc contradichas y la tabla tiene $nc"
  fi
done

[ "$fails" -eq 0 ] && { echo "OK: auditor"; exit 0; }
exit 1
