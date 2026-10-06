# Tutorial: agentes de migración

Genera, a partir del código de un proyecto, la documentación para reimplementarlo en otro lenguaje. Los agentes no migran código.

**Principio de paridad.** Todo el flujo asume que el destino debe comportarse igual que el origen, incluso donde el origen parece mejorable. Los agentes describen lo que el sistema hace hoy y no te preguntan si conviene cambiarlo: lo que podría mejorarse queda anotado aparte, como sugerencia opcional, y solo cambia algo si tú lo decides. Así lo que tienes que revisar son hechos y unas pocas incógnitas reales, no decenas de preguntas de diseño.

Tres agentes te acompañan en todo momento:

- **`migration-orchestrator`** te dice en qué paso estás, qué falta revisar y te da el prompt exacto del siguiente paso. Consúltalo siempre que dudes. Las mejoras sin decidir no las cuenta como pendientes: solo las menciona. Después de generar los specs te recomienda auditarlos, y lista como pendientes los hallazgos del auditor que sigan sin corregir.
- **`migration-tl-resolver`** aplica tus decisiones y cambios. Describe el cambio en lenguaje natural en vez de editar archivos a mano.
- **`migration-auditor`** comprueba que lo que dicen los specs es lo que hace el código, regla por regla, y te lista las discrepancias. No modifica nada.

## 1. Instalación

El flujo tiene dos partes, y las dos van dentro de `.claude/` en la raíz del proyecto, es decir, en la carpeta padre que contiene los repositorios (sección 2):

- Los subagentes: copia la carpeta `agents/` de este repositorio dentro de `.claude/agents/`.
- Los scripts del flujo: copia a `.claude/migration/` los archivos `backlog.sh`, `verificar.sh`, `lib-rev.sh`, `lib-destino.sh` y todos los `verify-*.sh` de la carpeta `scripts/`, salvo `verify-idempotency.sh`.

Desde una copia de este repositorio, un comando hace las dos cosas:

```
bash scripts/install.sh /ruta/a/mi-proyecto
```

```
mi-proyecto/
├── .claude/
│   ├── agents/
│   │   ├── migration-orchestrator.md
│   │   └── ...
│   └── migration/
│       ├── backlog.sh
│       ├── verificar.sh
│       └── ...
├── frontend/
└── bff/
```

Los scripts necesitan bash 4 y utilidades GNU, incluido `gawk` (en Windows, Git Bash las trae). Sirven para dos cosas:

- `backlog.sh` calcula el orden del backlog. Lo ejecuta `migration-pm`; sin él, el paso 7 se detiene.
- `verificar.sh` comprueba la estructura de todo lo que hay en `migration/`. Lo ejecutas tú, cuando quieras, desde la carpeta del proyecto:

  ```
  bash .claude/migration/verificar.sh
  ```

  Revisa los campos de cada artefacto, el formato de los identificadores, las citas, las versiones y las secciones, solo de lo que ya exista, y termina con una línea por tipo de artefacto. Comprueba que algo está bien formado, no que sea correcto: para eso están tu revisión y el auditor.

Son 10 subagentes:

- `migration-orchestrator`: diagnostica en qué paso estás y te da el prompt del siguiente. Solo lee.
- `migration-tl-resolver`: aplica tus decisiones y cambios sobre los artefactos.
- `migration-auditor`: contrasta los specs con el código que citan. Solo escribe su informe.
- `migration-indexer`: paso 1, índices y convenciones.
- `migration-analyst`: paso 2, mapa de capacidades.
- `migration-tl-adrs`: paso 3, ADRs.
- `migration-tl-specs`: paso 4, specs por capacidad.
- `migration-qa`: paso 5, planes de prueba.
- `migration-tl-tasks`: paso 6, tareas de implementación.
- `migration-pm`: paso 7, backlog.

Después abre una sesión nueva de Claude Code en esa carpeta, porque los subagentes se cargan al iniciar.

## 2. Preparar la carpeta

Deja los repositorios como subcarpetas de una carpeta padre y abre Claude Code en esa carpeta, no dentro de un repo:

```
mi-proyecto/
├── frontend/
└── bff/
```

Conviene versionar `mi-proyecto/` con git y hacer commit antes de cada paso. Puedes deshacer con `git checkout`, clonar la carpeta en otra máquina o tenerla en una carpeta sincronizada: el orquestador no mira cuándo se modificó cada archivo, sino los números de versión escritos dentro de ellos, y da el mismo diagnóstico en cualquier copia.

## 3. Paso a paso

En cada paso: ejecuta el agente, revisa, aplica cambios con el resolver y pregunta al orquestador qué sigue.

### Paso 1: indexar

**Qué es:** genera un mapa del código para que los demás agentes no tengan que recorrer los repositorios completos. Por cada repo escribe un `index.md` con cada archivo de código real y dos líneas que dicen qué contiene y para qué sirve, descartando lo que no aporta (lockfiles, compilados, imágenes, cachés). También escribe un `index.md` general que apunta a los de cada repo, el bloque de convenciones del flujo en `CLAUDE.md` y la carpeta `migration/` con el README y las plantillas de los artefactos.

```
Usa el subagente migration-indexer
```

Crea un `index.md` por repo, un `index.md` general en la carpeta padre, el bloque de convenciones en `CLAUDE.md` y `migration/` con plantillas. Revisa que los índices no tengan archivos basura y que los resúmenes sean concretos. Fija el destino:

```
Usa el subagente migration-tl-resolver: fija el destino en Kotlin
```

Eso migra todos los repositorios a Kotlin. Lo habitual es otra cosa: migrar el backend y dejar el frontend como está, o llevar cada repositorio a un lenguaje distinto. Para eso el destino se fija por repositorio, y `conservar` significa que ese repositorio no se migra:

```
Usa el subagente migration-tl-resolver: fija el destino de bff en Kotlin
Usa el subagente migration-tl-resolver: conserva el repositorio frontend
```

El resultado queda en la cabecera de `migration/README.md`, en una sola línea:

```
destino: Kotlin                                  # un valor: todos los repositorios
destino: {bff: Kotlin, frontend: conservar}      # un valor por repositorio
```

Con un mapa, cada repositorio detectado necesita su entrada: si falta uno, los agentes que usan el destino se detienen y te dicen cuál. Una vez fijado, no hace falta repetir el destino en los prompts; el README manda.

Qué cambia para un repositorio conservado:

| Paso | Efecto |
|---|---|
| ADRs | Los observados se escriben igual. No se propone framework, build ni tests para él. Lo que ese repositorio consume (contratos de API, formato de errores, sesión) queda marcado como restricción para el repositorio que sí se migra. |
| Specs | No cambian: describen la capacidad completa, porque el comportamiento del repositorio conservado es el contrato que el migrado debe respetar. La sección de alcance indica qué se migra y qué se conserva. |
| Tareas | Ninguna de implementación en ese repositorio. Solo una tarea de adaptación (`tipo: adaptacion`) si una decisión tuya obliga a cambiarle algo. |
| Planes de prueba | Sin casos para las reglas que viven solo en él; figuran como "no aplica: repositorio conservado". |
| Backlog | Los repositorios conservados constan en los riesgos. |

Una capacidad cuyos repositorios están todos conservados queda fuera de alcance: sigue en el mapa de capacidades, pero no recibe spec, tareas ni plan. Si la quieres documentada, pídela con `solo la capacidad X`.

El bloque de `CLAUDE.md` lo reescribe el indexador en cada corrida; escribe tus notas fuera de las marcas.

El `index.md` general anota además el commit de cada repo en el momento de indexar (`sin-git` si el repo no usa git). Los specs copian ese commit, y así se puede saber más adelante si el código cambió desde que se escribieron y sus citas pueden haberse desplazado. Por eso conviene tener los cambios de los repos commiteados antes de indexar.

`migration/README.md` guarda en su cabecera la configuración del proceso:

| Campo | Para qué sirve | Quién lo cambia |
|---|---|---|
| `destino:` | Lenguaje al que se migra: un valor para todos los repositorios o un mapa por repositorio, con `conservar` para los que no se migran. | Tú, con el resolver. |
| `excluir:` | Capacidades descartadas; el analista las omite siempre. | Tú, con el resolver. |
| `politica:` | Siempre `paridad`: el destino reproduce el comportamiento del origen. Es el único valor que existe; los agentes se detienen si encuentran otro. | Nadie; lo escribe el indexador. |

**Proyectos grandes.** El indexador lee cada archivo de código, así que en un proyecto grande una corrida puede no alcanzar. Tres cosas lo hacen manejable:

- **Se reanuda.** Si se queda sin capacidad, deja el índice de ese repositorio con una última línea `> Índice incompleto: falta desde <carpeta>`. Vuelve a ejecutar `Usa el subagente migration-indexer`: continúa desde esa carpeta sin releer lo ya indexado. Repite hasta que no quede ningún índice incompleto. El bloque de `CLAUDE.md` y `migration/` se escriben antes de indexar, así que un corte no te deja sin ellos.
- **Se acota a un repositorio.** `Usa el subagente migration-indexer, solo el repo bff` indexa solo ese repositorio y no escribe nada más. Con varios repositorios puedes lanzarlos a la vez, pidiéndoselo a la sesión principal en un mismo mensaje:

  ```
  Lanza estos subagentes en paralelo, en un mismo mensaje:
  - Usa el subagente migration-indexer, solo el repo bff
  - Usa el subagente migration-indexer, solo el repo frontend
  ```

- **Se consolida sin reindexar.** Cuando terminen, `Usa el subagente migration-indexer` sin alcance escribe `migration/`, el bloque de `CLAUDE.md` y el índice general, y deja como están los índices ya completos. Hasta que no consolides no hay bloque de `CLAUDE.md` y los demás agentes no trabajan.

No hace falta recordar esto: el orquestador entrega el bloque de paralelo cuando hay varios repositorios sin indexar, y el prompt de reanudación cuando hay un índice incompleto. El analista se niega a trabajar sobre un índice incompleto.

**Si vuelves a correr el indexador:**

| Archivo | Qué pasa |
|---|---|
| `index.md` de cada repo | Si no existe, se crea. Si está incompleto, se continúa. Si está completo y el repositorio sigue en el mismo commit (línea `Commit:` del encabezado), no se toca. Si el commit cambió o el repositorio no tiene git, se regenera entero. Para forzar la regeneración: `migration-indexer, solo el repo X`. Los cambios sin commit no se detectan. |
| `index.md` general | Se regenera entero, incluida la columna con el commit actual de cada repo. |
| `CLAUDE.md` | Solo se reemplaza el bloque entre las marcas; el resto no cambia. |
| `migration/README.md` | No se toca, salvo añadir `excluir: []` y `politica: paridad` si faltan, o actualizar un README de la versión anterior. |
| `migration/templates/*.md` | No se tocan; solo se crean las que falten. |

El indexador nunca indexa `migration/`: no es código del proyecto sino el resultado del proceso, y los demás agentes leen sus artefactos directamente. No hace falta repetirlo después de generar ADRs, specs o tareas. Repítelo solo si cambia el código de algún repo, si añades o quitas un repositorio de la carpeta padre, o si actualizas los agentes a una versión que cambia el bloque de `CLAUDE.md`. Si cambió el código, sigue después la tabla de la sección 4.

### Paso 2: capacidades

**Qué es:** identifica qué puede hacer el sistema de principio a fin, por ejemplo autenticarse, listar productos o gestionar el carrito, aunque cada capacidad cruce varios repos. El resultado es `migration/specs/_capacidades.md`, una tabla con cada capacidad, los repos que toca y los archivos que la implementan. Esa lista define cuántos specs habrá después.

```
Usa el subagente migration-analyst
```

Revisa `migration/specs/_capacidades.md`. Es el mejor momento para descartar capacidades:

```
Usa el subagente migration-tl-resolver: excluye la capacidad pagos
```

La exclusión es permanente: el analista la omite en cada corrida. Para agrupar o dividir, repite el analista indicándolo en el prompt.

### Paso 3: ADRs

**Qué es:** escribe los ADR (Architecture Decision Records, registros de decisiones de arquitectura) en `migration/adr/`. Son documentos cortos que dejan por escrito una decisión de diseño, su contexto, la evidencia en el código y sus consecuencias. Hay dos tipos: los **observados**, decisiones que el código actual ya tomó (cómo autentica, cómo maneja errores, dónde guarda datos), y los **propuestos**, decisiones que la migración obliga a tomar y que el código no responde (qué framework usar en el destino, cómo construir, cómo probar). Necesita el lenguaje destino.

```
Usa el subagente migration-tl-adrs
```

**Observados.** Documentan lo que el código ya hace, con una implicación para la migración: conservar, reemplazar o reevaluar. No bloquean nada: puedes generar specs y tareas aunque no los marques `revisado`. Aun así, conviene revisarlos antes de los specs, por dos motivos:

- Si repites `migration-tl-adrs`, los observados que no estén `revisado` se regeneran. Conservan su id, así que las citas desde los specs siguen siendo válidas, pero su texto o su implicación pueden cambiar.
- Si corriges un observado después de generar specs o tareas, esa corrección no llega sola a ellos. El resolver te lista qué artefactos lo citan, y tú decides qué regenerar (sección 4).

Para confirmar uno sin cambiarlo: `Usa el subagente migration-tl-resolver: marca revisado el ADR 0003`.

**Propuestos.** Son decisiones que tomas tú y bloquean las tareas hasta que las decidas. Resuelve los que dependen de otros primero (framework antes que librería JWT):

```
Usa el subagente migration-tl-resolver: en el ADR 0011 elijo Ktor porque el equipo conoce corrutinas
Usa el subagente migration-tl-resolver: en el ADR 0014 acepta la recomendación
Usa el subagente migration-tl-resolver: en el ADR 0009 la implicación es reemplazar, el carrito irá a Redis
```

El resolver escribe la decisión con la tecnología nombrada, borra la recomendación, conserva las alternativas, marca `revisado` y desbloquea tareas si ya existen.

Lo que decide un ADR propuesto no se vuelve a preguntar en los specs. Si hay un ADR sobre la persistencia del carrito, el spec de carrito no pregunta si el carrito debe sobrevivir a un reinicio ni lo lista como mejora: cita el ADR.

### Paso 4: specs

**Qué es:** escribe una especificación por capacidad en `migration/specs/<capacidad>.md`. Describe el comportamiento del sistema sin código del lenguaje origen: flujos, contratos de API en notación neutral, modelos de datos, reglas de negocio numeradas (`RN-n`), casos borde y errores (`CB-n`), preguntas abiertas para lo que no se pudo determinar leyendo el código, y posibles mejoras (`MJ-n`) para lo que el código sí determina pero parece mejorable. Es la pieza con la que otro equipo reimplementa la capacidad en cualquier lenguaje.

```
Usa el subagente migration-tl-specs
```

Con muchas capacidades conviene repartirlas: cada corrida con `solo la capacidad X` escribe solo su spec, así que se pueden lanzar a la vez. El orquestador lo propone cuando hay dos o más pendientes, en tandas de cinco, con un bloque como este, que pegas tal cual en la sesión principal:

```
Lanza estos subagentes en paralelo, en un mismo mensaje:
- Usa el subagente migration-tl-specs, solo la capacidad autenticacion
- Usa el subagente migration-tl-specs, solo la capacidad carrito
- Usa el subagente migration-tl-specs, solo la capacidad listado-productos
```

Qué se puede lanzar en paralelo y qué no:

| Agente | En paralelo | Por qué |
|---|---|---|
| `migration-indexer, solo el repo X` | Sí | Cada corrida escribe solo el índice de su repositorio. Después se consolida sin alcance. |
| `migration-tl-specs, solo la capacidad X` | Sí | Cada corrida escribe solo su spec. |
| `migration-qa, solo la capacidad X` | Sí | Cada corrida escribe solo su plan. Después, `solo la cobertura`. |
| `migration-tl-tasks` | No | Numera las tareas y crea las fundacionales: dos corridas a la vez duplicarían ids. |
| `migration-auditor` | No | Reescribe `_auditoria.md` entero. |
| Los demás | No | No trabajan por capacidad. |

Es la revisión más importante: un error aquí llega a tareas y pruebas como requisito. Revisa primero los hechos (flujos, contratos, `RN-n`, `CB-n`): bajo paridad son lo que se va a construir, también los que describen un comportamiento raro del origen. Después responde las preguntas abiertas, que deberían ser pocas:

```
Usa el subagente migration-tl-resolver: en el spec carrito, respuesta a la pregunta PA-1: el carrito debe persistir; conviértelo en regla
Usa el subagente migration-tl-resolver: en el spec autenticacion, el token expira a los 30 minutos
Usa el subagente migration-tl-resolver: marca revisado el spec catalogo-productos
```

**Política de paridad.** El flujo asume que el destino reproduce el comportamiento observado en el origen, salvo que decidas lo contrario. Es el campo `politica: paridad` de `migration/README.md` y es la única política que existe. Por eso cada spec separa dos cosas que no deben confundirse:

- **Preguntas abiertas (sección 12):** solo lo que no se pudo saber leyendo el código, como qué responde un servicio externo cuyo código no está en los repos. Suelen ser pocas, a veces ninguna. Las que cambian qué se construye bloquean tareas y generan casos de prueba pendientes.
- **Posibles mejoras (sección 13):** comportamiento que el código sí determina pero parece mejorable o sospechoso, como "quitar una línea que no existe responde 204; ¿debería ser 404?". Cada `MJ-n` cita la regla que describe el comportamiento actual. No bloquean tareas, no generan casos pendientes y el orquestador no las cuenta como pendientes: si no haces nada, el destino se construye igual que el origen.

No tienes que revisar las mejoras para avanzar. Cuando quieras adoptar o cerrar alguna:

```
Usa el subagente migration-tl-resolver: aplica la mejora MJ-2 del spec carrito
Usa el subagente migration-tl-resolver: descarta la mejora MJ-3 del spec carrito
Usa el subagente migration-tl-resolver: la pregunta PA-2 del spec carrito es una mejora
```

Cada pregunta abierta lleva su identificador escrito, `PA-1`, `PA-2`, igual que las reglas llevan `RN-n`. Es lo que citas al responderla y lo que citan las tareas que bloquea (`PA:carrito:2` es la pregunta `PA-2` del spec carrito). El identificador no cambia aunque se añadan, se quiten o se muevan otras preguntas; una pregunta reclasificada o que deja de aplicar se marca como retirada y conserva su número.

Aplicar una mejora añade la regla nueva, marca la anterior como retirada y la mejora como aplicada. Descartarla solo la marca. La tercera orden sirve para specs ya `revisado` cuyas preguntas en realidad eran mejoras.

Cómo se ve en el spec:

```
## 8. Casos borde y errores
CB-7: quitar una línea que no existe responde 204 y no cambia el carrito.

## 12. Preguntas abiertas
- PA-1: ¿Qué responde el servicio de identidad cuando la cuenta está bloqueada? El adaptador solo distingue el 200 de todo lo demás.

## 13. Posibles mejoras
MJ-1: responder 404 al quitar una línea que no existe. Comportamiento actual: CB-7.
MJ-2: informar al cliente cuando el tope de 10 recorta la cantidad. Comportamiento actual: RN-6. (descartada 2026-10-01)
```

Para saber dónde debería estar algo, pregúntate qué hace hoy el sistema en ese caso:

| Situación | Dónde va |
|---|---|
| El código lo determina, sea o no deseable | Hecho: `RN-n`, `CB-n`, contrato o flujo. |
| El código lo determina y parece mejorable o sospechoso | Hecho, y además una `MJ-n` que lo cita. |
| No se puede saber leyendo el código: depende de un sistema externo, de una rama no rastreada o de un valor de origen incierto | Pregunta abierta. |
| Lo decide un ADR propuesto | Ni pregunta ni mejora: el spec cita el ADR. |

**Citas.** Cada regla y cada caso borde termina con la línea de código que lo respalda, para que puedas comprobarlo sin releer archivos enteros:

```
RN-6: la cantidad de un producto en el carrito nunca supera 10; al sumar, se recorta a 10 sin avisar. [bff/src/routes/cart.ts:32]
RN-12: no existe operación para vaciar el carrito. [ausente: bff/src/routes/cart.ts]
RN-22: quitar una línea que no existe responde 404. [decisión: MJ-1]
```

`[ruta:línea]` señala dónde se decide el comportamiento. `[ausente: ruta]` marca una regla deducida de que algo no existe. `[decisión: ...]` marca una regla que viene de una decisión tuya y no del código. El spec anota además en `commits:` el commit de cada repo sobre el que se escribió: si el código cambia, las líneas pueden desplazarse y conviene regenerar. Los tests del proyecto origen también cuentan como evidencia y pueden aparecer citados.

**Comportamientos por defecto.** Hay comportamiento que el proyecto no escribe en ninguna línea porque lo pone el framework: qué responde una ruta que no existe, un método no permitido, un cuerpo vacío o un cuerpo mal formado. El framework del destino tendrá otros valores por defecto, así que cada spec con endpoints los recoge siempre como casos borde que empiezan por una frase fija:

```
CB-14: Ruta no definida: una ruta inexistente bajo /cart responde 404 por defecto del framework, sin el formato de error del sistema. [bff/src/server.ts:11]
CB-15: Método no permitido: ...
CB-16: Cuerpo ausente: ...
CB-17: Cuerpo mal formado: ...
```

Si el agente no puede determinar uno con certeza, lo deja como pregunta abierta que empieza por la misma frase. Revísalos con atención: son los que más fácilmente cambian sin que nadie lo decida al migrar.

Cómo aprovechar las citas:

- **Al revisar**, abre la línea citada de las reglas que te sorprendan o que más pesen en el negocio. No hace falta comprobarlas todas a mano: para eso está el auditor, en el apartado siguiente.
- **Al pedir un cambio**, puedes dar tú la cita y el resolver la escribe. Si no la das, la busca él. Si la regla nueva es una decisión tuya y no algo que haga el código, queda marcada como `[decisión: ...]`:

```
Usa el subagente migration-tl-resolver: en el spec carrito añade un caso borde: quitar una línea responde 204 [bff/src/routes/cart.ts:40]
Usa el subagente migration-tl-resolver: en el spec carrito, RN-6: el tope es 10, no 20
```

- **Si un test del origen contradice a la implementación**, el spec no elige: lo deja como pregunta abierta, porque no se sabe cuál de los dos es el requisito. Respóndela tú.
- **Las citas no llegan a las tareas ni a los casos de prueba.** Son una ayuda para revisar el spec, no parte del requisito.

Tres cosas a tener en cuenta al revisar:

- **Las mejoras son sugerencias del agente, no una lista de tareas.** Algunas señalan algo sospechoso del origen y otras son ideas de producto, como añadir una función que hoy no existe. Aplica solo las que quieras de verdad en el destino; ignorar el resto no tiene ningún efecto.
- **Aplicar una mejora cambia el alcance.** El destino dejará de ser equivalente al origen en ese punto, y habrá que regenerar tareas y pruebas de esa capacidad (sección 4).
- **Si una pregunta abierta es en realidad una mejora**, o al revés, corrígelo con el resolver. Una pregunta abierta bloquea tareas y deja casos de prueba pendientes; una mejora no.

### Auditar los specs (recomendado antes de los planes de prueba)

**Qué es:** una comprobación automática de fidelidad. El auditor recorre cada regla de cada spec, abre el código que cita, decide qué hace ese código y solo entonces lo compara con lo que afirma la regla. No es un paso obligatorio ni numerado: puedes correrlo cuando quieras y tantas veces como haga falta.

```
Usa el subagente migration-auditor
Usa el subagente migration-auditor, solo la capacidad carrito
```

Escribe `migration/specs/_auditoria.md` con una tabla por capacidad y un veredicto por regla:

| Veredicto | Significa |
|---|---|
| respaldada | El código citado hace lo que la regla dice. |
| sin respaldo | La cita existe, pero ese código no muestra ese comportamiento. Suele ser una regla inventada o mal citada. |
| contradicha | El código hace otra cosa: otro valor, otro código de respuesta, otra condición. |
| cita no localizable | El archivo o la línea citados no existen. |
| decisión | La regla viene de una decisión tuya; no se audita. |

Debajo lista los hallazgos, numerados `AU-n`, cada uno con el prompt para corregirlo. También anota como "omitido" el comportamiento que ve en el código y que ninguna regla recoge.

Así se ve un fragmento del informe:

```
## carrito

Auditada: 2026-10-01. Commits del spec: bff 65ca5ae, frontend d578ded (coinciden con el índice).

| Regla | Veredicto | Cita | Nota |
|---|---|---|---|
| RN-5 | respaldada | bff/src/routes/cart.ts:13 | |
| RN-6 | contradicha | bff/src/routes/cart.ts:32 | El código recorta a 10; la regla dice 20. |

### Hallazgos

- **AU-1** (contradicha, RN-6): el tope en el código es 10 y la regla dice 20.
  Corrección: `Usa el subagente migration-tl-resolver: en el spec carrito, RN-6: el tope es 10, no 20`
```

Cuándo correrlo:

- **Justo después de generar los specs y antes de revisarlos tú.** Te ahorra comprobar a mano las reglas respaldadas y te deja concentrarte en los hallazgos y en lo que el auditor no puede juzgar: si el spec está completo y si refleja lo que el negocio necesita.
- **Después de corregir un spec**, con alcance sobre esa capacidad, para confirmar que el hallazgo desapareció.
- **Cuando cambie el código de un repo**, después de repetir el indexador y los specs.

Audita también los specs `revisado`, porque no los modifica. Si al principio de una sección avisa de que los commits del spec no coinciden con el índice, el código cambió desde que se escribió el spec: muchos hallazgos serán líneas desplazadas, y lo que corresponde es regenerar el spec, no corregir regla por regla.

Qué hacer:
- Revisa solo los hallazgos; las reglas respaldadas no requieren nada.
- En una contradicción decides tú: o el spec está mal y se corrige, o el comportamiento del código es justo lo que quieres cambiar y entonces es una mejora.
- Corrige con el resolver, usando el prompt que trae cada hallazgo, y repite el auditor para esa capacidad. Un hallazgo corregido desaparece en la siguiente auditoría; no hay que marcarlo.
- El auditor no modifica specs y no ejecuta código ni tests. Tampoco sustituye tu revisión: comprueba que cada regla tiene respaldo, no que el spec esté completo.

### Paso 5: planes de prueba

**Qué es:** escribe un plan de pruebas por capacidad en `migration/test-plans/`, con casos en formato Dado/Cuando/Entonces que cubren el camino feliz, los casos borde, los errores y los contratos de API. Cada caso dice qué regla o caso borde cubre. Los planes se escriben antes que las tareas y no las citan: QA es la última revisión del spec, y conviene hacerla antes de derivar nada de él. Lo que el spec no define queda como caso pendiente, y las ambigüedades que encuentra quedan como hallazgos `H-n`. `_cobertura.md` resume qué quedó sin cubrir. Estos planes sirven luego para validar la implementación en el destino.

No hace falta haber decidido los ADRs propuestos: QA no depende de ellos, así que puedes lanzarlo mientras los decides. Antes de correr QA conviene tener los specs validados y las preguntas abiertas respondidas: QA convierte el spec en casos afirmados con seguridad, y cada pregunta abierta sin responder queda como caso pendiente. Los casos prueban el comportamiento actual, incluido el que una mejora propone cambiar: las mejoras sin aplicar no generan casos ni pendientes.

```
Usa el subagente migration-qa
```

Con alcance (`solo la capacidad X`) QA escribe solo el plan de esa capacidad y no toca `_cobertura.md`, para que varias corridas puedan ir a la vez. El resumen de cobertura se consolida aparte, sin tocar los planes:

```
Usa el subagente migration-qa, solo la cobertura
```

Revisa los hallazgos `H-n` al final de cada plan. Decide y aplica al spec:

```
Usa el subagente migration-tl-resolver: resuelve el hallazgo H-1 del plan carrito: el esquema Bearer no distingue mayúsculas
```

Luego repite QA para esa capacidad (`Usa el subagente migration-qa, solo la capacidad carrito`) y consolida la cobertura (`Usa el subagente migration-qa, solo la cobertura`). Como las tareas todavía no existen, no hay nada más que regenerar: por eso los planes van antes. Si falta un caso cuyo comportamiento no está en el spec, el resolver te pedirá añadirlo primero al spec.

### Paso 6: tareas

**Qué es:** convierte los specs y las decisiones de los ADRs en tareas de implementación para el lenguaje destino, una por archivo en `migration/tasks/`. Primero las fundacionales (estructura del proyecto, build, integración continua) y luego las de cada capacidad. Cada tarea indica de qué otras depende, su tamaño, criterios de aceptación que citan las reglas del spec y, si queda algo sin decidir, qué la bloquea.

```
Usa el subagente migration-tl-tasks
```

Si quedan ADRs propuestos, se detiene y te da el prompt para decidirlos. Así las tareas se generan una sola vez, con el framework nombrado. Los criterios de aceptación afirman el comportamiento actual que describen las reglas, sin condicionales. Las mejoras sin aplicar no aparecen en las tareas, y solo una pregunta abierta real cuya respuesta cambie qué se construye puede bloquear una tarea. Conviene llegar aquí con los specs auditados y los hallazgos de QA resueltos: una regla equivocada se convierte en un criterio de aceptación equivocado, y cada cambio posterior en el spec obliga a regenerar sus tareas. Cada tarea de capacidad trae una sección `## Pruebas` con la ruta de su plan; los casos que la validan son los que cubren las reglas de sus criterios. Si falta el plan de alguna capacidad, las tareas se generan igual y el resumen lo avisa. Corrige con el resolver:

```
Usa el subagente migration-tl-resolver: la tarea T-016 también depende de T-004 y es tamaño L
```

### Paso 7: backlog

**Qué es:** ordena las tareas para que el equipo pueda empezar a implementar. El orden no lo decide el modelo: lo calcula el script `backlog.sh`, que comprueba que las dependencias no tengan ciclos ni referencias rotas y asigna fases y prioridades con reglas fijas, siempre las mismas para las mismas tareas. El agente lo ejecuta, copia sus tablas y escribe el resumen y los riesgos. Escribe `migration/backlog.md` con los hitos, los bloqueos y los riesgos, y rellena `fase` y `prioridad` en cada tarea.

```
Usa el subagente migration-pm
```

Las reglas del script:

- El hito 0 son las tareas fundacionales (sin spec).
- Las capacidades van en orden de dependencia: una capacidad depende de otra cuando alguna de sus tareas depende de una tarea de la otra. Primero las que más capacidades tienen detrás.
- Las capacidades se juntan en una fase mientras no pasen de 12 puntos (S = 1, M = 2, L = 4). Una capacidad entra siempre completa; si sola supera 12, ocupa una fase propia.
- La prioridad es un número único. Dentro de cada fase van primero las tareas de las que más tareas dependen, y nunca una tarea antes que otra de la que depende. Es la columna Orden del backlog.

Escribe hitos, bloqueos y riesgos. En los riesgos verás una línea con cuántas mejoras quedan sin decidir por capacidad: es informativa, el backlog se planifica asumiendo paridad. Si hay un ciclo o una dependencia rota, no escribe nada y te dice qué corregir (con el resolver). Para cambiar el orden:

```
Usa el subagente migration-tl-resolver: adelanta T-013 al hito 1 con prioridad 3
```

y repite el PM. El resolver deja esa tarea `revisado`, y el script respeta la fase y la prioridad de las tareas `revisado`: las demás se reordenan alrededor. Si lo que fijaste choca con una dependencia, el backlog lo lista entre los riesgos como conflicto.

### Resultado

`migration/` es lo que entregas al equipo. Empiezan por el Hito 0, con la sección "Cómo empezar a implementar" de `migration/README.md`.

## 4. Qué repetir después de un cambio

Los agentes forman una cadena: specs → planes de prueba → tareas → backlog. Los planes y las tareas dependen del spec y no entre sí: cambiar tareas no obliga a repetir QA. Cuando cambias algo, hay que regenerar lo que viene **después** en la cadena, en ese orden, y acotado a la capacidad afectada cuando se pueda. Nada se regenera solo.

| Cambiaste | Repite, en este orden |
|---|---|
| Corregiste un spec por un hallazgo `AU-n` del auditor | `migration-auditor, solo la capacidad X` para confirmar que el hallazgo desapareció; después, como cualquier cambio de spec. |
| El código de un repo | `migration-indexer`; `migration-analyst` si pudieron cambiar las capacidades; `migration-tl-specs, solo la capacidad X` para las afectadas (actualiza las citas y los commits); `migration-auditor` sobre ellas; luego `migration-qa`, `migration-tl-tasks` y `migration-pm` para esas capacidades. |
| Agrupaste o dividiste capacidades | `migration-analyst` con la indicación; `migration-tl-specs` para las capacidades nuevas; `migration-qa`, `migration-tl-tasks`, `migration-pm`. |
| Excluiste una capacidad | Si el resolver lista tareas con `depende_de` roto o specs que la mencionan, corrígelos con el resolver. Luego `migration-qa, solo la cobertura` (para que `_cobertura.md` deje de contarla) y `migration-pm` (para que salga del backlog). |
| Decidiste un ADR propuesto después de generar tareas | `migration-tl-tasks` (para que las notas nombren la tecnología elegida) y `migration-pm`. Los planes no cambian. |
| Corregiste un ADR observado | Si cambia el comportamiento, llévalo al spec con el resolver y sigue la fila siguiente. Si solo cambia cómo se implementa, `migration-tl-tasks` y `migration-pm`. |
| Un spec: regla, contrato o caso borde | `migration-qa, solo la capacidad X` y `migration-qa, solo la cobertura`; si ya hay tareas, `migration-tl-tasks, solo la capacidad X` y `migration-pm`. |
| El destino de un repositorio, o pasaste uno a `conservar` | `migration-tl-adrs` (retira o añade las decisiones de ese repositorio); `migration-qa`; `migration-tl-tasks`; `migration-pm`. El resolver te lista los ADRs y tareas afectados y no borra nada. Los specs solo cambian en la nota de alcance. |
| Aplicaste una mejora `MJ-n` | Igual que un cambio de spec: `migration-qa` y, si ya hay tareas, `migration-tl-tasks` y `migration-pm`, con `solo la capacidad X`. Descartarla no requiere repetir nada. |
| Reclasificaste una pregunta como mejora | `migration-qa, solo la capacidad X` para que desaparezca el caso pendiente. Si esa pregunta bloqueaba tareas, el resolver ya quitó el bloqueo; `migration-pm` para actualizar el backlog. |
| Actualizaste los agentes a la versión con citas y auditor en un proyecto ya empezado | `migration-indexer` (añade el commit de cada repo y el bloque nuevo); `migration-tl-specs` para que los specs `generado` reciban citas y `commits:`; `migration-auditor`. Los specs `revisado` no se regeneran: el auditor los revisa igual y reporta cada regla sin cita con la línea que encontró, para que la añadas con el resolver; o los reabres (`reabre el spec X`) y repites `migration-tl-specs`. |
| Actualizaste los agentes a la versión con política de paridad en un proyecto ya empezado | `migration-indexer` (añade `politica: paridad` y el bloque nuevo); `migration-tl-specs` para reclasificar los specs `generado`; luego `migration-qa`, `migration-tl-tasks` y `migration-pm`. Los specs `revisado` no se regeneran: reclasifica sus preguntas con el resolver, o reábrelos (`reabre el spec X`) y repite `migration-tl-specs`. |
| Respondiste una pregunta abierta | Si la convertiste en regla o cambia qué se construye, igual que la fila anterior. Si solo confirma el comportamiento actual, `migration-qa, solo la capacidad X` para que el caso pendiente pase a ser un caso normal. |
| Resolviste un hallazgo `H-n` de QA | `migration-qa, solo la capacidad X` y `migration-qa, solo la cobertura`. Si todavía no generaste tareas, nada más. Si ya las hay y cambia qué se construye, `migration-tl-tasks, solo la capacidad X` y `migration-pm`. |
| Una tarea: dependencias, tamaño, fase o prioridad | `migration-pm`. Los planes no cambian. |
| Actualizaste los agentes a la versión con identificador en las preguntas abiertas (`PA-n`) en un proyecto ya empezado | Nada obligatorio: los specs anteriores siguen funcionando y sus referencias se resuelven como antes. Para pasar al formato nuevo, `Usa el subagente migration-tl-resolver: numera las preguntas`: pone `PA-1`, `PA-2`... en el orden en que están, sin cambiar nada más y sin que haya que repetir ningún agente. El orquestador lista los specs que faltan por numerar. |
| Actualizaste los agentes a la versión con los planes antes que las tareas en un proyecto ya empezado | Nada obligatorio. Los planes antiguos que traen `tareas:` y líneas `- Tareas:` siguen siendo válidos y se limpian cuando se regeneren. Si tienes tareas y ningún plan, el orquestador te propone `migration-qa` y después `migration-pm`, sin regenerar las tareas. |
| Un plan de prueba | Nada; queda `revisado`. |
| Una plantilla de `migration/templates/` | El agente que genera ese tipo de artefacto, y lo que venga después. |

**Dos casos típicos, paso a paso:**

Generaste tareas forzando ADRs propuestos y luego los decides:

```
Usa el subagente migration-tl-resolver: en los ADRs 0011, 0012 y 0013 acepta la recomendación
Usa el subagente migration-tl-tasks
Usa el subagente migration-pm
```

El resolver ya quita esos ADRs de `bloqueada_por`, pero las notas de las tareas se escribieron sin conocer la tecnología: por eso se regeneran. Los planes de prueba no se tocan: no dependen de las tareas ni de los ADRs.

QA encontró hallazgos en el plan de carrito:

```
Usa el subagente migration-tl-resolver: resuelve el hallazgo H-1 del plan carrito: DELETE /cart/items/ sin id responde 404 sin cuerpo
Usa el subagente migration-qa, solo la capacidad carrito
Usa el subagente migration-qa, solo la cobertura
```

Eso es todo si aún no generaste las tareas, que es lo normal: QA va antes precisamente para que resolver sus hallazgos no obligue a rehacer nada más. Si las tareas ya existían y la decisión cambia qué se construye, añade `Usa el subagente migration-tl-tasks, solo la capacidad carrito` y `Usa el subagente migration-pm`.

**Lo `revisado` no se regenera, hasta que lo reabres.** Si marcaste `revisado` un spec, una tarea o un plan, el agente correspondiente lo conserva tal cual, incluidos los que editó el resolver, porque él marca `revisado` lo que toca. Cuando quieras que se regenere (cambió el código, actualizaste los agentes, quieres otra pasada), pídeselo al resolver:

```
Usa el subagente migration-tl-resolver: reabre el spec carrito
Usa el subagente migration-tl-resolver: reabre la capacidad carrito
```

La primera forma vale también para una tarea (`reabre la tarea T-012`), un plan (`reabre el plan carrito`) o un ADR observado (`reabre el ADR 0003`). La segunda reabre de una vez el spec, el plan y las tareas de esa capacidad, que es lo habitual cuando cambió su código. Reabrir solo cambia el estado: no toca el contenido ni la versión, y no regenera nada. El resolver te da el prompt del agente que regenera.

Antes de regenerar, lee la sección "Al regenerar" de la respuesta del resolver: te dice qué hay en ese artefacto que salió de ti y qué pasará con ello.

| Artefacto | Se conserva al regenerar | Se pierde al regenerar |
|---|---|---|
| Spec | Respuestas a preguntas abiertas; mejoras aplicadas y descartadas; reglas que nacieron de una decisión tuya (`[decisión: ...]`); reglas retiradas; la numeración | Correcciones de reglas, contratos o flujos que el código no respalde: el spec se vuelve a derivar del código |
| Plan de pruebas | Hallazgos resueltos y su numeración | Casos añadidos o editados a mano; los casos se reescriben desde el spec y se renumeran |
| Tarea | Su id | Dependencias, tamaño, criterios y notas que hayas cambiado; `fase` y `prioridad` fijadas, con lo que deja de ser una restricción para el backlog |
| ADR observado | Su id | El texto y la implicación que hayas corregido: se vuelven a derivar del código |

Un ADR que decidiste no se reabre: regenerarlo borraría la decisión. Para cambiarla, `en el ADR 0011 cambio la decisión: elijo <opción>`. Los derivados (`index.md`, `_capacidades.md`, `_auditoria.md`, `_cobertura.md`, `backlog.md`) no tienen estado: se regeneran siempre.

**Si dudas**, pregunta al orquestador: compara versiones y te dice qué quedó desactualizado y con qué prompt regenerarlo.

**Cómo sabe el orquestador qué está desactualizado.** Cada spec, ADR y tarea lleva `rev: <número>` en su cabecera. El número sube cuando cambia el contenido (lo regenera un agente o lo edita el resolver) y no cuando solo cambia el estado. Cada artefacto derivado anota de qué versión salió:

| Artefacto | Anota | Queda desactualizado si |
|---|---|---|
| Tarea | `spec_rev: 2` y `adrs_rev: {0003: 1, 0011: 2}` | el spec o alguno de esos ADRs tiene ahora un `rev` mayor |
| Plan de pruebas | `spec_rev: 2` | el spec tiene un `rev` mayor. Añadir, quitar o regenerar tareas no lo desactualiza |
| Sección de auditoría | `Spec rev: 2.` en su línea `Auditada:` | el spec tiene un `rev` mayor |
| Backlog | columna `Rev` junto a cada tarea | alguna tarea tiene otro `rev`, falta o sobra alguna, o lista un bloqueo que la tarea ya no tiene |

Marcar `revisado` no desactualiza nada. Decidir un ADR sí cambia su contenido: sube su `rev` y las tareas que lo citan quedan pendientes de regenerar.

Si un derivado está `revisado`, su agente no lo sobrescribe. Corrígelo con el resolver y, cuando esté al día, decláralo: `Usa el subagente migration-tl-resolver: registra las versiones de la tarea T-012`.

**Cómo decide el orquestador el siguiente paso.** Siempre igual, con el primero de estos que aplique:

1. Si falta indexar o consolidar, el indexador.
2. Si hay artefactos sin versión registrada, `registra las versiones`.
3. El agente del punto más temprano de la cadena al que le falte algo o tenga algo desactualizado: analista, ADRs, specs, auditor, QA, tareas, PM. Con una capacidad afectada, `solo la capacidad X`; con varias, en paralelo si el agente lo admite.
4. Antes de ese agente pueden cerrarse tres puertas, que se resuelven con el resolver: el destino sin fijar (antes de los ADRs y de las tareas), los ADRs propuestos (antes de las tareas) y los hallazgos `H-n` de QA sin resolver (antes de las tareas). El agente frenado queda como camino alternativo, por si prefieres seguir.
5. Si nada falta ni está desactualizado, no hay agente que ejecutar: queda revisar lo pendiente y empezar a implementar.

Lo que está pendiente de revisión (artefactos en `generado`, preguntas abiertas, hallazgos del auditor, mejoras) aparece en su sección y no cambia el siguiente paso, salvo esas tres puertas.

La respuesta termina con una sección `## Datos` de siete líneas (`agente`, `motivo`, `alcance`, `paralelo`, `faltan`, `desactualizado`, `sin-version`) que resume lo mismo en forma fija. Para ti es redundante; sirve si quieres automatizar algo sobre el orquestador, y es lo que comprueban las pruebas.

El orquestador también informa de la completitud por capacidad: en la línea `Faltan:` dice a qué capacidades les falta spec, tareas o plan, aunque hayas corrido un paso con `solo la capacidad X`.

## 5. Reglas que conviene saber

- `revisado` protege un artefacto: ningún agente generador lo sobrescribe. El resolver marca `revisado` lo que edita, y lo devuelve a un estado regenerable cuando se lo pides con `reabre <artefacto>` o `reabre la capacidad <slug>`, avisando de qué se conserva y qué se pierde al regenerar.
- No edites derivados: `index.md`, `_capacidades.md`, `_auditoria.md`, `_cobertura.md`, `backlog.md`. El resolver se niega y te dice qué agente los regenera.
- Cada regla de un spec cita la línea de código que la respalda. El auditor comprueba esas citas y nunca modifica un spec: informa, y tú corriges con el resolver. Un hallazgo corregido desaparece al repetir la auditoría.
- Los identificadores nunca se renumeran; lo retirado queda marcado como retirado.
- Política de paridad: el destino reproduce el comportamiento del origen. Las mejoras `MJ-n` son opcionales y no bloquean nada; las preguntas abiertas son solo para lo que el código no permite determinar.
- Cuando algo cambia, se regenera lo que viene después en la cadena (sección 4). El orquestador te avisa de lo desactualizado comparando el `rev` de cada artefacto con la versión que anotan sus derivados; las fechas de los archivos no cuentan.
- Si editas a mano el contenido de un spec, un ADR o una tarea, sube su `rev` en 1. Si lo editas con el resolver, lo sube él.

## 6. Si algo falla

| Síntoma | Causa y solución |
|---|---|
| No encontré repositorios | Abre Claude Code en la carpeta padre. |
| Falta el bloque de convenciones en `CLAUDE.md` | Corre `migration-indexer`. |
| El indexador termina con "Índice incompleto" | Se quedó sin capacidad. Vuelve a ejecutar `Usa el subagente migration-indexer`: continúa desde la carpeta que indica, sin repetir lo hecho. |
| El analista se detiene por un índice incompleto | Reanuda el indexador hasta que todos los índices estén completos. |
| Indexaste con `solo el repo X` y los demás agentes dicen que falta el bloque de `CLAUDE.md` | Las corridas con alcance solo escriben el índice de su repositorio. Consolida con `Usa el subagente migration-indexer`. |
| Volviste a correr el indexador y un índice no cambió | El repositorio sigue en el mismo commit. Haz commit de los cambios o fuerza con `migration-indexer, solo el repo X`. |
| `_cobertura.md` no refleja un plan que acabas de regenerar | QA con alcance no lo actualiza. `Usa el subagente migration-qa, solo la cobertura`. |
| `migration-pm` dice que faltan los scripts del flujo | No existe `.claude/migration/backlog.sh` en el proyecto. Instálalos (sección 1) y repite. El PM no calcula el backlog a mano. |
| `migration-pm` se detiene por un ciclo o una dependencia que no existe | Nombra las tareas. Corrige sus `depende_de` con el resolver y repite; mientras tanto no escribe nada. |
| `verificar.sh` marca un tipo de artefacto con FALLA | Cada línea nombra el archivo y qué le falta. Corrígelo con el resolver o repite el agente que lo genera. En un proyecto empezado con una versión anterior de los agentes, lee antes la sección 4. |
| Un verificador dice que una tarea cita una pregunta que no existe | La tarea tiene en `bloqueada_por` un `PA:<capacidad>:<n>` y el spec no tiene `PA-n`. Si la pregunta se respondió o se retiró, quita el bloqueo con el resolver; si se borró a mano, repón la línea con su identificador. |
| Un verificador dice que la sección 12 mezcla preguntas con y sin identificador | Alguien añadió una pregunta a mano sin su `PA-n`. `Usa el subagente migration-tl-resolver: numera las preguntas del spec X` le da el siguiente número. |
| No sé a qué lenguaje se migra | Fija el destino con el resolver. |
| El mapa de destino no cubre el repositorio X | Falta la entrada de ese repositorio: `fija el destino de X en <lenguaje>` o `conserva el repositorio X`. |
| El agente se detiene porque el destino del prompt y el del README difieren | El README manda. Quita el destino del prompt o corrige el README con el resolver. |
| Pediste al resolver que marcara resuelto un hallazgo `AU-n` y se negó | El informe de auditoría es un derivado. Corrige el spec y repite `migration-auditor, solo la capacidad X`: el hallazgo desaparece solo. |
| El auditor marca reglas como "sin cita" | El spec es anterior a las citas o está `revisado`. Si está `generado`, repite `migration-tl-specs`; si está `revisado`, añade las citas con el resolver usando la línea que da cada hallazgo, o reábrelo (`reabre el spec X`) y repite `migration-tl-specs`. |
| El auditor marca muchas reglas como sin respaldo o no localizables a la vez | El código cambió desde que se escribió el spec y las líneas se desplazaron. Mira si avisa de que los commits no coinciden; repite `migration-indexer` y `migration-tl-specs` para esa capacidad. |
| El auditor marca una regla como contradicha y crees que el spec está bien | Abre la línea citada: el veredicto dice qué leyó. Si el auditor se equivoca, deja la regla como está; el informe no cambia nada por sí solo. |
| El orquestador dice "no se puede determinar, no tiene versión registrada" | El proyecto se generó antes de que existieran las versiones. Si sabes que nada cambió desde entonces: `Usa el subagente migration-tl-resolver: registra las versiones`, que pone `rev: 1` y anota en cada tarea y plan la versión actual de sus insumos; luego repite `migration-auditor` y `migration-pm`, que regeneran sus derivados. Si no lo sabes, regenera con el agente de cada paso. |
| Política desconocida | `politica:` en `migration/README.md` tiene un valor distinto de `paridad`. Corrígelo: `Usa el subagente migration-tl-resolver: fija la política en paridad`. |
| Un spec tiene muchas preguntas del tipo "¿se mantiene X o debería ser Y?" | Se generó antes de la política de paridad o quedó `revisado`. Si está `generado`, repite `migration-tl-specs`; si está `revisado`, reclasifica cada pregunta con el resolver, o reábrelo (`reabre el spec X`) y repite `migration-tl-specs`. |
| Aplicaste una mejora y las tareas siguen igual | Aplicar solo cambia el spec. Repite `migration-tl-tasks` y `migration-qa` con `solo la capacidad X`. |
| `migration-tl-tasks` se detiene | Hay ADRs propuestos. Decide con el resolver o fuerza con "aunque haya ADRs propuestos". |
| El resolver no aplicó algo | Revisa la sección "No aplicado" de su resumen: id inexistente u orden ambigua. |
| El PM reporta un ciclo | Corrige `depende_de` con el resolver y repite el PM. |
| Una tarea o un spec no cambió al repetir el agente | Está `revisado`. Reábrelo con el resolver (`reabre el spec X`, `reabre la tarea T-012`), lee qué se pierde al regenerar y repite el agente (sección 4). |
| El orquestador dice que un plan o una tarea `revisado` está desactualizado | Su agente no lo sobrescribe. O lo corriges con el resolver y lo declaras al día con `registra las versiones de <artefacto>`, o lo reabres con `reabre <artefacto>` y repites el agente. |
| Pediste reabrir un ADR y el resolver se negó | Es un ADR decidido. Para cambiar la decisión: `en el ADR NNNN cambio la decisión: elijo <opción>`. |
| No sabes qué sigue | `Usa el subagente migration-orchestrator`. |
