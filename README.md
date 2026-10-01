# spec-agent

Subagentes de Claude Code que generan, a partir del código de un proyecto, la documentación para reimplementarlo en otro lenguaje: índices, ADRs, specs por capacidad, tareas, planes de prueba y backlog. Los agentes no migran código.

- Tutorial paso a paso: [`docs/tutorial.md`](docs/tutorial.md)
- Diseño: [`v2`](docs/specs/2026-09-29-migration-agents-v2-design.md), sobre [`v1`](docs/specs/2026-09-28-migration-agents-design.md)

## Instalación

```bash
bash scripts/install.sh
```

Copia los nueve agentes a `~/.claude/agents/`, retira `migration-techlead` y no sobrescribe archivos ajenos con el mismo nombre. Abre una sesión nueva de Claude Code después.

## Agentes

| Paso | Agente | Produce |
|---|---|---|
| 1 | `migration-indexer` | `index.md` por repo, `index.md` general, bloque de convenciones en `CLAUDE.md`, `migration/` con plantillas |
| 2 | `migration-analyst` | `migration/specs/_capacidades.md` |
| 3 | `migration-tl-adrs` | ADRs observados y propuestos |
| 4 | `migration-tl-specs` | un spec por capacidad |
| 5 | `migration-tl-tasks` | tareas; se detiene si quedan ADRs propuestos |
| 6 | `migration-qa` | planes de prueba, `_cobertura.md`, hallazgos `H-n` |
| 7 | `migration-pm` | `backlog.md`, `fase` y `prioridad` por tarea |
| — | `migration-tl-resolver` | aplica decisiones y cambios que describes |
| — | `migration-orchestrator` | diagnóstico y prompt del siguiente paso (solo lectura) |

## Uso

Abre Claude Code en la carpeta padre de los repositorios y pide `Usa el subagente migration-indexer`. Desde ahí:

- Para saber qué sigue: `Usa el subagente migration-orchestrator`. Te da el prompt exacto.
- Para decidir o cambiar algo: `Usa el subagente migration-tl-resolver: <cambio>`. Por ejemplo `en el ADR 0011 elijo Ktor`, `en el spec carrito, respuesta a la pregunta 2: ...`, `resuelve el hallazgo H-1 del plan carrito: ...`, `excluye la capacidad pagos`.

Revisa entre cada paso. Las tareas se generan una sola vez, después de decidir los ADRs.

## Convenciones

Viven en el bloque de `CLAUDE.md` que escribe el indexador: estados (`generado`, `revisado`, `observado`, `propuesto`), derivados que no se editan, identificadores que nunca se renumeran (`RN-n`, `CB-n`, `PA:<capacidad>:<n>`, `MJ-n`, `TC-…`, `H-n`, `T-NNN`, `NNNN`), destino, `excluir:` y `politica:` en `migration/README.md`.

**Política de paridad.** `politica: paridad` es la única política: el destino reproduce el comportamiento observado salvo decisión explícita. En cada spec, `## 12. Preguntas abiertas` contiene solo lo que el código no permite determinar, y `## 13. Posibles mejoras` lista como `MJ-n` lo que el código determina pero parece mejorable. Las mejoras no bloquean tareas ni generan casos pendientes; se aplican o descartan con `migration-tl-resolver`. Diseño: [`docs/specs/2026-10-01-politica-paridad-design.md`](docs/specs/2026-10-01-politica-paridad-design.md).

## Pruebas

Requisitos: bash 4 o superior con utilidades GNU (Git Bash en Windows) y `claude` en el PATH para las corridas con agentes.

Tres niveles:

```bash
bash scripts/test-fast.sh                          # sin agentes, en paralelo; en cada cambio
bash scripts/test-agents.sh migration-tl-specs     # solo las pruebas que tocan ese agente
bash scripts/test-agents.sh                        # todas las pruebas con agentes, en paralelo
bash scripts/test-all.sh                           # las dos anteriores
bash scripts/run-all.sh                            # cadena completa con una ronda del resolver; antes de una PR
```

Cómo se acelera:

- `run-agent.sh` arranca la sesión directamente como el agente (`claude -p --agent <nombre>`), sin una sesión intermedia que delegue. Mismo modelo y esfuerzo que en uso real.
- `snapshot.sh` guarda el workspace tras cada etapa de la cadena (`fixture`, `indexer`, `analyst`, `tl-adrs`, `tl-specs`, `tl-tasks`, `qa`, `pm`) con una huella del fixture y de los prompts. Las pruebas restauran la etapa que necesitan. Si cambias un prompt, solo se rehacen esa etapa y las posteriores; cambiar el resolver o el orquestador no rehace nada.
- `test-agents.sh` corre las pruebas en paralelo (`JOBS=3` por defecto), cada una en su propio workspace bajo `.work/ws/`, con un log por prueba en `.work/logs/`.

Pruebas individuales, todas aceptan `WORKDIR`:

| Script | Qué prueba |
|---|---|
| `test-indexer-claude.sh` | bloque de `CLAUDE.md` y actualización de un README de v1 |
| `test-analyst.sh` | exclusión de capacidades y bloque ausente |
| `test-tl-specs.sh` | alcance sobre una capacidad excluida |
| `test-tl-tasks.sh` | parada ante ADRs propuestos y forzado |
| `test-resolver.sh` | operaciones del resolver |
| `test-orchestrator.sh` | diagnóstico en varios estados |
| `verify-idempotency.sh` | un spec revisado sobrevive a una recorrida |

Las corridas de agentes usan `claude -p` con permisos desactivados: solo sobre workspaces descartables de `.work/`. `run-agent.sh` sale con 2 si Claude responde con un aviso de límite de uso. En Windows, lanzar procesos es lento y más dentro de carpetas sincronizadas como OneDrive; `SNAPSHOT_DIR`, `WS_DIR` y `LOG_DIR` permiten mover los workspaces de prueba fuera de ellas.

## Estructura

- `agents/`: los nueve subagentes.
- `fixtures/sample-workspace/`: frontend y BFF mínimos para probar.
- `scripts/`: instalación, corrida y verificación.
- `docs/`: tutorial, diseños y planes.

## Limitaciones conocidas

- Probado solo sobre el fixture, no sobre un repositorio real.
- El orquestador compara fechas de modificación; copiar o clonar archivos puede alterarlas.
