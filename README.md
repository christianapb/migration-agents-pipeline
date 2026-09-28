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

Requisitos: Git Bash, `claude` en el PATH.

```bash
bash scripts/test-check-agent.sh     # validador de agentes
bash scripts/test-fixture.sh         # fixture y reset
bash scripts/run-all.sh              # flujo completo sobre el fixture con verificadores
bash scripts/verify-idempotency.sh   # un spec revisado sobrevive a una segunda corrida
```

Cada `scripts/verify-<agente>.sh` se puede correr por separado tras `scripts/run-agent.sh <agente>`. El workspace de prueba vive en `.work/sample-workspace/` (ignorado por git) y `scripts/fixture-reset.sh` lo reconstruye. Las corridas de agentes usan `claude -p` con permisos desactivados, así que solo deben ejecutarse sobre ese workspace descartable.

## Estructura

- `agents/`: los cuatro subagentes. Es el producto.
- `fixtures/sample-workspace/`: frontend y BFF mínimos para probar. No se ejecutan, solo se leen.
- `scripts/`: instalación, corrida y verificación.
- `docs/specs/`: diseño. `docs/plans/`: plan de implementación.

## Revisión entre pasos

Tras cada agente, revisa lo generado y marca con `estado: revisado` en el frontmatter lo que validaste. Los agentes no sobreescriben artefactos en ese estado. Los ADRs `propuesto` requieren una decisión humana: edita la decisión y cambia el estado a `revisado` para desbloquear las tareas que dependen de ellos. El lenguaje destino se indica en el prompt del tech lead o en el campo `destino:` de `migration/README.md`.
