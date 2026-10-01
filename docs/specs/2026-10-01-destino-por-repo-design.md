# Destino por repositorio: diseño

Fecha: 2026-10-01
Estado: pendiente de revisión escrita
Modifica: `docs/specs/2026-09-29-migration-agents-v2-design.md` (v2) y se integra con la política de paridad y con la evidencia por regla y el auditor (ambos del 2026-10-01). Lo que este documento no cambia sigue rigiendo según esos.

## 1. Propósito

El destino es hoy un único valor para todo el proyecto. En el fixture, con destino Kotlin, el flujo propone llevar también el frontend React a Kotlin: 5 ADRs propuestos, uno de ellos entero sobre la tecnología del frontend, y 26 tareas, 9 con `repo_destino: frontend`. Nadie pidió migrar el frontend; el flujo no sabe expresar otra cosa. El caso habitual es migrar el backend y conservar el frontend, o llevar cada repositorio a un lenguaje distinto.

**Criterio de éxito:** el usuario fija un destino por repositorio, incluido "se conserva"; para un repositorio conservado no se proponen decisiones sobre su tecnología ni se generan tareas de reimplementación; los specs siguen describiendo su comportamiento porque es el contrato que el repositorio migrado debe respetar; y un valor único sigue funcionando igual que hoy.

## 2. Decisiones

| Tema | Decisión |
|---|---|
| Formato | `destino:` admite un valor simple (aplica a todos los repositorios) o un mapa en una sola línea: `destino: {bff: Kotlin, frontend: conservar}`. |
| Palabra reservada | `conservar`: el repositorio se queda en su stack actual. |
| Mapa incompleto | Un repositorio detectado que no está en el mapa, o una clave que no es un repositorio detectado, es un error: el agente se detiene y lo dice. No hay valor por defecto. |
| Origen del valor | El README manda. El destino del prompt solo se usa si el README no lo tiene. Si ambos existen y difieren, el agente se detiene. |
| Frase de prompt | Se mantiene `con destino <lenguaje>`. Nueva, por repositorio: `con destino <repo>=<lenguaje>, <repo>=conservar`. |
| ADRs propuestos | Campo nuevo `repos:` en el frontmatter de todo ADR. Ningún ADR propuesto afecta a un repositorio conservado. |
| Tareas | Ninguna tarea de reimplementación en un repositorio conservado. Caben tareas de adaptación, marcadas `tipo: adaptacion`. |
| Capacidad que vive entera en repositorios conservados | Fuera de alcance: sigue en el mapa de capacidades, pero no se le escribe spec, tareas ni plan. |
| Pruebas con agentes | La cadena principal sigue con destino único. Una prueba dirigida cubre el mapa. |

### 2.1 Por qué el README manda sobre el prompt

Hoy el prompt tiene prioridad. Con un mapa, un `con destino Kotlin` escrito por costumbre en el prompt convertiría de golpe un repositorio conservado en uno a migrar. Con el README como fuente, el destino se fija una vez y los prompts del orquestador dejan de repetirlo. Si el README está vacío, el prompt sigue funcionando como hoy.

### 2.2 Por qué una capacidad entera en repositorios conservados queda fuera de alcance

Un spec de una capacidad compartida describe también la parte conservada, porque ese comportamiento es el contrato que la parte migrada debe respetar. Si ninguna parte se migra, no hay contrato que proteger ni nada que reimplementar: el spec solo sería volumen que revisar. La capacidad sigue visible en `_capacidades.md`, y `migration-tl-specs` informa de que la omitió y por qué. Si el usuario la quiere documentada igualmente, puede pedirla con `solo la capacidad X`.

### 2.3 Por qué la cadena principal de pruebas no cambia

Cambiarla al mapa dejaría el fixture más representativo, pero obligaría a una segunda cadena para demostrar que el valor simple sigue igual. Con la cadena principal en valor simple, esa equivalencia la comprueban todos los verificadores actuales sin trabajo adicional, y el mapa se prueba con dos corridas dirigidas (`migration-tl-adrs` y `migration-tl-tasks`) sobre la instantánea de specs. Cuesta menos cuota y no altera las demás pruebas.

## 3. Formato y lectura del destino

```yaml
destino: Kotlin                                  # todos los repositorios
destino: {bff: Kotlin, frontend: conservar}      # por repositorio
destino: {api: Kotlin, web: TypeScript, legacy: conservar}
```

- Una sola línea, como `excluir: []`, porque los verificadores leen el frontmatter con sed y grep.
- Las claves son los nombres de las carpetas de los repositorios, tal como aparecen en el índice general.
- Regla común de lectura, escrita en el bloque de `CLAUDE.md` y aplicada por todo agente que use el destino:
  1. Lee `destino:` del README. Vacío: usa el del prompt, si viene; si no, se detiene.
  2. Valor simple: ese lenguaje para todos los repositorios detectados.
  3. Mapa: cada repositorio detectado debe tener entrada, y cada clave debe ser un repositorio detectado. Si no, se detiene: "El mapa de destino no cubre `<repo>`" o "`<clave>` no es un repositorio detectado".
  4. Si el prompt trae un destino distinto del README, se detiene y pide corregir el README con el resolver.
- Un proyecto con todos los repositorios en `conservar` no tiene nada que migrar: `migration-tl-adrs` y `migration-tl-tasks` se detienen y lo dicen.

## 4. Cambios por agente

### 4.1 `migration-indexer`

- Plantilla del README: `destino:` sigue vacío. La sección "Cómo continuar" muestra las dos formas y recuerda que cada repositorio detectado debe tener destino o `conservar`.
- Un README existente con valor simple no se toca ni se convierte.
- Plantilla `adr.md`: campo `repos: []`. Plantilla `task.md`: campo `tipo: implementacion` y su comentario.
- Bloque de `CLAUDE.md`: los dos formatos, `conservar`, la regla de lectura de §3, la frase de prompt por repositorio, las frases del resolver y la regla de la capacidad fuera de alcance.

### 4.2 `migration-tl-adrs`

- Aplica la regla de lectura de §3.
- Todo ADR declara `repos:` con los repositorios a los que afecta.
- Observados: se escriben para todos los repositorios, también los conservados, porque documentan lo que existe. Un observado sobre algo que un repositorio conservado consume o del que depende (contratos de API, formato de errores, sesión, rutas) lleva `implicacion_migracion: conservar` y dice en "Implicación para la migración" qué repositorio conservado depende de ello: es una restricción para el repositorio migrado. Si el agente cree que debería cambiarse, lo anota como consecuencia, no cambia la implicación.
- Propuestos: solo para repositorios que se migran. Framework, build, tests y despliegue se proponen por repositorio migrado y con su lenguaje destino. Ningún propuesto incluye un repositorio conservado en `repos:`.
- Con destinos distintos por repositorio, las decisiones se separan por repositorio en vez de mezclarse en un ADR.

### 4.3 `migration-tl-specs`

- No exige destino. Si el README lo tiene, lo usa para dos cosas:
  - La sección "3. Alcance por repo" indica junto a cada repositorio si se migra y a qué, o si se conserva.
  - Omite las capacidades cuyos repositorios (columna Repos del mapa) están todos conservados, y las lista en el resumen final como fuera de alcance. `solo la capacidad X` la escribe igualmente.
- El contenido del spec no cambia: describe la capacidad completa, incluida la parte conservada.

### 4.4 `migration-tl-tasks`

- Aplica la regla de lectura de §3.
- Tareas fundacionales solo para repositorios que se migran.
- Tareas de capacidad solo con `repo_destino` en un repositorio que se migra. Las reglas del spec cuya evidencia está solo en un repositorio conservado no generan tarea: ya están implementadas.
- Tareas de adaptación: solo cuando una decisión ya tomada (un ADR `revisado` o una mejora aplicada) obliga a cambiar algo en un repositorio conservado, por ejemplo una URL base o un nombre de campo. Llevan `tipo: adaptacion`, `repo_destino` en el repositorio conservado, y citan en `adrs` o en los criterios la decisión que las causa. Bajo paridad lo normal es que no haya ninguna.
- `tipo: implementacion` en todas las demás.

### 4.5 `migration-qa`

- Los casos se escriben igual para las reglas con parte en un repositorio migrado.
- Las reglas cuya evidencia está solo en repositorios conservados no generan casos: ese comportamiento no se reimplementa. En la matriz de cobertura figuran como "no aplica: repositorio conservado".
- Un caso que ejercita a la vez ambos lados (por ejemplo, extremo a extremo) lista en `Tareas:` solo las del repositorio migrado.

### 4.6 `migration-pm`

- Sin cambios de lógica. Las tareas `tipo: adaptacion` se planifican como cualquier otra.
- Una capacidad sin tareas no genera fase. El backlog añade en "Riesgos" una línea con los repositorios conservados y las capacidades fuera de alcance, para que consten.

### 4.7 `migration-tl-resolver`

Operaciones sobre `destino:`:

| Prompt | Efecto |
|---|---|
| "fija el destino en Kotlin" | Valor simple. Si ya había un mapa, lo reemplaza y lo dice en el resumen. |
| "fija el destino de bff en Kotlin" | Escribe o actualiza esa entrada del mapa. Si había un valor simple, lo convierte en mapa con ese valor para los demás repositorios. |
| "conserva el repositorio frontend" | Entrada `frontend: conservar`, con la misma conversión. |

- Valida que el repositorio exista en el índice general; si no, no aplica y lo reporta.
- No borra ADRs, specs ni tareas. Lista lo que queda afectado: ADRs propuestos cuyo `repos:` incluye el repositorio ahora conservado, tareas con ese `repo_destino`, y recomienda repetir `migration-tl-adrs`, `migration-tl-tasks`, `migration-qa` y `migration-pm`.

### 4.8 `migration-orchestrator`

- Destino pendiente si `destino:` está vacío o si el mapa no cubre algún repositorio detectado, nombrando cuál.
- Los prompts que entrega no añaden destino cuando el README lo tiene. Si está vacío, el siguiente paso es fijarlo con el resolver y ofrece las dos formas.
- Desactualizado: tareas con `repo_destino` en un repositorio conservado sin `tipo: adaptacion`, y ADRs propuestos cuyo `repos:` incluye un repositorio conservado. Ocurre cuando el destino cambió después de generarlos.
- En "Estado" indica qué repositorios se migran y cuáles se conservan.

### 4.9 `migration-analyst`, `migration-auditor`

Sin cambios. El auditor audita los specs igual: las reglas del repositorio conservado siguen citando su código.

## 5. Verificadores y pruebas

**Sin agentes** (`test-fast.sh`):

- `verify-tl-adrs.sh`: todo ADR tiene `repos:`. Si `destino:` es un mapa, ningún ADR `propuesto` incluye en `repos:` un repositorio conservado.
- `verify-tl-tasks.sh`: si `destino:` es un mapa, toda tarea con `repo_destino` en un repositorio conservado tiene `tipo: adaptacion`. Toda tarea tiene `tipo:` con un valor válido.
- Función compartida para leer el destino del README, con sus casos en `test-verifiers.sh`: valor simple aceptado; mapa completo aceptado; mapa al que le falta un repositorio rechazado; mapa con una clave que no es un repositorio rechazado; ADR propuesto sobre un repositorio conservado rechazado; tarea de implementación en un repositorio conservado rechazada; tarea de adaptación aceptada.
- `verify-indexer.sh`: `repos:` en la plantilla de ADR, `tipo:` en la de tarea, y `conservar` y la frase por repositorio en el bloque.
- `test-prompts.sh`: presencia de las reglas de §3 y §4 en los prompts.

**Con agentes:**

- Cadena principal (`snapshot.sh`): sin cambios, destino único Kotlin por prompt. Demuestra que el valor simple se comporta como hoy.
- `test-destino.sh` (nuevo): restaura la instantánea `tl-specs`, borra `adr/` y `tasks/`, fija `destino: {bff: Kotlin, frontend: conservar}` en el README y ejecuta `migration-tl-adrs` y `migration-tl-tasks` sin destino en el prompt. Comprueba:
  - ningún ADR propuesto incluye `frontend` en `repos:`;
  - existen ADRs observados que sí incluyen `frontend`;
  - ninguna tarea tiene `repo_destino: frontend`, salvo las `tipo: adaptacion`;
  - los specs no cambiaron y siguen describiendo el frontend (reglas con cita a `frontend/`);
  - imprime cuántos ADRs propuestos y cuántas tareas hay, para compararlos con el destino único.
  - Segundo caso, sin generar nada: con el mapa `{bff: Kotlin}` (falta `frontend`), `migration-tl-tasks` se detiene sin escribir.
- `test-resolver.sh`: fijar el destino de un repositorio convierte el valor simple en mapa; conservar un repositorio; rechazar un repositorio inexistente.
- `test-orchestrator.sh`: con el README ya con destino, el prompt recomendado no añade `con destino`.

## 6. Compatibilidad

- Un README con valor simple sigue funcionando y significa todos los repositorios.
- ADRs anteriores sin `repos:` y tareas sin `tipo:` no pasan los verificadores nuevos; se regeneran con `migration-tl-adrs` y `migration-tl-tasks`. Los `revisado` se completan con el resolver.
- Proyectos que pasaban el destino solo por prompt siguen igual mientras el README esté vacío. El orquestador recomendará fijarlo en el README.

## 7. Documentación

`docs/tutorial.md`: los dos formatos con un ejemplo de cada uno en el paso 1, qué implica `conservar` en los pasos 3 a 7, la fila "cambiaste el destino de un repositorio" en "Qué repetir después de un cambio", y los errores de mapa incompleto en "Si algo falla". Los ejemplos de prompt dejan de repetir `con destino Kotlin` una vez fijado. `README.md`: convenciones.

## 8. Medición

Al final se informa de cuántos ADRs propuestos y cuántas tareas genera el fixture con destino único (línea base: 5 propuestos, 26 tareas, 9 del frontend) y con el mapa `{bff: Kotlin, frontend: conservar}`.

## 9. Fuera de alcance

- Migrar un repositorio a varios lenguajes o dividirlo en varios.
- Destinos por capacidad en lugar de por repositorio.
- Convertir automáticamente un README de valor simple a mapa.
- Borrar automáticamente ADRs o tareas al cambiar el destino.
