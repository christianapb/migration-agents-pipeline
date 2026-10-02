# Indexador reanudable y pasos en paralelo: diseño

Fecha: 2026-10-01
Estado: pendiente de revisión escrita
Modifica: `docs/specs/2026-09-29-migration-agents-v2-design.md` (v2) y se integra con la política de paridad, la evidencia por regla y el auditor, el destino por repositorio y las versiones de artefactos (los cuatro del 2026-10-01, ya en `master`). Lo que este documento no cambia sigue rigiendo según esos.

## 1. Propósito

El flujo solo se ha probado con un fixture de dos repositorios y unos veinte archivos. Con un proyecto real no termina:

1. El indexador hace todo en una corrida y un contexto: lee cada archivo de todos los repositorios.
2. No se puede reanudar. Prevé el corte (`> Índice incompleto: falta desde <carpeta>`), pero la corrida siguiente sobrescribe el índice entero y se corta en el mismo sitio.
3. El bloque de `CLAUDE.md` y `migration/` se escriben después de indexar. Si se corta indexando, no existen, y todos los demás agentes se niegan a trabajar.
4. Los pasos por capacidad (specs, planes) procesan todas las capacidades en una corrida, y el orquestador nunca propone repartirlas.

**Criterio de éxito:** una corrida cortada del indexador se continúa sin repetir lo hecho; el indexador se puede acotar a un repositorio y lanzar varias veces a la vez; un corte no deja el proyecto sin bloque ni sin `migration/`; el orquestador entrega la forma de lanzar en paralelo los pasos que lo admiten; y lanzar en paralelo no produce ids duplicados ni derivados pisados.

**Límite de este cambio:** el fixture no permite comprobar el comportamiento con miles de archivos. Las pruebas plantan el corte; no demuestran escala (§9).

## 2. Decisiones

| Tema | Decisión |
|---|---|
| Orden del indexador | Primero `migration/`, plantillas y bloque de `CLAUDE.md`; después el índice de cada repositorio; al final el índice general. |
| Reanudar | Un índice que termina con la línea de incompleto se continúa desde la carpeta indicada, conservando lo escrito. |
| Alcance | Frase nueva `solo el repo <nombre>`. Una corrida con alcance solo escribe `<repo>/index.md`. |
| Corrida sin alcance | Completa lo que falta: indexa los repositorios sin índice, reanuda los incompletos y deja como están los completos cuyo commit no cambió. Escribe siempre lo compartido. |
| Índice completo y vigente | El encabezado de cada índice anota `Commit:`. Un índice completo se conserva si ese commit es el `HEAD` actual; si difiere, o el repositorio no tiene git, se regenera. |
| Forzar la regeneración | `solo el repo <nombre>` sobre un índice completo lo regenera entero. |
| Alcance por carpeta | No se añade (§3.5). |
| `migration-analyst` ante un índice incompleto | Se detiene y pide reanudar el indexador. |
| Paralelo en el orquestador | Un solo bloque copiable que pide a la sesión principal lanzar el subagente una vez por capacidad en el mismo mensaje. A partir de 2 pendientes; en tandas de 5 como máximo. |
| Seguro en paralelo | `migration-indexer` con alcance, `migration-tl-specs` con alcance, `migration-qa` con alcance. |
| En serie | `migration-tl-tasks`, `migration-auditor`, `migration-tl-adrs`, `migration-pm`, `migration-analyst`, `migration-tl-resolver`. |
| `_cobertura.md` | Una corrida de QA con alcance no lo escribe. Frase nueva `solo la cobertura`, que lo regenera a partir de los planes existentes sin tocarlos. |

## 3. Indexador

### 3.1 Orden

1. Detectar repositorios.
2. `migration/`: README y plantillas (solo las que no existan).
3. Bloque de `CLAUDE.md`.
4. Índice de cada repositorio, uno tras otro.
5. Índice general.

Un corte durante el paso 4 deja el bloque y `migration/` escritos, y sin índice general. El orquestador lo reconoce (§5.1) y el siguiente paso es volver a ejecutar el indexador.

### 3.2 Qué hace con cada repositorio

| Estado de `<repo>/index.md` | Corrida sin alcance | Corrida `solo el repo <repo>` |
|---|---|---|
| No existe | Lo indexa | Lo indexa |
| Termina con la línea de incompleto | Lo reanuda | Lo reanuda |
| Completo, `Commit:` igual al `HEAD` actual | No lo toca | Lo regenera entero |
| Completo, `Commit:` distinto, ausente o `sin-git` | Lo regenera entero | Lo regenera entero |

Así, consolidar después de varias corridas con alcance no reindexa nada, y volver a ejecutar el indexador tras un corte solo hace lo que falta. Sobre el fixture limpio una corrida sin alcance produce lo mismo que hoy, más la línea `Commit:`.

Límite conocido: cambios sin commit en un repositorio con git no se detectan. Se fuerza con `solo el repo <repo>`.

### 3.3 Reanudar

El encabezado del índice añade `Commit: <hash corto o sin-git>`. Al reanudar:

1. Lee el índice existente y la carpeta de la línea `> Índice incompleto: falta desde <carpeta>`.
2. Vuelve a obtener la lista de archivos del repositorio (paso barato: no lee contenidos).
3. Por cada carpeta ya escrita, compara los nombres de archivo de su sección con la lista. Si coinciden, la conserva sin releer nada. Si sobra o falta algún archivo, rehace solo esa sección.
4. Quita la línea de incompleto y sigue añadiendo secciones desde la carpeta indicada, con el mismo procedimiento incremental.
5. Si el `Commit:` del encabezado difiere del actual, lo dice en el resumen: las secciones conservadas pueden describir contenido anterior. No las rehace; para rehacerlas se borra el índice o se usa `solo el repo <repo>` cuando esté completo.
6. Al terminar actualiza `Commit:` y `Generado:` del encabezado. Si vuelve a quedarse sin capacidad, deja de nuevo la línea de incompleto con la carpeta siguiente.

### 3.4 Escrituras compartidas

Una corrida con alcance solo escribe `<repo>/index.md`: ni `migration/`, ni `CLAUDE.md`, ni el índice general. Varias corridas con alcance, una por repositorio, no comparten ningún archivo.

Tras ellas, una corrida sin alcance consolida: escribe `migration/`, el bloque y el índice general, y por la tabla de §3.2 no vuelve a indexar los repositorios ya completos. Si el nombre del alcance no es un repositorio detectado, el agente se detiene sin escribir y lista los disponibles.

Consecuencia: tras solo corridas con alcance no hay bloque de `CLAUDE.md`. El orquestador lo trata como estado propio (§5.1) y recomienda consolidar.

### 3.5 Por qué no hay alcance por carpeta

Reanudar ya permite indexar un repositorio muy grande en varias corridas sucesivas, cada una con contexto nuevo. Un alcance por carpeta solo añadiría paralelismo dentro de un repositorio, y a cambio varias corridas escribirían secciones del mismo `index.md` a la vez, que es justo el problema de escrituras compartidas que el alcance por repositorio evita. Si la escala real mostrara que hace falta, la forma sería un índice por carpeta de primer nivel más un consolidado; queda anotado y no se hace.

## 4. Pasos por capacidad en paralelo

### 4.1 `migration-tl-specs`

Sin cambios de comportamiento: cada corrida con alcance escribe solo `specs/<slug>.md`. Se añade la frase explícita: con alcance no escribe ni modifica ningún otro archivo.

### 4.2 `migration-qa`

- Con `solo la capacidad <slug>`: escribe solo `test-plans/<slug>.md`. No escribe `_cobertura.md`. Su resumen final indica que falta consolidar la cobertura.
- Con `solo la cobertura`: lee todos los planes existentes y regenera `_cobertura.md`. No toca ningún plan.
- Sin alcance: como hoy, todos los planes y la cobertura.
- `_cobertura.md` añade la columna `Spec rev` con el `spec_rev` de cada plan. Así el orquestador detecta, comparando valores, que la cobertura no tiene fila para un plan o resume una versión anterior.

### 4.3 `migration-tl-tasks`: en serie

Numera las tareas nuevas desde el número más alto existente y crea las fundacionales que falten. Dos corridas a la vez producirían ids `T-NNN` duplicados y fundacionales repetidas. Reservar rangos por capacidad rompería la numeración correlativa y el emparejamiento por título en las recorridas, y no resuelve las fundacionales. Se deja en serie; el orquestador lo sabe y lo dice.

### 4.4 `migration-auditor`: en serie

Con alcance reescribe `_auditoria.md` entero conservando las demás secciones. Dos corridas a la vez se pisarían. No se rediseña aquí.

### 4.5 `migration-analyst`

Si algún índice termina con la línea de incompleto, se detiene sin escribir y pide reanudar el indexador. Un mapa de capacidades construido sobre un índice parcial omite capacidades sin que nada lo señale después.

## 5. Orquestador

### 5.1 Paso 1 y estados del indexador

El paso 1 está completado si existen el bloque, `migration/README.md`, el índice general, y cada repositorio detectado tiene `index.md` sin la línea de incompleto.

| Situación | Siguiente paso |
|---|---|
| Nada indexado, un repositorio | `Usa el subagente migration-indexer` |
| Nada indexado, dos o más repositorios | Paralelo: un `solo el repo <nombre>` por repositorio, y después consolidar |
| Un repositorio sin índice o incompleto | `Usa el subagente migration-indexer` (reanuda y consolida en la misma corrida) |
| Dos o más repositorios sin índice o incompletos | Paralelo con alcance, y después consolidar |
| Índices completos y falta el bloque, `migration/` o el índice general | `Usa el subagente migration-indexer` (consolida) |

Como el bloque puede no existir todavía, el orquestador conoce la frase `solo el repo <nombre>` por su propio prompt, además de por el bloque. Sin bloque, detecta los repositorios con la misma regla que el indexador.

### 5.2 Forma del paralelo

La sección "Siguiente paso" sigue siendo un solo paso, con un solo bloque copiable:

```
Lanza estos subagentes en paralelo, en un mismo mensaje:
- Usa el subagente migration-tl-specs, solo la capacidad autenticacion
- Usa el subagente migration-tl-specs, solo la capacidad carrito
- Usa el subagente migration-tl-specs, solo la capacidad listado-productos
```

- Un bloque y no varios prompts sueltos porque los subagentes no pueden lanzar otros: el reparto lo hace la sesión principal, y pegar el bloque entero es lo que lo provoca.
- Se propone a partir de 2 capacidades (o repositorios) pendientes. Con 1, el prompt normal con alcance.
- Como máximo 5 por tanda. Si hay más, lista las cinco primeras, dice cuántas quedan y pide volver a consultar al orquestador al terminar.
- Para `migration-qa` e indexador con alcance, el bloque termina con la línea de consolidación: `Cuando terminen: Usa el subagente migration-qa, solo la cobertura` o `Cuando terminen: Usa el subagente migration-indexer`.
- Aplica igual cuando lo pendiente es regenerar lo desactualizado: varios planes con `spec_rev` atrasado se regeneran en paralelo.
- Para `migration-tl-tasks` y `migration-auditor` nunca propone paralelo, aunque haya varias capacidades pendientes: un solo prompt, y una línea que dice que ese paso va en serie.

### 5.3 Cobertura

`_cobertura.md` está desactualizado si algún plan no tiene fila o la columna `Spec rev` de su fila difiere del `spec_rev` del plan. Se regenera con `Usa el subagente migration-qa, solo la cobertura`. El paso 6 no está completado sin él.

## 6. Verificadores y pruebas

**Sin agentes** (`test-fast.sh`):

- `verify-indexer.sh`: `Commit:` en el encabezado de cada índice; las frases nuevas en el bloque.
- `verify-qa.sh`: cada plan tiene fila en `_cobertura.md`, con su `spec_rev`. `test-verifiers.sh`: rechaza una cobertura sin la fila de un plan y con un `Spec rev` distinto.
- `test-prompts.sh`: el orden de secciones del indexador (el bloque antes que los índices), la reanudación, el alcance, la regla de QA con alcance, la parada del analista, y en el orquestador el paralelo y los pasos en serie.

**Con agentes:**

`test-indexer-escala.sh` (nuevo):

1. Reanudación. Sobre la instantánea `indexer`: recorta el índice de un repositorio al encabezado y la primera sección, pone una marca en esa sección y añade la línea de incompleto. Ejecuta el indexador. Comprueba: índice completo, sin la línea, la marca sigue, el índice del otro repositorio no cambió, `verify-indexer.sh` pasa.
2. Alcance. Sobre `fixture`: `solo el repo bff`. Comprueba: existe `bff/index.md`; no existen `frontend/index.md`, `CLAUDE.md`, `migration/` ni el índice general.
3. Consolidación. Ejecuta el indexador sin alcance. Comprueba: `bff/index.md` no cambió, existe todo lo demás, `verify-indexer.sh` pasa.

`test-paralelo.sh` (nuevo):

1. Sobre la instantánea `tl-adrs`, sin specs: lanza a la vez `migration-tl-specs` para las tres capacidades, en el mismo workspace. Comprueba que hay tres specs y `verify-tl-specs.sh` pasa.
2. Sobre la instantánea `tl-tasks`: lanza a la vez `migration-qa` para las tres capacidades. Comprueba que hay tres planes y que no se escribió `_cobertura.md`. Ejecuta `solo la cobertura`: los planes no cambian y `verify-qa.sh` pasa.

`test-orchestrator.sh`:

- Con el mapa y los ADRs hechos y ningún spec: el siguiente paso propone el paralelo y nombra las tres capacidades.
- Con un índice incompleto: el siguiente paso es el indexador y la salida nombra ese repositorio.
- Con specs hechos y sin tareas: no propone paralelo.

`test-analyst.sh`: con un índice incompleto, se detiene sin escribir.

## 7. Compatibilidad

- Índices anteriores sin `Commit:` se regeneran en la siguiente corrida sin alcance (cuentan como commit distinto).
- `_cobertura.md` anterior sin columna `Spec rev`: el orquestador lo da por desactualizado; se regenera con `solo la cobertura`.
- Cambia un comportamiento: volver a ejecutar el indexador ya no reescribe los índices completos de repositorios cuyo commit no cambió. El tutorial lo explica y da la forma de forzarlo.
- Cambia otro: `migration-qa, solo la capacidad X` ya no actualiza `_cobertura.md`.

## 8. Documentación

`docs/tutorial.md`: cómo indexar un proyecto grande (alcance, reanudar, consolidar) en el paso 1; la tabla "Si vuelves a correr el indexador"; cómo lanzar specs y planes en paralelo y qué pasos van en serie; filas nuevas en la tabla de fallos. `README.md`: convenciones y pruebas.

## 9. Fuera de alcance

- **Reindexado incremental por archivo.** Con el `Commit:` ya anotado en el encabezado, la continuación natural es pedir a git los archivos que cambiaron entre ese commit y `HEAD` y rehacer solo sus líneas. Este cambio solo decide a nivel de repositorio entero.
- **Prueba de escala real.** Haría falta un repositorio de varios miles de archivos, medir cuántas corridas necesita el indexador para completarlo, comprobar que la reanudación converge y que el índice resultante sigue siendo utilizable por el analista (un índice de miles de líneas puede no caber en su contexto).
- Alcance por carpeta, paralelo en `migration-tl-tasks` y en `migration-auditor`.
- Que el analista trabaje por repositorio o por partes del índice.
