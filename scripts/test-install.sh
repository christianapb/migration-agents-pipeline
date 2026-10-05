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

printf '%s' "$out" | grep -q 'no se instalaron los scripts' || fail "sin carpeta de proyecto, install.sh no avisa de que faltan los scripts"
[ -e "$TMP/.claude/migration" ] && fail "sin carpeta de proyecto, install.sh instaló scripts en el HOME"

# Instalación completa en un proyecto: agentes y scripts
. "$ROOT/scripts/lib-dist.sh"
P="$TMP/mi proyecto"; mkdir -p "$P"
out="$(HOME="$TMP/otro-home" bash "$ROOT/scripts/install.sh" "$P" 2>&1)" || fail "install.sh <proyecto> terminó con error: $out"
for src in "$ROOT"/agents/*.md; do
  cmp -s "$src" "$P/.claude/agents/$(basename "$src")" || fail "$(basename "$src") no se instaló en el proyecto"
done
for s in "${DIST_SCRIPTS[@]}"; do
  cmp -s "$ROOT/scripts/$s" "$P/.claude/migration/$s" || fail "$s no se instaló en .claude/migration/ del proyecto"
done
[ -e "$TMP/otro-home/.claude" ] && fail "install.sh <proyecto> escribió también en el HOME"
ls "$P/.claude/migration" | grep -q '^test-\|^snapshot\|^run-\|idempotency' && fail "install.sh entregó scripts de prueba al proyecto"
printf '%s' "$out" | grep -q 'verificar.sh' || fail "install.sh no dice con qué comando verificar"
bash "$ROOT/scripts/install.sh" "$TMP/no-existe" >/dev/null 2>&1 && fail "install.sh acepta una carpeta de proyecto que no existe"

[ "$fails" -eq 0 ] && { echo "OK: install"; exit 0; }
exit 1
