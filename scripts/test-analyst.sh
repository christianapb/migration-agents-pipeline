#!/usr/bin/env bash
# Casos 2 y 10 del spec v2 y Review Focus 3.
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
snap() { find "$W" -path "$W/*/.git" -prune -o -type f -print0 | sort -z | xargs -0 md5sum; }

bash "$ROOT/scripts/snapshot.sh" restore analyst "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa analyst"; exit 1; }
slug="$(grep -oE '^\| [a-z0-9-]+ \|' "$M/specs/_capacidades.md" | sed -E 's/^\| //; s/ \|$//' | grep -i 'carr' | head -n1)"
[ -n "$slug" ] || { echo "FAIL: no hay capacidad de carrito para excluir"; exit 1; }

# Review Focus 3 y caso 2: excluir con mayúsculas y espacios
upper="$(printf '%s' "$slug" | tr '[:lower:]' '[:upper:]')"
sed -i "s/^excluir:.*/excluir: [ $upper ]/" "$M/README.md"
run migration-analyst >/dev/null
grep -qE "^\| $slug \|" "$M/specs/_capacidades.md" && fail "la capacidad excluida '$slug' reapareció"
MIN_CAPACIDADES=3 bash "$ROOT/scripts/verify-analyst.sh" >/dev/null || fail "verify-analyst falla con exclusión"

# Índice incompleto: el analista se detiene y pide reanudar el indexador
cp "$W/bff/index.md" "$SNAP_TMP/bff-index.bak"
printf '> Índice incompleto: falta desde src/routes\n' >> "$W/bff/index.md"
snap > "$SNAP_TMP/snap-a.txt"
out="$(run migration-analyst)"
snap > "$SNAP_TMP/snap-b.txt"
diff -q "$SNAP_TMP/snap-a.txt" "$SNAP_TMP/snap-b.txt" >/dev/null || fail "escribió archivos con un índice incompleto"
printf '%s' "$out" | grep -q 'migration-indexer' || fail "índice incompleto: no pidió reanudar migration-indexer"
cp "$SNAP_TMP/bff-index.bak" "$W/bff/index.md"

# Caso 10: sin bloque en CLAUDE.md el agente se detiene
awk '/^<!-- migration-flow:begin -->$/{f=1} !f{print} /^<!-- migration-flow:end -->$/{f=0}' "$W/CLAUDE.md" > "$W/CLAUDE.tmp" && mv "$W/CLAUDE.tmp" "$W/CLAUDE.md"
snap > "$SNAP_TMP/snap-a.txt"
out="$(run migration-analyst)"
snap > "$SNAP_TMP/snap-b.txt"
diff -q "$SNAP_TMP/snap-a.txt" "$SNAP_TMP/snap-b.txt" >/dev/null || fail "escribió archivos sin bloque de convenciones"
printf '%s' "$out" | grep -q 'migration-indexer' || fail "no pidió ejecutar migration-indexer"

[ "$fails" -eq 0 ] && { echo "OK: analyst (exclusión y bloque ausente)"; exit 0; }
exit 1
