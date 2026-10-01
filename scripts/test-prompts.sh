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

# Política de paridad (docs/specs/2026-10-01-politica-paridad-design.md)
for k in 'politica: paridad' 'MJ-n' 'aplica la mejora MJ-n' 'no es una pregunta abierta'; do
  printf '%s' "$block" | grep -qF -- "$k" || fail "bloque de CLAUDE.md sin '$k'"
done
has migration-indexer.md '## 13. Posibles mejoras'
has migration-indexer.md 'añade `politica: paridad`'
has migration-tl-specs.md 'Política desconocida'
has migration-tl-specs.md 'no es una pregunta abierta'
has migration-tl-specs.md '## 13. Posibles mejoras'
has migration-tl-specs.md 'conserva la numeración `MJ-n`'
has migration-tl-specs.md 'ya lo cubre un ADR propuesto'
has migration-tl-tasks.md 'Las mejoras `MJ-n` sin aplicar no existen para las tareas'
has migration-qa.md 'La sección 13 del spec no genera casos'
has migration-tl-resolver.md '**Aplicar una mejora**'
has migration-tl-resolver.md '**Descartar una mejora**'
has migration-tl-resolver.md '**Reclasificar una pregunta como mejora**'
has migration-tl-resolver.md 'La única política soportada es `paridad`'
has migration-orchestrator.md 'no cuentan como pendiente de revisión'
has migration-pm.md 'mejoras sin decidir'
grep -qF 'paridad provisional' "$A/migration-tl-tasks.md" && fail "migration-tl-tasks.md sigue usando 'paridad provisional'"

# Evidencia por regla y auditor (docs/specs/2026-10-01-evidencia-y-auditor-design.md)
for k in '[ruta:línea]' '[ausente: ' '[decisión: ' 'AU-n' '_auditoria.md' 'migration-auditor' 'commits:'; do
  printf '%s' "$block" | grep -qF -- "$k" || fail "bloque de CLAUDE.md sin '$k'"
done
has migration-indexer.md '| Repo | Stack | Entrada | Commit | Índice |'
has migration-indexer.md 'rev-parse --short HEAD'
has migration-indexer.md 'commits: {}'
has migration-tl-specs.md 'Una regla sin cita no se escribe'
has migration-tl-specs.md 'Como mucho tres citas por regla'
has migration-tl-specs.md 'Lee los tests del origen'
has migration-tl-specs.md 'actualiza las citas a las líneas actuales'
has migration-tl-specs.md 'copia `commits:`'
grep -qF 'No leas estilos, tests ni lockfiles' "$A/migration-analyst.md" && fail "migration-analyst.md sigue indicando no leer tests"
has migration-analyst.md 'Lee los tests cuando existan'
has migration-auditor.md 'tools: Read, Glob, Grep, Write'
has migration-auditor.md 'antes de leer el texto de la regla'
has migration-auditor.md 'Nunca edites un spec'
has migration-auditor.md 'cita no localizable'
has migration-auditor.md 'compara el valor exacto'
has migration-auditor.md 'conserva las secciones de las demás capacidades'
has migration-auditor.md 'Usa el subagente migration-tl-resolver'
has migration-tl-resolver.md 'añade su cita'
has migration-tl-resolver.md '`_auditoria.md`'
has migration-tl-resolver.md 'No marques hallazgos `AU-n` como resueltos'
has migration-orchestrator.md 'Hallazgos `AU-n`'
has migration-orchestrator.md 'auditoría más antigua que su spec'
has migration-orchestrator.md 'Usa el subagente migration-auditor'
has migration-tl-tasks.md 'La cita entre corchetes al final de cada regla no forma parte del requisito'
has migration-qa.md 'La cita entre corchetes al final de cada regla no forma parte del requisito'

# Comportamientos por defecto
for k in 'Ruta no definida:' 'Método no permitido:' 'Cuerpo ausente:' 'Cuerpo mal formado:'; do
  has migration-tl-specs.md "$k"
done
has migration-tl-specs.md 'Comportamientos por defecto'
has migration-tl-specs.md 'no lo inventes'
has migration-auditor.md 'comportamiento por defecto del framework'

# Destino por repositorio (docs/specs/2026-10-01-destino-por-repo-design.md)
for k in 'destino: {bff: Kotlin, frontend: conservar}' 'conservar' 'con destino <repo>=<lenguaje>, <repo>=conservar' 'fija el destino de <repo> en <lenguaje>' 'conserva el repositorio <repo>' 'El README manda' 'fuera de alcance'; do
  printf '%s' "$block" | grep -qF -- "$k" || fail "bloque de CLAUDE.md sin '$k'"
done
has migration-indexer.md 'repos: []'
has migration-indexer.md 'tipo: implementacion'
for a in migration-tl-adrs.md migration-tl-tasks.md; do
  has "$a" 'El mapa de destino no cubre el repositorio'
  has "$a" 'el README manda'
done
has migration-tl-adrs.md 'Ningún ADR propuesto incluye un repositorio conservado en `repos:`'
has migration-tl-adrs.md 'es una restricción para el repositorio que se migra'
has migration-tl-specs.md 'fuera de alcance'
has migration-tl-specs.md '(se conserva)'
has migration-tl-tasks.md 'tipo: adaptacion'
has migration-tl-tasks.md 'Ninguna tarea de implementación tiene `repo_destino` en un repositorio conservado'
has migration-qa.md 'no aplica: repositorio conservado'
has migration-pm.md 'repositorios conservados'
has migration-tl-resolver.md '**Fijar el destino de un repositorio**'
has migration-tl-resolver.md '**Conservar un repositorio**'
has migration-orchestrator.md 'el mapa no cubre algún repositorio detectado'
has migration-orchestrator.md 'No añadas destino al prompt cuando el README ya lo tiene'

[ "$fails" -eq 0 ] && { echo "OK: prompts"; exit 0; }
exit 1
