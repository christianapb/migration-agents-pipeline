#!/usr/bin/env bash
# Copia los agentes a ~/.claude/agents/, retira agentes obsoletos y no pisa
# archivos ajenos con el mismo nombre.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.claude/agents"
RETIRED=(migration-techlead)

agent_name() { awk 'NR==1{next} /^---$/{exit} {print}' "$1" | sed -n 's/^name:[[:space:]]*//p' | head -n1; }

"$ROOT/scripts/check-agent.sh"
mkdir -p "$DEST"

for r in "${RETIRED[@]}"; do
  f="$DEST/$r.md"
  if [ -f "$f" ] && [ "$(agent_name "$f")" = "$r" ]; then
    rm -f "$f"
    echo "Retirado: $r"
  fi
done

for src in "$ROOT"/agents/*.md; do
  b="$(basename "$src")"
  case " ${RETIRED[*]} " in *" ${b%.md} "*) continue ;; esac
  dst="$DEST/$b"
  if [ -f "$dst" ]; then
    n="$(agent_name "$dst")"
    case "$n" in
      migration-*) ;;
      *) echo "AVISO: $dst ya existe y no es de este proyecto (name: '$n'); no se sobrescribe."; continue ;;
    esac
  fi
  cp "$src" "$dst"
  echo "Instalado: $b"
done
echo "Abre una sesión nueva de Claude Code para cargar los agentes."
