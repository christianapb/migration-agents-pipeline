#!/usr/bin/env bash
# Casos 4 a 8 del spec v2 y Review Focus 1 y 2. Prepara su propio workspace.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/.work/sample-workspace"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
run() { bash "$ROOT/scripts/run-agent.sh" "$@"; rc=$?; [ $rc -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }; return $rc; }
R() { run migration-tl-resolver "$1"; }
adrfile() { ls "$M"/adr/"$1"-*.md 2>/dev/null | head -n1; }

if [ "${SKIP_SETUP:-0}" != 1 ]; then
  bash "$ROOT/scripts/fixture-reset.sh" >/dev/null
  run migration-indexer >/dev/null
  run migration-analyst >/dev/null
  run migration-tl-adrs "Ejecútalo con destino Kotlin." >/dev/null
  run migration-tl-specs >/dev/null
  run migration-tl-tasks "Ejecútalo con destino Kotlin, aunque haya ADRs propuestos." >/dev/null
  run migration-qa >/dev/null
fi

# Caso 4: decidir un ADR propuesto aceptando la recomendación
P="$(grep -l '^estado: propuesto' "$M"/adr/*.md | head -n1 | xargs basename | cut -c1-4)"
[ -n "$P" ] || { echo "FAIL: no hay ADR propuesto"; exit 1; }
R "En el ADR $P acepta la recomendación." >/dev/null
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
S="$(for s in "$M"/specs/[!_]*.md; do awk '/^## 12\. Preguntas abiertas/{f=1;next} f' "$s" | grep -q '^- ' && { basename "$s" .md; break; }; done)"
q1="$(awk '/^## 12\. Preguntas abiertas/{f=1;next} f' "$M/specs/$S.md" | grep '^- ' | head -n1)"
ids_before="$(grep -oE '^(- )?(RN|CB)-[0-9]+:' "$M/specs/$S.md" | sort)"
R "En el spec $S, respuesta a la pregunta abierta 1: se conserva el comportamiento actual." >/dev/null
grep -qF -- "$q1" "$M/specs/$S.md" || fail "caso 5: se borró la pregunta abierta 1"
ids_after="$(grep -oE '^(- )?(RN|CB)-[0-9]+:' "$M/specs/$S.md" | sort)"
[ -z "$(comm -23 <(printf '%s\n' "$ids_before") <(printf '%s\n' "$ids_after"))" ] || fail "caso 5: se perdieron o renumeraron RN/CB"
grep -l "PA:$S:1\b" "$M"/tasks/*.md >/dev/null 2>&1 && fail "caso 5: alguna tarea sigue bloqueada por PA:$S:1"

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
out="$(R "En el ADR 9999 elijo Ktor. Marca revisado el spec $S2.")"
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

[ "$fails" -eq 0 ] && { echo "OK: resolver"; exit 0; }
exit 1
