#!/usr/bin/env bash
# Comprobaciones estructurales de los prompts: reglas que deben estar escritas
# de forma explícita para que el comportamiento no dependa del modelo.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
A="$ROOT/agents"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
has() { grep -qF -- "$2" "$A/$1" || fail "$1: falta \"$2\""; }

# Hallazgo 1: frases canónicas de prompt en el bloque y uso exclusivo en el orquestador
block="$(awk '/^<!-- migration-flow:begin -->$/{f=1;next} /^<!-- migration-flow:end -->$/{f=0} f' "$A/migration-indexer.md")"
for k in 'Frases de prompt' 'con destino <lenguaje>' 'solo la capacidad <slug>' 'aunque haya ADRs propuestos' 'sin marcar revisado' 'acepta la recomendación'; do
  printf '%s' "$block" | grep -qF -- "$k" || fail "bloque de CLAUDE.md sin '$k'"
done
has migration-orchestrator.md 'usa exclusivamente las frases de prompt del bloque'

# Hallazgo 2: la limpieza de bloqueada_por no cambia el estado de las tareas
has migration-tl-resolver.md 'sin cambiar `estado:` ni ninguna otra línea'
has migration-tl-resolver.md 'salvo las tareas tocadas solo por la limpieza de `bloqueada_por`'

# Hallazgo 3: el indexador actualiza un README de v1
has migration-indexer.md 'Si el README existente contiene `migration-techlead`'

# Hallazgo 4: dirección del orden de Glob y cambios de solo estado
has migration-orchestrator.md 'del más antiguo al más reciente'
has migration-orchestrator.md 'si un spec solo cambió de `estado`'

# Hallazgo 6: tl-specs conserva la numeración al sobrescribir
has migration-tl-specs.md 'conserva el número de cada `RN-n` y `CB-n` cuyo contenido persiste'

# Hallazgo 7: Bash del resolver acotado
has migration-tl-resolver.md '^[a-z0-9-]+$'
has migration-tl-resolver.md 'nunca `rm -r`'

[ "$fails" -eq 0 ] && { echo "OK: prompts"; exit 0; }
exit 1
