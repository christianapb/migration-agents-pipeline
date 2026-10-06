#!/usr/bin/env bash
# Pruebas de backlog.sh sobre conjuntos de tareas sintéticos. No ejecuta agentes.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
B="$ROOT/scripts/backlog.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

# Tarea mínima: <ws> <id> <spec> <dependencias separadas por coma> <tamaño> [estado] [fase] [prioridad] [bloqueada_por] [adrs]
mk() {
  local ws="$1" id="$2" spec="$3" deps="${4//,/, }" tam="$5" estado="${6:-generado}" fase="${7:-}" prio="${8:-}" bloq="${9:-}" adrs="${10:-}"
  mkdir -p "$ws/migration/tasks"
  printf -- '---\nid: %s\ntitulo: Tarea %s\nrev: 1\nspec: %s\nspec_rev: %s\nrepo_destino: bff\ntipo: implementacion\ndepende_de: [%s]\ntamaño: %s\nadrs: [%s]\nadrs_rev: {}\nestado: %s\nfase: %s\nprioridad: %s\nbloqueada_por: [%s]\n---\n# %s: Tarea %s\n\n## Criterios de aceptación\n- fase: no es un campo aquí\n' \
    "$id" "$id" "$spec" "${spec:+1}" "$deps" "$tam" "$adrs" "$estado" "$fase" "$prio" "$bloq" "$id" "$id" > "$ws/migration/tasks/$id-tarea.md"
}
mapa() { # <ws> <capacidades...>
  local ws="$1" c; shift
  mkdir -p "$ws/migration/specs" "$ws/migration/adr" "$ws/migration/test-plans"
  { printf '# Capacidades\n\n| Capacidad | Descripción | Repos | Archivos principales |\n|---|---|---|---|\n'
    for c in "$@"; do printf '| %s | x | bff | bff/a.ts |\n' "$c"; done; } > "$ws/migration/specs/_capacidades.md"
}
# Las 25 tareas que el flujo genera hoy para el fixture
fixture_tasks() {
  local ws="$1"
  mapa "$ws" autenticacion listado-productos carrito
  mk "$ws" T-001 "" "" M;            mk "$ws" T-002 "" "" M
  mk "$ws" T-003 "" T-001 S;         mk "$ws" T-004 "" T-002 M
  mk "$ws" T-005 "" T-001 S;         mk "$ws" T-006 "" T-001 S
  mk "$ws" T-007 "" T-003,T-009 S;   mk "$ws" T-008 "" T-004,T-010 S
  mk "$ws" T-009 "" T-003 M;         mk "$ws" T-010 "" T-004 M
  mk "$ws" T-011 autenticacion T-003,T-005,T-006 L generado "" "" "0011,PA:autenticacion:1" 0011
  mk "$ws" T-012 autenticacion T-005,T-006,T-011 M
  mk "$ws" T-013 autenticacion T-006,T-011,T-012 M
  mk "$ws" T-014 autenticacion T-002,T-004 M
  mk "$ws" T-015 autenticacion T-002,T-014 M
  mk "$ws" T-016 autenticacion T-009,T-011,T-012,T-013 M
  mk "$ws" T-017 listado-productos T-003,T-006 M generado "" "" "0011" 0011
  mk "$ws" T-018 listado-productos T-006,T-013,T-017 M
  mk "$ws" T-019 listado-productos T-002,T-014 S
  mk "$ws" T-020 listado-productos T-009,T-017,T-018 S
  mk "$ws" T-021 carrito T-006,T-012,T-017 M
  mk "$ws" T-022 carrito T-017,T-021 M
  mk "$ws" T-023 carrito T-013,T-021,T-022 M
  mk "$ws" T-024 carrito T-002,T-014,T-019 M
  mk "$ws" T-025 carrito T-009,T-021,T-022,T-023 M
  printf -- '---\nid: 0011\ntitulo: Framework HTTP del BFF\nrev: 1\nrepos: [bff]\nestado: propuesto\nimplicacion_migracion:\n---\n# ADR 0011\n' > "$ws/migration/adr/0011-framework.md"
  printf -- '---\ncapacidad: autenticacion\nestado: generado\nrev: 1\n---\n# Spec\n## 12. Preguntas abiertas\n- PA-1: ¿Qué responde identidad con una cuenta bloqueada?\n## 13. Posibles mejoras\nNinguna\n' > "$ws/migration/specs/autenticacion.md"
  : > "$ws/migration/test-plans/autenticacion.md"
}
tsv() { bash "$B" calcular --tsv "$1"; }
campo_tsv() { awk -F'\t' -v id="$2" -v c="$3" '$1==id {print $c}' "$1"; }
# Invariantes sobre un TSV y sus tareas: fases y prioridades respetan dependencias; prioridades únicas
invariantes() { # <ws> <tsv> <etiqueta>
  local dup malas
  dup="$(cut -f3 "$2" | sort -n | uniq -d | head -n3 | paste -sd' ' -)"
  [ -z "$dup" ] || fail "$3: prioridades repetidas: $dup"
  malas="$(grep -H '^depende_de:' "$1"/migration/tasks/*.md | sed -E 's#.*/(T-[0-9]+)-[^:]*:depende_de: \[(.*)\]#\1 \2#' | tr -d ',' \
    | awk -F'\t' 'NR==FNR {f[$1]=$2; p[$1]=$3; next} { n=split($0, a, " "); for (i=2; i<=n; i++) { if (f[a[i]]+0 > f[a[1]]+0) print a[1] " en fase " f[a[1]] " depende de " a[i] " en fase " f[a[i]]; if (p[a[i]]+0 >= p[a[1]]+0) print a[1] " con prioridad " p[a[1]] " depende de " a[i] " con prioridad " p[a[i]] } }' "$2" - | head -n3)"
  [ -z "$malas" ] || fail "$3: $malas"
}

[ -f "$B" ] || { echo "FAIL: no existe scripts/backlog.sh"; exit 1; }

# 1. Ciclo de dos tareas
W="$TMP/c2"; mapa "$W" alfa
mk "$W" T-001 "" "" S; mk "$W" T-002 alfa T-003 M; mk "$W" T-003 alfa T-002 M; mk "$W" T-004 alfa T-001 S
out="$(bash "$B" validar "$W" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || fail "ciclo de dos: validar terminó con código 0"
printf '%s' "$out" | grep -qi 'ciclo' || fail "ciclo de dos: no menciona 'ciclo'"
for t in T-002 T-003; do printf '%s' "$out" | grep -q "$t" || fail "ciclo de dos: no nombra $t"; done
printf '%s' "$out" | grep -i 'ciclo' | grep -q 'T-004\|T-001' && fail "ciclo de dos: nombra tareas que no están en el ciclo"
h="$(cat "$W"/migration/tasks/* | md5sum)"
bash "$B" calcular "$W" >/dev/null 2>&1 && fail "ciclo de dos: calcular terminó con código 0"
bash "$B" aplicar "$W" >/dev/null 2>&1 && fail "ciclo de dos: aplicar terminó con código 0"
[ "$(cat "$W"/migration/tasks/* | md5sum)" = "$h" ] || fail "ciclo de dos: aplicar modificó tareas pese al ciclo"

# 2. Ciclo largo
W="$TMP/c5"; mapa "$W" alfa
mk "$W" T-001 "" "" S; mk "$W" T-010 alfa T-050,T-001 M; mk "$W" T-020 alfa T-010 M; mk "$W" T-030 alfa T-020 M; mk "$W" T-040 alfa T-030 M; mk "$W" T-050 alfa T-040 M; mk "$W" T-060 alfa T-050 M
out="$(bash "$B" validar "$W" 2>&1)" && fail "ciclo largo: validar terminó con código 0"
for t in T-010 T-020 T-030 T-040 T-050; do printf '%s' "$out" | grep -i 'ciclo' | grep -q "$t" || fail "ciclo largo: no nombra $t"; done
printf '%s' "$out" | grep -i 'ciclo' | grep -q 'T-060' && fail "ciclo largo: nombra T-060, que solo depende del ciclo"

# 2b. Una tarea que depende de sí misma
W="$TMP/c1"; mapa "$W" alfa; mk "$W" T-001 "" "" S; mk "$W" T-002 alfa T-002 M
out="$(bash "$B" validar "$W" 2>&1)" && fail "autodependencia: validar terminó con código 0"
printf '%s' "$out" | grep -i 'ciclo' | grep -q 'T-002' || fail "autodependencia: no la trata como ciclo"

# 3. Dependencia a un id inexistente
W="$TMP/rota"; mapa "$W" alfa; mk "$W" T-001 "" "" S; mk "$W" T-002 alfa T-001,T-099 M
out="$(bash "$B" validar "$W" 2>&1)" && fail "dependencia rota: validar terminó con código 0"
printf '%s' "$out" | grep 'no existe' | grep 'T-002' | grep -q 'T-099' || fail "dependencia rota: no dice que T-099 no existe ni nombra T-002"

# 3b. Fundacional que depende de una tarea de capacidad
W="$TMP/fund"; mapa "$W" alfa; mk "$W" T-001 "" T-002 S; mk "$W" T-002 alfa "" M
bash "$B" validar "$W" >/dev/null 2>&1 && fail "fundacional que depende de capacidad: validar terminó con código 0"

# 4. Las tareas del fixture: fundaciones, y las capacidades en orden de dependencia
W="$TMP/fx"; fixture_tasks "$W"
bash "$B" validar "$W" >/dev/null 2>&1 || fail "fixture: validar falla"
tsv "$W" > "$TMP/fx.tsv" || fail "fixture: calcular --tsv falla"
[ "$(wc -l < "$TMP/fx.tsv")" -eq 25 ] || fail "fixture: el TSV tiene $(wc -l < "$TMP/fx.tsv") filas, se esperaban 25"
for n in 01 02 03 04 05 06 07 08 09 10; do [ "$(campo_tsv "$TMP/fx.tsv" "T-0$n" 2)" = 0 ] || fail "fixture: T-0$n no está en el hito 0"; done
for n in 11 12 13 14 15 16; do [ "$(campo_tsv "$TMP/fx.tsv" "T-0$n" 2)" = 1 ] || fail "fixture: T-0$n (autenticacion) no está en la fase 1"; done
for n in 17 18 19 20; do [ "$(campo_tsv "$TMP/fx.tsv" "T-0$n" 2)" = 2 ] || fail "fixture: T-0$n (listado-productos) no está en la fase 2"; done
for n in 21 22 23 24 25; do [ "$(campo_tsv "$TMP/fx.tsv" "T-0$n" 2)" = 3 ] || fail "fixture: T-0$n (carrito) no está en la fase 3"; done
[ "$(cut -f3 "$TMP/fx.tsv" | sort -n | paste -sd, -)" = "$(seq -s, 1 25)" ] || fail "fixture: las prioridades no son 1..25 sin repetir"
[ "$(campo_tsv "$TMP/fx.tsv" T-001 3)" = 1 ] || fail "fixture: T-001, de la que más tareas dependen, no tiene prioridad 1"
invariantes "$W" "$TMP/fx.tsv" "fixture"
md="$(bash "$B" calcular "$W")"
for k in '## Fases' '### Hito 0: fundaciones' '### Hito 1: autenticacion' '### Hito 3: carrito' '| Orden | Tarea | Rev | Título | Tamaño | Depende de | Plan de pruebas |' '## Bloqueos' '## Datos' 'Camino crítico'; do
  printf '%s' "$md" | grep -qF -- "$k" || fail "fixture: la salida de calcular no contiene '$k'"
done
printf '%s' "$md" | grep -qE '^\| 11 \| T-011 \| 1 \| Tarea T-011 \| L \| T-003, T-005, T-006 \| test-plans/autenticacion.md \|$' || fail "fixture: la fila de T-011 no tiene el formato esperado: $(printf '%s' "$md" | grep '| T-011 |' | head -n1)"
printf '%s' "$md" | grep -q '| T-017 |.*| — |$' || fail "fixture: T-017 no marca '—' cuando falta su plan de pruebas"
printf '%s' "$md" | awk '/^## Bloqueos/{f=1} f' | grep -q 'T-011.*0011' || fail "fixture: Bloqueos no lista T-011 bloqueada por el ADR 0011"
printf '%s' "$md" | awk '/^## Bloqueos/{f=1} f' | grep -q 'cuenta bloqueada' || fail "fixture: Bloqueos no cita la pregunta abierta PA:autenticacion:1"

# 4b. La pregunta de un bloqueo se busca por su id, no por su lugar en la lista
SPF="$W/migration/specs/autenticacion.md"
sed -i 's/^- PA-1: ¿Qué responde identidad.*/- PA-7: ¿Una pregunta añadida arriba?\n&/' "$SPF"
bash "$B" calcular "$W" | awk '/^## Bloqueos/{f=1} f' | grep 'PA:autenticacion:1' | grep -q 'cuenta bloqueada' || fail "backlog.sh cita la pregunta por su lugar y no por su id"
bash "$B" calcular "$W" | awk '/^## Bloqueos/{f=1} f' | grep 'PA:autenticacion:1' | grep -q '^| T-011 | PA:autenticacion:1 | ¿Qué responde' || fail "backlog.sh no quita el id del texto de la pregunta citada"
sed -i '/^- PA-1: /d' "$SPF"
bash "$B" calcular "$W" | awk '/^## Bloqueos/{f=1} f' | grep 'PA:autenticacion:1' | grep -q 'pregunta no encontrada' || fail "backlog.sh cita otra pregunta cuando el id no existe"
# Compatibilidad: un spec sin ids se resuelve por el lugar en la lista
sed -i 's/^- PA-7: .*/- ¿Primera, sin id?\n- ¿Segunda, sin id?/' "$SPF"
bash "$B" calcular "$W" | awk '/^## Bloqueos/{f=1} f' | grep 'PA:autenticacion:1' | grep -q '¿Primera, sin id?' || fail "backlog.sh no resuelve por lugar un spec del formato anterior"
fixture_tasks "$W"

# 5. Determinismo, también con los archivos en otro orden
bash "$B" calcular "$W" > "$TMP/a.md"; bash "$B" calcular "$W" > "$TMP/b.md"
cmp -s "$TMP/a.md" "$TMP/b.md" || fail "determinismo: dos ejecuciones dan salidas distintas"
ls "$W"/migration/tasks/*.md | sort -r > "$TMP/inverso.txt"
BACKLOG_LISTA="$TMP/inverso.txt" bash "$B" calcular "$W" > "$TMP/c.md"
cmp -s "$TMP/a.md" "$TMP/c.md" || fail "determinismo: la salida depende del orden en que se listan los archivos"

# 6. Tarea revisado con fase y prioridad fijadas
W="$TMP/fija"; fixture_tasks "$W"
mk "$W" T-019 listado-productos T-002,T-014 S revisado 5 99
fija="$(md5sum < "$W/migration/tasks/T-019-tarea.md")"
tsv "$W" > "$TMP/fija.tsv"
[ "$(campo_tsv "$TMP/fija.tsv" T-019 2)" = 5 ] && [ "$(campo_tsv "$TMP/fija.tsv" T-019 3)" = 99 ] || fail "tarea fijada: no conserva fase 5 y prioridad 99 ($(grep T-019 "$TMP/fija.tsv" | tr '\t' ' '))"
[ "$(campo_tsv "$TMP/fija.tsv" T-024 2)" -ge 5 ] 2>/dev/null || fail "tarea fijada: T-024 depende de T-019 (fase 5) y queda en una fase anterior"
dup="$(cut -f3 "$TMP/fija.tsv" | sort -n | uniq -d)"; [ -z "$dup" ] || fail "tarea fijada: prioridades repetidas: $dup"
bash "$B" aplicar "$W" >/dev/null || fail "tarea fijada: aplicar falla"
[ "$(md5sum < "$W/migration/tasks/T-019-tarea.md")" = "$fija" ] || fail "tarea fijada: aplicar modificó la tarea revisado"

# 7. Aplicar solo cambia fase y prioridad
W="$TMP/apl"; fixture_tasks "$W"
printf -- '---\r\nid: T-026\r\ntitulo: Con CRLF\r\nrev: 4\r\nspec: carrito\r\nspec_rev: 1\r\ndepende_de: [T-021]\r\ntamaño: S\r\nadrs: []\r\nestado: generado\r\nfase:\r\nprioridad:\r\nbloqueada_por: []\r\n---\r\n# T-026\r\nfase: en el cuerpo no se toca' > "$W/migration/tasks/T-026-crlf.md"
antes="$(for f in "$W"/migration/tasks/*.md; do awk 'NR==1{fm=1;print;next} fm && /^---/{fm=0} fm && /^(fase|prioridad):/{next} {print}' "$f" | md5sum; done)"
bash "$B" aplicar "$W" >/dev/null || fail "aplicar: terminó con error"
despues="$(for f in "$W"/migration/tasks/*.md; do awk 'NR==1{fm=1;print;next} fm && /^---/{fm=0} fm && /^(fase|prioridad):/{next} {print}' "$f" | md5sum; done)"
[ "$antes" = "$despues" ] || fail "aplicar: cambió líneas distintas de fase y prioridad"
tsv "$W" > "$TMP/apl.tsv"
while IFS=$'\t' read -r id f p; do
  t="$(ls "$W"/migration/tasks/"$id"-*.md)"
  [ "$(sed -n 's/^fase:[[:space:]]*//p' "$t" | head -n1 | tr -d '\r')" = "$f" ] || fail "aplicar: $id no quedó con fase $f"
  [ "$(sed -n 's/^prioridad:[[:space:]]*//p' "$t" | head -n1 | tr -d '\r')" = "$p" ] || fail "aplicar: $id no quedó con prioridad $p"
done < "$TMP/apl.tsv"
[ "$(tr -cd '\r' < "$W/migration/tasks/T-026-crlf.md" | wc -c)" -eq 15 ] || fail "aplicar: no conservó los finales de línea CRLF"
[ "$(tail -c 29 "$W/migration/tasks/T-026-crlf.md")" = "fase: en el cuerpo no se toca" ] || fail "aplicar: tocó una línea 'fase:' del cuerpo o añadió un salto final"
grep -aq '^rev: 4' "$W/migration/tasks/T-026-crlf.md" || fail "aplicar: cambió rev"
bash "$B" aplicar "$W" >/dev/null; tsv "$W" > "$TMP/apl2.tsv"
cmp -s "$TMP/apl.tsv" "$TMP/apl2.tsv" || fail "aplicar: recalcular después de aplicar da otro resultado"

# 8. 200 tareas: 10 fundacionales y 19 capacidades de 10
W="$TMP/g"; caps=(); for c in $(seq 1 19); do caps+=("cap$(printf '%02d' "$c")"); done
mapa "$W" "${caps[@]}"
for i in $(seq 1 10); do
  d=""; [ "$i" -gt 1 ] && d="T-$(printf '%03d' $(( i / 2 )))"
  mk "$W" "T-$(printf '%03d' "$i")" "" "$d" M
done
n=10
for c in $(seq 1 19); do
  for k in $(seq 1 10); do
    n=$((n+1)); id="T-$(printf '%03d' "$n")"; d="T-$(printf '%03d' $(( (n % 10) + 1 )))"
    [ "$k" -gt 1 ] && d="$d,T-$(printf '%03d' $((n-1)))"
    [ "$k" -eq 1 ] && [ "$c" -gt 1 ] && [ $((c % 3)) -ne 0 ] && d="$d,T-$(printf '%03d' $((n-1)))"
    case $((n % 3)) in 0) s=S ;; 1) s=M ;; *) s=L ;; esac
    mk "$W" "$id" "cap$(printf '%02d' "$c")" "$d" "$s"
  done
done
[ "$(ls "$W"/migration/tasks | wc -l)" -eq 200 ] || fail "200 tareas: el generador produjo $(ls "$W"/migration/tasks | wc -l)"
t0=$(date +%s%N)
tsv "$W" > "$TMP/g.tsv" || fail "200 tareas: calcular --tsv falla"
t1=$(date +%s%N)
ms=$(( (t1 - t0) / 1000000 ))
echo "--- 200 tareas: calcular tarda ${ms} ms"
[ "$ms" -lt 20000 ] || fail "200 tareas: calcular tarda ${ms} ms"
[ "$(wc -l < "$TMP/g.tsv")" -eq 200 ] || fail "200 tareas: el TSV tiene $(wc -l < "$TMP/g.tsv") filas"
invariantes "$W" "$TMP/g.tsv" "200 tareas"
[ "$(awk -F'\t' '$2==0' "$TMP/g.tsv" | wc -l)" -eq 10 ] || fail "200 tareas: el hito 0 no tiene exactamente las 10 fundacionales"
bash "$B" calcular "$W" > "$TMP/g.md" || fail "200 tareas: calcular falla"
bash "$B" aplicar "$W" >/dev/null || fail "200 tareas: aplicar falla"

# 9. Sin tareas
W="$TMP/vacio"; mapa "$W" alfa; mkdir -p "$W/migration/tasks"
bash "$B" validar "$W" >/dev/null 2>&1 && fail "sin tareas: validar terminó con código 0"

[ "$fails" -eq 0 ] && { echo "OK: backlog"; exit 0; }
exit 1
