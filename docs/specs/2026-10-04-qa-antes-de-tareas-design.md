# Planes de prueba antes que tareas: diseño

Fecha: 2026-10-04
Estado: aprobado para implementar (sigue la propuesta del encargo; las decisiones propias están en §2)
Modifica: `docs/specs/2026-09-29-migration-agents-v2-design.md` (v2), `2026-10-01-versiones-de-artefactos-design.md` (anotación `tareas:` de los planes) y `2026-10-01-escala-indexador-y-paralelo-design.md` (orden de regeneración). Convive con la política de paridad, la evidencia por regla y el auditor, y el destino por repositorio.

## 1. Propósito

QA es en la práctica la última revisión del spec, y hoy ocurre después de derivar las tareas:

1. Los hallazgos `H-n` son ambigüedades del spec. Resolverlos sube el `rev` del spec y deja desactualizadas las tareas. En el fixture actual QA produce 6 hallazgos (autenticacion 1, carrito 3, listado-productos 2): cada capacidad obliga a regenerar sus tareas al menos una vez.
2. QA no razona con las tareas: solo copia sus ids a la línea `- Tareas:` de cada caso y a `tareas:` del plan.
3. Esa referencia crea una dependencia al revés: añadir o quitar una tarea desactualiza el plan aunque ningún caso cambie.
4. QA no depende de las decisiones de ADRs; `migration-tl-tasks` sí. El tiempo que se tarda en decidirlos no se aprovecha.

**Criterio de éxito:** el orden pasa a ser specs → planes → tareas → backlog; `migration-qa` no lee ni cita tareas; un plan solo queda desactualizado cuando cambia su spec; resolver un hallazgo antes de generar tareas no obliga a regenerar nada más que el plan; se conserva la trazabilidad entre tareas y casos; y un proyecto generado con el orden anterior sigue funcionando.

## 2. Decisiones

| Tema | Decisión |
|---|---|
| Orden | 4 `migration-tl-specs`, 5 `migration-qa`, 6 `migration-tl-tasks`, 7 `migration-pm`. El auditor sigue recomendado justo después de specs, ahora antes de QA. |
| Trazabilidad | Opción A: sin cita directa. El cruce tarea ↔ caso sale de las `RN-n` y `CB-n`, que ambos citan. |
| Puntero en la tarea | Sección fija `## Pruebas` en cada tarea de capacidad, con la ruta de su plan. No lleva versión ni crea dependencia. |
| Planes | Sin `tareas:` en el frontmatter y sin línea `- Tareas:` en los casos. |
| `migration-tl-tasks` y los planes | Los recomienda, no los exige: genera tareas aunque falte el plan y lo dice en el resumen. |
| Plan desactualizado | Solo si su `spec_rev` es menor que el `rev` del spec. |
| Orden de regeneración | Planes antes que tareas, tareas antes que backlog. |
| ADRs propuestos | No frenan QA. El orquestador manda decidirlos cuando el siguiente agente es `migration-tl-tasks`, y antes lo menciona como camino que puede ir a la vez. |
| Planes antiguos | `tareas:` y `- Tareas:` en un plan existente no son error ni lo desactualizan. Desaparecen al regenerarlo. |

### 2.1 Por qué la opción A

La opción B (las tareas citan casos `TC`) da a quien implementa la lista exacta de pruebas, pero exige `rev` en los planes, `plan_rev` en las tareas y otra regla de desactualizado: regenerar un plan volvería a desactualizar tareas, que es la dependencia que este cambio quita, solo que en el otro sentido. Con la opción A no hay arista nueva: plan y tareas dependen ambos del spec y de nada más entre sí. La lista de pruebas de una tarea se obtiene sin ambigüedad: los casos cuyo `Cubre:` nombra alguna de las reglas de sus criterios, que además están en la matriz de cobertura del plan.

### 2.2 Por qué `migration-tl-tasks` no exige planes

Un proyecto generado con el orden anterior tiene tareas y puede no tener planes; y con `solo la capacidad X` es legítimo adelantar las tareas de una capacidad. Exigirlos convertiría un orden recomendado en un bloqueo sin ganar nada: las tareas no leen el plan.

## 3. Cambios por agente

- **`migration-qa`** (paso 5): no lee `migration/tasks/`. No escribe `tareas:` ni `- Tareas:`, aunque la plantilla del proyecto sea anterior y los traiga. La regla de repositorios conservados no cambia: usa `destino:` del README y las citas del spec. Siguiente paso de su resumen: resolver hallazgos, repetir QA para esa capacidad y ejecutar `migration-tl-tasks`.
- **`migration-tl-tasks`** (paso 6): añade a cada tarea de capacidad la sección `## Pruebas` con la línea fija `Plan de pruebas: migration/test-plans/<slug>.md. Validan esta tarea los casos cuyo "Cubre" nombra las reglas de sus criterios de aceptación.` Si el plan no existe, la escribe igual y lo avisa en el resumen. No lee el plan.
- **`migration-orchestrator`**: filas 5 y 6 intercambiadas con sus criterios; regla de plan sin `tareas:`; regeneración de planes antes que tareas; con specs hechos y ADRs propuestos el siguiente paso es QA y decidir los ADRs es el camino alternativo; la excepción del auditor se mantiene, antes de QA. Un proyecto con tareas y sin planes: le falta el paso 5, propone QA y no pide regenerar tareas.
- **`migration-tl-resolver`**: `registra las versiones` deja de anotar `tareas`. Al resolver un hallazgo o aplicar una mejora recomienda repetir QA y, solo si ya existen tareas de esa capacidad, `migration-tl-tasks`.
- **`migration-auditor`**, **`migration-tl-specs`**: el texto que remitía a `migration-tl-tasks` como siguiente paso remite a `migration-qa`.
- **`migration-indexer`**: tabla de agentes del bloque, convención de versiones, plantilla de plan (sin `tareas:` ni `- Tareas:`) y plantilla de tarea (sección `## Pruebas`).
- **`migration-pm`**: sin cambios. La columna "Plan de pruebas" y el riesgo "capacidades sin plan de pruebas" siguen valiendo.

## 4. Infraestructura de pruebas

- `scripts/snapshot.sh`: etapas en el orden `fixture indexer analyst tl-adrs tl-specs qa tl-tasks pm`. La etapa `qa` ya no contiene tareas; la etapa `tl-tasks` contiene planes y tareas.
- Pruebas que cambian de etapa: `test-orchestrator.sh` (los casos de versiones pasan de `qa` a `tl-tasks`), `test-resolver.sh` y `test-versiones.sh` (de `qa` a `tl-tasks`), `test-paralelo.sh` (la parte de QA pasa de `tl-tasks` a `tl-specs`).
- `verify-qa.sh`: deja de exigir `tareas:` y no falla si un plan antiguo lo trae. `test-verifiers.sh` cubre ambos casos.
- `test-orchestrator.sh`: specs hechos y ADRs propuestos → QA en paralelo, con decidir los ADRs como alternativa; planes hechos y ADRs propuestos → resolver; añadir una tarea a un spec no desactualiza ningún plan; subir el `rev` de un spec marca plan y tareas y regenera primero el plan; proyecto con tareas y sin planes → QA, sin regenerar tareas.
- `test-hallazgo.sh` (nuevo), el recorrido que se abarata: desde la etapa `qa`, resolver un hallazgo (o añadir una regla si no hay), repetir QA para esa capacidad, generar tareas; el orquestador no lista nada desactualizado y las tareas citan la regla nueva.

## 5. Compatibilidad

- Planes antiguos con `tareas:` y `- Tareas:`: válidos; se limpian al regenerar.
- Plantilla de plan antigua en un proyecto ya iniciado: sigue trayendo los campos; el prompt de QA manda no escribirlos.
- Tareas antiguas sin sección `## Pruebas`: válidas; el verificador no la exige.
- Proyecto con tareas y sin planes: el orquestador propone QA y después el PM.

## 6. Fuera de alcance

- Que las tareas citen casos `TC` (opción B).
- Versionar los planes.
