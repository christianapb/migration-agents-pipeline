#!/usr/bin/env bash
# Instala el flujo de migración.
#
# Uso: install.sh [carpeta-del-proyecto]
#   Con carpeta: copia los agentes a <carpeta>/.claude/agents/ y los scripts del
#   flujo (backlog.sh, verificar.sh y los verificadores) a
#   <carpeta>/.claude/migration/. Es la instalación completa.
#   Sin carpeta: copia solo los agentes a ~/.claude/agents/. Los scripts viven
#   en cada proyecto: sin ellos migration-pm se detiene.
#
# Retira agentes obsoletos y no pisa archivos ajenos con el mismo nombre.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib-dist.sh
. "$ROOT/scripts/lib-dist.sh"
PROY="${1:-}"
if [ -n "$PROY" ]; then
  [ -d "$PROY" ] || { echo "ERROR: no existe la carpeta $PROY" >&2; exit 1; }
  PROY="$(cd "$PROY" && pwd)"
  DEST="$PROY/.claude/agents"
else
  DEST="$HOME/.claude/agents"
fi
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

if [ -n "$PROY" ]; then
  copiar_scripts "$ROOT/scripts" "$PROY"
  echo "Scripts instalados en $PROY/.claude/migration/ (${#DIST_SCRIPTS[@]} archivos)."
  echo "Para comprobar la estructura de lo generado: bash .claude/migration/verificar.sh (desde $PROY)."
else
  echo "AVISO: no se instalaron los scripts del flujo. migration-pm los necesita en <proyecto>/.claude/migration/."
  echo "       Instálalos con: bash $ROOT/scripts/install.sh <carpeta-del-proyecto>"
fi
echo "Abre una sesión nueva de Claude Code para cargar los agentes."
