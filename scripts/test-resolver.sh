#!/usr/bin/env bash
# Casos 4 a 8 del spec v2 y Review Focus 1 y 2. Prepara su propio workspace.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
export WORKDIR="$W"
SNAP_TMP="$(mktemp -d)"
trap 'rm -rf "$SNAP_TMP"' EXIT
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
run() { bash "$ROOT/scripts/run-agent.sh" "$@"; rc=$?; [ $rc -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }; return $rc; }
R() { run migration-tl-resolver "$1"; }
adrfile() { ls "$M"/adr/"$1"-*.md 2>/dev/null | head -n1; }
. "$ROOT/scripts/lib-rev.sh"
revs_tareas() { grep -H '^rev:' "$M"/tasks/*.md 2>/dev/null | sort; }

if [ "${SKIP_SETUP:-0}" != 1 ]; then
  bash "$ROOT/scripts/snapshot.sh" restore qa "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa qa"; exit 1; }
fi

# Caso 4: decidir un ADR propuesto aceptando la recomendación
P="$(grep -l '^estado: propuesto' "$M"/adr/*.md | head -n1 | xargs basename | cut -c1-4)"
[ -n "$P" ] || { echo "FAIL: no hay ADR propuesto"; exit 1; }
rev_before="$(grep -l '^estado: revisado' "$M"/tasks/*.md 2>/dev/null | sort)"
v_adr="$(rev_de "$(adrfile "$P")")"; v_tareas="$(revs_tareas)"
R "En el ADR $P acepta la recomendación." >/dev/null
[ "$(rev_de "$(adrfile "$P")")" = "$((v_adr+1))" ] || fail "caso 4: decidir el ADR $P no subió su rev en 1 ($v_adr → $(campo "$(adrfile "$P")" rev))"
[ "$(revs_tareas)" = "$v_tareas" ] || fail "caso 4: la limpieza de bloqueada_por cambió el rev de alguna tarea"
rev_after="$(grep -l '^estado: revisado' "$M"/tasks/*.md 2>/dev/null | sort)"
[ "$rev_before" = "$rev_after" ] || fail "caso 4: la limpieza de bloqueada_por cambió el estado de tareas"
f="$(adrfile "$P")"
grep -q '^estado: revisado' "$f" || fail "caso 4: ADR $P no quedó revisado"
grep -q 'Recomendación:' "$f" && fail "caso 4: ADR $P conserva la recomendación"
grep -l "^bloqueada_por:.*\b$P\b" "$M"/tasks/*.md >/dev/null 2>&1 && fail "caso 4: alguna tarea sigue bloqueada por $P"

# Review Focus 2: cambiar una decisión ya revisada
before="$(md5sum < "$f")"
R "En el ADR $P cambio la decisión: elijo la primera opción de las alternativas." >/dev/null
[ "$(md5sum < "$f")" != "$before" ] || fail "RF2: la decisión del ADR $P no cambió"
grep -q '^estado: revisado' "$f" || fail "RF2: ADR $P dejó de estar revisado"
grep -q 'Recomendación:' "$f" && fail "RF2: reapareció la recomendación"

# Caso 5: responder una pregunta abierta sin renumerar
sec12() { awk '/^## 12\. /{f=1;next} /^## /{f=0} f' "$1"; }
S="$(for s in "$M"/specs/[!_]*.md; do sec12 "$s" | grep -q '^- ' && { basename "$s" .md; break; }; done)"
if [ -z "$S" ]; then
  # Bajo paridad puede no haber preguntas abiertas: se siembra una para probar la operación.
  S="$(ls "$M"/specs | grep -v '^_' | head -n1 | sed 's/\.md$//')"
  sed -i 's/^## 12\. Preguntas abiertas.*/&\n- ¿Qué responde el sistema externo de pagos ante un cobro duplicado?/' "$M/specs/$S.md"
fi
q1="$(sec12 "$M/specs/$S.md" | grep '^- ' | head -n1)"
ids_before="$(grep -oE '^(- )?(RN|CB)-[0-9]+:' "$M/specs/$S.md" | sort)"
v_spec="$(rev_de "$M/specs/$S.md")"
R "En el spec $S, respuesta a la pregunta abierta 1: se conserva el comportamiento actual." >/dev/null
grep -qF -- "$q1" "$M/specs/$S.md" || fail "caso 5: se borró la pregunta abierta 1"
ids_after="$(grep -oE '^(- )?(RN|CB)-[0-9]+:' "$M/specs/$S.md" | sort)"
[ -z "$(comm -23 <(printf '%s\n' "$ids_before") <(printf '%s\n' "$ids_after"))" ] || fail "caso 5: se perdieron o renumeraron RN/CB"
grep -l "^bloqueada_por:.*PA:$S:1\b" "$M"/tasks/*.md >/dev/null 2>&1 && fail "caso 5: alguna tarea sigue bloqueada por PA:$S:1"
grep -qE '^[[:space:]]*- Respuesta \(' "$M/specs/$S.md" || fail "caso 5: no añadió la línea Respuesta"
grep -q '^estado: revisado' "$M/specs/$S.md" || fail "caso 5: el spec no quedó revisado"
[ "$(rev_de "$M/specs/$S.md")" = "$((v_spec+1))" ] || fail "caso 5: editar el contenido del spec no subió su rev en 1 ($v_spec → $(campo "$M/specs/$S.md" rev))"

# Caso 9: aplicar una mejora
sec13() { awk '/^## 13\. /{f=1;next} /^## /{f=0} f' "$1"; }
SM="$(for s in "$M"/specs/[!_]*.md; do [ "$(sec13 "$s" | grep -cE '^(- )?MJ-[0-9]+:')" -ge 2 ] && { basename "$s" .md; break; }; done)"
if [ -z "$SM" ]; then
  fail "caso 9: ningún spec tiene al menos dos mejoras MJ-n"
else
  spm="$M/specs/$SM.md"
  mj1="$(sec13 "$spm" | grep -oE 'MJ-[0-9]+' | sed -n 1p)"
  mj2="$(sec13 "$spm" | grep -oE '^(- )?MJ-[0-9]+' | grep -oE 'MJ-[0-9]+' | sed -n 2p)"
  ids_b="$(grep -oE '^(- )?(RN|CB)-[0-9]+:' "$spm" | sort)"
  R "Aplica la mejora $mj1 del spec $SM." >/dev/null
  ids_a="$(grep -oE '^(- )?(RN|CB)-[0-9]+:' "$spm" | sort)"
  grep -E "^(- )?$mj1:" "$spm" | grep -q '(aplicada ' || fail "caso 9: $mj1 no quedó marcada como aplicada"
  [ -z "$(comm -23 <(printf '%s\n' "$ids_b") <(printf '%s\n' "$ids_a"))" ] || fail "caso 9: se perdieron o renumeraron RN/CB"
  [ "$(printf '%s\n' "$ids_a" | grep -c .)" -gt "$(printf '%s\n' "$ids_b" | grep -c .)" ] || fail "caso 9: no añadió una regla o caso borde nuevo"
  grep -E '^(- )?(RN|CB)-[0-9]+:' "$spm" | grep -q '(retirado .*sustituida' || fail "caso 9: no marcó como retirada la regla anterior"
  grep -q '^estado: revisado' "$spm" || fail "caso 9: el spec no quedó revisado"

  # Caso 10: descartar una mejora
  before10="$(grep -vE "^(- )?$mj2:" "$spm" | md5sum)"
  R "Descarta la mejora $mj2 del spec $SM." >/dev/null
  grep -E "^(- )?$mj2:" "$spm" | grep -q '(descartada ' || fail "caso 10: $mj2 no quedó marcada como descartada"
  [ "$(grep -vE "^(- )?$mj2:" "$spm" | md5sum)" = "$before10" ] || fail "caso 10: descartar cambió otras líneas del spec"
fi

# Caso 11: rechaza una política distinta de paridad
out="$(R "Fija la política en modernizar.")"
grep -q '^politica: paridad$' "$M/README.md" || fail "caso 11: cambió la política a un valor no soportado"
printf '%s' "$out" | grep -qi 'paridad' || fail "caso 11: no explicó que la única política es paridad"

# Caso 6: se niega a editar un derivado
g="$(md5sum < "$W/index.md")"
out="$(R "En el index.md general añade una fila para un repo llamado pagos.")"
[ "$(md5sum < "$W/index.md")" = "$g" ] || fail "caso 6: editó el índice general"
printf '%s' "$out" | grep -q 'migration-indexer' || fail "caso 6: no indicó qué agente regenera el índice"

# Caso 7: se niega a añadir un caso de prueba sin respaldo en el spec
pl="$M/test-plans/$S.md"
b7="$(md5sum < "$pl")"
out="$(R "En el plan de prueba $S añade un caso: cuando el usuario paga con criptomonedas, la respuesta es 402.")"
[ "$(md5sum < "$pl")" = "$b7" ] || fail "caso 7: editó el plan sin respaldo en el spec"
printf '%s' "$out" | grep -qi 'spec' || fail "caso 7: no propuso añadirlo primero al spec"

# Review Focus 1: varias órdenes, una con id inexistente
S2="$(ls "$M"/specs | grep -v '^_' | grep -v "^$S.md$" | head -n1 | sed 's/\.md$//')"
v_s2="$(campo "$M/specs/$S2.md" rev)"
out="$(R "En el ADR 9999 elijo Ktor. Marca revisado el spec $S2.")"
[ "$(campo "$M/specs/$S2.md" rev)" = "$v_s2" ] || fail "RF1: marcar revisado cambió el rev del spec $S2 ($v_s2 → $(campo "$M/specs/$S2.md" rev))"
grep -q '^estado: revisado' "$M/specs/$S2.md" || fail "RF1: no aplicó la orden válida"
printf '%s' "$out" | grep -q '9999' || fail "RF1: no reportó el id inexistente"

# Caso 8: excluir una capacidad
X="$(ls "$M"/specs | grep -v '^_' | grep -v "^$S.md$" | grep -v "^$S2.md$" | head -n1 | sed 's/\.md$//')"
[ -n "$X" ] || X="$S2"
out="$(R "Excluye la capacidad $X.")"
grep -qE "^excluir:.*\b$X\b" "$M/README.md" || fail "caso 8: '$X' no está en excluir"
[ -f "$M/specs/$X.md" ] && fail "caso 8: el spec $X sigue existiendo"
[ -f "$M/test-plans/$X.md" ] && fail "caso 8: el plan $X sigue existiendo"
grep -l "^spec: $X$" "$M"/tasks/*.md >/dev/null 2>&1 && fail "caso 8: quedan tareas de $X"
grep -qE "^\| $X \|" "$M/specs/_capacidades.md" && fail "caso 8: $X sigue en el mapa"

# Caso 12: destino por repositorio
. "$ROOT/scripts/lib-destino.sh"
R "Fija el destino de bff en Kotlin." >/dev/null
[ "$(destino_de "$W" bff)" = "Kotlin" ] || fail "caso 12: bff no quedó con destino Kotlin ($(destino_raw "$W"))"
destino_es_mapa "$W" || fail "caso 12: destino no quedó como mapa en una línea"
R "Conserva el repositorio frontend." >/dev/null
[ "$(destino_de "$W" frontend)" = "conservar" ] || fail "caso 12: frontend no quedó como conservar ($(destino_raw "$W"))"
[ "$(destino_de "$W" bff)" = "Kotlin" ] || fail "caso 12: al conservar el frontend se perdió el destino de bff"
[ "$(grep -c '^destino:' "$M/README.md")" -eq 1 ] || fail "caso 12: más de una línea destino en el README"
[ -z "$(destino_problemas "$W")" ] || fail "caso 12: el mapa resultante no es válido: $(destino_problemas "$W")"

# Caso 13: repositorio inexistente
antes="$(destino_raw "$W")"
out="$(R "Fija el destino de pagos en Go.")"
[ "$(destino_raw "$W")" = "$antes" ] || fail "caso 13: aceptó un repositorio que no existe"
printf '%s' "$out" | grep -q 'pagos' || fail "caso 13: no reportó el repositorio inexistente"

# Caso 14: registra las versiones en un proyecto que no las tenía
TS="$(grep -l "^spec: $S$" "$M"/tasks/T-*.md | head -n1)"
if [ -z "$TS" ]; then
  fail "caso 14: no hay tareas del spec $S para probar"
else
  sed -i '/^rev:/d' "$M/specs/$S.md"
  sed -i '/^spec_rev:/d; /^adrs_rev:/d' "$TS"
  sed -i '/^spec_rev:/d' "$M/test-plans/$S.md"
  adrs_antes="$(grep -H '^rev:' "$M"/adr/*.md | sort)"
  v_ts="$(campo "$TS" rev)"
  R "Registra las versiones." >/dev/null
  [ "$(campo "$M/specs/$S.md" rev)" = "1" ] || fail "caso 14: el spec sin versión no quedó con rev 1 ('$(campo "$M/specs/$S.md" rev)')"
  [ "$(campo "$TS" spec_rev)" = "1" ] || fail "caso 14: la tarea no anotó el spec_rev actual ('$(campo "$TS" spec_rev)')"
  grep -q '^adrs_rev: {' "$TS" || fail "caso 14: la tarea no recuperó adrs_rev"
  [ "$(campo "$M/test-plans/$S.md" spec_rev)" = "1" ] || fail "caso 14: el plan no anotó el spec_rev actual"
  [ "$(campo "$TS" rev)" = "$v_ts" ] || fail "caso 14: registrar versiones cambió el rev de la tarea"
  [ "$(grep -H '^rev:' "$M"/adr/*.md | sort)" = "$adrs_antes" ] || fail "caso 14: registrar versiones cambió el rev de algún ADR"
  # Cada ADR citado por la tarea tiene su versión anotada, y no supera la actual
  pares="$(mapa_pares "$(campo "$TS" adrs_rev)")"
  for a in $(lista "$(campo "$TS" adrs)"); do
    ar="$(printf '%s
' "$pares" | awk -v k="$a" '$1==k {print $2}')"
    [ -n "$ar" ] && [ "$ar" = "$(rev_de "$(adrfile "$a")")" ] || fail "caso 14: adrs_rev anota '$ar' para el ADR $a, cuyo rev es $(rev_de "$(adrfile "$a")")"
  done
fi

[ "$fails" -eq 0 ] && { echo "OK: resolver"; exit 0; }
exit 1
