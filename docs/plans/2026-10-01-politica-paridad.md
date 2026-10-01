# Política de paridad por defecto: plan de implementación

**Goal:** que las preguntas abiertas de los specs queden solo para lo que el código no permite determinar, moviendo lo mejorable a `## 13. Posibles mejoras` (`MJ-n`) bajo la política `paridad`.

**Spec:** `docs/specs/2026-10-01-politica-paridad-design.md`

**Ejecución:** en la misma sesión, tarea por tarea, con prueba antes del cambio. Las tareas 1 y 2 no usan agentes. El indexador se cierra antes de lanzar pruebas con agentes, porque cambiarlo invalida todas las instantáneas.

## Restricciones

- Único valor de política: `paridad`. Ausente o vacío equivale a `paridad`; otro valor detiene al agente.
- Las secciones 1 a 12 del spec no cambian de número. Identificador de mejoras: `MJ-n:` al inicio de línea, citando una `RN-n` o `CB-n` existente.
- Marcas de estado de una mejora: `(aplicada AAAA-MM-DD: RN-n)` y `(descartada AAAA-MM-DD)`.
- Frase de prompt nueva en el bloque de `CLAUDE.md`: `aplica la mejora MJ-n`.
- Tope por defecto de preguntas abiertas por spec en el verificador: `MAX_PREGUNTAS=5`.
- Línea base para comparar: `.work/baseline-paridad/` (no versionada).

## Tarea 1: verificadores (sin agentes)

Archivos: `scripts/verify-tl-specs.sh`, `verify-tl-tasks.sh`, `verify-qa.sh`, `verify-indexer.sh`, `test-verifiers.sh`.

1. En `test-verifiers.sh`, actualizar el workspace sintético (`politica: paridad`, sección 13 con una `MJ-1` que cita `CB-1`, pregunta abierta real sobre un sistema externo) y añadir los casos que deben fallar: spec sin sección 13; `MJ-n` que cita una regla inexistente; pregunta con fórmula de mejora; más preguntas que `MAX_PREGUNTAS`; el producto oculto en las preguntas; `PA` que apunta a una viñeta de la sección 13; tarea con "paridad provisional"; plan con `MJ-` en pendientes; más pendientes que preguntas.
2. Ejecutar `bash scripts/test-verifiers.sh` y ver fallar los casos nuevos.
3. Cambiar los verificadores:
   - lectura de la sección 12 acotada al siguiente `## ` en `verify-qa.sh`, `verify-tl-tasks.sh`, `verify-tl-specs.sh` (y en `test-resolver.sh` en la tarea 3);
   - `verify-tl-specs.sh`: secciones 1 a 13, citas de `MJ-n`, fórmulas de mejora, tope, y `REQUIRE_AMBIGUEDAD` trasladado a mejoras;
   - `verify-tl-tasks.sh`: sin "paridad provisional";
   - `verify-qa.sh`: sin exigencia de un pendiente global, sin `MJ-` en pendientes, pendientes ≤ preguntas;
   - `verify-indexer.sh`: `politica:` en el README, sección 13 en la plantilla, `MJ-n` y `politica` en el bloque.
4. `bash scripts/test-verifiers.sh` en verde. Commit.

## Tarea 2: prompts (sin agentes)

Archivos: `agents/migration-indexer.md`, `migration-tl-specs.md`, `migration-tl-tasks.md`, `migration-qa.md`, `migration-tl-resolver.md`, `migration-orchestrator.md`, `migration-pm.md`, `scripts/test-prompts.sh`.

1. Añadir a `test-prompts.sh` las comprobaciones de §5 del spec y verlas fallar.
2. Editar los siete prompts según §5.1 a §5.7.
3. `bash scripts/test-prompts.sh` y `bash scripts/check-agent.sh` en verde. Commit.

## Tarea 3: pruebas con agentes y documentación

Archivos: `scripts/test-resolver.sh`, `test-orchestrator.sh`, `test-indexer-claude.sh`, `docs/tutorial.md`, `README.md`.

1. `test-resolver.sh`: lectura acotada de la sección 12; casos nuevos de aplicar una mejora, descartar otra y rechazar una política distinta de `paridad`.
2. `test-orchestrator.sh`: "Pendiente de revisión" no menciona `MJ-`.
3. `test-indexer-claude.sh`: el README sembrado sin `politica:` la recibe.
4. Tutorial y README según §8.
5. `bash scripts/test-fast.sh` en verde. Commit.

## Tarea 4: validación con agentes y medición

1. `bash scripts/test-agents.sh` completo (reconstruye las siete instantáneas).
2. Si falla por clasificación, ajustar el prompt de `migration-tl-specs` y repetir solo lo afectado.
3. Medir contra `.work/baseline-paridad/`: preguntas y mejoras por spec, pendientes por plan, tareas con `PA:`, menciones de "paridad provisional".
4. Revisar a mano la clasificación y la fidelidad del spec de carrito (JSON mal formado responde 500, `productId` vacío responde 404, tope de 10 sin aviso).
5. Informe con los conteos antes y después y las preguntas mal clasificadas.
