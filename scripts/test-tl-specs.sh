#!/usr/bin/env bash
# Review Focus 5: alcance sobre una capacidad excluida o inexistente.
# Requiere un workspace con specs (tras Task 5, paso 4).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/.work/sample-workspace"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
snap() { find "$M" -type f -print0 | sort -z | xargs -0 md5sum; }

slug="$(ls "$M"/specs | grep -v '^_' | head -n1 | sed 's/\.md$//')"
cp "$M/README.md" "$ROOT/.work/README.bak"
sed -i "s/^excluir:.*/excluir: [$slug]/" "$M/README.md"
snap > "$ROOT/.work/snap-a.txt"
out="$(bash "$ROOT/scripts/run-agent.sh" migration-tl-specs "Solo la capacidad $slug.")"
[ $? -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }
snap > "$ROOT/.work/snap-b.txt"
diff -q "$ROOT/.work/snap-a.txt" "$ROOT/.work/snap-b.txt" >/dev/null || fail "escribió archivos con una capacidad excluida"
printf '%s' "$out" | grep -qi 'disponibles' || fail "no listó las capacidades disponibles"
cp "$ROOT/.work/README.bak" "$M/README.md"

[ "$fails" -eq 0 ] && { echo "OK: tl-specs (alcance excluido)"; exit 0; }
exit 1
