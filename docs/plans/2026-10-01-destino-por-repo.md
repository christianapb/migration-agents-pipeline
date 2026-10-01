# Destino por repositorio: plan de implementación

**Goal:** que el destino de la migración se fije por repositorio, incluida la opción de conservar un repositorio sin migrarlo, manteniendo el valor único.

**Spec:** `docs/specs/2026-10-01-destino-por-repo-design.md`

**Ejecución:** en la misma sesión, con la prueba antes del cambio. Las tareas 1 a 3 no usan agentes. El indexador (plantillas y bloque de `CLAUDE.md`) queda cerrado antes de lanzar pruebas con agentes.

## Restricciones

- `destino:` es un valor simple o un mapa en una línea: `destino: {bff: Kotlin, frontend: conservar}`. `conservar` es palabra reservada.
- Mapa incompleto o con una clave que no es un repositorio detectado: el agente se detiene.
- El README manda sobre el prompt; el prompt solo cuenta si el README está vacío; si difieren, el agente se detiene.
- Frase por repositorio: `con destino <repo>=<lenguaje>, <repo>=conservar`. Resolver: "fija el destino de <repo> en <lenguaje>", "conserva el repositorio <repo>".
- Campo `repos: []` en todo ADR. Campo `tipo: implementacion | adaptacion` en toda tarea.
- QA no escribe casos para reglas cuya evidencia está solo en repositorios conservados: "no aplica: repositorio conservado" en la matriz.
- Una capacidad cuyos repositorios están todos conservados queda fuera de alcance: sin spec, tareas ni plan.
- La cadena principal de instantáneas sigue con destino único Kotlin por prompt.

## Tarea 1: verificadores (sin agentes)

Archivos: `scripts/lib-destino.sh` (nuevo), `scripts/verify-tl-adrs.sh`, `scripts/verify-tl-tasks.sh`, `scripts/verify-indexer.sh`, `scripts/test-verifiers.sh`.

1. Workspace sintético con dos repositorios, `repos:` en los ADRs, `tipo:` y `repo_destino:` en las tareas. Casos: valor simple y mapa completo aceptados; mapa al que le falta un repositorio, mapa con clave desconocida, ADR sin `repos:`, tarea sin `tipo:`, ADR propuesto sobre un repositorio conservado y tarea de implementación en un repositorio conservado rechazados; tarea de adaptación aceptada.
2. Ver fallar los casos nuevos.
3. `lib-destino.sh` con la lectura y validación del destino; usarla en los dos verificadores; ampliar `verify-indexer.sh`.
4. `test-verifiers.sh` en verde. Commit.

## Tarea 2: prompts (sin agentes)

Archivos: `agents/migration-indexer.md`, `migration-tl-adrs.md`, `migration-tl-specs.md`, `migration-tl-tasks.md`, `migration-qa.md`, `migration-pm.md`, `migration-tl-resolver.md`, `migration-orchestrator.md`, `scripts/test-prompts.sh`.

1. Comprobaciones nuevas en `test-prompts.sh`; verlas fallar.
2. Editar los prompts según §3 y §4 del spec.
3. `test-prompts.sh` y `check-agent.sh` en verde. Commit.

## Tarea 3: pruebas con agentes y documentación (sin ejecutar agentes)

Archivos: `scripts/test-destino.sh` (nuevo), `scripts/test-agents.sh`, `scripts/test-runner.sh`, `scripts/test-resolver.sh`, `scripts/test-orchestrator.sh`, `docs/tutorial.md`, `README.md`.

1. `test-destino.sh` según §5 del spec; registrarla en `test-agents.sh` para `migration-tl-adrs` y `migration-tl-tasks`; actualizar el número de pruebas en `test-runner.sh`.
2. Casos de destino en `test-resolver.sh` y `test-orchestrator.sh`.
3. Tutorial y README.
4. `test-fast.sh` en verde. Commit.

## Tarea 4: validación con agentes y medición

1. `scripts/test-agents.sh` completo (reconstruye las siete instantáneas).
2. Informe: ADRs propuestos y tareas con destino único y con el mapa, las cuatro comprobaciones del mapa, y la decisión del caso límite.
