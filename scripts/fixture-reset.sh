#!/usr/bin/env bash
# Copia el fixture a .work/sample-workspace, inicializa git en cada repo
# y copia los agentes al .claude/agents del workspace.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/.work/sample-workspace"

rm -rf "$WORK"
mkdir -p "$ROOT/.work"
cp -r "$ROOT/fixtures/sample-workspace" "$WORK"

for repo in "$WORK"/*/; do
  (
    cd "$repo"
    git init -q
    git config core.autocrlf false
    git add -A
    git -c user.name=fixture -c user.email=fixture@example.com commit -qm "fixture"
  )
done

mkdir -p "$WORK/.claude/agents"
if ls "$ROOT"/agents/*.md >/dev/null 2>&1; then
  cp "$ROOT"/agents/*.md "$WORK/.claude/agents/"
fi
echo "workspace listo en $WORK"
