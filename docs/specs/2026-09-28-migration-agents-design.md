# Agentes de migración: diseño

Fecha: 2026-09-28
Estado: aprobado en conversación, pendiente de revisión escrita

## 1. Propósito

Un conjunto de cuatro subagentes de Claude Code que, a partir del código de un proyecto existente compuesto por varios repositorios (en el caso inicial, un frontend y un backend for frontend en JavaScript), generan la documentación necesaria para reimplementar el proyecto en otro lenguaje (en el caso inicial, Kotlin): índices de código, ADRs, specs por capacidad funcional, tareas de implementación, planes de prueba y un backlog priorizado.

Los agentes son agnósticos al stack de origen y al lenguaje destino. El destino es un parámetro.

**Criterio de éxito:** un desarrollador o agente que solo lea `migration/` puede reconstruir el sistema en el lenguaje destino sin abrir el código original, y un revisor humano puede validar cada paso antes de que empiece el siguiente.

## 2. Decisiones acordadas

| Tema | Decisión |
|---|---|
| Forma del entregable | Subagentes de Claude Code (`agents/*.md`), copiables a `~/.claude/agents/`. |
| Orquestación | Invocación manual, uno por uno, con revisión humana entre pasos. No hay comando orquestador. |
| Ubicación de artefactos | `migration/` en la carpeta padre que contiene los repos. Solo `index.md` va dentro de cada repo. |
| Formato de tareas | Markdown, una tarea por archivo, más `backlog.md`. |
| Granularidad de specs | Por capacidad funcional, cruzando repos. Sin código del lenguaje origen. |
| Planes de prueba | Uno por spec, casos en Given/When/Then, en Markdown. Sin código de test. |
| Idioma de artefactos | Español. |
| Plantillas | El indexador bootstrapea `migration/templates/`; los demás agentes leen de ahí. |
| Lenguaje destino | Parámetro del tech lead, tomado del prompt o del frontmatter de `migration/README.md`. |

## 3. Estructura de archivos

### 3.1 Este repositorio (`spec-agent`)

```
spec-agent/
├── agents/
│   ├── migration-indexer.md
│   ├── migration-techlead.md
│   ├── migration-qa.md
│   └── migration-pm.md
├── fixtures/
│   └── sample-workspace/
│       ├── frontend/
│       └── bff/
├── docs/
│   ├── specs/
│   └── plans/
└── README.md
```

`README.md` explica cómo instalar los agentes (copiar o enlazar `agents/*.md` a `~/.claude/agents/`) y cómo invocarlos.

### 3.2 Espacio de trabajo del usuario

Claude Code se abre en la carpeta padre que contiene los repos. Tras correr los cuatro agentes:

```
mi-proyecto/
├── frontend/                # repo git
│   └── index.md
├── bff/                     # repo git
│   └── index.md
└── migration/
    ├── README.md            # flujo, estado de cada paso, destino, cómo continuar
    ├── templates/
    │   ├── adr.md
    │   ├── spec.md
    │   ├── task.md
    │   ├── test-plan.md
    │   └── backlog.md
    ├── adr/                 # 0001-<slug>.md ...
    ├── specs/
    │   ├── _capacidades.md
    │   └── <capacidad>.md
    ├── tasks/               # T-001-<slug>.md ...
    ├── test-plans/
    │   ├── _cobertura.md
    │   └── <capacidad>.md
    └── backlog.md
```

Los nombres `frontend` y `bff` son ilustrativos. Los agentes detectan repos, no asumen nombres ni cantidad.

## 4. Flujo de invocación

Siempre desde la carpeta padre.

1. `migration-indexer` → `index.md` en cada repo, bootstrap de `migration/`.
2. Revisión humana. Rellenar `destino:` en `migration/README.md` si no se va a pasar por prompt.
3. `migration-techlead` (con destino) → `_capacidades.md`, ADRs, specs, tareas.
4. Revisión humana: cerrar preguntas abiertas, aceptar o cambiar ADRs propuestos, marcar artefactos como `estado: revisado`.
5. `migration-qa` → planes de prueba y `_cobertura.md`.
6. `migration-pm` → `backlog.md`, fase y prioridad en cada tarea, README actualizado.

QA y PM son independientes entre sí. Su orden relativo no importa.

## 5. Reglas transversales

Aplican a los cuatro agentes.

- **Detección de repos.** Un repo es cualquier subcarpeta directa de la carpeta actual que contenga `.git`, `package.json`, `pom.xml`, `build.gradle` o `build.gradle.kts`, `go.mod`, `pyproject.toml`, `Cargo.toml` o `composer.json`. Si no se detecta ninguno, el agente se detiene y explica que debe abrirse desde la carpeta padre.
- **Verificación de insumos.** Cada agente comprueba que existan los artefactos del paso anterior. Si faltan, se detiene con un mensaje que nombra el agente a correr antes.
- **Resumen final.** Cada agente termina con: archivos creados, archivos modificados, lo que no pudo resolver, y el siguiente paso.
- **Idempotencia y respeto del trabajo humano.** Todo artefacto generado lleva frontmatter con `estado`. Los valores posibles son `generado` (lo escribió un agente), `revisado` (un humano lo validó) y, solo en ADRs, `observado` y `propuesto`. Al volver a correr, un agente regenera los artefactos en `generado`, `observado` y `propuesto`, y no toca los marcados `revisado`. Los artefactos puramente derivados (`index.md`, `_capacidades.md`, `_cobertura.md`, `backlog.md`) se regeneran siempre.
- **Acotación.** Tech lead y QA aceptan un alcance en el prompt ("solo la capacidad checkout", "solo la fase 1"). Sin alcance, hacen todo.
- **Idioma.** Todo el contenido generado va en español. Los identificadores técnicos (rutas, nombres de campos, códigos de error) se conservan tal como están en el código.
- **Sin código de origen en specs.** Los specs describen comportamiento, contratos y datos. No incluyen fragmentos del lenguaje origen. La sección de evidencia cita rutas de archivo, no contenido.
- **Herramientas.** Los agentes usan Read, Glob, Grep, Bash (solo para `git ls-files` y listados) y Write/Edit. No instalan nada ni ejecutan el código del proyecto.

## 6. Agente 1: `migration-indexer`

**Propósito.** Dar a los demás agentes un mapa fiel del código y preparar `migration/`.

**Entradas.** La carpeta actual.

**Proceso.**

1. Detecta repos según la regla transversal.
2. Por cada repo, obtiene la lista de archivos candidatos: `git ls-files` si hay `.git`; si no, listado recursivo excluyendo `node_modules`, `.git` y equivalentes.
3. Aplica exclusiones fijas sobre esa lista: lockfiles (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`), binarios e imágenes, fuentes, `dist/`, `build/`, `out/`, `coverage/`, `.next/`, `.nuxt/`, archivos minificados (`*.min.*`), snapshots de test (`__snapshots__/`), fixtures de test mayores a 50 KB, y archivos generados (`*.generated.*`, `*.d.ts` producidos por build). Los archivos de configuración relevantes se conservan: `package.json`, configs de build y lint, `tsconfig*.json`, `.env.example`, Dockerfiles, configs de CI.
4. Lee cada archivo conservado y escribe dos líneas: qué contiene y para qué se usa. Para archivos mayores a 300 líneas lee el encabezado, los exports y las firmas de funciones y clases, y lo indica en el resumen.
5. Escribe `index.md` en la raíz del repo, procesando carpeta por carpeta y añadiendo al archivo de forma incremental. Si el agente se corta, el índice queda parcial y termina con la línea `> Índice incompleto: falta desde <carpeta>`. Una corrida posterior regenera desde cero.
6. Bootstrapea `migration/` si no existe: `README.md` y `templates/`. Si `templates/` ya existe, no toca ningún archivo que ya esté dentro.

**Formato de `index.md`.**

```markdown
# Índice: <nombre del repo>

Stack: <lenguaje, runtime, frameworks principales>
Entrada: <archivo o comando de arranque>
Build: <comando>. Tests: <comando y framework>.
Dependencias clave: <lista corta>
Generado: <fecha> por migration-indexer

## <carpeta>
- `<archivo>` — <línea 1: qué contiene>. <línea 2: para qué se usa o quién lo consume>.
```

**Formato de `migration/README.md` inicial.**

```markdown
---
destino:
generado: <fecha>
---
# Migración

## Flujo
1. [x] migration-indexer — <fecha>
2. [ ] migration-techlead — indicar destino arriba o en el prompt
3. [ ] migration-qa
4. [ ] migration-pm

## Repos detectados
- <repo>: <stack en una línea>

## Cómo continuar
<instrucciones de invocación del siguiente agente>
```

**Idempotencia.** Regenera `index.md` completo siempre. Nunca sobreescribe plantillas ni README existentes; solo el PM actualiza el README después.

## 7. Agente 2: `migration-techlead`

**Propósito.** Investigar el código, documentar las decisiones arquitectónicas que contiene, especificar cada capacidad funcional y derivar tareas de implementación para el destino.

**Entradas.** `index.md` de cada repo, `migration/templates/`, lenguaje destino (prompt o `destino:` en el README), alcance opcional.

Si falta algún índice, se detiene y pide correr el indexador. Si no hay destino, se detiene y lo pide.

**Fase 1: investigación y mapa de capacidades.**

Lee los índices y, a partir de ellos, los archivos relevantes: rutas y controladores del backend, páginas y flujos del frontend, módulos de dominio, clientes de servicios externos. Identifica capacidades funcionales cruzando repos: una capacidad es algo que un usuario o sistema externo puede hacer de principio a fin (autenticarse, buscar productos, pagar). Escribe `migration/specs/_capacidades.md`:

```markdown
# Capacidades

| Capacidad | Descripción | Repos | Archivos principales |
|---|---|---|---|
| autenticacion | Login, refresh y logout con JWT | frontend, bff | bff/src/routes/auth.ts, frontend/src/pages/Login.tsx |
```

Este archivo se regenera siempre y es lo primero que el revisor mira, porque define cuántos specs habrá.

**Fase 2: ADRs.**

Archivos `migration/adr/NNNN-<slug>.md`, numerados desde 0001 en orden de generación. Dos tipos:

- `estado: observado`. Decisiones implícitas en el código: patrón BFF, autenticación, manejo de estado, convención de errores, validación de entrada, estilo de contratos, integraciones externas, manejo de configuración, logging. Cada uno incluye contexto, decisión observada, evidencia (rutas de archivo), consecuencias, e **implicación para la migración** con uno de tres valores: conservar, reemplazar o reevaluar, con justificación.
- `estado: propuesto`. Decisiones que la migración obliga a tomar y que el código origen no responde: framework destino, estrategia de despliegue, herramienta de build, estrategia de tests. El agente lista opciones con ventajas y desventajas y marca una recomendación. No decide. El revisor lo cambia a `revisado` cuando acepta o edita la decisión.

**Fase 3: specs.**

Un archivo `migration/specs/<capacidad>.md` por fila de `_capacidades.md`. Secciones, en este orden:

1. Resumen (dos o tres frases).
2. Actores.
3. Alcance por repo (qué parte de la capacidad vive en cada uno).
4. Flujos de comportamiento (paso a paso, en prosa o listas numeradas).
5. Contratos de API en notación neutral: método, ruta, forma de entrada, forma de salida, códigos de error y su significado. Las formas se describen como estructuras con tipos genéricos (texto, entero, lista de X, opcional), no como tipos del lenguaje origen.
6. Modelos de datos.
7. Reglas de negocio, numeradas (RN-1, RN-2...) para que QA las cite.
8. Casos borde y errores, numerados (CB-1, CB-2...).
9. Dependencias externas.
10. ADRs relacionados.
11. Evidencia en el código original (rutas de archivo).
12. Preguntas abiertas: todo lo que el agente no pudo determinar con certeza. Nunca inventa comportamiento; lo anota aquí.

**Fase 4: tareas.**

Archivos `migration/tasks/T-NNN-<slug>.md`. Frontmatter:

```yaml
id: T-012
spec: autenticacion          # vacío en tareas fundacionales
repo_destino: bff            # nombre del repo destino equivalente
depende_de: [T-001, T-003]
tamaño: M                    # S, M o L
adrs: [0002, 0007]
estado: generado
fase:                        # lo rellena el PM
prioridad:                   # lo rellena el PM
bloqueada_por: []            # ADRs propuestos no aceptados o preguntas abiertas
```

Cuerpo: objetivo, criterios de aceptación (verificables, citan RN y CB del spec), notas específicas del destino (aquí sí se menciona el lenguaje destino y, si un ADR propuesto ya está revisado, el framework elegido).

Las tareas fundacionales (estructura del proyecto destino, CI, configuración, dependencias base) van numeradas al inicio y no tienen spec. Una tarea cuya implementación depende de un ADR con `estado: propuesto` lo cita en `bloqueada_por`.

**Acotación.** "solo la fase N" ejecuta esa fase. "solo la capacidad X" ejecuta las fases 3 y 4 para esa capacidad. Respeta `estado: revisado` en ADRs, specs y tareas.

## 8. Agente 3: `migration-qa`

**Propósito.** Producir, por cada spec, un plan de prueba que valide la implementación en el destino.

**Entradas.** `migration/specs/*.md`, `_capacidades.md`, `migration/tasks/*.md`, plantillas, alcance opcional. Si no hay specs, se detiene y pide correr el tech lead.

**Proceso.**

1. Por cada spec, escribe `migration/test-plans/<capacidad>.md` con el mismo nombre de archivo. Secciones: alcance y supuestos, matriz de cobertura (qué RN y CB cubre cada caso), casos agrupados en camino feliz, casos borde, errores y contratos de API, hallazgos para el tech lead.
2. Cada caso:

```markdown
### TC-autenticacion-007: refresh con token expirado
- Prioridad: crítica
- Nivel sugerido: integración
- Cubre: CB-3, contrato POST /refresh
- Tareas: T-014
- Dado un refresh token expirado hace más de un segundo
- Cuando el cliente llama a POST /refresh con ese token
- Entonces la respuesta es 401 con código de error TOKEN_EXPIRED y no se emite ningún token nuevo
```

3. Los casos derivan de reglas de negocio, casos borde y códigos de error del spec. Cada RN y cada CB debe aparecer en al menos un caso; si no es posible, se registra el hueco en `_cobertura.md`.
4. Las preguntas abiertas del spec se heredan como "casos pendientes de definición", con la pregunta citada. El agente no inventa el comportamiento esperado.
5. Si una sección del spec es ambigua y bloquea la escritura de un caso, se anota en "hallazgos para el tech lead" al final del plan.
6. Escribe `migration/test-plans/_cobertura.md`: tabla por capacidad con casos por tipo, RN y CB sin cubrir, y cantidad de casos pendientes de definición.

**Lo que no hace.** No escribe código de test ni elige framework. El nivel sugerido es orientativo.

**Idempotencia.** Regenera plan por plan, respeta `estado: revisado`. `_cobertura.md` se regenera siempre.

## 9. Agente 4: `migration-pm`

**Propósito.** Ordenar las tareas en fases ejecutables y dejar el backlog listo para empezar.

**Entradas.** `migration/tasks/*.md`, `_capacidades.md`, `migration/adr/*.md`, y `migration/test-plans/*.md` si existen. Si no hay tareas, se detiene y pide correr el tech lead.

**Proceso.**

1. Construye el grafo de dependencias desde `depende_de`. Si hay ciclos o referencias a tareas inexistentes, lo reporta con las tareas implicadas y se detiene.
2. Prioriza con criterio fijo, en este orden: (a) tareas fundacionales y las que desbloquean más tareas; (b) capacidades con más dependientes o con ADRs marcados "reemplazar" o "reevaluar", por riesgo; (c) el resto. No estima fechas ni asigna personas.
3. Agrupa en fases. Hito 0 son las fundacionales. Cada fase posterior solo depende de fases anteriores y termina con al menos una capacidad completa, con su plan de prueba si existe.
4. Escribe `migration/backlog.md`: resumen ejecutivo (cantidad de tareas, fases, bloqueos), fases con tareas ordenadas y su tamaño, tabla de bloqueos (tarea, motivo: ADR propuesto sin aceptar o pregunta abierta), riesgos detectados.
5. Actualiza en cada tarea los campos `fase` y `prioridad` del frontmatter. No toca el cuerpo. En tareas `revisado` conserva `fase` y `prioridad` si ya tenían valor.
6. Actualiza `migration/README.md`: marca los pasos completados con fecha y añade la sección "Cómo empezar a implementar" apuntando al backlog y a la primera fase.

**Idempotencia.** Recalcula el backlog completo en cada corrida.

## 10. Plantillas

El indexador escribe cinco plantillas en `migration/templates/`. Cada una es un archivo Markdown con el frontmatter y las secciones descritas en los apartados 7, 8 y 9, con un comentario HTML por sección explicando qué va ahí. Los agentes las leen y las siguen; si un revisor modifica una plantilla, la siguiente corrida la respeta. El contenido exacto de cada plantilla se escribe durante la implementación, embebido en el prompt del indexador, y debe reflejar exactamente las secciones y campos de frontmatter definidos en este documento.

## 11. Pruebas del sistema de agentes

**Fixture.** `fixtures/sample-workspace/` contiene un `frontend/` y un `bff/` mínimos pero con sustancia:

- Tres capacidades: autenticación (cruza ambos repos), listado de productos, carrito.
- Una dependencia cruzada: el carrito consulta precios al listado.
- Archivos a excluir: lockfile, `dist/` con un bundle, una imagen, un snapshot de test.
- Una ambigüedad deliberada: un endpoint que devuelve 200 con cuerpo vacío en un caso y 404 en otro, sin comentario que lo explique, para verificar que aparece como pregunta abierta.
- Sin `node_modules`; el fixture no se ejecuta, solo se lee.
- El fixture no contiene `.git`. Un script (`scripts/fixture-reset.sh`) lo copia a `.work/sample-workspace/` (carpeta ignorada por git), inicializa un repo git con un commit en cada subcarpeta y copia los agentes a `.work/sample-workspace/.claude/agents/`. Así `git ls-files` y la detección de repos se prueban por la vía principal sin anidar repos dentro de `spec-agent`, y cada corrida parte de un estado limpio.

**Procedimiento.** Correr los cuatro agentes en orden dentro de `.work/sample-workspace/` y verificar con esta lista (automatizada en `scripts/verify-<agente>.sh` donde sea posible):

| Agente | Verificaciones |
|---|---|
| indexer | Existe `index.md` en ambos repos. Ningún archivo excluido aparece. Todos los archivos de código aparecen con dos líneas. `migration/README.md` y las cinco plantillas existen. Segunda corrida no modifica plantillas. |
| techlead | `_capacidades.md` lista las tres capacidades. Hay al menos un ADR observado y uno propuesto. Cada spec tiene las doce secciones. Ningún spec contiene código JS. La ambigüedad aparece como pregunta abierta. Cada tarea cita un spec o es fundacional. Sin destino, se detiene. |
| qa | Un plan por spec con el mismo nombre. Cada RN y CB aparece en algún caso o en `_cobertura.md`. La pregunta abierta aparece como caso pendiente. |
| pm | `backlog.md` existe, hito 0 contiene solo fundacionales, ninguna tarea aparece antes que sus dependencias. Un ciclo inyectado a mano detiene al agente. |

**Regresión de idempotencia.** Marcar un spec como `revisado`, editarlo, volver a correr el tech lead y comprobar que no cambió.

## 12. Errores contemplados

| Situación | Comportamiento |
|---|---|
| Se abre desde dentro de un repo | El agente no detecta repos y explica que debe abrirse desde la carpeta padre. |
| Faltan insumos del paso anterior | Se detiene y nombra el agente a correr. |
| Falta el destino | Tech lead se detiene y lo pide. |
| Repo muy grande | Índice incremental con marca de incompleto. |
| Ciclo o referencia rota en dependencias | PM lo reporta y se detiene. |
| Spec ambiguo | QA registra hallazgo, no inventa. |
| Plantilla modificada por el humano | Se respeta en la siguiente corrida. |

## 13. Fuera de alcance

- Comando orquestador que corra los cuatro agentes seguidos.
- Publicación de tareas como issues de GitHub.
- Generación de código de test o de código destino.
- Estimación de fechas o asignación de personas.
