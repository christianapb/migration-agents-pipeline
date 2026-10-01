#!/usr/bin/env bash
# Verifica los specs.
# Variables: MAX_PREGUNTAS (tope de preguntas abiertas por spec, por defecto 5),
# REQUIRE_AMBIGUEDAD (1 por defecto: exige que el producto oculto del fixture
# esté como hecho y como mejora, y no como pregunta abierta).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
M="$W/migration"
MAXP="${MAX_PREGUNTAS:-5}"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

# Contenido de una sección numerada, hasta el siguiente encabezado de nivel 2.
section() { awk -v n="$2" '$0 ~ "^## " n "\\. " {f=1; next} /^## /{f=0} f' "$1"; }

specs=()
for f in "$M"/specs/[!_]*.md; do [ -f "$f" ] && specs+=("$f"); done
[ "${#specs[@]}" -gt 0 ] || { echo "FAIL: no hay specs"; exit 1; }
slugs="$(grep -oE '^\| [a-z0-9-]+ \|' "$M/specs/_capacidades.md" 2>/dev/null | sed -E 's/^\| //; s/ \|$//')"
todas_preguntas=""; todas_mejoras=""; todos_hechos=""
for s in "${specs[@]}"; do
  n="$(basename "$s" .md)"
  printf '%s\n' "$slugs" | grep -qx "$n" || fail "$n: spec sin fila en _capacidades.md"
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13; do
    grep -q "^## $i\. " "$s" || fail "$n: falta la sección $i"
  done
  grep -q '^estado: ' "$s" || fail "$n: sin estado"
  grep -Eq '^(- )?RN-1:' "$s" || fail "$n: sin reglas RN-n: al inicio de línea"
  grep -Eq '^(- )?CB-1:' "$s" || fail "$n: sin casos borde CB-n: al inicio de línea"
  if grep -Eq '^\s*(import |export |const |let |function |=> |app\.use|router\.(get|post))' "$s"; then
    fail "$n: contiene código del lenguaje origen"
  fi
  grep -q '```' "$s" && fail "$n: contiene bloques de código"

  grep -q '^commits: ' "$s" || fail "$n: sin commits en el frontmatter"

  # Evidencia por regla: cada RN-n y CB-n no retirada termina en una cita válida
  while IFS= read -r regla; do
    [ -n "$regla" ] || continue
    rid="$(printf '%s' "$regla" | grep -oE '(RN|CB)-[0-9]+' | head -n1)"
    cita="$(printf '%s' "$regla" | grep -oE '\[[^][]+\][[:space:]]*$' | sed -E 's/^\[//; s/\][[:space:]]*$//')"
    [ -n "$cita" ] || { fail "$n: $rid sin cita entre corchetes al final de la línea"; continue; }
    case "$cita" in
      "decisión: "*) continue ;;
      "ausente: "*)
        ruta="${cita#ausente: }"
        [ -f "$W/$ruta" ] || fail "$n: $rid cita como ausente un archivo que no existe: $ruta"
        continue ;;
    esac
    while IFS= read -r c; do
      c="$(printf '%s' "$c" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      [ -n "$c" ] || continue
      if ! printf '%s' "$c" | grep -Eq '^[^:[:space:]]+:[0-9]+(-[0-9]+)?$'; then
        fail "$n: $rid tiene una cita con formato inválido: '$c'"; continue
      fi
      ruta="${c%%:*}"; lin="${c##*:}"; fin="${lin##*-}"
      [ -f "$W/$ruta" ] || { fail "$n: $rid cita un archivo que no existe: $ruta"; continue; }
      total="$(awk 'END{print NR}' "$W/$ruta")"
      [ "$fin" -le "$total" ] || fail "$n: $rid cita la línea $fin de $ruta, que tiene $total"
    done <<< "$(printf '%s' "$cita" | tr ',' '\n')"
  done <<< "$(grep -E '^(- )?(RN|CB)-[0-9]+:' "$s" | grep -v '(retirado')"

  # Preguntas abiertas: solo incógnitas reales, pocas y sin fórmulas de mejora
  preguntas="$(section "$s" 12 | grep '^- ' | grep -v '(retirado' || true)"
  np="$(printf '%s\n' "$preguntas" | grep -c . || true)"
  [ "$np" -le "$MAXP" ] || fail "$n: $np preguntas abiertas, el tope es $MAXP (lo que el código determina va en la sección 13)"
  malas="$(printf '%s\n' "$preguntas" | grep -Ei 'se mantiene|se conserva|debe seguir|en lugar de' || true)"
  [ -z "$malas" ] || fail "$n: preguntas abiertas con fórmula de mejora: $(printf '%s' "$malas" | head -n1 | cut -c1-80)"

  # Mejoras: cada MJ-n cita una RN-n o CB-n definida en el mismo spec
  mejoras="$(section "$s" 13 | grep -E '^(- )?MJ-[0-9]+:' || true)"
  defs="$(grep -oE '^(- )?(RN|CB)-[0-9]+:' "$s" | sed -E 's/^- //; s/:$//' | sort -u)"
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    mid="$(printf '%s' "$m" | grep -oE 'MJ-[0-9]+' | head -n1)"
    refs="$(printf '%s' "$m" | grep -oE '\b(RN|CB)-[0-9]+\b' | sort -u)"
    [ -n "$refs" ] || { fail "$n: $mid no cita ninguna RN-n ni CB-n"; continue; }
    for r in $refs; do
      printf '%s\n' "$defs" | grep -qx "$r" || fail "$n: $mid cita $r, que no existe en el spec"
    done
  done <<< "$mejoras"

  todas_preguntas+="$preguntas"$'\n'
  todas_mejoras+="$mejoras"$'\n'
  todos_hechos+="$(grep -E '^(- )?(RN|CB)-[0-9]+:' "$s")"$'\n'
done

if [ "${REQUIRE_AMBIGUEDAD:-1}" = 1 ]; then
  # El producto oculto (200 sin cuerpo) lo determina el código: hecho + mejora, no pregunta.
  printf '%s' "$todos_hechos" | grep -Eiq 'ocult|hidden' || fail "ninguna RN/CB recoge el comportamiento del producto oculto"
  printf '%s' "$todas_mejoras" | grep -Eiq 'ocult|hidden' || fail "ninguna mejora MJ-n menciona el producto oculto (200 vacío frente a 404)"
  printf '%s' "$todas_preguntas" | grep -Eiq 'ocult|hidden' && fail "el producto oculto aparece como pregunta abierta; el código lo determina, es una mejora"
fi

[ "$fails" -eq 0 ] && { echo "OK: tl-specs"; exit 0; }
exit 1
