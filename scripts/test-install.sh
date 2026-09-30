#!/usr/bin/env bash
# Prueba install.sh con un HOME temporal.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
D="$TMP/.claude/agents"
mkdir -p "$D"
printf -- '---\nname: migration-techlead\ndescription: viejo\ntools: Read\n---\n## x\n' > "$D/migration-techlead.md"
printf -- '---\nname: mi-qa-propio\ndescription: ajeno\ntools: Read\n---\n## x\n' > "$D/migration-qa.md"
before="$(md5sum < "$D/migration-qa.md")"

out="$(HOME="$TMP" bash "$ROOT/scripts/install.sh" 2>&1)" || fail "install.sh terminó con error: $out"

[ -f "$D/migration-techlead.md" ] && fail "migration-techlead.md no se retiró"
[ "$(md5sum < "$D/migration-qa.md")" = "$before" ] || fail "se sobrescribió un archivo ajeno"
printf '%s' "$out" | grep -q '^AVISO: .*migration-qa.md' || fail "no avisó del archivo ajeno"
for src in "$ROOT"/agents/*.md; do
  b="$(basename "$src")"
  [ "$b" = "migration-qa.md" ] && continue
  [ "$b" = "migration-techlead.md" ] && continue
  cmp -s "$src" "$D/$b" || fail "$b no se instaló"
done

[ "$fails" -eq 0 ] && { echo "OK: install"; exit 0; }
exit 1
