# Política de paridad por defecto: diseño

Fecha: 2026-10-01
Estado: pendiente de revisión escrita
Modifica: `docs/specs/2026-09-29-migration-agents-v2-design.md` (v2). Todo lo que este documento no cambia sigue rigiendo según v2 y v1.

## 1. Propósito

El flujo genera más de lo que una persona puede revisar. Sobre el fixture, medido en la instantánea `pm` previa a este cambio (copia en `.work/baseline-paridad/`):

| Capacidad | Preguntas abiertas | Casos pendientes en QA |
|---|---|---|
| autenticacion | 15 | 15 |
| carrito | 14 | 14 |
| catalogo-productos | 8 | 8 |
| Total | 37 | 37 |

Además, 14 de las 20 tareas llevan notas de "paridad provisional" en sus criterios (39 menciones), y 2 están bloqueadas por preguntas abiertas en `bloqueada_por`.

Casi ninguna de esas preguntas es una incógnita. `bff/src/routes/cart.ts` tiene 43 líneas y el código determina su comportamiento; las 14 preguntas de carrito son de la forma "¿se mantiene 204 o debe responderse 404?" o "¿deben expirar los carritos inactivos?". Preguntan si conviene mejorar algo, no qué hace el sistema. Cada una genera aguas abajo un caso pendiente y una nota en las tareas.

**Criterio de éxito:** bajo la política por defecto, "Preguntas abiertas" contiene solo lo que el código no permite determinar; lo mejorable queda en una lista aparte que no bloquea tareas ni genera casos pendientes; el usuario puede adoptar una mejora con una orden al resolver; y la fidelidad del spec no empeora.

## 2. Decisiones

| Tema | Decisión |
|---|---|
| Política | Campo `politica:` en el frontmatter de `migration/README.md`. Único valor válido: `paridad`. |
| Significado | El destino reproduce el comportamiento observado en el origen, salvo decisión explícita en contra (una mejora aplicada o un ADR). |
| Otros valores | No existen. Campo ausente o vacío se trata como `paridad`. Un valor distinto detiene al agente con un mensaje. No se inventan políticas que no se vayan a probar. |
| Mejoras | Sección nueva `## 13. Posibles mejoras` en cada spec, con entradas `MJ-n:`. Las secciones 1 a 12 conservan su número. |
| Efecto de una mejora | Ninguno hasta que el usuario la aplica: no bloquea tareas, no genera casos pendientes y no cuenta como pendiente de revisión. |
| Aplicar o descartar | Operaciones nuevas de `migration-tl-resolver`. |

## 3. Qué va en cada sección

Regla única, escrita en el bloque de `CLAUDE.md` y en `migration-tl-specs`:

1. **Lo que el código determina** va como hecho en las secciones 4 a 8 (flujos, contratos, modelos, `RN-n`, `CB-n`), sea o no deseable. Esto no cambia.
2. **`## 12. Preguntas abiertas`**: solo lo que no se pudo determinar leyendo el código de los repositorios indexados. Tres casos:
   - una rama o llamada que no se pudo rastrear hasta el final;
   - un comportamiento que depende de un sistema externo cuyo código no está visible (por ejemplo, qué responde el servicio de identidad ante un caso no cubierto por el adaptador);
   - un valor cuyo origen o significado no consta (una constante sin explicación que no se sabe si es requisito o accidente y de la que depende otra cosa).
3. **`## 13. Posibles mejoras`**: comportamiento que el código sí determina pero que parece mejorable, inconsistente o sospechoso. Toda pregunta de la forma "¿se mantiene X o debería ser Y?" es una mejora, no una pregunta.
4. **Ni pregunta ni mejora**: lo que ya cubre un ADR propuesto (por ejemplo, si el carrito debe persistir cuando hay un ADR sobre persistencia). El spec cita el ADR en la sección 10 y no lo repite.

Prueba rápida para clasificar: si la respuesta a "¿qué hace hoy el sistema?" está en el código, no es una pregunta abierta.

Ejemplos con el fixture:

| Texto | Va en |
|---|---|
| Quitar una línea que no existe responde 204 | `CB-n` (hecho) y `MJ-n` (¿404?) |
| Un `productId` vacío responde 404 y no 400 | `CB-n` y `MJ-n` |
| El tope de 10 se aplica sin avisar | `RN-n` y `MJ-n` |
| Un producto oculto responde 200 sin cuerpo | `CB-n` y `MJ-n` |
| Los carritos no expiran | `RN-n` o `CB-n` y `MJ-n` |
| Qué devuelve el servicio de identidad si la cuenta está bloqueada | Pregunta abierta: su código no está en los repos |
| Si el carrito debe persistir tras un reinicio | ADR propuesto de persistencia; no se repite |

## 4. Formato de las mejoras

En la sección 13, una por línea, al inicio de línea:

```
MJ-1: responder 404 al quitar una línea que no existe. Comportamiento actual: CB-7.
MJ-2: informar al cliente cuando la cantidad se recorta a 10. Comportamiento actual: RN-6.
```

- Cada entrada cita al menos una `RN-n` o `CB-n` del mismo spec, que describe el comportamiento actual. Si no existe esa regla, el hecho falta en el spec y hay que escribirlo.
- Numeración `MJ-n` propia de cada spec, nunca renumerada, con las mismas reglas que `RN-n` y `CB-n`.
- Si no hay mejoras, la sección dice "Ninguna".
- Estados, al final de la línea: `(aplicada AAAA-MM-DD: RN-18)` o `(descartada AAAA-MM-DD)`. Sin marca, la mejora está sin decidir.

## 5. Cambios por agente

### 5.1 `migration-indexer`

- Plantilla de `migration/README.md`: frontmatter con `politica: paridad` tras `excluir: []`.
- README existente sin `politica:`: añade `politica: paridad`, igual que ya hace con `excluir: []`.
- Plantilla `spec.md`: sección `## 13. Posibles mejoras` tras la 12, con comentario del formato. El comentario de la sección 12 se reescribe con la regla de §3.
- Bloque de `CLAUDE.md`: convención de la política, identificador `MJ-n`, regla de §3 resumida, y la frase de prompt `aplica la mejora MJ-n`.
- Las plantillas existentes no se sobrescriben (regla de v1). Un workspace anterior conserva su `spec.md` sin sección 13; `migration-tl-specs` escribe la sección 13 igualmente (§5.2).

### 5.2 `migration-tl-specs`

- Lee `politica:`; ausente o vacío es `paridad`; otro valor detiene al agente: "Política desconocida `X`. La única política soportada es `paridad`."
- Aplica la regla de §3 con los ejemplos de ambos lados.
- Escribe las trece secciones aunque la plantilla del workspace tenga doce.
- Al sobrescribir un spec existente conserva la numeración `MJ-n` y sus marcas de estado, como ya hace con `RN-n`, `CB-n` y las respuestas a preguntas.
- Resumen final: cuenta preguntas abiertas y mejoras por spec.

### 5.3 `migration-tl-tasks`

- Las mejoras sin aplicar no existen para las tareas: no van en `bloqueada_por` ni en los criterios.
- Los criterios de aceptación citan `RN-n` y `CB-n` y afirman el comportamiento actual. La fórmula "pregunta abierta n, paridad provisional" desaparece para lo que es política; `PA:<slug>:<n>` queda solo para preguntas abiertas reales cuya respuesta cambia qué se construye.
- Una mejora aplicada ya es una `RN-n` o `CB-n` nueva y se trata como tal.

### 5.4 `migration-qa`

- Los casos afirman el comportamiento actual descrito por `RN-n` y `CB-n`.
- "Casos pendientes de definición" se genera solo desde la sección 12. La sección 13 no produce casos, pendientes ni hallazgos.
- `_cobertura.md` no cuenta mejoras.

### 5.5 `migration-tl-resolver`

Operaciones nuevas:

| Operación | Qué hace |
|---|---|
| Aplicar una mejora ("aplica la mejora MJ-2 del spec carrito") | Añade la `RN-n` o `CB-n` siguiente con el comportamiento nuevo; marca la regla que describía el comportamiento actual con `(retirado AAAA-MM-DD: sustituida por RN-n)`; marca la mejora `(aplicada AAAA-MM-DD: RN-n)`; ajusta contratos o flujos del spec si la mejora los cambia; marca el spec `revisado`; lista tareas y casos que citan la regla retirada y recomienda repetir `migration-tl-tasks` y `migration-qa` para esa capacidad. |
| Descartar una mejora ("descarta la mejora MJ-3 del spec carrito") | Marca `(descartada AAAA-MM-DD)`. No toca nada más. |
| Reclasificar ("la pregunta 2 del spec X es una mejora") | Mueve el texto a la sección 13 con el siguiente `MJ-n`; en la sección 12 deja la línea marcada `(retirado AAAA-MM-DD: movida a MJ-n)` porque no se borra (desde 2026-10-05, cada pregunta lleva su id `PA-n`) `PA`; quita `PA:<slug>:<n>` de `bloqueada_por`. |
| Fijar la política | Escribe `politica: paridad`. Rechaza cualquier otro valor. |

Si el prompt pide aplicar una mejora con un comportamiento distinto del que la mejora describe, se aplica lo que dice el prompt.

### 5.6 `migration-orchestrator`

- Las mejoras sin decidir no aparecen en "Pendiente de revisión" ni alteran el siguiente paso.
- En "Estado" añade una línea informativa: cuántas mejoras sin decidir hay por capacidad y que no bloquean.

### 5.7 `migration-pm`

- "Riesgos" del backlog: una línea con el total de mejoras sin decidir por capacidad y la aclaración de que el backlog asume paridad. No las lista ni las convierte en bloqueos.

### 5.8 `migration-analyst`, `migration-tl-adrs`

Sin cambios.

## 6. Verificadores y pruebas

**Lectura de la sección 12.** Hoy `verify-qa.sh`, `verify-tl-tasks.sh`, `verify-tl-specs.sh` y `test-resolver.sh` leen "todo lo que sigue a `## 12.`" hasta el final del archivo. Con la sección 13 detrás, las entradas `MJ-n:` no empiezan por guion y no se contarían como preguntas, pero cualquier viñeta posterior sí. Se cambia en los cuatro a "desde `## 12.` hasta el siguiente `## `".

**`verify-tl-specs.sh`:**
- Exige las secciones 1 a 13.
- Cada línea `MJ-n:` cita una `RN-n` o `CB-n` que existe en el mismo spec.
- Ninguna pregunta abierta contiene las fórmulas de mejora: "se mantiene", "se conserva", "debe seguir", "en lugar de".
- Tope de preguntas abiertas por spec: `MAX_PREGUNTAS`, por defecto 5.
- `REQUIRE_AMBIGUEDAD=1`: el caso del producto oculto (200 vacío frente a 404) es un comportamiento determinado por el código, así que debe aparecer como hecho en una `RN-n` o `CB-n` y como mejora en alguna `MJ-n`, y no en las preguntas abiertas.

**`verify-tl-tasks.sh`:** ya rechaza elementos desconocidos en `bloqueada_por`, lo que cubre `MJ-n`. Se añade que ningún criterio de aceptación diga "paridad provisional".

**`verify-qa.sh`:** se elimina la exigencia de al menos un caso pendiente en el fixture (bajo paridad puede no haber preguntas). Se añade que la sección de pendientes no mencione `MJ-`, y que el número de pendientes no supere al de preguntas abiertas del spec.

**`verify-indexer.sh`:** README con `politica:`; plantilla de spec con sección 13; bloque de `CLAUDE.md` con `MJ-n` y `politica`.

**`test-verifiers.sh`** (sin agentes): el workspace sintético gana sección 13 y `politica`. Casos nuevos: una viñeta en la sección 13 no cuenta como pregunta ni valida un `PA`; spec sin sección 13 falla; `MJ-n` que cita una regla inexistente falla; pregunta con fórmula de mejora falla; más de `MAX_PREGUNTAS` falla.

**`test-prompts.sh`** (sin agentes): presencia en los prompts de la política, la regla de clasificación, la conservación de `MJ-n` al regenerar, la exclusión de mejoras en tareas y QA, y las operaciones del resolver.

**`test-resolver.sh`** (con agentes): aplicar una mejora (regla nueva, regla anterior retirada, `MJ` marcada aplicada, spec `revisado`, sin renumerar); descartar una mejora; rechazar una política distinta de `paridad`.

**`test-orchestrator.sh`** (con agentes): "Pendiente de revisión" no menciona `MJ-`.

**`test-indexer-claude.sh`** (con agentes): un README existente sin `politica:` la recibe.

## 7. Compatibilidad

- Workspaces existentes: al repetir `migration-indexer` el README recibe `politica: paridad`. La plantilla `spec.md` no se sobrescribe. Los specs `generado` se reclasifican al repetir `migration-tl-specs`; los `revisado` no se tocan y conservan sus preguntas, que el usuario puede reclasificar con el resolver.
- Las posiciones `PA:<slug>:<n>` de specs `revisado` no cambian. En specs regenerados, las preguntas que pasan a mejoras dejan de existir como preguntas; por eso tras `migration-tl-specs` hay que repetir `migration-tl-tasks` y `migration-qa`, como ya indica el tutorial.

## 8. Documentación

`docs/tutorial.md`: qué es la política de paridad, la diferencia entre pregunta abierta y mejora en el paso 4, cómo aplicar o descartar una mejora, y una fila en "Qué repetir después de un cambio". `README.md`: `politica:` y `MJ-n` en convenciones.

## 9. Medición

Tras regenerar el fixture se comparan con `.work/baseline-paridad/`: preguntas abiertas y mejoras por spec, casos pendientes por plan, tareas con `PA:` en `bloqueada_por` y menciones de "paridad provisional". Se revisa a mano la clasificación de las preguntas que queden y de las mejoras, y se informa de las mal clasificadas.

Fidelidad: el spec de carrito regenerado debe seguir recogiendo como `RN-n` o `CB-n` que un JSON mal formado responde 500, que un `productId` vacío responde 404 y que el tope de 10 se aplica sin avisar.

## 10. Fuera de alcance

- Valores de política distintos de `paridad`.
- Un archivo aparte de mejoras por capacidad o un informe global de mejoras.
- Reclasificación automática de specs `revisado`.
- Reducir el número de casos de prueba o de reglas; este cambio solo ataca preguntas, pendientes y notas de paridad.
