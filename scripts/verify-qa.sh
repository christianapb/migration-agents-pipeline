#!/usr/bin/env bash
# Verifica los planes de prueba en .work/sample-workspace/migration/test-plans.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

specs=$(ls "$M"/specs/*.md 2>/dev/null | grep -v '/_' || true)
[ -n "$specs" ] || fail "no hay specs; corre migration-techlead"
[ -f "$M/test-plans/_cobertura.md" ] || fail "_cobertura.md no existe"

pending_total=0
for s in $specs; do
  slug=$(basename "$s" .md)
  p="$M/test-plans/$slug.md"
  [ -f "$p" ] || { fail "falta test-plans/$slug.md"; continue; }
  grep -q "^spec: $slug" "$p" || fail "$slug: frontmatter spec no apunta al spec"
  grep -q '^estado: ' "$p" || fail "$slug: sin estado"
  for sec in "## Alcance y supuestos" "## Matriz de cobertura" "## Casos: camino feliz" "## Casos: errores" "## Casos pendientes de definición" "## Hallazgos para el tech lead"; do
    grep -q "^$sec" "$p" || fail "$slug: falta sección '$sec'"
  done
  cases=$(grep -c "^### TC-$slug-[0-9]\{3\}: " "$p" || true)
  [ "$cases" -ge 3 ] || fail "$slug: solo $cases casos TC-$slug-nnn"
  # Cada caso tiene Dado/Cuando/Entonces y Cubre
  dado=$(grep -c '^- Dado ' "$p" || true); cuando=$(grep -c '^- Cuando ' "$p" || true); entonces=$(grep -c '^- Entonces ' "$p" || true)
  [ "$dado" -ge "$cases" ] && [ "$cuando" -ge "$cases" ] && [ "$entonces" -ge "$cases" ] || fail "$slug: casos sin Dado/Cuando/Entonces completos ($dado/$cuando/$entonces de $cases)"
  cubre=$(grep -c '^- Cubre: ' "$p" || true)
  [ "$cubre" -ge "$cases" ] || fail "$slug: casos sin línea Cubre"
  # Toda RN y CB del spec aparece en el plan o en _cobertura.md como sin cubrir
  for id in $(grep -oE '\b(RN|CB)-[0-9]+' "$s" | sort -u); do
    grep -q "$id" "$p" || grep -q "$id" "$M/test-plans/_cobertura.md" || fail "$slug: $id no aparece ni en el plan ni en _cobertura.md"
  done
  # Preguntas abiertas → casos pendientes
  qa=$(awk '/^## 12\. Preguntas abiertas/{f=1;next} f' "$s" | grep -c '^- ' || true)
  if [ "$qa" -gt 0 ]; then
    pend=$(awk '/^## Casos pendientes de definición/{f=1;next} /^## /{f=0} f' "$p" | grep -c '^- \|^### ' || true)
    [ "$pend" -ge 1 ] || fail "$slug: el spec tiene $qa preguntas abiertas pero el plan no tiene casos pendientes"
    pending_total=$((pending_total+pend))
  fi
  grep -q '```' "$p" && fail "$slug: contiene bloques de código"
done
[ "$pending_total" -ge 1 ] || fail "ningún plan tiene casos pendientes; la ambigüedad del fixture debería producir al menos uno"

[ "$fails" -eq 0 ] && { echo "OK: qa"; exit 0; }
exit 1
