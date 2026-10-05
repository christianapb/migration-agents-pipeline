# Reabrir un artefacto revisado: diseño

Fecha: 2026-10-05
Estado: implementado (sigue la propuesta del encargo; las decisiones propias están en §2 y §4)
Modifica: `migration-tl-resolver` (operación nueva), `migration-orchestrator` (una puerta más), el bloque de `CLAUDE.md` (dos frases) y, como decisión aparte, `migration-tl-specs` (§4).

## 1. Problema

Basta corregir una regla con el resolver para que el spec quede `revisado`, y ningún generador sobrescribe un artefacto `revisado`. Cuando después hace falta regenerarlo no hay ninguna orden para descongelarlo: el tutorial pide cambiar a mano `estado: revisado` por `estado: generado`. El orquestador tiene el mismo hueco. Y la edición manual esconde un riesgo: al regenerar se puede perder lo que el usuario decidió dentro del artefacto, sin que nadie se lo advierta.

**Criterio de éxito:** una orden del resolver devuelve un artefacto `revisado` a un estado regenerable; antes de regenerar, el resolver dice qué contenido de origen humano hay y qué pasará con él; el tutorial deja de pedir ediciones manuales; el orquestador ofrece reabrir cuando un derivado `revisado` está desactualizado.

## 2. Decisiones

| Tema | Decisión |
|---|---|
| Frases | `reabre <artefacto>` ("reabre el spec carrito", "reabre la tarea T-012", "reabre el plan carrito", "reabre el ADR 0003") y `reabre la capacidad <slug>`. |
| Efecto | Solo cambia la línea `estado:`. No cambia `rev` ni ninguna otra línea. No regenera nada. |
| Specs, tareas y planes | `revisado` pasa a `generado`. |
| ADR observado y revisado | Vuelve a `observado`. |
| ADR decidido | No se reabre. Se reconoce por la línea `**Elegida:` en su sección Decisión. El resolver se niega y remite a cambiar la decisión. |
| Por capacidad | Reabre el spec, el plan y las tareas con `spec: <slug>`. Las fundacionales no se tocan. |
| Ya regenerable | No se toca y se dice. |
| Derivados sin estado | El resolver se niega y nombra el agente que los regenera. |
| Aviso | El resumen lista el contenido de origen humano encontrado y, por tipo, si se conserva o se pierde al regenerar (§3). |
| Siguiente paso | El resumen termina con el prompt exacto del agente que regenera, con `solo la capacidad <slug>` cuando aplica. |
| Orquestador | Puerta nueva: si lo que hay que regenerar está `revisado`, el siguiente paso es el resolver, motivo `revisado`, con las dos salidas. |
| Regla perdida en `migration-tl-specs` | Se arregla aquí, en un commit aparte (§4). |

## 3. Qué conserva y qué pierde cada generador al regenerar

Leído de los prompts de los generadores. Es lo que el resolver avisa.

| Artefacto | Contenido de origen humano | Al regenerar |
|---|---|---|
| Spec | Respuestas a preguntas abiertas (`- Respuesta (...)`) | Se conservan, con el orden de las preguntas. |
| Spec | Mejoras `(aplicada ...)` y `(descartada ...)` | Se conservan con su número. |
| Spec | Reglas marcadas `(retirado ...)` | Se conservan: lo retirado se marca, no se borra. |
| Spec | Reglas nacidas de una decisión (`[decisión: ...]`) | Antes de este cambio, **no estaba garantizado**: el generador las habría contrastado con el código, que no las respalda. Con §4, se conservan. |
| Spec | Texto de reglas corregido a mano, contratos, flujos y demás secciones | **Se vuelve a derivar del código.** Una corrección que el código respalda reaparece; una que lo contradice se pierde. |
| Spec | Numeración `RN-n`, `CB-n`, `MJ-n` | Se conserva para lo que persiste; lo nuevo toma el siguiente número. |
| Plan de pruebas | Hallazgos `(resuelto: ...)` y numeración `H-n` | Se conservan. |
| Plan de pruebas | Casos añadidos o editados a mano; numeración `TC` | **Se pierden.** Los casos se vuelven a escribir desde el spec y se numeran desde 001. |
| Tarea | Id y nombre de archivo | Se conservan si la tarea sigue teniendo el mismo propósito. |
| Tarea | Dependencias, tamaño, criterios y notas editados | **Se pierden.** Se vuelven a derivar del spec y de los ADRs. |
| Tarea | `fase` y `prioridad` fijadas | **Se pierden**: el generador las deja vacías y `backlog.sh` deja de tratar la tarea como restricción. |
| ADR observado | Texto e `implicacion_migracion` corregidos | **Se vuelven a derivar del código.** |
| ADR decidido | La decisión | No se reabre. |

`rev` sube en 1 al regenerar, como siempre. Reabrir no lo cambia.

## 4. La pérdida que no debía ocurrir, y su arreglo

`migration-tl-specs` conservaba "el número de cada `RN-n` y `CB-n` cuyo contenido persiste" y marcaba como retirado "lo que ya no aplica", juzgándolo contra el código. Una regla nacida de una decisión del usuario (una mejora aplicada, una respuesta convertida en regla, una corrección que cambia el comportamiento) no tiene respaldo en el código por definición: al regenerar, el generador podía retirarla y volver a escribir como vigente la regla que la mejora había sustituido. Esa pérdida no se puede reconstruir desde el código.

Arreglo, con una instrucción general: al sobrescribir, las reglas cuya cita es `[decisión: ...]` y las marcadas `(retirado ...)` se copian tal cual y no se contrastan con el código.

Es una decisión aparte de la operación de reabrir y va en su propio commit, para poder revertirla sola. Se incluye aquí porque cambiar el bloque de `CLAUDE.md` ya invalida todas las instantáneas, de modo que arreglarlo ahora no añade coste de reconstrucción, y porque sin el arreglo el aviso veraz sería "se pierde", que haría peligroso reabrir cualquier spec con mejoras aplicadas.

No se cambian los demás generadores: lo que pierden tareas, planes y ADRs observados es contenido derivado, que se reconstruye desde el spec y el código. El aviso lo dice.

## 5. Orquestador

El procedimiento del siguiente paso gana una puerta: si lo que el candidato tendría que regenerar está `revisado`, su agente no lo sobrescribirá. El siguiente paso es `migration-tl-resolver`, motivo `revisado`, y ofrece las dos salidas con sus frases exactas: corregir el artefacto y declararlo al día con `registra las versiones de <artefacto>`, o `reabre <artefacto>` y regenerarlo.

## 6. Pruebas

- `test-resolver.sh`, casos 15 a 22: reabrir un spec (solo cambia `estado:`; el `rev` no cambia; el resumen trae el prompt con alcance y menciona la respuesta y la mejora aplicada); ADR decidido (se niega); ADR observado revisado (vuelve a `observado`); derivado (se niega y nombra el agente); algo ya `generado`; y una capacidad entera.
- `test-reabrir.sh` (nuevo), el recorrido: aplicar una mejora y responder una pregunta en un spec, reabrirlo, regenerarlo con alcance; el `rev` sube en 1 y la regla de la decisión, la marca de la mejora y la respuesta siguen ahí.
- `test-orchestrator.sh`: con un plan `revisado` y atrasado, `agente` es el resolver, `motivo` incluye `revisado`, y el siguiente paso trae las dos frases.

## 7. Fuera de alcance

- Identificador explícito para las preguntas abiertas.
- Que tareas, planes y ADRs observados conserven ediciones manuales al regenerarse.
