#!/usr/bin/env bash
# Copia el fixture a .work/sample-workspace, inicializa git en cada repo
# y copia los agentes al .claude/agents del workspace.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/.work/sample-workspace"

# En Windows (OneDrive, procesos recién cerrados) el directorio puede quedar
# con un handle abierto: se vacía el contenido y se reutiliza si no se puede borrar.
if [ -d "$WORK" ]; then
  rm -rf "$WORK" 2>/dev/null || true
fi
if [ -d "$WORK" ]; then
  find "$WORK" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
  if [ -n "$(ls -A "$WORK" 2>/dev/null)" ]; then
    echo "ERROR: no se pudo vaciar $WORK (¿algún proceso lo tiene abierto?)" >&2
    exit 1
  fi
fi
mkdir -p "$WORK"
cp -r "$ROOT/fixtures/sample-workspace/." "$WORK/"

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
