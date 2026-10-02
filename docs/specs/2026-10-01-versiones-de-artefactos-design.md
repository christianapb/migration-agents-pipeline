# Versiones de artefactos: diseño

Fecha: 2026-10-01
Estado: pendiente de revisión escrita
Modifica: `docs/specs/2026-09-29-migration-agents-v2-design.md` (v2) y se integra con la política de paridad, la evidencia por regla y el auditor, y el destino por repositorio (los tres del 2026-10-01, ya en `master`). Lo que este documento no cambia sigue rigiendo según esos.

## 1. Propósito

Los artefactos forman una cadena: specs → tareas → planes de prueba → backlog, con los ADRs alimentando a las tareas y cada spec alimentando su sección de auditoría. Nada se regenera solo, así que `migration-orchestrator` debe decir qué quedó desactualizado. Hoy lo deduce del orden en que Glob devuelve los archivos (fecha de modificación) y, si no basta, de fechas con precisión de día. Falla de cuatro formas:

1. Las fechas de modificación cambian sin que cambie el contenido: `git checkout`, un clon, carpetas sincronizadas.
2. Marcar `revisado` hace el archivo más nuevo sin cambiar su contenido; el orquestador responde "posiblemente desactualizado".
3. Al decidir un ADR, el resolver limpia `bloqueada_por` y con ello borra la otra señal que el orquestador tenía.
4. La prueba del orquestador usa `sleep 2; touch`: prueba la heurística, no el comportamiento.

Además, el orquestador da un paso por completado si existe "algún" ADR o "alguna" tarea, de modo que una corrida con `solo la capacidad X` hace que el paso parezca terminado para todas.

**Criterio de éxito:** el orquestador decide lo desactualizado comparando números escritos en los artefactos, sin usar fechas de modificación; da el mismo resultado en un clon que en la carpeta original; e informa de la completitud por capacidad.

## 2. Decisiones

| Tema | Decisión |
|---|---|
| Versión | `rev: <entero>` en el frontmatter de specs, ADRs y tareas. Empieza en 1. |
| Anotación en tareas | `spec_rev: <n>` (vacío en las fundacionales) y `adrs_rev: {0003: 1, 0011: 2}`, un mapa en una línea con la versión de cada ADR de `adrs:`. |
| Anotación en planes | `spec_rev: <n>` y `tareas: [T-011, T-012]`: los ids de las tareas del spec que existían al generar el plan. Sin versión de tarea. |
| Anotación en la auditoría | La línea `Auditada:` de cada sección de `_auditoria.md` añade `Spec rev: <n>.` |
| Anotación en el backlog | Columna `Rev` en las tablas de fases, junto a la columna Tarea. |
| Quién sube `rev` | El agente generador al reescribir un artefacto existente, siempre; el resolver al editar contenido. |
| Qué no sube `rev` | Marcar `revisado`, limpiar `bloqueada_por`, rellenar `fase` y `prioridad`, y registrar versiones (§3.3). |
| Artefactos sin versión | El orquestador los lista como "no se puede determinar" y recomienda `registra las versiones` con el resolver, o regenerar. No supone ninguna versión. |
| Completitud | Por capacidad en los pasos 4, 5 y 6. La salida dice qué capacidades faltan en cada paso. |
| Categoría "posiblemente desactualizado" | Desaparece. |

### 2.1 Por qué los planes anotan ids de tareas y no sus versiones

Un plan usa de las tareas solo sus ids, en la línea `Tareas:` de cada caso. Si anotara la versión de cada tarea, regenerar tareas por un cambio de ADR marcaría todos los planes aunque ningún caso cambie. Con la lista de ids, el plan queda desactualizado solo cuando aparece o desaparece una tarea de su spec, que es cuando la trazabilidad deja de ser correcta. Si el contenido que se prueba cambia, cambia el spec, y eso lo recoge `spec_rev`.

### 2.2 Por qué `fase` y `prioridad` no suben `rev`

Los escribe `migration-pm` a partir del backlog, que a su vez registra el `rev` de cada tarea. Si rellenarlos subiera `rev`, el backlog quedaría desactualizado en el mismo momento de generarse.

### 2.3 Por qué limpiar `bloqueada_por` no sube `rev`, y cómo se detecta igual

Quitar un bloqueo no cambia lo que la tarea pide implementar. Pero el backlog sí lista los bloqueos, y quedaría obsoleto sin señal. Se cubre con una comparación de contenido: el backlog está desactualizado si una fila de `## Bloqueos` nombra un bloqueo que la tarea ya no tiene en `bloqueada_por`. Por otro lado, decidir un ADR sí cambia su contenido y sube su `rev`, con lo que las tareas que lo citan quedan desactualizadas por `adrs_rev`: es la señal que hoy se pierde.

### 2.4 Por qué el generador sube siempre

Un agente no puede saber de forma fiable si lo que va a escribir difiere de lo que había. Subir siempre marca de más y nunca de menos.

## 3. Reglas de versión

Escritas en el bloque de `CLAUDE.md` y repetidas en el prompt de cada agente que escribe, porque el indexador no sobrescribe plantillas existentes y un proyecto ya iniciado no tendrá los campos en las suyas.

### 3.1 Al escribir un artefacto con `rev`

- Si el archivo no existe: `rev` es 1, o uno más que la mayor versión que algún derivado anote de ese artefacto (`spec_rev`, `adrs_rev`, columna `Rev`, `Spec rev:`), si la hay. Evita que un artefacto borrado y regenerado vuelva a una versión que sus derivados ya tienen anotada.
- Si existe y se reescribe: `rev` anterior más 1. Si no tenía `rev`, se aplica la regla anterior.
- Si existe con `estado: revisado`: no se toca, tampoco su `rev`.

### 3.2 Al escribir un derivado

Anota la versión actual de cada insumo leída de su frontmatter en ese momento. Si el insumo no tiene `rev`, deja la anotación vacía; no supone un valor.

### 3.3 `migration-tl-resolver`

- Sube `rev` en 1 cuando edita el contenido de un spec, un ADR o una tarea: decidir un ADR, cambiar una decisión, responder una pregunta abierta, resolver un hallazgo, aplicar una mejora, corregir un hallazgo de auditoría, una edición libre. Una vez por archivo y por invocación.
- No sube `rev`: marcar `revisado`, descartar una mejora (solo marca la entrada), limpiar `bloqueada_por`, fijar el destino, excluir una capacidad.
- Operación nueva, `registra las versiones`: para proyectos generados antes de este cambio. Añade `rev: 1` a los specs, ADRs y tareas que no lo tengan y anota en cada derivado sin anotación la versión actual de sus insumos. Es una declaración del usuario de que los derivados están al día; el resolver lo dice en el resumen. No toca los artefactos que ya tienen versión.
- En el resumen de cambios lista los artefactos cuyo `rev` subió y qué derivados quedan desactualizados.

## 4. Cambios por agente

### 4.1 `migration-indexer`

Plantillas: `rev: 1` en `spec.md`, `adr.md` y `task.md`; `spec_rev:` y `adrs_rev: {}` en `task.md`; `spec_rev:` y `tareas: []` en `test-plan.md`; columna `Rev` en `backlog.md`. Bloque de `CLAUDE.md`: las reglas de §3 y la frase `registra las versiones`.

### 4.2 `migration-tl-adrs`, `migration-tl-specs`

Escriben y suben `rev` según §3.1.

### 4.3 `migration-tl-tasks`

`rev` según §3.1; `spec_rev` con el `rev` del spec; `adrs_rev` con una entrada por cada id de `adrs:`.

### 4.4 `migration-qa`

`spec_rev` y `tareas:` en cada plan. Los planes no llevan `rev`: nadie los consume por versión.

### 4.5 `migration-auditor`

`Spec rev: <n>.` en la línea `Auditada:` de cada sección.

### 4.6 `migration-pm`

Columna `Rev` con el `rev` de cada tarea. Rellenar `fase` y `prioridad` no cambia `rev`.

### 4.7 `migration-orchestrator`

**Desactualizado**, solo por comparación de valores escritos:

| Artefacto | Desactualizado si |
|---|---|
| Plan | `spec_rev` menor que el `rev` del spec, o el conjunto de tareas con `spec: <slug>` difiere de `tareas:`. |
| Tarea | `spec_rev` menor que el `rev` del spec, o alguna entrada de `adrs_rev` menor que el `rev` de ese ADR, o un id de `adrs:` sin entrada en `adrs_rev`. |
| Sección de auditoría | `Spec rev:` menor que el `rev` del spec. |
| Backlog | alguna tarea con `rev` distinto del de su fila, tareas que no figuran, filas de tareas que ya no existen, o un bloqueo listado que la tarea ya no tiene. |

Se conservan las reglas que ya comparan contenido: `commits:` del spec frente al índice general, tareas y ADRs propuestos sobre repositorios conservados, hallazgos en formato v1. Desaparece "tareas con un ADR ya revisado en `bloqueada_por`" como señal de versión (queda cubierta por `adrs_rev`). Los hallazgos `AU-n` se listan como pendientes si el `Spec rev:` de su sección es igual al `rev` del spec.

**Sin versión:** un artefacto sin `rev`, o un derivado sin anotación, se lista en "Desactualizado" como `<artefacto>: no se puede determinar, no tiene versión registrada`. El orquestador no deduce nada de fechas. Recomienda `Usa el subagente migration-tl-resolver: registra las versiones` si el usuario sabe que nada cambió, y como alternativa regenerar con el agente correspondiente. Tiene la misma prioridad que lo desactualizado al elegir el siguiente paso.

**Completitud:**

| Paso | Completado si |
|---|---|
| 3 | existe al menos un ADR `observado` o `revisado`. Los ADRs no son por capacidad. |
| 4 | un spec por cada capacidad del mapa no excluida ni fuera de alcance. |
| 5 | al menos una tarea fundacional, y al menos una tarea con `spec: <slug>` por cada spec. |
| 6 | un plan por cada spec, y `_cobertura.md`. |

La sección "Estado" añade la línea `Faltan: <paso n: capacidades; ...>` o `Faltan: nada`. El siguiente paso, cuando falta una capacidad, lleva `solo la capacidad <slug>` si falta una sola.

El prompt del orquestador no menciona fechas de modificación ni el orden de Glob.

## 5. Verificadores y pruebas

**Sin agentes** (`test-fast.sh`):

- `verify-tl-specs.sh`, `verify-tl-adrs.sh`, `verify-tl-tasks.sh`: `rev` presente y entero mayor que 0.
- `verify-tl-tasks.sh`: `spec_rev` entero y no mayor que el `rev` del spec (vacío solo si `spec` está vacío); `adrs_rev` con una entrada por id de `adrs:` y ninguna mayor que el `rev` del ADR.
- `verify-qa.sh`: `spec_rev` no mayor que el `rev` del spec; `tareas:` solo con ids existentes.
- `verify-auditor.sh`: `Spec rev:` en cada sección, no mayor que el `rev` del spec.
- `verify-pm.sh`: columna `Rev`, y cada valor igual al `rev` de la tarea.
- `verify-indexer.sh`: campos nuevos en las plantillas y la convención en el bloque.
- `test-verifiers.sh`: rechaza `rev` no numérico, `spec_rev` mayor que el `rev` del spec, `adrs_rev` sin un ADR citado, `Rev` del backlog distinto del de la tarea.
- `test-prompts.sh`: cada agente que escribe contiene la regla de versión; el orquestador no contiene "fecha de modificación" ni "Glob devuelve".

**Con agentes:**

`test-orchestrator.sh`, sobre la instantánea `qa`:

1. Sin tocar nada: "Desactualizado" dice "Nada".
2. `touch` de un spec, sin cambiar contenido: "Nada".
3. Subir el `rev` de un spec: marca su plan y sus tareas, y ningún otro spec.
4. Cambiar solo `estado:` a `revisado`: "Nada".
5. Subir el `rev` de un ADR: marca solo las tareas que lo citan.
6. Borrar las tareas de una capacidad: "Estado" nombra esa capacidad como faltante en el paso 5.
7. Quitar `rev` de un spec: "no se puede determinar" y recomienda `registra las versiones`.

`test-resolver.sh`: una edición de contenido sube `rev` en 1; "marca revisado" no lo sube; `registra las versiones` sobre un workspace al que se le quitaron los campos los repone sin subir nada.

Subida por los generadores: `test-tl-specs.sh` y `test-tl-tasks.sh` comprueban que, tras una segunda corrida, los artefactos `generado` tienen `rev: 2` y los `revisado` conservan el suyo. `verify-idempotency.sh` comprueba además que el `rev` del spec revisado no cambia.

## 6. Compatibilidad

Un proyecto generado antes de este cambio no tiene versiones. Sus verificadores fallan y el orquestador informa "no se puede determinar". El camino es `registra las versiones` (si el usuario sabe que está al día) o regenerar. Las plantillas existentes no se actualizan; los agentes escriben los campos igualmente.

## 7. Documentación

`docs/tutorial.md`: en la sección 2 desaparece el aviso sobre `git checkout`; en la 4, "compara fechas" pasa a "compara versiones"; en la 5, la regla de qué repetir se explica con `rev`. Se añade qué hacer en un proyecto anterior. `README.md`: convenciones.

## 8. Fuera de alcance

- Detectar que un spec quedó viejo porque cambió el código origen. Ya existe la pieza equivalente: cada spec anota en `commits:` el commit de cada repositorio y el orquestador lo compara con la columna Commit del índice general. Es el mismo modelo (el derivado anota la versión del insumo) con el commit como versión del código. No se cambia aquí.
- Versión del mapa de capacidades y de los índices: los specs no anotan de qué versión del mapa salieron.
- Detectar ediciones a mano que no suben `rev`. Quien edita a mano debe subirlo o usar el resolver; el tutorial lo dice.
- `rev` en planes de prueba y backlog: nadie los consume por versión.
