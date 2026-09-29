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

Conviene versionar `mi-proyecto/` con git y hacer commit antes de cada paso.

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

Los observados documentan lo que el código ya hace; confírmalos o corrígelos. Los propuestos son decisiones que tomas tú. Resuelve los que dependen de otros primero (framework antes que librería JWT):

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

## 4. Reglas que conviene saber

- `revisado` protege un artefacto: ningún agente generador lo sobrescribe. El resolver marca `revisado` lo que edita.
- No edites derivados: `index.md`, `_capacidades.md`, `_cobertura.md`, `backlog.md`. El resolver se niega y te dice qué agente los regenera.
- Los identificadores nunca se renumeran; lo retirado queda marcado como retirado.
- Si un spec cambia, repite QA y, si cambia lo que se construye, las tareas. El orquestador te avisa de lo desactualizado.

## 5. Si algo falla

| Síntoma | Causa y solución |
|---|---|
| No encontré repositorios | Abre Claude Code en la carpeta padre. |
| Falta el bloque de convenciones en `CLAUDE.md` | Corre `migration-indexer`. |
| No sé a qué lenguaje se migra | Fija el destino con el resolver o indícalo en el prompt. |
| `migration-tl-tasks` se detiene | Hay ADRs propuestos. Decide con el resolver o fuerza con "aunque haya ADRs propuestos". |
| El resolver no aplicó algo | Revisa la sección "No aplicado" de su resumen: id inexistente u orden ambigua. |
| El PM reporta un ciclo | Corrige `depende_de` con el resolver y repite el PM. |
| No sabes qué sigue | `Usa el subagente migration-orchestrator`. |
