# Agentes de migración v2: diseño

Fecha: 2026-09-29
Estado: aprobado en conversación, pendiente de revisión escrita
Reemplaza parcialmente a: `docs/specs/2026-09-28-migration-agents-design.md` (v1). Todo lo que este documento no cambia sigue rigiendo según v1, en particular los formatos de artefactos (v1 §6 a §10).

## 1. Propósito del cambio

La v1 funciona, pero el uso real mostró cuatro fricciones:

1. El tech lead hace cuatro cosas distintas. Correrlo entero genera tareas antes de que se decidan los ADRs, y pedir etapas sueltas confundía "etapa" con "fase".
2. No hay forma rápida de saber en qué punto está el proceso ni qué sigue.
3. Aplicar decisiones y correcciones exige editar a mano varios archivos coherentemente: escribir la decisión del ADR, borrar la recomendación, marcar `revisado`, quitar bloqueos de las tareas.
4. Las reglas comunes están copiadas en cada prompt, y los hallazgos de QA no tienen quién los resuelva.

**Criterio de éxito:** el usuario avanza consultando a un orquestador que le da el prompt exacto del siguiente paso, delega todas las modificaciones a un agente en lenguaje natural, las tareas se generan una sola vez con las decisiones ya tomadas y ninguna capacidad descartada reaparece.

## 2. Decisiones acordadas

| Tema | Decisión |
|---|---|
| Forma | Nueve subagentes de Claude Code. Sin skills ni ejecución automática de la cadena. |
| Tech lead | Se divide en cuatro agentes: capacidades, ADRs, specs y tareas. `migration-techlead` se retira. |
| Orquestador | Subagente de solo lectura. Diagnostica el estado a partir de los archivos y entrega el siguiente paso con su prompt exacto. No ejecuta ni edita. |
| Decisiones y ediciones | Un subagente aplica lo que el usuario describe en el prompt y devuelve un resumen de cambios a la conversación principal. |
| Reglas comunes | Fuente única en un bloque delimitado del `CLAUDE.md` de la carpeta padre, escrito por el indexador. |
| Índice general | `index.md` en la carpeta padre que apunta a los índices de cada repo. |
| Formatos | Sin cambios, salvo los hallazgos de QA numerados (`H-n`) y el campo `excluir:` en `migration/README.md`. |
| Revisión humana | Se mantiene entre cada paso. |

## 3. Agentes

| Agente | Lee | Escribe | Requiere destino |
|---|---|---|---|
| `migration-indexer` | los repos | `index.md` por repo, `index.md` general, `CLAUDE.md`, `migration/` con plantillas | no |
| `migration-analyst` | índices, código | `migration/specs/_capacidades.md` | no |
| `migration-tl-adrs` | índices, mapa, código | `migration/adr/*.md` | sí |
| `migration-tl-specs` | mapa, ADRs, código | `migration/specs/<capacidad>.md` | no |
| `migration-tl-tasks` | specs, ADRs | `migration/tasks/T-*.md` | sí |
| `migration-qa` | specs, tareas | `migration/test-plans/*` | no |
| `migration-pm` | tareas, ADRs, mapa, planes | `migration/backlog.md`, `fase` y `prioridad` de tareas, README | no |
| `migration-tl-resolver` | lo que nombre el prompt y lo necesario para mantener coherencia | los artefactos que nombre el prompt | no |
| `migration-orchestrator` | todo | nada | no |

Orden de la cadena: indexer, analyst, tl-adrs, tl-specs, tl-tasks, qa, pm, con revisión humana entre cada paso. `migration-tl-resolver` se usa en cualquier punto para aplicar decisiones o correcciones. `migration-orchestrator` se consulta en cualquier momento.

`migration-qa` y `migration-pm` conservan su comportamiento de v1 salvo lo indicado en §9.

## 4. Reglas comunes y `CLAUDE.md`

### 4.1 Fuente única

El indexador escribe en la carpeta padre un `CLAUDE.md` con un bloque delimitado:

```
<!-- migration-flow:begin -->
...
<!-- migration-flow:end -->
```

Escritura:
- Si `CLAUDE.md` no existe, lo crea con el bloque.
- Si existe sin bloque, añade el bloque al final.
- Si existe con bloque, reemplaza solo el contenido entre las marcas. Todo lo que esté fuera se conserva byte a byte.

Contenido del bloque:
- Propósito del flujo y tabla de agentes con qué produce cada uno, en orden.
- Convenciones comunes (§4.2).
- Instrucciones para la sesión principal: consultar `migration-orchestrator` para saber qué sigue y usar `migration-tl-resolver` para decisiones y cambios en artefactos, en lugar de editar a mano.

### 4.2 Convenciones del bloque

- Detección de repos (v1 §5).
- Estados `generado`, `revisado`, `observado`, `propuesto` y su significado. `revisado` nunca lo sobrescribe un agente generador.
- Derivados que se regeneran siempre y no se editan: `index.md` por repo, `index.md` general, `_capacidades.md`, `_cobertura.md`, `backlog.md`.
- Identificadores: `RN-n:`, `CB-n:`, `PA:<capacidad>:<n>`, `TC-<capacidad>-<nnn>`, `H-n`, `T-NNN`, `NNNN` para ADRs. Nunca se renumeran. Un elemento retirado se marca como retirado, no se borra.
- Contenido en español. Identificadores técnicos tal cual.
- Specs sin código del lenguaje origen.
- Destino en `destino:` de `migration/README.md` o en el prompt. Capacidades descartadas en `excluir:` del mismo archivo.
- Cada agente termina con: archivos creados, archivos modificados, lo que no pudo resolver y siguiente paso.

### 4.3 Uso por los agentes

Cada agente, salvo `migration-indexer`, lee el bloque al empezar. Si `CLAUDE.md` o el bloque no existen, se detiene sin escribir nada y pide correr `migration-indexer`.

Cada prompt conserva además, de forma explícita, dos reglas críticas aunque estén en el bloque: nunca sobrescribir `revisado` y detenerse si falta un insumo. El resto de convenciones se toma del bloque.

## 5. `migration-indexer`

Hace todo lo de v1 §6 y además:

**Índice general** en `<carpeta padre>/index.md`, derivado:

```markdown
# Índice general

Generado: <AAAA-MM-DD> por migration-indexer

| Repo | Stack | Entrada | Índice |
|---|---|---|---|
| bff | Node 20, Express 4, TypeScript | src/server.ts | [bff/index.md](bff/index.md) |

Artefactos de migración: [migration/](migration/README.md)
```

**`CLAUDE.md`** según §4.1.

**README de `migration/`.** Si no existe, lo crea con este frontmatter y sin la lista de pasos de v1:

```markdown
---
destino:
excluir: []
generado: <AAAA-MM-DD>
---
# Migración

## Repos detectados
- <repo>: <stack>

## Cómo continuar
Consulta el subagente migration-orchestrator para saber el siguiente paso.
```

Si ya existe, no lo toca, salvo añadir `excluir: []` al frontmatter cuando falta.

`migration-analyst` y el resto de agentes leen el índice general para saber qué repos existen y dónde está cada índice.

## 6. Agentes que reemplazan al tech lead

Comportamiento común:
- Leen el bloque del `CLAUDE.md` e insumos. Si falta un insumo, se detienen y nombran el agente a correr antes.
- Respetan `revisado`.
- En recorridas no duplican: reutilizan ids emparejando (v2 conserva la regla de v1 del tech lead) y listan huérfanos en el resumen sin borrarlos.

### 6.1 `migration-analyst`

- Insumos: índice general e índices por repo.
- Hace la investigación y escribe `_capacidades.md` como v1 §7 fase 1.
- Omite las capacidades listadas en `excluir:`. Si detecta en el código una capacidad excluida, la menciona en el resumen como "excluida, omitida".
- No requiere destino. La línea de cabecera de `_capacidades.md` ya no incluye destino.

### 6.2 `migration-tl-adrs`

- Insumos: `_capacidades.md` y destino.
- Escribe ADRs observados y propuestos como v1 §7 fase 2.
- Recorridas: empareja por `titulo` y reutiliza id.

### 6.3 `migration-tl-specs`

- Insumos: `_capacidades.md` y al menos un ADR.
- Escribe un spec por capacidad como v1 §7 fase 3, citando ADRs existentes.
- Alcance: `solo la capacidad X`. Si X no está en el mapa o está en `excluir:`, se detiene y lista las disponibles.

### 6.4 `migration-tl-tasks`

- Insumos: al menos un spec, ADRs y destino.
- **Se detiene si hay ADRs con `estado: propuesto`**, listándolos y dando el prompt para resolverlos con `migration-tl-resolver`. Continúa si el prompt incluye "aunque haya ADRs propuestos".
- Escribe tareas como v1 §7 fase 4, con la regla de `bloqueada_por` restringida a preguntas que impiden empezar.
- Alcance: `solo la capacidad X`.

## 7. `migration-tl-resolver`

### 7.1 Propósito

Aplica decisiones y correcciones descritas en lenguaje natural sobre ADRs, specs, tareas, planes de prueba y `migration/README.md`. Solo modifica lo que el prompt nombra, más las referencias estrictamente necesarias para mantener coherencia en los casos que §7.2 indica. No decide por el usuario ni regenera artefactos.

### 7.2 Operaciones

| Operación | Qué hace |
|---|---|
| Decidir un ADR propuesto | Escribe en Decisión la opción elegida nombrando la tecnología, elimina la línea de recomendación, conserva las alternativas descartadas con su motivo y numeración, reescribe "Implicación para la migración", pasa a `revisado` y quita ese id de `bloqueada_por` en todas las tareas. "Acepta la recomendación" usa la opción recomendada. |
| Corregir un ADR observado | Edita texto o `implicacion_migracion` y pasa a `revisado`. |
| Responder una pregunta abierta | Escribe la respuesta debajo de la pregunta sin borrarla. Si se pide, crea una `RN-n` o `CB-n` nueva con el siguiente número libre. Quita `PA:<capacidad>:<n>` de `bloqueada_por` en las tareas. |
| Resolver un hallazgo de QA | Aplica `H-n` del plan al spec como regla, caso borde o aclaración, y marca el hallazgo como resuelto en el plan indicando qué cambió en el spec. |
| Excluir una capacidad | La añade a `excluir:`, borra su spec, su plan y sus tareas, quita su fila de `_capacidades.md` y lista, sin editarlos, los restos en otros artefactos (menciones en specs, `depende_de`, ADRs que solo la trataban). |
| Fijar destino | Escribe `destino:` en el README. |
| Marcar revisado | Pasa a `revisado` los artefactos nombrados. |
| Edición libre | Cualquier cambio descrito sobre un ADR, spec, tarea o plan: reglas, contratos, criterios, dependencias, tamaño, `fase`, `prioridad`, casos de prueba. |

### 7.3 Reglas

- **Marca `revisado` lo que edita**, salvo que el prompt diga "sin marcar revisado".
- **No renumera** ids. Lo nuevo toma el siguiente número libre. Lo eliminado se marca como retirado con fecha.
- **No propaga por su cuenta.** Tras editar, busca y lista los artefactos que citan lo cambiado y recomienda qué agente repetir. Solo edita esos artefactos si el prompt los nombra. Excepción: la limpieza de `bloqueada_por` en decisiones de ADR y respuestas a preguntas abiertas, que forma parte de la operación.
- **Casos de prueba sin respaldo en el spec.** Si se pide añadir un caso de prueba cuyo comportamiento no está en el spec, no edita el plan: lo explica y entrega el prompt para añadirlo primero al spec.
- **Derivados.** Se niega a editar `index.md`, `_cobertura.md` y `backlog.md` e indica qué agente los regenera. `_capacidades.md` solo se toca mediante la exclusión.
- **Ambigüedad.** Si una instrucción es ambigua o un id no existe, no edita ese punto, lo reporta y sigue con el resto.

### 7.4 Resumen

Termina con una tabla por archivo modificado (archivo, cambio, estado final), la lista de puntos no aplicados con el motivo, los artefactos que citan lo cambiado y los agentes que conviene repetir.

## 8. `migration-orchestrator`

### 8.1 Propósito

Diagnostica el estado del proceso leyendo archivos y entrega el siguiente paso. Solo lectura. No guarda estado propio.

### 8.2 Diagnóstico

1. **Paso actual**, deducido de qué artefactos existen: bloque de `CLAUDE.md`, índices, mapa, ADRs, specs, tareas, planes, backlog.
2. **Pendientes de revisión:** ADRs `propuesto`, artefactos en `generado`, preguntas abiertas sin respuesta, hallazgos `H-n` sin resolver, destino vacío, restos de capacidades excluidas.
3. **Desactualizados**, por fecha de modificación: plan más antiguo que su spec, tareas más antiguas que su spec o que un ADR revisado después, backlog más antiguo que alguna tarea, planes sin hallazgos numerados (formato v1).
4. **Siguiente paso:** uno solo, recomendado, con el prompt exacto para copiar. Si hay decisiones pendientes, el prompt es para `migration-tl-resolver` con los ids ya puestos y un marcador `<tu decisión>` donde el usuario escribe su elección. Si hay otro camino válido, lo menciona en una línea.

### 8.3 Formato de salida

```markdown
## Estado
Paso actual: <agente> completado.

## Pendiente de revisión
- <artefacto>: <qué falta>

## Desactualizado
- <artefacto>: <por qué>

## Siguiente paso
<una frase>

    <prompt exacto>
```

Secciones vacías se escriben con "Nada".

## 9. Cambios en `migration-qa` y `migration-pm`

- `migration-qa` numera los hallazgos para el tech lead como `H-1`, `H-2`… dentro de cada plan. Un hallazgo resuelto por el resolver queda marcado como resuelto y no se vuelve a listar en `_cobertura.md`.
- `migration-pm` ya no marca pasos en `migration/README.md`, porque la lista de pasos desaparece. Mantiene `destino:`, repos detectados y la sección "Cómo empezar a implementar".

## 10. Instalación y compatibilidad

**Instalador.** `scripts/install.sh` copia los nueve agentes a `~/.claude/agents/` y elimina `migration-techlead.md` si existe. Antes de sobrescribir un archivo con el mismo nombre, comprueba que su frontmatter `name` empiece por `migration-`; si no, avisa y no lo sobrescribe.

**Workspaces de v1.** Los artefactos de v1 siguen siendo válidos. El usuario vuelve a correr `migration-indexer`, que crea `CLAUDE.md`, el índice general y añade `excluir:`. Las capacidades quitadas a mano en v1 se registran con `migration-tl-resolver`. `migration-orchestrator` detecta planes sin hallazgos numerados y sugiere repetir `migration-qa`.

**Documentación.** `README.md` y `docs/tutorial.md` se reescriben para el flujo de nueve agentes, con el orquestador como punto de entrada y el resolver como vía para todos los cambios.

## 11. Pruebas

Sobre el fixture existente (`fixtures/sample-workspace/`), con la infraestructura de v1 (`fixture-reset.sh`, `run-agent.sh`, verificadores).

**Verificadores:**
- `verify-indexer.sh` ampliado: índice general con enlaces válidos a cada `index.md`, `CLAUDE.md` con bloque delimitado, README con `excluir:`.
- `verify-techlead.sh` se divide en `verify-analyst.sh`, `verify-tl-adrs.sh`, `verify-tl-specs.sh` y `verify-tl-tasks.sh` con las mismas comprobaciones repartidas.
- `verify-qa.sh` ampliado: hallazgos numerados `H-n`.
- `verify-pm.sh` sin cambios salvo quitar la comprobación de pasos en el README.
- `verify-resolver.sh` y `verify-orchestrator.sh` nuevos.

**Casos de prueba específicos:**
1. El bloque del `CLAUDE.md` se reemplaza y el texto fuera de él se conserva byte a byte.
2. Una capacidad en `excluir:` no reaparece al repetir `migration-analyst`.
3. `migration-tl-tasks` se detiene con ADRs propuestos sin escribir nada, y continúa con "aunque haya ADRs propuestos".
4. El resolver decide un ADR propuesto: decisión con tecnología nombrada, sin recomendación, `revisado`, y ese id ausente de todo `bloqueada_por`.
5. El resolver responde una pregunta abierta sin renumerar y quita el `PA` correspondiente.
6. El resolver se niega a editar `backlog.md`.
7. El resolver se niega a añadir un caso de prueba sin respaldo en el spec.
8. El resolver excluye una capacidad y lista restos.
9. El orquestador da el paso correcto en tres estados: tras el indexador, con ADRs propuestos, con un plan más antiguo que su spec.
10. Un agente sin bloque en `CLAUDE.md` se detiene pidiendo el indexador.

**Flujo completo.** `run-all.sh` ejecuta indexer, analyst, tl-adrs, un paso de resolver que acepta las recomendaciones de todos los ADRs propuestos, tl-specs, tl-tasks, qa y pm, con sus verificadores.

## 12. Errores contemplados

Se añaden a los de v1 §12:

| Situación | Comportamiento |
|---|---|
| Falta `CLAUDE.md` o su bloque | El agente se detiene y pide correr `migration-indexer`. |
| `migration-tl-tasks` con ADRs propuestos | Se detiene y lista los ADRs con el prompt para resolverlos, salvo que se fuerce. |
| Prompt del resolver ambiguo o con id inexistente | No aplica ese punto, lo reporta y aplica el resto. |
| Resolver sobre un derivado | Se niega e indica el agente que lo regenera. |
| Caso de prueba sin respaldo en el spec | El resolver no edita el plan y entrega el prompt para añadirlo al spec. |
| Capacidad excluida pedida como alcance | El agente se detiene y lista las disponibles. |
| Archivo ajeno con el nombre de un agente en `~/.claude/agents/` | El instalador avisa y no lo sobrescribe. |

## 13. Fuera de alcance

- Ejecución automática de la cadena o de varios agentes seguidos.
- Skills o comandos.
- Cambios de formato de artefactos más allá de `H-n` y `excluir:`.
- Archivo de estado propio del orquestador.
