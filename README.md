# spec-agent

Subagentes de Claude Code para generar la documentación de migración de un proyecto (índices de código, ADRs, specs por capacidad, tareas, planes de prueba y backlog) a partir de su código, con el objetivo de reimplementarlo en otro lenguaje.

Los agentes no migran código: producen los documentos con los que un equipo puede reimplementar sin abrir el código original.

- Tutorial paso a paso: [`docs/tutorial.md`](docs/tutorial.md)
- Diseño: [`docs/specs/2026-09-28-migration-agents-design.md`](docs/specs/2026-09-28-migration-agents-design.md)
- Plan de implementación: [`docs/plans/2026-09-28-migration-agents.md`](docs/plans/2026-09-28-migration-agents.md)

## Instalación

```bash
bash scripts/install.sh
```

Copia `agents/*.md` a `~/.claude/agents/`. Vuelve a ejecutarlo cada vez que actualices los agentes y abre una sesión nueva de Claude Code, porque se cargan al iniciar. Alternativa por proyecto: copiar los archivos a `<carpeta padre>/.claude/agents/`.

## Uso

Abrir Claude Code en la carpeta padre que contiene los repositorios, no dentro de uno de ellos. Se avanza por etapas y se revisa entre cada una, de modo que cada artefacto se genera una sola vez y no hay retrabajo:

| Paso | Prompt | Qué produce | Qué revisar antes de seguir |
|---|---|---|---|
| 0 | `Usa el subagente migration-indexer` | `index.md` en cada repo y `migration/` con plantillas | Índices correctos. Rellenar `destino:` en `migration/README.md`. |
| 1 | `Usa el subagente migration-techlead con destino Kotlin, solo la etapa 1` | `specs/_capacidades.md` | Capacidades correctas. Borrar filas de las que no se quieren. |
| 2 | `... solo la etapa 2` | ADRs observados y propuestos | Confirmar los observados. Decidir los propuestos y marcarlos `revisado`. |
| 3 | `... solo la etapa 3` | Un spec por capacidad | Validar contra el sistema, responder preguntas abiertas y marcar `revisado`. |
| 4 | `... solo la etapa 4` | Tareas en `tasks/` | Criterios y dependencias. Marcar `revisado`. |
| 5 | `Usa el subagente migration-qa` | Planes de prueba y `_cobertura.md` | Hallazgos y casos pendientes. |
| 6 | `Usa el subagente migration-pm` | `backlog.md`, `fase` y `prioridad` por tarea | Bloqueos y riesgos. |

Sin alcance, el tech lead ejecuta las cuatro etapas de una vez, pero las tareas salen antes de que hayas decidido los ADRs propuestos y hay que regenerarlas. Por eso se recomienda ir por etapas. El detalle de cada paso, con qué hacer en cada archivo y qué pasa si se omite, está en el [tutorial](docs/tutorial.md).

Los artefactos quedan en `migration/`. Los `index.md` quedan en la raíz de cada repo y decides tú si los versionas.

## Convenciones

**Estado.** Todo artefacto generado tiene `estado` en su cabecera. `generado` se sobrescribe al repetir la corrida. `revisado` lo validó un humano y ningún agente lo vuelve a tocar. En ADRs también existen `observado` y `propuesto`. Un ADR `propuesto` bloquea las tareas que dependen de él hasta que se decida y se marque `revisado`.

**Derivados.** `index.md`, `_capacidades.md`, `_cobertura.md` y `backlog.md` se regeneran siempre y no se editan a mano. La excepción es borrar filas de `_capacidades.md` justo después de la etapa 1, siempre que no se repita esa etapa.

**Identificadores.** Las reglas de negocio de cada spec se numeran `RN-n:` y los casos borde `CB-n:`. Las tareas y los casos de prueba los citan; no se renumeran. Las preguntas abiertas del spec se citan por posición como `PA:<capacidad>:<n>`, por lo que se responden debajo de la pregunta sin borrar la línea.

**Etapa y fase.** La etapa es uno de los cuatro pasos internos del tech lead. La fase es la agrupación del backlog que asigna el PM. Se pide siempre "etapa" al tech lead.

**Alcance.** El tech lead y QA aceptan alcance por capacidad, como `solo la capacidad carrito`. El tech lead acepta además `solo la etapa N`. Un nombre de capacidad inexistente detiene al agente con la lista de las disponibles, y una etapa cuyo insumo previo no existe lo detiene con el nombre de la etapa que falta.

**Cuándo repetir.** Si el tech lead regenera specs o tareas, hay que repetir QA y PM. Un cambio en un ADR propuesto pide repetir la etapa 4 y el PM.

## Pruebas

Requisitos: Git Bash o cualquier bash 4 o superior, utilidades GNU (`sed -i`, `md5sum`) y `claude` en el PATH para las corridas con agentes.

```bash
bash scripts/test-check-agent.sh     # validador de agentes
bash scripts/test-fixture.sh         # fixture y reset
bash scripts/test-verifiers.sh       # verificadores y run-agent.sh sobre workspaces sintéticos
bash scripts/run-all.sh              # flujo completo sobre el fixture con verificadores
bash scripts/verify-idempotency.sh   # un spec revisado sobrevive a una segunda corrida
```

Cada `scripts/verify-<agente>.sh` se puede correr por separado tras `scripts/run-agent.sh <agente>`. Ambos usan `WORKDIR` para apuntar a otra carpeta, por defecto `.work/sample-workspace/` (ignorada por git, la reconstruye `scripts/fixture-reset.sh`). Las corridas de agentes usan `claude -p` con permisos desactivados, así que solo deben ejecutarse sobre ese workspace descartable. `run-agent.sh` sale con código 2 si Claude responde con un aviso de límite de uso, para que ninguna verificación dé por buena una corrida que no ocurrió.

## Estructura

- `agents/`: los cuatro subagentes. Es el producto.
- `fixtures/sample-workspace/`: frontend y BFF mínimos para probar. No se ejecutan, solo se leen.
- `scripts/`: instalación, corrida y verificación.
- `docs/`: tutorial, diseño y plan de implementación.

## Limitaciones conocidas

- El flujo se probó solo sobre el fixture, no sobre un repositorio real. Conviene revisar con cuidado la primera vez el índice, el mapa de capacidades y los specs.
- No existe un mecanismo permanente de exclusión de capacidades: la capacidad borrada reaparece si se repite la etapa 1 o se corre el tech lead sin alcance.
- Los planes de QA y el backlog no avisan cuando quedan desactualizados tras regenerar specs o tareas.
- Sin probar: pedir por prompt que el tech lead agrupe o divida capacidades. Las etapas por separado y su aviso de insumo faltante sí se probaron sobre el fixture.
