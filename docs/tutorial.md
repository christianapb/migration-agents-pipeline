# Tutorial: agentes de migración

Genera, a partir del código de un proyecto, la documentación para reimplementarlo en otro lenguaje. Los agentes no migran código.

Dos agentes te acompañan en todo momento:

- **`migration-orchestrator`** te dice en qué paso estás, qué falta revisar y te da el prompt exacto del siguiente paso. Consúltalo siempre que dudes.
- **`migration-tl-resolver`** aplica tus decisiones y cambios. Describe el cambio en lenguaje natural en vez de editar archivos a mano.

## 1. Instalación

```bash
git clone https://github.com/christianapb/migration-agents-pipeline.git
cd migration-agents-pipeline
bash scripts/install.sh
```

Abre una sesión nueva de Claude Code para que carguen los agentes.

## 2. Preparar la carpeta

Deja los repositorios como subcarpetas de una carpeta padre y abre Claude Code en esa carpeta, no dentro de un repo:

```
mi-proyecto/
├── frontend/
└── bff/
```

Conviene versionar `mi-proyecto/` con git y hacer commit antes de cada paso. Para deshacer, prefiere `git revert` o restaurar archivos concretos: un `git checkout` de toda la carpeta cambia las fechas de modificación y el orquestador puede marcar como desactualizado algo que no lo está.

## 3. Paso a paso

En cada paso: ejecuta el agente, revisa, aplica cambios con el resolver y pregunta al orquestador qué sigue.

### Paso 1: indexar

```
Usa el subagente migration-indexer
```

Crea un `index.md` por repo, un `index.md` general en la carpeta padre, el bloque de convenciones en `CLAUDE.md` y `migration/` con plantillas. Revisa que los índices no tengan archivos basura y que los resúmenes sean concretos. Fija el destino:

```
Usa el subagente migration-tl-resolver: fija el destino en Kotlin
```

El bloque de `CLAUDE.md` lo reescribe el indexador en cada corrida; escribe tus notas fuera de las marcas.

**Si vuelves a correr el indexador:**

| Archivo | Qué pasa |
|---|---|
| `index.md` de cada repo | Se regenera entero desde el código actual. Pierdes cualquier edición manual. |
| `index.md` general | Se regenera entero. |
| `CLAUDE.md` | Solo se reemplaza el bloque entre las marcas; el resto no cambia. |
| `migration/README.md` | No se toca, salvo añadir `excluir: []` si falta o actualizar un README de la versión anterior. |
| `migration/templates/*.md` | No se tocan; solo se crean las que falten. |

El indexador nunca indexa `migration/`: no es código del proyecto sino el resultado del proceso, y los demás agentes leen sus artefactos directamente. No hace falta repetirlo después de generar ADRs, specs o tareas. Repítelo solo si cambia el código de algún repo, si añades o quitas un repositorio de la carpeta padre, o si actualizas los agentes a una versión que cambia el bloque de `CLAUDE.md`. Si cambió el código, sigue después la tabla de la sección 4.

### Paso 2: capacidades

```
Usa el subagente migration-analyst
```

Revisa `migration/specs/_capacidades.md`. Es el mejor momento para descartar capacidades:

```
Usa el subagente migration-tl-resolver: excluye la capacidad pagos
```

La exclusión es permanente: el analista la omite en cada corrida. Para agrupar o dividir, repite el analista indicándolo en el prompt.

### Paso 3: ADRs

```
Usa el subagente migration-tl-adrs con destino Kotlin
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

### Paso 4: specs

```
Usa el subagente migration-tl-specs
```

Es la revisión más importante: un error aquí llega a tareas y pruebas como requisito. Valida contra lo que sabes del sistema y responde las preguntas abiertas que cambian el comportamiento:

```
Usa el subagente migration-tl-resolver: en el spec carrito, respuesta a la pregunta 1: el carrito debe persistir; conviértelo en regla
Usa el subagente migration-tl-resolver: en el spec autenticacion, el token expira a los 30 minutos
Usa el subagente migration-tl-resolver: marca revisado el spec catalogo-productos
```

### Paso 5: tareas

```
Usa el subagente migration-tl-tasks con destino Kotlin
```

Si quedan ADRs propuestos, se detiene y te da el prompt para decidirlos. Así las tareas se generan una sola vez, con el framework nombrado. Corrige con el resolver:

```
Usa el subagente migration-tl-resolver: la tarea T-016 también depende de T-004 y es tamaño L
```

### Paso 6: planes de prueba

Antes de correr QA conviene tener los specs validados y las preguntas importantes respondidas: QA convierte el spec en casos afirmados con seguridad, y lo no respondido queda como caso pendiente.

```
Usa el subagente migration-qa
```

Revisa los hallazgos `H-n` al final de cada plan. Decide y aplica al spec:

```
Usa el subagente migration-tl-resolver: resuelve el hallazgo H-1 del plan carrito: el esquema Bearer no distingue mayúsculas
```

Luego repite QA para esa capacidad (`Usa el subagente migration-qa, solo la capacidad carrito`). Si falta un caso cuyo comportamiento no está en el spec, el resolver te pedirá añadirlo primero al spec.

### Paso 7: backlog

```
Usa el subagente migration-pm
```

Escribe hitos, bloqueos y riesgos. Si hay un ciclo o una dependencia rota, no escribe nada y te dice qué corregir (con el resolver). Para cambiar el orden:

```
Usa el subagente migration-tl-resolver: adelanta T-013 al hito 1 con prioridad 3
```

y repite el PM.

### Resultado

`migration/` es lo que entregas al equipo. Empiezan por el Hito 0, con la sección "Cómo empezar a implementar" de `migration/README.md`.

## 4. Qué repetir después de un cambio

Los agentes forman una cadena: specs → tareas → planes de prueba → backlog. Cuando cambias algo, hay que regenerar lo que viene **después** en la cadena, en ese orden, y acotado a la capacidad afectada cuando se pueda. Nada se regenera solo.

| Cambiaste | Repite, en este orden |
|---|---|
| El código de un repo | `migration-indexer`; `migration-analyst` si pudieron cambiar las capacidades; `migration-tl-specs, solo la capacidad X` para las afectadas; luego `migration-tl-tasks`, `migration-qa` y `migration-pm` para esas capacidades. |
| Agrupaste o dividiste capacidades | `migration-analyst` con la indicación; `migration-tl-specs` para las capacidades nuevas; `migration-tl-tasks`, `migration-qa`, `migration-pm`. |
| Excluiste una capacidad | Si el resolver lista tareas con `depende_de` roto o specs que la mencionan, corrígelos con el resolver. Luego `migration-qa` (para que `_cobertura.md` deje de contarla) y `migration-pm` (para que salga del backlog). |
| Decidiste un ADR propuesto después de generar tareas | `migration-tl-tasks` (para que las notas nombren la tecnología elegida); `migration-qa` si las tareas cambiaron; `migration-pm`. |
| Corregiste un ADR observado | Si cambia el comportamiento, llévalo al spec con el resolver y sigue la fila siguiente. Si solo cambia cómo se implementa, `migration-tl-tasks` y `migration-pm`. |
| Un spec: regla, contrato o caso borde | `migration-tl-tasks, solo la capacidad X`; `migration-qa, solo la capacidad X`; `migration-pm`. |
| Respondiste una pregunta abierta | Si la convertiste en regla o cambia qué se construye, igual que la fila anterior. Si solo confirma el comportamiento actual, `migration-qa, solo la capacidad X` para que el caso pendiente pase a ser un caso normal. |
| Resolviste un hallazgo `H-n` de QA | Igual que un cambio de spec: `migration-tl-tasks` si cambia qué se construye, luego `migration-qa` y `migration-pm`, todo con `solo la capacidad X`. |
| Una tarea: dependencias, tamaño, fase o prioridad | `migration-pm`. |
| Un plan de prueba | Nada; queda `revisado`. |
| Una plantilla de `migration/templates/` | El agente que genera ese tipo de artefacto, y lo que venga después. |

**Dos casos típicos, paso a paso:**

Generaste tareas forzando ADRs propuestos y luego los decides:

```
Usa el subagente migration-tl-resolver: en los ADRs 0011, 0012 y 0013 acepta la recomendación
Usa el subagente migration-tl-tasks con destino Kotlin
Usa el subagente migration-qa
Usa el subagente migration-pm
```

El resolver ya quita esos ADRs de `bloqueada_por`, pero las notas de las tareas se escribieron sin conocer la tecnología: por eso se regeneran. QA solo hace falta si las tareas cambiaron, porque sus casos citan ids de tareas.

QA encontró hallazgos en el plan de carrito:

```
Usa el subagente migration-tl-resolver: resuelve el hallazgo H-1 del plan carrito: DELETE /cart/items/ sin id responde 404 sin cuerpo
Usa el subagente migration-tl-tasks con destino Kotlin, solo la capacidad carrito
Usa el subagente migration-qa, solo la capacidad carrito
Usa el subagente migration-pm
```

El segundo paso solo hace falta si la decisión cambia qué se construye, por ejemplo una regla nueva que alguna tarea debe cubrir. Si solo aclara un detalle ya cubierto, pasa directo a QA.

**Lo `revisado` no se regenera.** Si marcaste `revisado` un spec, una tarea o un plan, el agente correspondiente lo conserva tal cual, incluidos los que editó el resolver, porque él marca `revisado` lo que toca. Si quieres que se regenere, cambia a mano su línea `estado: revisado` por `estado: generado` y repite el agente. Es la única edición manual que el flujo espera de ti.

**Si dudas**, pregunta al orquestador: compara fechas y te dice qué quedó desactualizado y con qué prompt regenerarlo.

## 5. Reglas que conviene saber

- `revisado` protege un artefacto: ningún agente generador lo sobrescribe. El resolver marca `revisado` lo que edita.
- No edites derivados: `index.md`, `_capacidades.md`, `_cobertura.md`, `backlog.md`. El resolver se niega y te dice qué agente los regenera.
- Los identificadores nunca se renumeran; lo retirado queda marcado como retirado.
- Cuando algo cambia, se regenera lo que viene después en la cadena (sección 4). El orquestador te avisa de lo desactualizado.

## 6. Si algo falla

| Síntoma | Causa y solución |
|---|---|
| No encontré repositorios | Abre Claude Code en la carpeta padre. |
| Falta el bloque de convenciones en `CLAUDE.md` | Corre `migration-indexer`. |
| No sé a qué lenguaje se migra | Fija el destino con el resolver o indícalo en el prompt. |
| `migration-tl-tasks` se detiene | Hay ADRs propuestos. Decide con el resolver o fuerza con "aunque haya ADRs propuestos". |
| El resolver no aplicó algo | Revisa la sección "No aplicado" de su resumen: id inexistente u orden ambigua. |
| El PM reporta un ciclo | Corrige `depende_de` con el resolver y repite el PM. |
| Una tarea o un spec no cambió al repetir el agente | Está `revisado`. Cambia su estado a `generado` y repite (sección 4). |
| No sabes qué sigue | `Usa el subagente migration-orchestrator`. |
