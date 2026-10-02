#!/usr/bin/env bash
# Indexador a escala: reanuda un índice cortado sin repetir lo hecho, se acota
# a un repositorio sin escribir lo compartido, y consolida sin reindexar.
# El fixture es demasiado pequeño para que el indexador se corte solo: el corte
# se planta. Esto no prueba el comportamiento con miles de archivos.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
export WORKDIR="$W"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
run() { bash "$ROOT/scripts/run-agent.sh" "$@"; rc=$?; [ $rc -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }; return $rc; }

# --- 1. Reanudación: índice de bff cortado tras su primera sección
bash "$ROOT/scripts/snapshot.sh" restore indexer "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa indexer"; exit 1; }
I="$W/bff/index.md"
nsec="$(grep -c '^## ' "$I")"
[ "$nsec" -ge 2 ] || { echo "FAIL: el índice de bff tiene menos de dos secciones; no se puede plantar el corte"; exit 1; }
falta="$(grep '^## ' "$I" | sed -n 2p | sed 's/^## //')"
awk '/^## /{n++} n>=2{exit} {print}' "$I" > "$I.tmp"
# Marca dentro de la sección conservada: si sigue ahí, no se reescribió
awk '!m && /^- `/{print $0 " MARCA-REANUDAR"; m=1; next} {print}' "$I.tmp" > "$I"
rm -f "$I.tmp"
printf '> Índice incompleto: falta desde %s\n' "$falta" >> "$I"
grep -q 'MARCA-REANUDAR' "$I" || { echo "FAIL: no se pudo plantar la marca"; exit 1; }
otro="$(md5sum < "$W/frontend/index.md")"
echo "--- corte plantado en bff: falta desde $falta ($nsec secciones en el original)"

run migration-indexer >/dev/null
grep -q 'Índice incompleto' "$I" && fail "reanudación: el índice de bff sigue marcado incompleto"
grep -q 'MARCA-REANUDAR' "$I" || fail "reanudación: reescribió la sección ya indexada (se perdió la marca)"
[ "$(grep -c '^## ' "$I")" -ge "$nsec" ] || fail "reanudación: el índice tiene $(grep -c '^## ' "$I") secciones, el original tenía $nsec"
[ "$(md5sum < "$W/frontend/index.md")" = "$otro" ] || fail "reanudación: reindexó frontend, cuyo índice estaba completo y en el mismo commit"
bash "$ROOT/scripts/verify-indexer.sh" || fail "reanudación: verify-indexer falla"

# --- 2. Alcance: solo el repo bff, sobre una carpeta sin nada indexado
bash "$ROOT/scripts/snapshot.sh" restore fixture "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa fixture"; exit 1; }
run migration-indexer "Solo el repo bff." >/dev/null
[ -f "$W/bff/index.md" ] || fail "alcance: no existe bff/index.md"
[ -f "$W/frontend/index.md" ] && fail "alcance: escribió frontend/index.md"
[ -f "$W/CLAUDE.md" ] && fail "alcance: escribió CLAUDE.md"
[ -e "$W/migration" ] && fail "alcance: creó migration/"
[ -f "$W/index.md" ] && fail "alcance: escribió el índice general"
grep -q 'Índice incompleto' "$W/bff/index.md" 2>/dev/null && fail "alcance: bff/index.md quedó incompleto"

# --- 3. Consolidación: una corrida sin alcance completa lo que falta
bffmd5="$(md5sum < "$W/bff/index.md" 2>/dev/null)"
run migration-indexer >/dev/null
[ "$(md5sum < "$W/bff/index.md" 2>/dev/null)" = "$bffmd5" ] || fail "consolidación: reindexó bff, que ya estaba completo y en el mismo commit"
[ -f "$W/frontend/index.md" ] || fail "consolidación: no indexó frontend"
bash "$ROOT/scripts/verify-indexer.sh" || fail "consolidación: verify-indexer falla"

[ "$fails" -eq 0 ] && { echo "OK: indexador (reanudación, alcance y consolidación)"; exit 0; }
exit 1
