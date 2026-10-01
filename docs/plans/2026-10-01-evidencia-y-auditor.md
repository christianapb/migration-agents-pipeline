# Evidencia por regla y agente auditor: plan de implementación

**Goal:** que cada `RN-n` y `CB-n` cite ruta y línea de su respaldo en el código, y que un agente nuevo, `migration-auditor`, contraste los specs con el código sin modificarlos.

**Spec:** `docs/specs/2026-10-01-evidencia-y-auditor-design.md`

**Ejecución:** en la misma sesión, con la prueba antes del cambio. Las tareas 1 a 3 no usan agentes. El indexador, la plantilla y el bloque de `CLAUDE.md` quedan cerrados antes de lanzar pruebas con agentes.

## Restricciones

- Formato de cita: `[ruta:línea]`, `[ruta:inicio-fin]`, varias separadas por coma; `[ausente: ruta]`; `[decisión: ...]`. Al final de la línea de la regla.
- Auditor transversal, sin número de paso. Herramientas: `Read, Glob, Grep, Write`.
- Veredictos: `respaldada`, `sin respaldo`, `contradicha`, `cita no localizable`, `decisión`.
- Hallazgos `AU-n` por capacidad en `migration/specs/_auditoria.md`, derivado, sin marca de resuelto.
- Commit de cada repo en la columna `Commit` del índice general y en `commits:` del frontmatter del spec.
- Un test del origen que contradice la implementación se anota como pregunta abierta.
- Se integra con la política de paridad: las `MJ-n` no llevan cita.

## Tarea 1: verificadores (sin agentes)

Archivos: `scripts/verify-tl-specs.sh`, `scripts/verify-indexer.sh`, `scripts/verify-auditor.sh` (nuevo), `scripts/test-verifiers.sh`.

1. Workspace sintético de `test-verifiers.sh`: archivo de código real, citas en las reglas, `commits:`, y un `_auditoria.md` válido. Casos que deben fallar: regla sin cita, archivo citado inexistente, línea fuera de rango, formato inválido, spec sin `commits:`; y para el auditor: regla ausente de la tabla, veredicto desconocido, hallazgo sin prompt, veredicto negativo sin hallazgo, resumen que no cuadra, capacidad sin sección. Caso que debe pasar: `verify-qa.sh` y `verify-tl-tasks.sh` con reglas citadas.
2. Ver fallar los casos nuevos.
3. Implementar `verify-auditor.sh` y ampliar `verify-tl-specs.sh` y `verify-indexer.sh`.
4. `test-verifiers.sh` en verde. Commit.

## Tarea 2: prompts (sin agentes)

Archivos: `agents/migration-auditor.md` (nuevo), `migration-indexer.md`, `migration-tl-specs.md`, `migration-analyst.md`, `migration-tl-resolver.md`, `migration-orchestrator.md`, `migration-tl-tasks.md`, `migration-qa.md`, `scripts/test-prompts.sh`.

1. Comprobaciones nuevas en `test-prompts.sh`; verlas fallar.
2. Escribir el auditor y editar los demás según §4 y §5 del spec.
3. `test-prompts.sh` y `check-agent.sh` (diez agentes) en verde. Commit.

## Tarea 3: prueba del auditor, infraestructura y documentación (sin agentes)

Archivos: `scripts/test-auditor.sh` (nuevo), `scripts/test-agents.sh`, `scripts/test-runner.sh`, `scripts/test-orchestrator.sh`, `docs/tutorial.md`, `README.md`.

1. `test-auditor.sh`: auditoría sin alterar (cero contradichas), tres errores plantados en carrito, auditoría con alcance, veredictos esperados, hashes de specs intactos, otras secciones conservadas.
2. `test-agents.sh`: `migration-auditor` con `test-auditor`. `test-runner.sh`: 13 pruebas.
3. Tutorial y README según §8.
4. `test-fast.sh` en verde. Commit.

## Tarea 4: validación con agentes y medición

1. `scripts/test-agents.sh` completo (reconstruye las siete instantáneas).
2. Si el auditor reporta una contradicción sobre specs sin alterar, averiguar si el error es del auditor o del spec antes de cambiar nada.
3. Informe: reglas auditadas por capacidad y por categoría, resultado de los errores plantados, y las decisiones sobre el commit y la numeración.
