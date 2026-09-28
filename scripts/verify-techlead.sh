#!/usr/bin/env bash
# Verifica los artefactos del tech lead en .work/sample-workspace/migration.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

# Mapa de capacidades
[ -f "$M/specs/_capacidades.md" ] || fail "_capacidades.md no existe"
rows=$(grep -c '^| [a-z0-9-]* |' "$M/specs/_capacidades.md" 2>/dev/null || echo 0)
[ "$rows" -ge 3 ] || fail "_capacidades.md tiene $rows filas, se esperaban al menos 3"

# Specs
specs=$(ls "$M"/specs/*.md 2>/dev/null | grep -v '/_' || true)
[ -n "$specs" ] || fail "no hay specs"
for s in $specs; do
  n=$(basename "$s")
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    grep -q "^## $i\. " "$s" || fail "$n: falta la sección $i"
  done
  grep -q '^estado: ' "$s" || fail "$n: sin estado"
  grep -q 'RN-1' "$s" || fail "$n: sin reglas numeradas RN-n"
  grep -q 'CB-1' "$s" || fail "$n: sin casos borde numerados CB-n"
  # Sin código JS/TS en el cuerpo
  if grep -Eq '^\s*(import |export |const |let |function |=> |app\.use|router\.(get|post))' "$s"; then
    fail "$n: contiene código del lenguaje origen"
  fi
  grep -q '```' "$s" && fail "$n: contiene bloques de código"
done

# La ambigüedad de products debe aparecer como pregunta abierta en algún spec
if [ -n "$specs" ]; then
  preguntas=""
  for s in $specs; do
    preguntas+="$(awk '/^## 12\. Preguntas abiertas/{f=1;next} f' "$s")"$'\n'
  done
  if ! printf '%s' "$preguntas" | grep -Eiq '200|vac[ií]o|oculto|hidden'; then
    fail "ninguna pregunta abierta menciona el caso del producto oculto (200 vacío vs 404)"
  fi
fi

# ADRs
[ -d "$M/adr" ] || fail "no hay carpeta adr"
grep -lq '^estado: observado' "$M"/adr/*.md 2>/dev/null || fail "no hay ADR observado"
grep -lq '^estado: propuesto' "$M"/adr/*.md 2>/dev/null || fail "no hay ADR propuesto"
for a in "$M"/adr/*.md; do
  [ -f "$a" ] || continue
  n=$(basename "$a")
  echo "$n" | grep -Eq '^[0-9]{4}-[a-z0-9-]+\.md$' || fail "$n: nombre no sigue NNNN-slug.md"
  grep -q '^## Implicación para la migración' "$a" || fail "$n: sin sección de implicación"
  grep -q '^## Evidencia' "$a" || fail "$n: sin evidencia"
done

# Tareas
tasks=$(ls "$M"/tasks/T-*.md 2>/dev/null || true)
[ -n "$tasks" ] || fail "no hay tareas"
fund=0
for t in $tasks; do
  n=$(basename "$t")
  echo "$n" | grep -Eq '^T-[0-9]{3}-[a-z0-9-]+\.md$' || fail "$n: nombre no sigue T-NNN-slug.md"
  id=$(sed -n 's/^id:[[:space:]]*//p' "$t" | head -n1)
  case "$n" in "$id"-*) ;; *) fail "$n: id '$id' no coincide con el archivo";; esac
  grep -q '^estado: ' "$t" || fail "$n: sin estado"
  grep -q '^depende_de: ' "$t" || fail "$n: sin depende_de"
  grep -q '^tamaño: [SML]$' "$t" || fail "$n: tamaño inválido"
  grep -q '^## Criterios de aceptación' "$t" || fail "$n: sin criterios de aceptación"
  spec=$(sed -n 's/^spec:[[:space:]]*//p' "$t" | head -n1)
  if [ -z "$spec" ]; then
    fund=$((fund+1))
  else
    [ -f "$M/specs/$spec.md" ] || fail "$n: spec '$spec' no existe"
  fi
done
[ "$fund" -ge 1 ] || fail "no hay tareas fundacionales (spec vacío)"

# Tareas bloqueadas por ADR propuesto
if [ -n "$tasks" ]; then
  grep -lq '^bloqueada_por: \[.\+\]' $tasks || fail "ninguna tarea está bloqueada por un ADR propuesto"
fi

[ "$fails" -eq 0 ] && { echo "OK: techlead"; exit 0; }
exit 1
