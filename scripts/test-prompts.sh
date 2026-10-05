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
has migration-orchestrator.md 'Lo decides solo comparando valores escritos en los archivos'
has migration-orchestrator.md 'Un artefacto que solo cambió de `estado` conserva su `rev`'

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
has migration-orchestrator.md 'es menor que el `rev` del spec'
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
has migration-tl-tasks.md 'migration/tasks/T-NNN-<slug>.md'
has migration-tl-tasks.md 'Ninguna tarea de implementación tiene `repo_destino` en un repositorio conservado'
has migration-qa.md 'no aplica: repositorio conservado'
has migration-pm.md 'repositorios conservados'
has migration-tl-resolver.md '**Fijar el destino de un repositorio**'
has migration-tl-resolver.md '**Conservar un repositorio**'
has migration-orchestrator.md 'el mapa no cubre algún repositorio detectado'
has migration-orchestrator.md 'No añadas destino al prompt cuando el README ya lo tiene'

# Versiones de artefactos (docs/specs/2026-10-01-versiones-de-artefactos-design.md)
for k in 'rev: <entero>' 'spec_rev: <n>' 'adrs_rev: {0003: 1, 0011: 2}' 'Spec rev: <n>.' 'columna `Rev`' 'registra las versiones' 'nunca se supone un valor' 'las fechas de modificación de los archivos no significan nada'; do
  printf '%s' "$block" | grep -qF -- "$k" || fail "bloque de CLAUDE.md sin '$k'"
done
for a in migration-tl-adrs.md migration-tl-specs.md migration-tl-tasks.md; do
  has "$a" 'aunque la plantilla no lo traiga'
  has "$a" 'súbelo en 1'
done
has migration-tl-tasks.md 'adrs_rev: {0003: 1, 0011: 2}'
has migration-tl-tasks.md 'spec_rev'
has migration-qa.md 'spec_rev'
has migration-auditor.md 'Spec rev: <n>.'
has migration-pm.md 'Orden, Tarea, Rev, Título'
has migration-pm.md 'Aplicar no cambia `rev`'
has migration-tl-resolver.md '**Registrar versiones**'
has migration-tl-resolver.md 'migration-qa no podría regenerarlo'
has migration-tl-resolver.md 'Sube `rev` en 1'
has migration-tl-resolver.md 'No subas `rev`'
has migration-orchestrator.md 'no se puede determinar, no tiene versión registrada'
has migration-orchestrator.md 'Faltan:'
has migration-orchestrator.md 'registra las versiones'
for k in 'fecha de modificación' 'Glob devuelve' 'más antiguo' 'más nuevo' 'posiblemente'; do
  grep -qF -- "$k" "$ROOT/agents/migration-orchestrator.md" && fail "migration-orchestrator.md todavía contiene '$k'"
done

# Indexador reanudable y pasos en paralelo (docs/specs/2026-10-01-escala-indexador-y-paralelo-design.md)
for k in 'solo el repo <nombre>' 'solo la cobertura' 'en paralelo' 'migration-tl-tasks y migration-auditor van siempre en serie'; do
  printf '%s' "$block" | grep -qF -- "$k" || fail "bloque de CLAUDE.md sin '$k'"
done
IDX="$A/migration-indexer.md"
orden() { grep -n -m1 -F -- "$1" "$IDX" | cut -d: -f1; }
[ "$(orden '## 4. Bloque de convenciones en `CLAUDE.md`')" -lt "$(orden '## 7. Escribir `index.md` de forma incremental')" ] 2>/dev/null \
  || fail "migration-indexer.md: el bloque de CLAUDE.md debe escribirse antes que los índices"
[ "$(orden '## 3. Bootstrapear `migration/`')" -lt "$(orden '## 5. Listar archivos candidatos por repositorio')" ] 2>/dev/null \
  || fail "migration-indexer.md: migration/ debe prepararse antes de indexar"
has migration-indexer.md 'solo el repo <nombre>'
has migration-indexer.md 'tu único archivo de salida es `<nombre>/index.md`'
has migration-indexer.md 'Commit: <hash corto o sin-git>'
has migration-indexer.md '**Reanudar.**'
has migration-indexer.md 'No lo toques'
grep -qF 'Si ya existe `index.md`, sobreescríbelo completo' "$IDX" && fail "migration-indexer.md conserva la regla de sobrescribir siempre el índice"
has migration-analyst.md 'detente sin escribir nada y pide reanudar'
has migration-tl-specs.md 'no escribas ni modifiques ningún otro archivo'
has migration-qa.md 'solo la cobertura'
has migration-qa.md 'no escribas `_cobertura.md`'
has migration-qa.md 'Spec rev'
has migration-orchestrator.md 'Lanza estos subagentes en paralelo, en un mismo mensaje:'
has migration-orchestrator.md 'solo el repo <nombre>'
has migration-orchestrator.md 'solo la cobertura'
has migration-orchestrator.md 'Cuando terminen:'
has migration-orchestrator.md 'van siempre en serie'
has migration-orchestrator.md 'como máximo 5'

# Planes de prueba antes que tareas (docs/specs/2026-10-04-qa-antes-de-tareas-design.md)
printf '%s' "$block" | grep -qF -- '| 5 | migration-qa |' || fail "bloque de CLAUDE.md: migration-qa no es el paso 5"
printf '%s' "$block" | grep -qF -- '| 6 | migration-tl-tasks |' || fail "bloque de CLAUDE.md: migration-tl-tasks no es el paso 6"
printf '%s' "$block" | grep -qF -- 'tareas: [T-011, T-012]' && fail "bloque de CLAUDE.md conserva la anotación tareas de los planes"
has migration-qa.md 'description: Paso 5 del flujo de migración'
has migration-tl-tasks.md 'description: Paso 6 del flujo de migración'
has migration-qa.md 'No leas `migration/tasks/`'
has migration-qa.md 'aunque la plantilla del proyecto los traiga'
has migration-tl-tasks.md '## Pruebas'
has migration-tl-tasks.md 'Plan de pruebas: `migration/test-plans/<slug>.md`'
has migration-orchestrator.md '| 5 | migration-qa |'
has migration-orchestrator.md '| 6 | migration-tl-tasks |'
has migration-orchestrator.md 'planes antes que tareas, tareas antes que backlog'
has migration-orchestrator.md 'Los ADRs propuestos no frenan a migration-qa'
has migration-auditor.md 'antes de migration-qa'
for f in migration-qa.md migration-indexer.md migration-tl-resolver.md; do
  grep -qE '^- Tareas:|tareas: \[\]|`tareas:`|y `tareas` en los planes' "$A/$f" && fail "$f todavía describe la referencia de los planes a las tareas"
done
grep -rnE 'tareas antes que planes|antes de migration-tl-tasks|antes del paso 5' "$A" "$ROOT/docs/tutorial.md" "$ROOT/README.md" >/dev/null && fail "queda texto que describe el orden anterior"

# Backlog por script (docs/specs/2026-10-05-backlog-por-script-design.md)
PMF="$A/migration-pm.md"
grep -q '^tools: .*Bash' "$PMF" || fail "migration-pm.md no tiene Bash"
for k in 'bash .claude/migration/backlog.sh validar' 'bash .claude/migration/backlog.sh calcular' 'bash .claude/migration/backlog.sh aplicar' 'Ningún otro comando' 'No calcules el backlog a mano' 'No escribas ni modifiques ningún archivo' 'copia tal cual' 'bash .claude/migration/verificar.sh'; do
  has migration-pm.md "$k"
done
# El prompt del PM ya no describe ningún algoritmo
for k in 'en profundidad' 'en la pila' 'transitivamente' 'desempate' 'fase mínima' 'S=1, M=2' 'procura que' 'Detecta ciclos'; do
  grep -qF -- "$k" "$PMF" && fail "migration-pm.md todavía describe el cálculo: '$k'"
done
grep -q '^tools: .*Bash' "$A/migration-orchestrator.md" && fail "migration-orchestrator.md no debe tener Bash"
has migration-orchestrator.md 'bash .claude/migration/verificar.sh'

[ "$fails" -eq 0 ] && { echo "OK: prompts"; exit 0; }
exit 1
