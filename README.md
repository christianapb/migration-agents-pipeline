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

Viven en el bloque de `CLAUDE.md` que escribe el indexador: estados (`generado`, `revisado`, `observado`, `propuesto`), derivados que no se editan, identificadores que nunca se renumeran (`RN-n`, `CB-n`, `PA:<capacidad>:<n>`, `TC-…`, `H-n`, `T-NNN`, `NNNN`), destino y `excluir:` en `migration/README.md`.

## Pruebas

Requisitos: bash 4 o superior con utilidades GNU (Git Bash en Windows) y `claude` en el PATH para las corridas con agentes.

```bash
bash scripts/test-check-agent.sh     # validador de agentes
bash scripts/test-install.sh         # instalador
bash scripts/test-fixture.sh         # fixture
bash scripts/test-verifiers.sh       # verificadores sobre workspaces sintéticos
bash scripts/run-all.sh              # cadena completa con una ronda del resolver
bash scripts/test-indexer-claude.sh  # bloque de CLAUDE.md
bash scripts/test-analyst.sh         # exclusión y bloque ausente
bash scripts/test-tl-specs.sh        # alcance sobre capacidad excluida
bash scripts/test-tl-tasks.sh        # parada ante ADRs propuestos
bash scripts/test-resolver.sh        # operaciones del resolver
bash scripts/test-orchestrator.sh    # diagnóstico en varios estados
bash scripts/verify-idempotency.sh   # un spec revisado sobrevive a una recorrida
```

Los scripts de agentes usan `.work/sample-workspace/` (o `WORKDIR`) y `claude -p` con permisos desactivados: solo sobre ese workspace descartable. `run-agent.sh` sale con 2 si Claude responde con un aviso de límite de uso.

## Estructura

- `agents/`: los nueve subagentes.
- `fixtures/sample-workspace/`: frontend y BFF mínimos para probar.
- `scripts/`: instalación, corrida y verificación.
- `docs/`: tutorial, diseños y planes.

## Limitaciones conocidas

- Probado solo sobre el fixture, no sobre un repositorio real.
- El orquestador compara fechas de modificación; copiar o clonar archivos puede alterarlas.
