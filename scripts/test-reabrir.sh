#!/usr/bin/env bash
# Recorrido completo de reabrir: un spec con una mejora aplicada y una respuesta
# queda revisado; se reabre, se regenera con alcance y se comprueba que lo que
# el aviso del resolver dijo que se conservaba sigue ahí.
set -uo pipefail
# Activa las comprobaciones de los verificadores propias del fixture
export FIXTURE="${FIXTURE:-1}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
export WORKDIR="$W"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
run() { bash "$ROOT/scripts/run-agent.sh" "$@"; rc=$?; [ $rc -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }; return $rc; }
. "$ROOT/scripts/lib-rev.sh"
sec() { awk -v n="$2" '$0 ~ "^## " n "\\. " {f=1; next} /^## /{f=0} f' "$1"; }

bash "$ROOT/scripts/snapshot.sh" restore tl-specs "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa tl-specs"; exit 1; }

# Un spec con al menos una mejora sin decidir
S=""
for s in "$M"/specs/[!_]*.md; do
  sec "$s" 13 | grep -E '^(- )?MJ-[0-9]+:' | grep -vq '(aplicada\|(descartada' && { S="$(basename "$s" .md)"; break; }
done
[ -n "$S" ] || { echo "FAIL: ningún spec tiene una mejora sin decidir"; exit 1; }
SP="$M/specs/$S.md"
MJ="$(sec "$SP" 13 | grep -E '^(- )?MJ-[0-9]+:' | grep -v '(aplicada\|(descartada' | grep -oE 'MJ-[0-9]+' | head -n1)"

# 1. Contenido de origen humano: una mejora aplicada (regla de decisión y regla retirada) y una respuesta
ids0="$(grep -oE '^(- )?(RN|CB)-[0-9]+:' "$SP" | sed -E 's/^- //; s/:$//' | sort -u)"
run migration-tl-resolver "Aplica la mejora $MJ del spec $S." >/dev/null
NUEVA="$(comm -13 <(printf '%s\n' "$ids0") <(grep -oE '^(- )?(RN|CB)-[0-9]+:' "$SP" | sed -E 's/^- //; s/:$//' | sort -u) | tail -n1)"
[ -n "$NUEVA" ] || { echo "FAIL: aplicar la mejora $MJ no añadió ninguna regla al spec $S"; exit 1; }
grep -E "^(- )?$NUEVA:" "$SP" | grep -q '\[decisión: ' || fail "la regla $NUEVA, nacida de la mejora, no lleva cita [decisión: ...]"
RET="$(grep -E '^(- )?(RN|CB)-[0-9]+:' "$SP" | grep '(retirado .*sustituida' | grep -oE '(RN|CB)-[0-9]+' | head -n1)"
[ -n "$RET" ] || fail "aplicar la mejora no dejó marcada como retirada la regla anterior"
# Una pregunta abierta con su respuesta, plantadas para no depender de lo generado
sed -i 's/^## 12\. Preguntas abiertas.*/&\n- ¿Qué responde el sistema externo de pagos ante un cobro duplicado?\n  - Respuesta (2026-10-05): se ignora el segundo cobro./' "$SP"
grep -q '^estado: revisado' "$SP" || fail "tras aplicar la mejora el spec no quedó revisado"
v0="$(rev_de "$SP")"
echo "--- spec $S: mejora $MJ aplicada como $NUEVA, $RET retirada, rev $v0"

# 2. Reabrir: solo cambia el estado, y avisa
h0="$(grep -v '^estado:' "$SP" | md5sum)"
out="$(run migration-tl-resolver "Reabre el spec $S.")"
grep -q '^estado: generado' "$SP" || fail "reabrir no dejó el spec en generado"
[ "$(grep -v '^estado:' "$SP" | md5sum)" = "$h0" ] || fail "reabrir cambió algo más que la línea estado"
[ "$(rev_de "$SP")" = "$v0" ] || fail "reabrir cambió el rev ($v0 → $(rev_de "$SP"))"
printf '%s' "$out" | grep -q "$MJ\|$NUEVA" || fail "el aviso no nombra la mejora aplicada ni la regla que nació de ella"
printf '%s' "$out" | grep -qi 'conserva' || fail "el aviso no dice qué se conserva"
printf '%s' "$out" | grep -q "migration-tl-specs, solo la capacidad $S" || fail "el resumen no entrega el prompt para regenerar con alcance"

# 3. Regenerar con alcance: se reescribe, y lo que el aviso dijo que se conservaba sigue ahí
otros="$(for s in "$M"/specs/[!_]*.md; do [ "$s" = "$SP" ] || md5sum "$s"; done)"
run migration-tl-specs "Solo la capacidad $S." >/dev/null
[ "$(rev_de "$SP")" = "$((v0+1))" ] || fail "regenerar no subió el rev en 1 ($v0 → $(campo "$SP" rev)): ¿se reescribió el spec?"
grep -E "^(- )?$NUEVA:" "$SP" | grep -v '(retirado' | grep -q '\[decisión: ' || fail "se perdió la regla $NUEVA, nacida de una decisión, o su cita [decisión: ...]"
grep -E "^(- )?$RET:" "$SP" | grep -q '(retirado' || fail "la regla $RET, retirada por la mejora, volvió a estar vigente o desapareció"
grep -E "^(- )?$MJ:" "$SP" | grep -q '(aplicada ' || fail "la mejora $MJ perdió su marca de aplicada"
grep -q 'Respuesta (2026-10-05): se ignora el segundo cobro' "$SP" || fail "se perdió la respuesta a la pregunta abierta"
grep -q 'cobro duplicado' "$SP" || fail "se perdió la pregunta abierta respondida"
[ "$(for s in "$M"/specs/[!_]*.md; do [ "$s" = "$SP" ] || md5sum "$s"; done)" = "$otros" ] || fail "regenerar con alcance tocó otros specs"
REQUIRE_HECHOS=0 bash "$ROOT/scripts/verify-tl-specs.sh" >/dev/null || fail "el spec regenerado no pasa verify-tl-specs"

[ "$fails" -eq 0 ] && { echo "OK: reabrir (recorrido completo)"; exit 0; }
exit 1
