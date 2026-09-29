#!/usr/bin/env bash
# Valida la estructura de uno o más archivos de agente de Claude Code.
# Uso: scripts/check-agent.sh [archivo.md ...]   (sin argumentos: agents/*.md)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
files=("$@")
if [ "${#files[@]}" -eq 0 ]; then files=("$ROOT"/agents/*.md); fi

status=0
fail() { echo "FAIL: $1: $2"; status=1; }

for f in "${files[@]}"; do
  base="$(basename "$f" .md)"
  [ -f "$f" ] || { fail "$f" "no existe"; continue; }
  [ "$(head -n1 "$f")" = "---" ] || { fail "$f" "no empieza con frontmatter"; continue; }
  # Frontmatter = líneas entre la primera y la segunda '---'
  fm="$(awk 'NR==1{next} /^---$/{exit} {print}' "$f")"
  body="$(awk 'NR==1{next} f{print} /^---$/{f=1}' "$f")"
  name="$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -n1)"
  desc="$(printf '%s\n' "$fm" | sed -n 's/^description:[[:space:]]*//p' | head -n1)"
  tools="$(printf '%s\n' "$fm" | sed -n 's/^tools:[[:space:]]*//p' | head -n1)"
  [ -n "$name" ] || fail "$f" "falta name"
  [ "$name" = "$base" ] || fail "$f" "name '$name' no coincide con el archivo '$base'"
  [ -n "$desc" ] || fail "$f" "falta description"
  [ -n "$tools" ] || fail "$f" "falta tools"
  printf '%s\n' "$body" | grep -q '^## ' || fail "$f" "el cuerpo no tiene secciones '## '"
done

[ "$status" -eq 0 ] && echo "OK: ${#files[@]} agente(s) válido(s)"
exit "$status"
