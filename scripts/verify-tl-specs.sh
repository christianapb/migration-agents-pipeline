#!/usr/bin/env bash
# Verifica los specs.
# Variables: MAX_PREGUNTAS (tope de preguntas abiertas por spec, por defecto 5),
# REQUIRE_HECHOS (propia del fixture; activa solo con FIXTURE=1: comprueba hechos y trampas con verify-hechos.sh;
# esté como hecho y como mejora, y no como pregunta abierta).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
W="${WORKDIR:-$PWD}"
M="$W/migration"
MAXP="${MAX_PREGUNTAS:-5}"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
# shellcheck source=lib-rev.sh
. "$HERE/lib-rev.sh"

# Líneas que son código y no prosa. Solo al inicio de línea: el código citado
# dentro de una frase, entre comillas invertidas, no cuenta. Cubre JavaScript y
# TypeScript, Python, y la familia de Java (Java, Kotlin, C#).
CODIGO_RE='^[[:space:]]*('
CODIGO_RE+='import |export |const |let |function |=> |app\.use|router\.(get|post)'
CODIGO_RE+='|def [A-Za-z_][A-Za-z0-9_]*\(|class [A-Z][A-Za-z0-9_]*[(:{ ]|from [A-Za-z0-9_.]+ import |@[A-Za-z_][A-Za-z0-9_.]*\('
CODIGO_RE+='|return [^ ]*[(;]|return [^ ].*;$|(if|elif|for|while|try|except|else|with)[ A-Za-z0-9_.,()=<>!"]*:$'
CODIGO_RE+='|(public|private|protected|internal) (static |final |abstract |class |interface |void |fun |val |var |[A-Za-z<>]+ [A-Za-z_]+ ?[(=;])'
CODIGO_RE+='|fun [A-Za-z_][A-Za-z0-9_]*\(|(val|var) [A-Za-z_][A-Za-z0-9_]* ?[:=]|package [a-z0-9_.]+;?$|(if|for|while) ?\(.*\) ?\{$'
CODIGO_RE+=')'

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
  cod="$(grep -nE "$CODIGO_RE" "$s" | head -n1)"
  [ -z "$cod" ] || fail "$n: contiene código del lenguaje origen (línea ${cod%%:*}: $(printf '%s' "${cod#*:}" | cut -c1-60))"
  grep -q '```' "$s" && fail "$n: contiene bloques de código"

  grep -q '^commits: ' "$s" || fail "$n: sin commits en el frontmatter"
  es_rev "$(campo "$s" rev)" || fail "$n: rev ausente o no es un entero mayor que 0 ('$(campo "$s" rev)')"

  # Evidencia por regla: cada RN-n y CB-n no retirada termina en una cita válida
  while IFS= read -r regla; do
    [ -n "$regla" ] || continue
    rid="$(printf '%s' "$regla" | grep -oE '(RN|CB)-[0-9]+' | head -n1)"
    cita="$(printf '%s' "$regla" | grep -oE '\[[^][]+\][[:space:]]*$' | sed -E 's/^\[//; s/\][[:space:]]*$//')"
    [ -n "$cita" ] || { fail "$n: $rid sin cita entre corchetes al final de la línea"; continue; }
    case "$cita" in
      "decisión: "*) continue ;;
    esac
    # Una cita puede combinar partes separadas por coma; cada una es
    # "ausente: ruta" o "ruta:línea[-fin]".
    while IFS= read -r c; do
      c="$(printf '%s' "$c" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      [ -n "$c" ] || continue
      case "$c" in
        "ausente: "*)
          ruta="${c#ausente: }"
          [ -f "$W/$ruta" ] || fail "$n: $rid cita como ausente un archivo que no existe: $ruta"
          continue ;;
      esac
      if ! printf '%s' "$c" | grep -Eq '^[^:[:space:]]+:[0-9]+(-[0-9]+)?$'; then
        fail "$n: $rid tiene una cita con formato inválido: '$c'"; continue
      fi
      ruta="${c%%:*}"; lin="${c##*:}"; fin="${lin##*-}"
      [ -f "$W/$ruta" ] || { fail "$n: $rid cita un archivo que no existe: $ruta"; continue; }
      total="$(awk 'END{print NR}' "$W/$ruta")"
      [ "$fin" -le "$total" ] || fail "$n: $rid cita la línea $fin de $ruta, que tiene $total"
    done <<< "$(printf '%s' "$cita" | tr ',' '\n')"
  done <<< "$(grep -E '^(- )?(RN|CB)-[0-9]+:' "$s" | grep -v '(retirado')"

  # Comportamientos por defecto: obligatorios si el spec expone endpoints HTTP.
  # Cada uno es una CB-n que empieza por la frase fija, o una pregunta abierta
  # que empieza igual si no se pudo determinar.
  contratos="$(section "$s" 5)"
  # Solo cuentan los endpoints que el spec declara (un método seguido de una
  # ruta, como título, viñeta o fila de tabla), no los que menciona de pasada:
  # una página puede describir un formulario que se envía a otra capacidad.
  declarados="$(printf '%s\n' "$contratos" | grep -E '^[#*` -]*(GET|POST|PUT|PATCH|DELETE)[ `]+/|^\|[ `]*(GET|POST|PUT|PATCH|DELETE)[ `]*\|' || true)"
  if [ -n "$declarados" ]; then
    frases=("Ruta no definida" "Método no permitido")
    if printf '%s' "$declarados" | grep -Eq '\b(POST|PUT|PATCH)\b'; then
      frases+=("Cuerpo ausente" "Cuerpo mal formado")
    fi
    for frase in "${frases[@]}"; do
      grep -E '^(- )?CB-[0-9]+:' "$s" | grep -v '(retirado' | grep -Eq "^(- )?CB-[0-9]+: $frase:" \
        || section "$s" 12 | grep -Eq "^- $frase:" \
        || fail "$n: falta el comportamiento por defecto '$frase:' (como CB-n o como pregunta abierta)"
    done
  fi

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

# Fidelidad, propia de cada fixture (solo con FIXTURE=1): los specs recogen los
# hechos del código y no afirman sus trampas. Los datos están en
# fixtures/hechos/<fixture>.txt; el comprobador no se entrega a los usuarios.
if [ "${REQUIRE_HECHOS:-${FIXTURE:-0}}" = 1 ] && [ -f "$HERE/verify-hechos.sh" ]; then
  salida="$(WORKDIR="$W" bash "$HERE/verify-hechos.sh" 2>&1)"; hrc=$?
  printf '%s\n' "$salida" | grep -E '^(CONOCIDO|---)' || true
  if [ "$hrc" -ne 0 ]; then
    printf '%s\n' "$salida" | grep '^FAIL' || true
    fails=$((fails + $(printf '%s\n' "$salida" | grep -c '^FAIL' || true)))
    [ "$fails" -gt 0 ] || fails=1
  fi
fi

[ "$fails" -eq 0 ] && { echo "OK: tl-specs"; exit 0; }
exit 1
