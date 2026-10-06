#!/usr/bin/env bash
# Verifica los planes de prueba (carpeta: WORKDIR o, por defecto, la actual).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
W="${WORKDIR:-$PWD}"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
# shellcheck source=lib-rev.sh
. "$HERE/lib-rev.sh"

specs=()
for f in "$M"/specs/[!_]*.md; do [ -f "$f" ] && specs+=("$f"); done
[ "${#specs[@]}" -gt 0 ] || fail "no hay specs; corre migration-techlead"
[ -f "$M/test-plans/_cobertura.md" ] || fail "_cobertura.md no existe"

for s in "${specs[@]}"; do
  slug=$(basename "$s" .md)
  p="$M/test-plans/$slug.md"
  [ -f "$p" ] || { fail "falta test-plans/$slug.md"; continue; }
  grep -q "^spec: $slug" "$p" || fail "$slug: frontmatter spec no apunta al spec"
  grep -q '^estado: ' "$p" || fail "$slug: sin estado"
  # Versión del spec del que se generó el plan. Un plan antiguo puede traer
  # `tareas:` y líneas `- Tareas:`: no se exigen ni se rechazan.
  prev="$(campo "$p" spec_rev)"
  if ! es_rev "$prev"; then
    fail "$slug: spec_rev ausente o no numérico ('$prev')"
  else
    actual="$(rev_de "$s")"
    [ -z "$actual" ] || [ "$prev" -le "$actual" ] || fail "$slug: spec_rev $prev es mayor que el rev $actual del spec"
  fi
  # La cobertura consolidada tiene una fila por plan, con el spec_rev del plan
  crev="$(sed -nE "s/^\| *$slug *\| *([0-9]+) *\|.*/\1/p" "$M/test-plans/_cobertura.md" 2>/dev/null | head -n1)"
  [ -n "$crev" ] || fail "$slug: _cobertura.md no tiene fila con Spec rev para este plan"
  [ -z "$crev" ] || [ "$crev" = "$prev" ] || fail "$slug: _cobertura.md registra Spec rev $crev y el plan tiene spec_rev '$prev'"
  for sec in "## Alcance y supuestos" "## Matriz de cobertura" "## Casos: camino feliz" "## Casos: errores" "## Casos pendientes de definición" "## Hallazgos para el tech lead"; do
    grep -q "^$sec" "$p" || fail "$slug: falta sección '$sec'"
  done
  cases=$(grep -c "^### TC-$slug-[0-9]\{3\}: " "$p" || true)
  [ "$cases" -ge 3 ] || fail "$slug: solo $cases casos TC-$slug-nnn"
  # Cada caso tiene Dado/Cuando/Entonces y Cubre
  dado=$(grep -c '^- Dado[ ,]' "$p" || true); cuando=$(grep -c '^- Cuando[ ,]' "$p" || true); entonces=$(grep -c '^- Entonces[ ,]' "$p" || true)
  [ "$dado" -ge "$cases" ] && [ "$cuando" -ge "$cases" ] && [ "$entonces" -ge "$cases" ] || fail "$slug: casos sin Dado/Cuando/Entonces completos ($dado/$cuando/$entonces de $cases)"
  cubre=$(grep -c '^- Cubre: ' "$p" || true)
  [ "$cubre" -ge "$cases" ] || fail "$slug: casos sin línea Cubre"
  # Toda RN y CB definida en el spec (líneas "RN-n:" o "CB-n:", no referencias cruzadas)
  # aparece en el plan o en _cobertura.md como sin cubrir. Coincidencia exacta del id.
  ids=$(grep -oE '^(- )?(RN|CB)-[0-9]+:' "$s" | sed -E 's/^- //; s/:$//' | sort -u)
  [ -n "$ids" ] || fail "$slug: el spec no tiene ninguna RN/CB con formato 'RN-n:' o 'CB-n:'"
  for id in $ids; do
    grep -Eq "\b${id}\b" "$p" || grep -Eq "\b${id}\b" "$M/test-plans/_cobertura.md" || fail "$slug: $id no aparece ni en el plan ni en _cobertura.md"
  done
  # Preguntas abiertas → casos pendientes
  qa=$(awk '/^## 12\. /{f=1;next} /^## /{f=0} f' "$s" | grep '^- ' | grep -vc '(retirado' || true)
  pendsec="$(awk '/^## Casos pendientes de definición/{f=1;next} /^## /{f=0} f' "$p")"
  pend=$(printf '%s\n' "$pendsec" | grep -c '^- \|^### ' || true)
  if [ "$(pa_formato "$s")" = nuevo ]; then
    # Cada pendiente cita por su id una pregunta que existe y sigue abierta,
    # y cada pregunta abierta tiene su pendiente. "Pendiente 3" se lee como PA-3.
    abiertas="$(pa_abiertas "$s")"
    citadas="$(printf '%s\n' "$pendsec" | grep -oE '\*\*Pendiente (PA-)?[0-9]+\*\*' | grep -oE '[0-9]+' || true)"
    for q in $citadas; do
      printf '%s\n' "$abiertas" | grep -qx "$q" || fail "$slug: el caso pendiente PA-$q no corresponde a ninguna pregunta abierta del spec"
    done
    for q in $abiertas; do
      printf '%s\n' "$citadas" | grep -qx "$q" || fail "$slug: la pregunta abierta PA-$q no tiene caso pendiente en el plan"
    done
    nc="$(printf '%s\n' "$citadas" | grep -c . || true)"
    [ "$pend" -le "$nc" ] || fail "$slug: hay casos pendientes que no citan ninguna pregunta PA-n; las mejoras no generan pendientes"
  else
    # Compatibilidad: spec del formato anterior, sin ids; se compara por conteo
    if [ "$qa" -gt 0 ]; then
      [ "$pend" -ge 1 ] || fail "$slug: el spec tiene $qa preguntas abiertas pero el plan no tiene casos pendientes"
    fi
    [ "$pend" -le "$qa" ] || fail "$slug: $pend casos pendientes para $qa preguntas abiertas; las mejoras no generan pendientes"
  fi
  printf '%s' "$pendsec" | grep -q 'MJ-[0-9]' && fail "$slug: los casos pendientes mencionan mejoras MJ-n"
  hall="$(awk '/^## Hallazgos para el tech lead/{f=1;next} /^## /{f=0} f' "$p" | grep -v '^[[:space:]]*$' || true)"
  if [ -n "$hall" ] && ! printf '%s\n' "$hall" | grep -qx 'Ninguno\.\?'; then
    bad="$(printf '%s\n' "$hall" | grep '^- ' | grep -Ev '^- \*\*H-[0-9]+\*\*:' || true)"
    [ -z "$bad" ] || fail "$slug: hallazgos sin numerar H-n"
  fi
  grep -q '```' "$p" && fail "$slug: contiene bloques de código"
done

[ "$fails" -eq 0 ] && { echo "OK: qa"; exit 0; }
exit 1
