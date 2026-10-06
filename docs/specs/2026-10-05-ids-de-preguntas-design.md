# Identificador propio para las preguntas abiertas: diseño

Fecha: 2026-10-05
Estado: implementado (sigue la propuesta del encargo; las decisiones propias están en §2)
Modifica: el formato de la sección 12 de los specs y todo lo que cita una pregunta abierta.

## 1. Problema

Reglas, casos borde y mejoras llevan un id escrito al inicio de su línea (`RN-n:`, `CB-n:`, `MJ-n:`) y nunca se renumeran. Las preguntas abiertas eran la excepción: viñetas sin id, citadas por su lugar en la lista como `PA:<capacidad>:<n>`. Eso se sostenía con dos reglas de disciplina: el resolver no borraba preguntas y `migration-tl-specs` conservaba su orden al regenerar. Si alguna fallaba, o alguien editaba la sección a mano, todas las referencias posteriores pasaban a apuntar a otra pregunta y nada lo detectaba.

**Criterio de éxito:** cada pregunta lleva su id escrito; todas las referencias se resuelven por ese id; insertar, reordenar o borrar una línea de la sección 12 no cambia a qué pregunta apunta ninguna referencia, y una referencia rota la detecta un verificador; los proyectos ya generados siguen funcionando y pasan al formato nuevo sin rehacer nada.

## 2. Decisiones

| Tema | Decisión |
|---|---|
| Formato en el spec | `- PA-3: <pregunta>`, con el id al inicio de la línea. Las líneas `Respuesta` y las marcas `(retirado ...)` no cambian. |
| Referencias | Conservan su forma: `PA:<capacidad>:<n>` en las tareas y `[decisión: PA n]` en las reglas. `n` pasa de ser el lugar en la lista a ser el número del id. |
| Reglas del id | Las de los demás: no se renumera, lo nuevo toma el siguiente número libre, lo retirado se marca y no se borra. |
| Formato anterior | Un spec sin ningún id en la sección 12. Sus referencias se siguen resolviendo por el lugar en la lista, como vía de compatibilidad, y el orquestador lo lista como pendiente de numerar. |
| Formatos mezclados | Error: preguntas con id y sin id en la misma sección. Lo reporta `verify-tl-specs.sh`. |
| Numerar | Operación nueva del resolver: `numera las preguntas` (todos los specs) y `numera las preguntas del spec <slug>`. Numera según el lugar actual, contando las retiradas. No sube `rev` ni cambia `estado`. |
| Casos pendientes de QA | `- **Pendiente PA-3**: <pregunta>...`. El formato anterior `**Pendiente 3**` se sigue aceptando y se lee como PA-3. |
| Orquestador | Nombra las preguntas por id y añade a `## Datos` la línea `sin-numerar:` con los specs del formato anterior. No cambia el siguiente paso. |
| Auditor | Sin cambios: `[decisión: PA n]` sigue dando el veredicto `decisión`, sea cual sea `n`. |

### 2.1 Por qué las referencias conservan su forma

Es lo que hace barata la compatibilidad. En un spec ya generado, numerar las preguntas según su lugar actual deja cada `PA:<capacidad>:<n>` y cada `[decisión: PA n]` apuntando a la misma pregunta de antes, sin tocar ninguna tarea, plan ni backlog. Las retiradas cuentan al numerar porque hasta ahora conservaban su sitio precisamente para eso.

### 2.2 Por qué numerar no sube `rev`

No cambia qué pregunta el spec ni qué significa ninguna referencia: es un registro, como `registra las versiones`. Si subiera `rev`, pasar al formato nuevo dejaría desactualizados todos los derivados de un proyecto que no ha cambiado.

## 3. Sitios donde se usaba el lugar en la lista, y cómo quedan

| Sitio | Antes | Ahora |
|---|---|---|
| Spec, sección 12 | Viñeta sin id | `- PA-n: ...` |
| `migration-tl-specs`, al regenerar | Conservaba el orden de las preguntas | Conserva el id de cada pregunta que persiste, numera las nuevas desde el más alto y marca como retiradas las que ya no aplican. Un spec del formato anterior se numera primero según su lugar. |
| Tareas, `bloqueada_por` | `PA:<slug>:<n>`, n = lugar | `PA:<slug>:<n>`, n = id |
| Reglas nacidas de una respuesta | `[decisión: PA n]`, n = lugar | `[decisión: PA n]`, n = id |
| Resolver, responder | "la pregunta 3" = la tercera viñeta | "la pregunta 3" = `PA-3` |
| Resolver, reclasificar como mejora | Marcaba la línea como retirada para que las demás no cambiaran de lugar | La marca como retirada porque los ids no se borran |
| Resolver, limpiar bloqueos | Quitaba `PA:<slug>:<n>` por lugar | Lo quita por id |
| Planes, casos pendientes | `**Pendiente <n>**` | `**Pendiente PA-<n>**` |
| `scripts/backlog.sh` | Citaba la viñeta número n de la sección 12 | Busca la línea `- PA-n:`; por lugar solo si el spec no tiene ningún id |
| `scripts/verify-tl-tasks.sh` | Comprobaba que n no superara el número de viñetas | Exige que exista `PA-n`; por conteo solo si el spec no tiene ningún id |
| `scripts/verify-tl-specs.sh` | Contaba viñetas | Además: ids únicos y sin mezclar formatos |
| `scripts/verify-qa.sh` | Comparaba el número de pendientes con el de preguntas | Cada pendiente cita una pregunta que existe y sigue abierta |
| Orquestador | Contaba preguntas por spec | Las nombra por id y lista los specs sin numerar |
| Bloque de `CLAUDE.md` | citadas como `PA:<capacidad>:<n>` según su lugar en la lista | "`PA-n:` al inicio de línea en la sección 12, citadas como `PA:<capacidad>:<n>`" |
| Plantillas | Sección 12 sin formato; comentario de `bloqueada_por` | Sección 12 con `- PA-1:`; el comentario dice que n es el id |

## 4. Compatibilidad

- Un proyecto generado antes funciona sin tocar nada: sus specs son del formato anterior y sus referencias se resuelven como hasta ahora.
- Para pasar al formato nuevo: `Usa el subagente migration-tl-resolver: numera las preguntas`. No hay que regenerar ni repetir ningún agente.
- La plantilla de spec de un proyecto ya iniciado no muestra el formato nuevo; `migration-tl-specs` lo exige igualmente.
- Un plan con `**Pendiente 3**` sigue siendo válido tras numerar su spec.

## 5. Pruebas

Sin agentes:
1. Spec con PA-1, PA-2 y PA-3 y una tarea bloqueada por `PA:<slug>:3`. Se borra la línea de PA-2: `backlog.sh` sigue citando el texto de PA-3 y `verify-tl-tasks.sh` pasa.
2. Lo mismo insertando una pregunta nueva al principio.
3. Referencia a un id que no existe: `verify-tl-tasks.sh` falla y la nombra.
4. Ids duplicados y formatos mezclados: `verify-tl-specs.sh` falla.
5. Spec del formato anterior: los verificadores y `backlog.sh` lo aceptan y resuelven por lugar.

Con agentes, sembrando las preguntas (bajo paridad los fixtures generan pocas o ninguna):
6. Numerar un spec antiguo con una pregunta retirada en medio y una tarea bloqueada por la última.
7. Responder una pregunta por id y comprobar que se limpia el bloqueo correcto.
8. Regenerar un spec con una pregunta respondida y otra abierta: conserva ambos ids y la respuesta.
9. Las cadenas de los dos fixtures pasan sus verificadores de etapa.

## 6. Fuera de alcance

- El tope de preguntas por spec y la clasificación entre pregunta y mejora.
- Planificación de datos y estrategia de corte.
