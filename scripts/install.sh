#!/usr/bin/env bash
# Copia los agentes a ~/.claude/agents/ para usarlos desde cualquier carpeta.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.claude/agents"
"$ROOT/scripts/check-agent.sh"
mkdir -p "$DEST"
cp "$ROOT"/agents/*.md "$DEST/"
echo "Instalados en $DEST:"
ls "$DEST" | grep '^migration-'
