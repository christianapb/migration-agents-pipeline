#!/usr/bin/env bash
# Review Focus 5: alcance sobre una capacidad excluida o inexistente.
# Requiere un workspace con specs (tras Task 5, paso 4).
set -uo pipefail
# Activa las comprobaciones de los verificadores propias del fixture
export FIXTURE="${FIXTURE:-1}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
export WORKDIR="$W"
SNAP_TMP="$(mktemp -d)"
trap 'rm -rf "$SNAP_TMP"' EXIT
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
bash "$ROOT/scripts/snapshot.sh" restore tl-specs "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa tl-specs"; exit 1; }
snap() { find "$M" -type f -print0 | sort -z | xargs -0 md5sum; }

slug="$(ls "$M"/specs | grep -v '^_' | head -n1 | sed 's/\.md$//')"
cp "$M/README.md" "$SNAP_TMP/README.bak"
sed -i "s/^excluir:.*/excluir: [$slug]/" "$M/README.md"
snap > "$SNAP_TMP/snap-a.txt"
out="$(bash "$ROOT/scripts/run-agent.sh" migration-tl-specs "Solo la capacidad $slug.")"
[ $? -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }
snap > "$SNAP_TMP/snap-b.txt"
diff -q "$SNAP_TMP/snap-a.txt" "$SNAP_TMP/snap-b.txt" >/dev/null || fail "escribió archivos con una capacidad excluida"
printf '%s' "$out" | grep -qi 'disponibles' || fail "no listó las capacidades disponibles"
cp "$SNAP_TMP/README.bak" "$M/README.md"

[ "$fails" -eq 0 ] && { echo "OK: tl-specs (alcance excluido)"; exit 0; }
exit 1
