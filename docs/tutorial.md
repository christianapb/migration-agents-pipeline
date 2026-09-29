# Tutorial: usar los agentes de migración en cualquier repositorio

Este tutorial explica cómo generar, a partir del código de un proyecto, la documentación necesaria para reimplementarlo en otro lenguaje: índices, ADRs, specs por capacidad, tareas, planes de prueba y backlog. Los agentes no migran código. Producen los documentos con los que un equipo, o un agente de desarrollo, puede reimplementar sin abrir el código original.

Idea central: **se avanza por etapas y se revisa entre cada una**. Cada etapa lee lo que dejó la anterior. Si revisas y decides en orden, cada artefacto se genera una sola vez y no hay retrabajo.

## Vocabulario

Dos palabras se parecen y significan cosas distintas.

- **Etapa**: uno de los cuatro pasos internos del tech lead. Etapa 1 mapa de capacidades, etapa 2 ADRs, etapa 3 specs, etapa 4 tareas.
- **Fase**: agrupación del backlog que asigna el PM al final. Aparece como el campo `fase` de las tareas y como hitos en `backlog.md`. Al principio no existe.

Si pides al tech lead "la fase 4", puede responder que no existe ninguna. Usa siempre "etapa".

## 1. Instalación, una sola vez

Requisitos: Claude Code, Git y, en Windows, Git Bash.

```bash
git clone https://github.com/christianapb/migration-agents-pipeline.git
cd migration-agents-pipeline
bash scripts/install.sh
```

El script copia los cuatro agentes a `~/.claude/agents/`. Abre una sesión nueva de Claude Code después de instalar o de actualizar los agentes, porque se cargan al iniciar. Si no quieres instalarlos globalmente, copia `agents/*.md` a `.claude/agents/` dentro de la carpeta padre del proyecto.

## 2. Preparar la carpeta

Crea una carpeta padre y deja dentro los repositorios como subcarpetas directas. Los nombres no importan y puede haber dos o más.

```
mi-proyecto/
├── frontend/
└── bff/
```

Abre Claude Code en `mi-proyecto/`, **no dentro de un repo**. Si lo abres dentro de uno, el indexador se detiene con un mensaje y no escribe nada.

Antes de empezar conviene hacer `git init` en `mi-proyecto/` o crear una rama, porque `migration/` se llenará de archivos que querrás versionar. Haz commit de `migration/` antes de cada corrida de agente: los agentes sobrescriben lo que no está `revisado` y el commit te permite ver qué cambió y recuperar ediciones.

## 3. Cómo se marca lo que ya validaste

Todo artefacto generado tiene un campo `estado` en su cabecera.

| Estado | Significado |
|---|---|
| `generado` | Lo escribió un agente. Se sobrescribe si vuelves a correr. |
| `revisado` | Lo validaste tú. Ningún agente lo vuelve a tocar. |
| `observado` | ADR que documenta lo que el código ya hace. |
| `propuesto` | ADR con una decisión que la migración obliga a tomar. Bloquea tareas hasta que lo resuelvas. |

Regla práctica: **edita a mano solo los archivos con `estado` y márcalos `revisado` cuando terminen**. Estos cuatro son derivados y se regeneran, así que no los edites: `index.md`, `_capacidades.md`, `_cobertura.md` y `backlog.md`. Hay una excepción documentada en la etapa 1.

## 4. Paso a paso

### Paso 0: indexar

```
Usa el subagente migration-indexer
```

Deja un `index.md` en la raíz de cada repo y crea `migration/` con un README y cinco plantillas.

Qué hacer:
- **`<repo>/index.md`**: solo lectura. Comprueba que no falten archivos de código, que no sobren archivos basura y que los resúmenes sean concretos. Si está mal, vuelve a correr el indexador. Un índice pobre degrada todo lo que viene después. Decide si lo versionas.
- **`migration/README.md`**: escribe el lenguaje en `destino:`, por ejemplo `destino: Kotlin`. Es lo único que debes tocar ahí.
- **`migration/templates/*.md`**: opcional. Si quieres otro formato de spec, tarea o plan, edita la plantilla y las siguientes corridas la respetan.

### Paso 1: mapa de capacidades (etapa 1 del tech lead)

```
Usa el subagente migration-techlead con destino Kotlin, solo la etapa 1 (mapa de capacidades)
```

Escribe `migration/specs/_capacidades.md`, una tabla con cada capacidad funcional, los repos que toca y sus archivos principales. Este archivo define cuántos specs habrá, así que **es el mejor momento para decidir qué capacidades no quieres**.

Qué hacer:
- Comprueba que cada capacidad sea algo que un usuario o sistema puede hacer de principio a fin, y que no falte ninguna.
- Para **quitar** una capacidad, borra su fila del archivo a mano. Esta es la excepción a la regla de no editar derivados: las etapas 3 y 4 leen el archivo tal como esté, así que la capacidad no vuelve **mientras no repitas la etapa 1** ni corras al tech lead sin alcance.
- Para unir o dividir capacidades, vuelve a correr la etapa 1 indicándolo en el prompt, por ejemplo "agrupa autenticación y sesión en una sola capacidad". Esa indicación por prompt no está probada.

### Paso 2: ADRs (etapa 2)

```
Usa el subagente migration-techlead con destino Kotlin, solo la etapa 2 (ADRs)
```

Escribe los ADRs en `migration/adr/`, de dos tipos.

**ADRs observados.** Documentan decisiones que el código ya tomó, con evidencia en rutas de archivo. Cada uno trae una implicación para la migración: conservar, reemplazar o reevaluar. Léelos, corrige el texto o la implicación si no coinciden con lo que sabes del sistema y cambia `estado:` a `revisado`.

**ADRs propuestos.** Son decisiones que el código origen no responde, como el framework destino, la herramienta de build, la estrategia de tests o la librería JWT. Traen opciones numeradas con ventajas, desventajas y una recomendación. El agente no decide. Tú sí:

1. Escribe la elección en la sección Decisión como una frase completa que **nombre la tecnología**, no solo el número. El tech lead la copia a las notas de las tareas y no debe adivinar qué era la "Opción 2".
2. Borra la línea "Recomendación:" del agente, para que no haya dos señales en conflicto.
3. Deja las alternativas descartadas con una frase de por qué. Conserva su numeración original.
4. Actualiza la sección "Implicación para la migración": ya no habla de tareas bloqueadas, sino de lo que implica la decisión.
5. Cambia `estado: propuesto` por `estado: revisado`. Deja `implicacion_migracion` vacío, que es lo normal en propuestos.
6. No borres los títulos `## Evidencia` ni `## Implicación para la migración`.

Ejemplo de la sección Decisión ya resuelta:

```markdown
## Decisión

**Elegida: Opción 2, Ktor.** El BFF se implementa con Ktor sobre Netty.

Motivo: el equipo ya conoce corrutinas y el BFF actual es pequeño, así que no se justifica el peso de Spring.

Alternativas descartadas:
1. Spring Boot. Descartada por tamaño y tiempo de arranque para un servicio de este alcance.
3. http4k. Descartada por menor conocimiento del equipo.
```

Los ADRs propuestos suelen encadenarse. La recomendación para la librería JWT, por ejemplo, depende de qué framework elijas. Resuélvelos en orden y actualiza los que dependan de otro.

Si un ADR trata solo de una capacidad que decidiste quitar en el paso 1, elimínalo. Los ADRs no se borran solos.

### Paso 3: specs (etapa 3)

```
Usa el subagente migration-techlead con destino Kotlin, solo la etapa 3 (specs)
```

Escribe un spec por capacidad en `migration/specs/<capacidad>.md`, con doce secciones fijas: resumen, actores, alcance por repo, flujos, contratos de API, modelos de datos, reglas de negocio, casos borde, dependencias externas, ADRs relacionados, evidencia y preguntas abiertas. No contiene código del lenguaje origen. Las reglas llevan ids `RN-n` y los casos borde `CB-n`, y las tareas y los planes de prueba los citan.

Qué hacer:
- **Valida el contenido contra lo que sabes del sistema.** Es la revisión más importante del flujo. Un error aquí llega a las tareas y a los planes de prueba como si fuera un requisito seguro.
- **Responde las preguntas abiertas de la sección 12** que cambian el comportamiento, escribiendo la respuesta debajo de la pregunta. **No borres la línea**: las tareas la citan por su posición (`PA:carrito:3`).
- **No renumeres `RN-n` ni `CB-n`** y mantén el formato `RN-n:` y `CB-n:` al inicio de línea. Si lo cambias, se rompe la trazabilidad y el verificador de cobertura falla.
- Cuando el spec esté validado, cambia `estado:` a `revisado`.

### Paso 4: tareas (etapa 4)

```
Usa el subagente migration-techlead con destino Kotlin, solo la etapa 4 (tareas)
```

Esta es la etapa que hace que ir por partes ahorre trabajo: las tareas se generan **una sola vez**, con el framework ya nombrado en sus notas y solo los bloqueos que de verdad quedan. Escribe `migration/tasks/T-NNN-<slug>.md`, primero las fundacionales (estructura, build, CI) y luego las de cada capacidad, con dependencias, tamaño, criterios de aceptación y un campo `bloqueada_por`.

`bloqueada_por` lista solo los ADRs propuestos sin revisar y las preguntas abiertas cuya respuesta cambia qué se construye. Una pregunta que se resuelve provisionalmente reproduciendo el comportamiento observado va en los criterios de aceptación, no en el bloqueo.

Qué hacer:
- Revisa los criterios de aceptación y las dependencias. Corrige lo que no cuadre y marca `revisado` las tareas validadas.
- No toques `fase` ni `prioridad`: son del PM.
- Comprueba desde la carpeta padre:

```bash
grep -l "^bloqueada_por: \[.\+\]" migration/tasks/*.md
grep -rn "<id-del-adr>" migration/tasks/*.md
```

La primera lista lo que sigue bloqueado y debería ser poco. La segunda debería mostrar el id de tus ADRs aceptados solo en el campo `adrs`, no en `bloqueada_por`.

### Paso 5: planes de prueba (QA)

Antes de correr QA, revisa esta lista. La mayoría no es obligatoria para que el agente corra; cambia la calidad de lo que produce.

| Antes de correr QA | Si no lo haces |
|---|---|
| Que existan `_capacidades.md` y al menos un spec | QA se detiene con un mensaje y no escribe nada. |
| Que exista `migration/templates/test-plan.md` | El agente no define qué hace sin ella y puede improvisar un formato. |
| Haber quitado las capacidades que no quieres y borrado su plan de prueba | QA escribe un plan por cada spec que exista, y un plan huérfano queda en la carpeta sin aviso. |
| Haber validado los specs contra el sistema real | Un error del spec pasa a los casos como resultado esperado afirmado con seguridad, y el equipo probaría el Kotlin contra un comportamiento incorrecto. |
| Haber respondido las preguntas abiertas que cambian el comportamiento | Quedan como casos pendientes sin resultado esperado y los casos borde relacionados salen como huecos en `_cobertura.md`. Habrá que repetir QA. |
| Conservar el formato y la numeración `RN-n:` y `CB-n:` | Se pierde la trazabilidad y quedan requisitos sin caso de prueba. |
| Tener las tareas al día | Cada caso cita ids de tareas. Si luego cambian o se borran, las referencias quedan mal. |
| Haber marcado `revisado` los specs validados | No afecta esta corrida, pero si el tech lead vuelve a correr, regenera el spec y el plan queda desfasado sin aviso. |
| Haber hecho commit de `migration/` | QA sobrescribe los planes no `revisado` y no podrás ver qué cambió. |

Los ADRs propuestos no hace falta resolverlos antes de QA, porque QA no los lee. Lo que sí importa es que las decisiones que cambian el comportamiento estén reflejadas en el spec.

```
Usa el subagente migration-qa
```

Escribe `migration/test-plans/<capacidad>.md` (mismo nombre que el spec) con casos en formato Dado/Cuando/Entonces, y `_cobertura.md`. Puedes acotar: `Usa el subagente migration-qa, solo la capacidad carrito`.

Qué hacer:
- Lee la sección "Hallazgos para el tech lead" de cada plan y `_cobertura.md`. Si señalan una ambigüedad real, corrige el spec, márcalo `revisado` y repite QA para esa capacidad.
- Los casos pendientes de definición se resuelven respondiendo la pregunta abierta en el spec y repitiendo QA.
- Si editas un plan a mano, márcalo `revisado` antes de volver a correr QA, o se sobrescribe.

### Paso 6: backlog (PM)

```
Usa el subagente migration-pm
```

Construye el grafo de dependencias, prioriza con un criterio fijo, agrupa en hitos y escribe `migration/backlog.md` con fases, bloqueos y riesgos. Rellena `fase` y `prioridad` en cada tarea y actualiza `migration/README.md`.

Si detecta un ciclo o una dependencia a una tarea que no existe, **no escribe nada** y te dice qué tareas corregir en `depende_de`. Arréglalo y repite.

Qué hacer:
- Lee los hitos, los bloqueos y los riesgos. `backlog.md` es solo lectura: si no te gusta el orden, marca `revisado` las tareas afectadas, ajusta su `fase` y `prioridad` a mano y repite el PM, que respeta esos valores.
- Resuelve los bloqueos que enumera antes de empezar el Hito 0.

### Resultado

La carpeta `migration/` es lo que entregas al equipo de implementación. Empiezan por el Hito 0, con la sección "Cómo empezar a implementar" de `migration/README.md` como guía.

## 5. Qué hacer en cada archivo

| Archivo | Acción |
|---|---|
| `<repo>/index.md` | Leer. Si está mal, repetir el indexador. No editar. |
| `migration/README.md` | Rellenar `destino:`. Lo demás lo actualiza el PM. |
| `migration/templates/*.md` | Opcional. Editar para cambiar formatos. |
| `specs/_capacidades.md` | Leer. Tras la etapa 1 se pueden borrar filas a mano si no se repite la etapa 1. |
| `adr/*.md` observados | Confirmar, corregir y marcar `revisado`. |
| `adr/*.md` propuestos | Decidir como se explicó y marcar `revisado`. |
| `specs/<capacidad>.md` | Validar, responder preguntas sin borrar líneas y marcar `revisado`. |
| `tasks/T-*.md` | Revisar criterios y dependencias y marcar `revisado`. No tocar `fase` ni `prioridad`. |
| `test-plans/<capacidad>.md` | Leer hallazgos y pendientes. Marcar `revisado` si se edita. |
| `test-plans/_cobertura.md` | Solo lectura. |
| `backlog.md` | Solo lectura. Resolver los bloqueos que lista. |

## 6. Si algo cambia después

Cuánto hay que repetir depende de qué cambies.

| Cambiaste | Repite |
|---|---|
| Un ADR propuesto (decisión) | La etapa 4 del tech lead y luego el PM. |
| Un spec o respondiste preguntas abiertas | La etapa 4 para esa capacidad (`solo la capacidad X` ejecuta las etapas 3 y 4 y respeta lo `revisado`), luego QA y PM. |
| Una tarea o sus dependencias | El PM. |
| Solo un plan de prueba | Nada, márcalo `revisado`. |

Regla general: si el tech lead regenera specs o tareas, QA y PM quedan desactualizados y conviene repetirlos.

### Quitar una capacidad cuando ya hay specs y tareas

Lo ideal es quitarla en el paso 1. Si ya existen los demás artefactos:

1. Borra a mano `specs/<capacidad>.md`, `test-plans/<capacidad>.md` y todas las tareas cuyo campo `spec` sea esa capacidad.
2. Borra los ADRs propuestos que trataban solo de ella.
3. Quita su fila de `specs/_capacidades.md`.
4. Busca restos desde la carpeta padre y corrígelos:

```bash
grep -rn "<capacidad>" migration/ --include="*.md"
grep -rn "<id-del-adr>" migration/ --include="*.md"
```

Revisa los specs de otras capacidades que la mencionen y los campos `adrs` y `bloqueada_por` que citen el ADR borrado. Si otra capacidad dependía de esa decisión, no debiste borrarla.

5. Corre QA, que regenera `_cobertura.md`, y luego el PM, que actúa como comprobación: si alguna tarea sigue apuntando a una tarea borrada, se detiene y te dice cuál.

No renumeres los ids que quedan con huecos. Recuerda que la capacidad reaparece si alguien corre al tech lead **sin alcance** o repite la etapa 1.

### Trabajo por alcance

```
Usa el subagente migration-techlead con destino Kotlin, solo la capacidad carrito
Usa el subagente migration-qa, solo la capacidad carrito
```

El nombre de la capacidad es el archivo en `migration/specs/` sin extensión. Si pasas uno que no existe, el agente lista los disponibles y no toca nada.

## 7. Si algo falla

| Mensaje o síntoma | Causa y solución |
|---|---|
| No encontré repositorios | Abriste Claude Code dentro de un repo o en una carpeta sin repos. Ábrelo en la carpeta padre. |
| Falta `<archivo>`, ejecuta primero migration-indexer | Te saltaste un paso. Corre el agente anterior. |
| No sé a qué lenguaje se migra | Falta el destino. Escríbelo en el prompt o en `destino:` del README. |
| El tech lead dice que no existe la "fase 4" | Interpretó fases de backlog. Pide "la cuarta etapa" y empieza el prompt con "Usa el subagente migration-techlead". |
| El tech lead pide correr una etapa antes | Pediste la etapa 3 sin mapa de capacidades, o la 4 sin specs. Sigue el orden. |
| El PM lista un ciclo o una tarea que no existe | Corrige `depende_de` en las tareas que menciona y repite. |
| Un `index.md` termina con "Índice incompleto" | El repo era muy grande y el agente se quedó sin contexto. Vuelve a correr el indexador. |
| Casi todas las tareas siguen bloqueadas | Quedan ADRs propuestos sin revisar, o repetiste la etapa 4 antes de marcarlos `revisado`. |
| Una capacidad que borraste reaparece | Se repitió la etapa 1 o se corrió el tech lead sin alcance. Quítala del mapa de nuevo y sigue por etapas. |

## 8. Advertencias

- Los agentes leen el código pero nunca lo ejecutan ni instalan nada. Solo escriben `index.md` dentro de los repos.
- El flujo se probó sobre un proyecto de ejemplo, no sobre un repositorio real. Revisa con especial cuidado la primera vez el índice, el mapa de capacidades y los specs.
- Las etapas por separado, el aviso cuando falta el insumo de la etapa anterior y el uso de "fase" como sinónimo de etapa se probaron sobre el proyecto de ejemplo. No se ha probado pedir por prompt que el tech lead agrupe o divida capacidades.
