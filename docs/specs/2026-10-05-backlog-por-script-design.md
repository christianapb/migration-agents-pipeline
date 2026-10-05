# Backlog calculado por script y verificadores para el usuario: diseño

Fecha: 2026-10-05
Estado: aprobado para implementar (sigue la propuesta del encargo; las decisiones propias están en §2)
Modifica: `docs/specs/2026-09-29-migration-agents-v2-design.md` (v2), en lo relativo a `migration-pm` y a la instalación. Convive con la política de paridad, la evidencia por regla y el auditor, el destino por repositorio, las versiones de artefactos, el paralelo por capacidad y los planes antes que las tareas.

## 1. Propósito

**El PM calcula a mano.** `migration-pm` valida referencias, detecta ciclos, cuenta dependientes transitivos, asigna prioridades y reparte fases leyendo frontmatter. Con 20 tareas funciona; con 200 no hay motivo para esperar que un modelo haga bien un recorrido de grafo de memoria, y el error no se nota: el backlog sale con buen aspecto y orden equivocado. Además, varias reglas eran blandas ("procura que no supere 12 puntos") o se apoyaban en datos que no existen ("capacidades con más dependientes en `_capacidades.md`"), y ninguna prueba plantaba un ciclo.

**Los verificadores no salen del repo.** `scripts/verify-*.sh` son lo único determinista que hay y solo los usan las pruebas. Tampoco se podían entregar: toman por defecto `.work/sample-workspace`, cargan bibliotecas desde la raíz del repo y mezclan comprobaciones genéricas con otras propias del fixture, activas por defecto.

**Criterio de éxito:** un script valida el grafo y calcula prioridades y fases, siempre con la misma salida para la misma entrada; `migration-pm` usa ese resultado sin recalcular; ante un ciclo o una dependencia rota no se escribe nada, y hay prueba de ello; quien usa el flujo verifica su carpeta con un comando; las comprobaciones del fixture siguen para las pruebas y no corren en el proyecto de un usuario.

## 2. Decisiones

| Tema | Decisión |
|---|---|
| Lenguaje | Bash que envuelve un único programa `gawk`. Sin dependencias nuevas: el README ya exige utilidades GNU. Un solo proceso lee todas las tareas, lo que importa en Windows, donde lanzar procesos es caro. |
| Script | `backlog.sh <validar\|calcular\|aplicar> [carpeta]`. La carpeta por defecto es la actual. |
| Cómo lo usa el PM | Opción A: `migration-pm` recibe Bash, limitado en su prompt a ejecutar ese script. Un solo paso para el usuario. |
| Script ausente | El PM lo dice y se detiene. No calcula a mano. |
| Ubicación en el proyecto | `.claude/migration/`, junto a `.claude/agents/`. Solo en el proyecto, no en `~/.claude`. |
| Instalación | `scripts/install.sh <carpeta-del-proyecto>` copia agentes y scripts al proyecto. Sin argumento sigue copiando solo los agentes a `~/.claude/agents/` y avisa de que faltan los scripts. |
| Verificación para el usuario | `verificar.sh [carpeta]`: ejecuta los verificadores que apliquen según lo que exista y resume por tipo de artefacto. |
| Comprobaciones del fixture | Desactivadas por defecto. Las pruebas las activan con `FIXTURE=1`. |
| Quién recomienda verificar | El tutorial, el resumen final del PM y una línea fija en la salida del orquestador. El orquestador sigue sin Bash. |
| `migration-indexer` | No se toca: no se invalidan las instantáneas anteriores a `pm`. |

### 2.1 Por qué la opción A

Con la opción B el paso 7 serían dos acciones y el usuario tendría que saber cuándo repetir cada una. La restricción de Bash a un solo comando ya tiene precedente en `migration-tl-resolver`. El riesgo de que el PM use Bash para otra cosa se acota en el prompt y con una prueba: ante un ciclo, ningún archivo cambia.

### 2.2 Por qué los scripts viven solo en el proyecto

El PM busca el script en una única ruta, relativa a la carpeta donde trabaja. Así "no está instalado" es un estado comprobable y la prueba no depende de lo que haya en el `~/.claude` de quien la ejecuta. También deja el comando de verificación igual para todos: `bash .claude/migration/verificar.sh`.

## 3. Reglas exactas del backlog

Entrada: el frontmatter de `migration/tasks/T-*.md`, el de `migration/adr/*.md` (`id`, `titulo`, `estado`, `implicacion_migracion`), las filas de `migration/specs/_capacidades.md` (solo su orden) y la existencia de `migration/test-plans/<spec>.md`.

Los ids se comparan por su número y, a igualdad, como texto. Ningún resultado depende del orden en que se listan los archivos.

### 3.1 Validación

Cualquiera de estos problemas hace que `validar` termine con código distinto de cero y la lista completa, y que `calcular` y `aplicar` no hagan nada:

- `no existe`: un `depende_de` nombra un id sin tarea. Se nombra la tarea y el id.
- `ciclo`: tras retirar repetidamente las tareas sin dependencias pendientes y las tareas de las que nadie pendiente depende, lo que queda está en un ciclo. Se nombran todas, y un recorrido de ejemplo desde la de menor id. Una tarea que depende de sí misma es un ciclo.
- `id duplicado`: dos archivos con el mismo `id`.
- `fundacional depende de capacidad`: una tarea sin `spec` depende de una con `spec`. El hito 0 no podría contener solo fundacionales.

### 3.2 Puntos

`S` = 1, `M` = 2, `L` = 4. Un tamaño ausente o distinto cuenta como `M` y se avisa.

### 3.3 Dependencias entre capacidades

La capacidad de una tarea es su `spec`. Una capacidad A depende de B cuando alguna tarea de A depende directamente de una tarea de B, con A distinta de B. "Dependientes de una capacidad" es el número de capacidades que dependen de ella, directa o indirectamente. `_capacidades.md` solo aporta el orden de sus filas.

### 3.4 Orden de las capacidades

Se eligen una a una. En cada paso son candidatas las capacidades cuyas dependencias ya están elegidas; si no hay ninguna (ciclo entre capacidades), todas las restantes. Entre las candidatas gana, por este orden:

1. más dependientes (§3.3);
2. tener alguna tarea que cite un ADR con `implicacion_migracion` `reemplazar` o `reevaluar`;
3. aparecer antes en `_capacidades.md` (las que no figuran van al final);
4. slug en orden alfabético.

### 3.5 Fases

- **Hito 0:** exactamente las tareas sin `spec`.
- **Reparto de capacidades**, en el orden de §3.4, empezando en la fase 1 con 0 puntos: si la fase ya tiene puntos y sumarle la capacidad entera supera 12, se abre la fase siguiente. La capacidad entra completa en la fase abierta. El límite de 12 es duro para juntar capacidades y no para partirlas: una capacidad que sola supera 12 ocupa una fase propia y no se divide por tamaño.
- **Fase de cada tarea:** la de su capacidad, o la mayor fase de sus dependencias si es posterior. Es el único caso en que una capacidad se parte: cuando una tarea suya depende de otra situada en una fase posterior (solo ocurre con ciclos entre capacidades o con tareas fijadas). Se informa como "capacidad partida".
- Los puntos de cada fase se informan con el reparto final. Una fase puede superar 12 por una capacidad grande o por tareas desplazadas; se lista en los datos de riesgos.

### 3.6 Prioridad

Entero único desde 1; 1 es la más alta. Las tareas se numeran por fase ascendente y, dentro de cada fase, eligiendo una a una entre las que ya tienen numeradas todas sus dependencias de esa fase. Gana, por este orden:

1. más tareas que dependen de ella, directa o indirectamente;
2. citar un ADR con `implicacion_migracion` `reemplazar` o `reevaluar`;
3. capacidad anterior en el orden de §3.4;
4. id menor.

Como el último criterio es el id, no queda ningún empate. La prioridad respeta siempre las dependencias: ninguna tarea tiene un número menor que una de la que depende. La columna `Orden` del backlog es esta prioridad.

### 3.7 Tareas `revisado`

Una tarea con `estado: revisado` y con `fase` y `prioridad` numéricas las conserva: `aplicar` no la toca. Su fase cuenta para las tareas que dependen de ella. Los números de prioridad que ocupa se saltan al numerar las demás. Se informa como conflicto, sin detenerse, si su fase es anterior a la de una dependencia, si su prioridad es menor que la de una dependencia, o si dos tareas fijadas comparten prioridad.

### 3.8 Camino crítico

La cadena de dependencias con más puntos. A igualdad, la que termina en el id menor y, hacia atrás, la que pasa por la dependencia de id menor.

### 3.9 `aplicar`

Reescribe solo las líneas `fase:` y `prioridad:` del frontmatter de cada tarea no fijada. No cambia `rev` ni ninguna otra línea, ni los finales de línea.

## 4. Salida de `calcular`

Markdown por la salida estándar, para pegar sin reinterpretar:

- `## Fases`: por cada fase, `### Hito N: <nombre>`, sus puntos y la tabla `Orden | Tarea | Rev | Título | Tamaño | Depende de | Plan de pruebas`. El hito 0 se llama "fundaciones"; los demás, la lista de sus capacidades.
- `## Bloqueos`: la tabla de tareas bloqueadas por ADRs, el resumen de cuántas tareas desbloquea cada ADR, y la tabla de tareas bloqueadas por preguntas abiertas con la pregunta citada desde el spec.
- `## Datos`: totales, puntos por fase, bloqueadas solo por ADRs y por preguntas, camino crítico y sus tareas `L`, capacidades partidas, capacidades sin plan de pruebas, fases que superan 12 puntos, conflictos con tareas fijadas, dependencias entre capacidades y dependientes transitivos por tarea.

`calcular --tsv` imprime `id`, fase y prioridad separados por tabulador; lo usa `verify-pm.sh`.

## 5. `migration-pm`

Recibe Bash, solo para `bash .claude/migration/backlog.sh <modo>`. Su prompt deja de describir algoritmos:

1. Si el script no existe, responde que faltan los scripts del flujo y cómo instalarlos, y se detiene sin escribir.
2. `validar`. Si falla, responde con su salida y se detiene sin escribir ni modificar nada.
3. `calcular`. Copia tal cual `## Fases` y `## Bloqueos` en `backlog.md`. Escribe con criterio el resumen ejecutivo y los riesgos, a partir de `## Datos`, las mejoras sin decidir y los repositorios conservados.
4. `aplicar`.
5. Sección "Cómo empezar a implementar" del README, como hoy.

## 6. Verificadores

- Cada `verify-*.sh` resuelve `lib-rev.sh` y `lib-destino.sh` respecto a su propia carpeta y toma por defecto la carpeta actual (`WORKDIR` la cambia).
- Propias del fixture, ahora solo con `FIXTURE=1`: en `verify-tl-specs.sh`, el producto oculto (`REQUIRE_AMBIGUEDAD`); en `verify-tl-adrs.sh`, que exista algún ADR propuesto (`REQUIRE_PROPUESTO`); en `verify-analyst.sh`, el mínimo de 3 capacidades (`MIN_CAPACIDADES`, que pasa a 1); en `verify-indexer.sh`, los repositorios `frontend` y `bff` y sus listas de archivos esperados y excluidos. La parte genérica de `verify-indexer.sh` recorre los repositorios detectados.
- `verify-pm.sh` compara las tareas y las filas del backlog con `backlog.sh calcular --tsv`, además de lo que ya comprobaba.
- `verify-idempotency.sh` lanza un agente: no se distribuye.
- `verificar.sh [carpeta]` ejecuta, según lo que exista: índices y bloque, mapa de capacidades, ADRs, specs, planes, tareas, auditoría y backlog. Imprime una línea por tipo (`OK` o `FALLA` con los mensajes, que nombran el archivo) y termina con código distinto de cero si algo falla.

## 7. Instalación y pruebas

- `scripts/lib-dist.sh` define la lista de scripts que se distribuyen y la función que los copia. La usan `install.sh` y `snapshot.sh`, que deja los scripts en `.claude/migration/` de cada workspace de prueba. La huella de la etapa `pm` incluye `backlog.sh`.
- `test-backlog.sh` (sin agentes): ciclo de dos y ciclo largo; dependencia rota; las 25 tareas del fixture; determinismo, también con los archivos en otro orden; 200 tareas sintéticas con su tiempo; tarea fijada; `aplicar` no cambia nada más que `fase` y `prioridad`.
- `test-verificar.sh` (sin agentes): workspace válido; defecto plantado; ejecución fuera del repo con los scripts copiados a una carpeta temporal.
- `test-pm.sh` (con agentes): ciclo plantado sobre la etapa `tl-tasks` (menciona el ciclo, nombra las dos tareas, ningún archivo cambia) y script ausente (se detiene y lo dice).

## 8. Fuera de alcance

- **Lo desactualizado por script.** La detección que hace el orquestador (comparar `rev` con `spec_rev`, `adrs_rev`, `Spec rev:` y la columna `Rev`) es el mismo tipo de cálculo. Encajaría como `estado.sh`, con una salida que el orquestador leyera en lugar de deducirla. El obstáculo es que el orquestador no tiene Bash y no debe tenerlo: haría falta que el usuario ejecutara el script o que lo hiciera otro agente. No se hace aquí.
- Estimación de fechas o asignación de personas.
- Reparto por repositorio destino o por equipo.
