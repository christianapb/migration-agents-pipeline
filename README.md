# spec-agent

Subagentes de Claude Code para generar la documentación de migración de un proyecto (índices de código, ADRs, specs por capacidad, tareas, planes de prueba y backlog) a partir de su código, con el objetivo de reimplementarlo en otro lenguaje.

Diseño: `docs/specs/2026-09-28-migration-agents-design.md`.

## Instalación

```bash
bash scripts/install.sh
```

Copia `agents/*.md` a `~/.claude/agents/`. Alternativa por proyecto: copiar los archivos a `<carpeta padre>/.claude/agents/`.

## Uso

Abrir Claude Code en la carpeta padre que contiene los repositorios (no dentro de uno de ellos) y pedir, en orden y revisando entre pasos:

1. `Usa el subagente migration-indexer`
2. `Usa el subagente migration-techlead con destino Kotlin`
3. `Usa el subagente migration-qa`
4. `Usa el subagente migration-pm`

Los artefactos quedan en `migration/`. Los `index.md` quedan en la raíz de cada repo.

## Pruebas

Ver la sección al final de este archivo (se completa en Task 7).
