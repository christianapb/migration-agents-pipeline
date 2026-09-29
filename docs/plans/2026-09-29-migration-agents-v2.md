# Agentes de migración v2: plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar el tech lead por cuatro agentes de una sola responsabilidad y añadir un orquestador de diagnóstico, un agente que aplica decisiones y cambios, un índice general y un bloque de convenciones en `CLAUDE.md`.

**Architecture:** Cada agente es un Markdown con frontmatter en `agents/`. Las convenciones comunes viven en un bloque delimitado del `CLAUDE.md` que escribe `migration-indexer` en la carpeta padre; los demás agentes lo leen y conservan en su prompt solo su procedimiento y dos reglas críticas. Las pruebas corren los agentes con `claude -p` sobre el fixture existente y comprueban los artefactos con scripts bash.

**Tech Stack:** Subagentes de Claude Code, Bash (Git Bash en Windows, bash ≥ 4 con utilidades GNU), `claude -p`, git.

**Spec:** `docs/specs/2026-09-29-migration-agents-v2-design.md` (y `docs/specs/2026-09-28-migration-agents-design.md` para todo lo que v2 no cambia).

## Global Constraints

- Nombres de agentes exactos: `migration-indexer`, `migration-analyst`, `migration-tl-adrs`, `migration-tl-specs`, `migration-tl-tasks`, `migration-qa`, `migration-pm`, `migration-tl-resolver`, `migration-orchestrator`.
- `migration-techlead` se retira: el archivo `agents/migration-techlead.md` y `scripts/verify-techlead.sh` se eliminan y el instalador lo borra de `~/.claude/agents/`.
- Marcas del bloque, exactas: `<!-- migration-flow:begin -->` y `<!-- migration-flow:end -->`.
- Formatos de ADR, spec, tarea, plan y backlog sin cambios respecto a v1, salvo hallazgos numerados `H-n` y el campo `excluir:` en `migration/README.md`.
- Todo el contenido generado en español; identificadores técnicos tal cual.
- `migration-orchestrator` solo tiene herramientas de lectura: `Read, Glob, Grep`.
- `migration-analyst`, `migration-tl-specs` y `migration-qa` no requieren destino; `migration-tl-adrs` y `migration-tl-tasks` sí.
- Los scripts se ejecutan desde la raíz de `spec-agent` con Git Bash y respetan `WORKDIR` cuando operan sobre un workspace.
- Commits terminan con `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Prompt al resolver con varias órdenes y una con id inexistente**: aplica las válidas y reporta la inválida sin abortar. Test en Task 8, paso 6.
2. **Resolver cambia una decisión ya `revisado`** (el usuario cambia de opinión): la decisión se reescribe, sigue sin recomendación y queda `revisado`. Test en Task 8, paso 6.
3. **`excluir:` con mayúsculas o espacios** (`[ Carrito ]`): se trata igual que `carrito`. Test en Task 3, paso 6.
4. **Orquestador en una carpeta sin `CLAUDE.md`**: recomienda `migration-indexer` sin escribir nada. Test en Task 9, paso 4.
5. **`migration-tl-specs` con alcance sobre una capacidad excluida**: se detiene y lista las disponibles. Test en Task 5, paso 6.

---

## Estructura de archivos

```
agents/
  migration-indexer.md        # Task 2 (modificar)
  migration-analyst.md        # Task 3 (nuevo)
  migration-tl-adrs.md        # Task 4 (nuevo)
  migration-tl-specs.md       # Task 5 (nuevo)
  migration-tl-tasks.md       # Task 6 (nuevo)
  migration-qa.md             # Task 7 (modificar)
  migration-pm.md             # Task 7 (modificar)
  migration-tl-resolver.md    # Task 8 (nuevo)
  migration-orchestrator.md   # Task 9 (nuevo)
  migration-techlead.md       # Task 10 (eliminar)
scripts/
  install.sh, test-install.sh                    # Task 1
  verify-indexer.sh, test-indexer-claude.sh      # Task 2
  verify-analyst.sh, test-analyst.sh             # Task 3
  verify-tl-adrs.sh                              # Task 4
  verify-tl-specs.sh, test-tl-specs.sh           # Task 5
  verify-tl-tasks.sh, test-tl-tasks.sh           # Task 6
  verify-qa.sh, verify-pm.sh                     # Task 7
  test-resolver.sh                               # Task 8
  test-orchestrator.sh                           # Task 9
  run-all.sh, verify-idempotency.sh, test-verifiers.sh  # Task 10
  verify-techlead.sh                             # Task 10 (eliminar)
README.md, docs/tutorial.md                      # Task 10
```

Nota para todas las tareas que corren agentes: cada corrida de `scripts/run-agent.sh` tarda minutos. Si una corrida devuelve código 2 (aviso de límite de uso de Claude), no se ejecutó: espera y repítela; nunca des por buena una comprobación posterior.

Antes de cada `run-agent.sh`, `scripts/fixture-reset.sh` copia los agentes de `agents/` al workspace; si solo cambias un prompt sin resetear, cópialo a mano: `cp agents/<agente>.md .work/sample-workspace/.claude/agents/`.

---

### Task 1: Instalador con retiro de agentes y protección de archivos ajenos

**Files:**
- Modify: `scripts/install.sh`
- Create: `scripts/test-install.sh`

**Interfaces:**
- Produces: `scripts/install.sh` usa `$HOME/.claude/agents`; borra `migration-techlead.md` si su `name` es `migration-techlead`; no sobrescribe un archivo existente cuyo `name` no empiece por `migration-` e imprime una línea que empieza por `AVISO:`.

- [ ] **Step 1: Escribir el test**

`scripts/test-install.sh`:

```bash
#!/usr/bin/env bash
# Prueba install.sh con un HOME temporal.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
D="$TMP/.claude/agents"
mkdir -p "$D"
printf -- '---\nname: migration-techlead\ndescription: viejo\ntools: Read\n---\n## x\n' > "$D/migration-techlead.md"
printf -- '---\nname: mi-qa-propio\ndescription: ajeno\ntools: Read\n---\n## x\n' > "$D/migration-qa.md"
before="$(md5sum < "$D/migration-qa.md")"

out="$(HOME="$TMP" bash "$ROOT/scripts/install.sh" 2>&1)" || fail "install.sh terminó con error: $out"

[ -f "$D/migration-techlead.md" ] && fail "migration-techlead.md no se retiró"
[ "$(md5sum < "$D/migration-qa.md")" = "$before" ] || fail "se sobrescribió un archivo ajeno"
printf '%s' "$out" | grep -q '^AVISO: .*migration-qa.md' || fail "no avisó del archivo ajeno"
for src in "$ROOT"/agents/*.md; do
  b="$(basename "$src")"
  [ "$b" = "migration-qa.md" ] && continue
  cmp -s "$src" "$D/$b" || fail "$b no se instaló"
done

[ "$fails" -eq 0 ] && { echo "OK: install"; exit 0; }
exit 1
```

- [ ] **Step 2: Ejecutarlo y verificar que falla**

Run: `bash scripts/test-install.sh`
Expected: `FAIL: migration-techlead.md no se retiró`, `FAIL: se sobrescribió un archivo ajeno`, `FAIL: no avisó del archivo ajeno`; salida 1.

- [ ] **Step 3: Reescribir `scripts/install.sh`**

```bash
#!/usr/bin/env bash
# Copia los agentes a ~/.claude/agents/, retira agentes obsoletos y no pisa
# archivos ajenos con el mismo nombre.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.claude/agents"
RETIRED=(migration-techlead)

agent_name() { awk 'NR==1{next} /^---$/{exit} {print}' "$1" | sed -n 's/^name:[[:space:]]*//p' | head -n1; }

"$ROOT/scripts/check-agent.sh"
mkdir -p "$DEST"

for r in "${RETIRED[@]}"; do
  f="$DEST/$r.md"
  if [ -f "$f" ] && [ "$(agent_name "$f")" = "$r" ]; then
    rm -f "$f"
    echo "Retirado: $r"
  fi
done

for src in "$ROOT"/agents/*.md; do
  b="$(basename "$src")"
  dst="$DEST/$b"
  if [ -f "$dst" ]; then
    n="$(agent_name "$dst")"
    case "$n" in
      migration-*) ;;
      *) echo "AVISO: $dst ya existe y no es de este proyecto (name: '$n'); no se sobrescribe."; continue ;;
    esac
  fi
  cp "$src" "$dst"
  echo "Instalado: $b"
done
echo "Abre una sesión nueva de Claude Code para cargar los agentes."
```

- [ ] **Step 4: Ejecutar el test y verificar que pasa**

Run: `bash scripts/test-install.sh`
Expected: `OK: install`.

- [ ] **Step 5: Commit**

```bash
git add scripts/install.sh scripts/test-install.sh
git commit -m "feat: instalador retira agentes obsoletos y no pisa archivos ajenos

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Indexador con índice general, bloque de `CLAUDE.md` y README v2

**Files:**
- Modify: `agents/migration-indexer.md`
- Modify: `scripts/verify-indexer.sh`
- Create: `scripts/test-indexer-claude.sh`

**Interfaces:**
- Produces en el workspace: `<padre>/index.md` (título `# Índice general`, tabla con columnas Repo, Stack, Entrada, Índice; enlaces `[<repo>/index.md](<repo>/index.md)`; línea `Artefactos de migración: [migration/](migration/README.md)`); `<padre>/CLAUDE.md` con el bloque entre marcas; `migration/README.md` con frontmatter `destino:`, `excluir: []`, `generado:`.
- El bloque nombra los nueve agentes y contiene las líneas literales `Usa el subagente migration-orchestrator` y `Usa el subagente migration-tl-resolver`.

- [ ] **Step 1: Ampliar `scripts/verify-indexer.sh`**

Sustituir el bloque desde `# Bootstrap de migration/` hasta `grep -q 'migration-indexer' "$W/migration/README.md" || fail "README sin flujo"` por:

```bash
# Bootstrap de migration/
[ -f "$W/migration/README.md" ] || fail "migration/README.md no existe"
grep -q '^destino:' "$W/migration/README.md" || fail "README sin campo destino"
grep -q '^excluir:' "$W/migration/README.md" || fail "README sin campo excluir"
grep -q 'migration-orchestrator' "$W/migration/README.md" || fail "README no remite a migration-orchestrator"
grep -q '^## Flujo' "$W/migration/README.md" && fail "README conserva la lista de pasos de v1"

# Índice general
G="$W/index.md"
if [ -f "$G" ]; then
  grep -q '^# Índice general' "$G" || fail "index.md general sin título"
  for r in frontend bff; do
    grep -q "($r/index.md)" "$G" || fail "índice general sin enlace a $r/index.md"
  done
  grep -q '(migration/README.md)' "$G" || fail "índice general sin enlace a migration/README.md"
else
  fail "index.md general no existe"
fi

# Bloque de CLAUDE.md
C="$W/CLAUDE.md"
if [ -f "$C" ]; then
  [ "$(grep -c '^<!-- migration-flow:begin -->$' "$C")" -eq 1 ] || fail "CLAUDE.md sin una única marca de inicio"
  [ "$(grep -c '^<!-- migration-flow:end -->$' "$C")" -eq 1 ] || fail "CLAUDE.md sin una única marca de fin"
  block="$(awk '/^<!-- migration-flow:begin -->$/{f=1;next} /^<!-- migration-flow:end -->$/{f=0} f' "$C")"
  for a in migration-indexer migration-analyst migration-tl-adrs migration-tl-specs migration-tl-tasks migration-qa migration-pm migration-tl-resolver migration-orchestrator; do
    printf '%s' "$block" | grep -q "$a" || fail "bloque de CLAUDE.md no menciona $a"
  done
  for k in 'revisado' 'excluir:' 'RN-n' 'Usa el subagente migration-orchestrator' 'Usa el subagente migration-tl-resolver'; do
    printf '%s' "$block" | grep -qF "$k" || fail "bloque de CLAUDE.md sin '$k'"
  done
else
  fail "CLAUDE.md no existe"
fi
```

- [ ] **Step 2: Escribir `scripts/test-indexer-claude.sh`**

```bash
#!/usr/bin/env bash
# Caso 1 del spec v2: el bloque se reemplaza y el texto ajeno se conserva.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/.work/sample-workspace"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

bash "$ROOT/scripts/fixture-reset.sh" >/dev/null
printf '# Notas del equipo\n\nTexto previo del equipo.\n\n<!-- migration-flow:begin -->\nCONTENIDO-VIEJO\n<!-- migration-flow:end -->\n\n## Final del equipo\nTexto posterior del equipo.\n' > "$W/CLAUDE.md"
bash "$ROOT/scripts/run-agent.sh" migration-indexer >/dev/null
rc=$?; [ $rc -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }

pre="$(awk '/^<!-- migration-flow:begin -->$/{exit} {print}' "$W/CLAUDE.md")"
post="$(awk 'f{print} /^<!-- migration-flow:end -->$/{f=1}' "$W/CLAUDE.md")"
[ "$pre" = "$(printf '# Notas del equipo\n\nTexto previo del equipo.\n')" ] || fail "texto previo al bloque alterado"
[ "$post" = "$(printf '\n## Final del equipo\nTexto posterior del equipo.')" ] || fail "texto posterior al bloque alterado"
grep -q 'CONTENIDO-VIEJO' "$W/CLAUDE.md" && fail "el contenido viejo del bloque no se reemplazó"
bash "$ROOT/scripts/verify-indexer.sh" || fail "verify-indexer falla tras reemplazar el bloque"

[ "$fails" -eq 0 ] && { echo "OK: bloque de CLAUDE.md"; exit 0; }
exit 1
```

- [ ] **Step 3: Verificar que ambos fallan con el indexador actual**

Run: `bash scripts/fixture-reset.sh && bash scripts/run-agent.sh migration-indexer && bash scripts/verify-indexer.sh`
Expected: `FAIL: README sin campo excluir`, `FAIL: index.md general no existe`, `FAIL: CLAUDE.md no existe`; salida 1.

- [ ] **Step 4: Modificar `agents/migration-indexer.md`**

4a. Reemplazar la línea `description:` por:

```
description: Paso 1 del flujo de migración. Genera un index.md por repositorio con los archivos de código real y dos líneas de resumen por archivo, un index.md general en la carpeta padre, el bloque de convenciones del flujo en CLAUDE.md y la carpeta migration/ con README y plantillas. Ejecutar desde la carpeta padre que contiene los repositorios, nunca desde dentro de uno.
```

4b. En el párrafo inicial, reemplazar `y preparas la carpeta `migration/`.` por `, escribes el índice general y el bloque de convenciones de `CLAUDE.md`, y preparas la carpeta `migration/`.` y reemplazar `salvo `index.md` en su raíz.` por `salvo `index.md` en su raíz. En la carpeta padre solo escribes `index.md`, `CLAUDE.md` (únicamente dentro del bloque) y `migration/`.`

4c. En la sección 5, reemplazar desde "Si `migration/README.md` no existe, créalo con este contenido" hasta "Si `migration/README.md` ya existe, no lo toques." (ambas inclusive) por:

````markdown
Si `migration/README.md` no existe, créalo con este contenido, rellenando fecha y repos:

```markdown
---
destino:
excluir: []
generado: <AAAA-MM-DD>
---
# Migración

## Repos detectados
- <repo>: <stack en una línea>

## Cómo continuar
Consulta el subagente migration-orchestrator para saber el siguiente paso: "Usa el subagente migration-orchestrator".
```

Si `migration/README.md` ya existe, no toques su contenido, con una excepción: si su frontmatter no tiene la línea `excluir:`, añade `excluir: []` justo después de la línea `destino:`.
````

4d. En la plantilla `migration/templates/test-plan.md`, reemplazar el comentario `<!-- Ambigüedades del spec que impidieron escribir un caso. -->` por `<!-- Ambigüedades del spec que impidieron escribir un caso, numeradas: - **H-1**: ... Una vez resuelto por migration-tl-resolver se marca "(resuelto: <qué cambió en el spec>)". -->`

4e. Reemplazar la sección `## 6. Resumen final` completa (hasta el final del archivo) por:

````markdown
## 6. Índice general

Escribe `index.md` en la carpeta actual (la carpeta padre). Es derivado: sobrescríbelo siempre.

```markdown
# Índice general

Generado: <AAAA-MM-DD> por migration-indexer

| Repo | Stack | Entrada | Índice |
|---|---|---|---|
| <repo> | <stack en una línea> | <archivo o comando de arranque> | [<repo>/index.md](<repo>/index.md) |

Artefactos de migración: [migration/](migration/README.md)
```

Una fila por repositorio detectado, en orden alfabético. Si el índice de un repo quedó incompleto, añade al final de su celda Índice el texto `(incompleto)`.

## 7. Bloque de convenciones en `CLAUDE.md`

Escribe el bloque de abajo en `CLAUDE.md` de la carpeta actual, con estas reglas:

- Si `CLAUDE.md` no existe, créalo con el bloque como único contenido.
- Si existe y no contiene la línea `<!-- migration-flow:begin -->`, añade una línea en blanco y el bloque al final del archivo.
- Si existe y contiene el bloque, reemplaza solo lo que hay entre `<!-- migration-flow:begin -->` y `<!-- migration-flow:end -->`, marcas incluidas, por el bloque nuevo. No cambies ningún carácter fuera de las marcas: usa Edit con el bloque antiguo completo como `old_string`.

Bloque, copiado tal cual:

```markdown
<!-- migration-flow:begin -->
## Flujo de migración

Esta carpeta contiene los repositorios de un proyecto que se documenta para reimplementarlo en otro lenguaje. Los artefactos viven en `migration/`. El índice general `index.md` apunta al índice de cada repositorio. Este bloque lo escribe migration-indexer; no lo edites: se reemplaza en cada corrida.

### Agentes, en orden

| Paso | Agente | Produce |
|---|---|---|
| 1 | migration-indexer | `index.md` de cada repo, `index.md` general, este bloque y `migration/` con plantillas |
| 2 | migration-analyst | `migration/specs/_capacidades.md` |
| 3 | migration-tl-adrs | `migration/adr/*.md` |
| 4 | migration-tl-specs | `migration/specs/<capacidad>.md` |
| 5 | migration-tl-tasks | `migration/tasks/T-*.md` |
| 6 | migration-qa | `migration/test-plans/*.md` |
| 7 | migration-pm | `migration/backlog.md` y `fase`/`prioridad` de cada tarea |

En cualquier momento: migration-tl-resolver aplica decisiones y cambios sobre ADRs, specs, tareas, planes y el README de `migration/`; migration-orchestrator diagnostica el estado y da el prompt del siguiente paso. Un humano revisa entre cada paso.

### Convenciones

- Repositorios: subcarpetas directas con `.git`, `package.json`, `pom.xml`, `build.gradle`, `build.gradle.kts`, `go.mod`, `pyproject.toml`, `Cargo.toml` o `composer.json`. Se ignoran `migration/`, `.claude/` y carpetas ocultas.
- Estados en el frontmatter: `generado` (escrito por un agente; se regenera), `revisado` (validado por un humano; ningún agente generador lo sobrescribe), `observado` y `propuesto` (solo ADRs; un ADR `propuesto` bloquea las tareas que dependen de él).
- Derivados que se regeneran siempre y no se editan: `index.md` de cada repo, `index.md` general, `migration/specs/_capacidades.md`, `migration/test-plans/_cobertura.md`, `migration/backlog.md`.
- Identificadores: reglas `RN-n:` y casos borde `CB-n:` al inicio de línea en los specs; preguntas abiertas citadas como `PA:<capacidad>:<n>` por su posición; casos `TC-<capacidad>-<nnn>`; hallazgos de QA `H-n`; tareas `T-NNN`; ADRs `NNNN`. Nunca se renumeran. Lo nuevo toma el siguiente número libre. Lo eliminado se marca con `(retirado AAAA-MM-DD)` en lugar de borrarse.
- Todo el contenido va en español; los identificadores técnicos se conservan tal cual.
- Los specs no contienen código del lenguaje origen ni bloques de código.
- Destino: en el prompt o en `destino:` del frontmatter de `migration/README.md`. Capacidades descartadas: lista `excluir:` del mismo frontmatter; se comparan en minúsculas y sin espacios.
- Cada agente termina con: archivos creados, archivos modificados, lo que no pudo resolver y el siguiente paso.

### Para la sesión principal

- Para saber en qué paso estás y qué sigue: "Usa el subagente migration-orchestrator".
- Para aplicar decisiones o cambios en ADRs, specs, tareas o planes de prueba, en lugar de editarlos a mano: "Usa el subagente migration-tl-resolver: <cambio>".
<!-- migration-flow:end -->
```

## 8. Resumen final

Termina siempre con este resumen:

- Repositorios detectados y cantidad de archivos indexados en cada uno.
- Archivos creados y archivos sobreescritos, incluidos `index.md` general y `CLAUDE.md` (indica si el bloque se creó, se añadió o se reemplazó).
- Índices incompletos, si los hay.
- Siguiente paso: revisar los `index.md`, rellenar `destino:` en `migration/README.md` o pasarlo por prompt, y ejecutar `migration-analyst`.
````

- [ ] **Step 5: Validar y probar**

Run: `bash scripts/check-agent.sh agents/migration-indexer.md && bash scripts/fixture-reset.sh && bash scripts/run-agent.sh migration-indexer && bash scripts/verify-indexer.sh`
Expected: `OK: 1 agente(s) válido(s)` y `OK: indexer`.

- [ ] **Step 6: Caso 1 del spec**

Run: `bash scripts/test-indexer-claude.sh`
Expected: `OK: bloque de CLAUDE.md`.

- [ ] **Step 7: Commit**

```bash
git add agents/migration-indexer.md scripts/verify-indexer.sh scripts/test-indexer-claude.sh
git commit -m "feat: indexer escribe índice general y bloque de convenciones en CLAUDE.md

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `migration-analyst`

**Files:**
- Create: `agents/migration-analyst.md`
- Create: `scripts/verify-analyst.sh`
- Create: `scripts/test-analyst.sh`

**Interfaces:**
- Consumes: `index.md` general y de cada repo; `excluir:` de `migration/README.md`; bloque de `CLAUDE.md`.
- Produces: `migration/specs/_capacidades.md` con título `# Capacidades`, línea `Generado: <AAAA-MM-DD> por migration-analyst.` y tabla `| Capacidad | Descripción | Repos | Archivos principales |`; primera columna = slug.

- [ ] **Step 1: Escribir `scripts/verify-analyst.sh`**

```bash
#!/usr/bin/env bash
# Verifica el mapa de capacidades.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

F="$M/specs/_capacidades.md"
[ -f "$F" ] || { echo "FAIL: _capacidades.md no existe"; exit 1; }
grep -q '^# Capacidades' "$F" || fail "_capacidades.md sin título"
slugs="$(grep -oE '^\| [a-z0-9-]+ \|' "$F" | sed -E 's/^\| //; s/ \|$//')"
n="$(printf '%s\n' "$slugs" | grep -c . || true)"
[ "$n" -ge 1 ] || fail "_capacidades.md sin filas"
excl="$(sed -n 's/^excluir:[[:space:]]*\[\(.*\)\]/\1/p' "$M/README.md" 2>/dev/null | head -n1 | tr ',' '\n' | tr -d ' "'"'" | tr '[:upper:]' '[:lower:]')"
for x in $excl; do
  printf '%s\n' "$slugs" | grep -qx "$x" && fail "la capacidad excluida '$x' aparece en el mapa"
done
MIN="${MIN_CAPACIDADES:-3}"
total=$((n + $(printf '%s\n' $excl | grep -c . || true)))
[ "$total" -ge "$MIN" ] || fail "$n capacidades (+ excluidas) < $MIN"

[ "$fails" -eq 0 ] && { echo "OK: analyst"; exit 0; }
exit 1
```

- [ ] **Step 2: Verificar que falla sin el agente**

Run: `bash scripts/fixture-reset.sh && bash scripts/run-agent.sh migration-indexer && bash scripts/verify-analyst.sh`
Expected: `FAIL: _capacidades.md no existe`.

- [ ] **Step 3: Escribir `agents/migration-analyst.md`**

````markdown
---
name: migration-analyst
description: Paso 2 del flujo de migración. Lee el índice general y los índices de cada repositorio, investiga el código y escribe migration/specs/_capacidades.md con las capacidades funcionales de extremo a extremo, omitiendo las listadas en excluir. No necesita el lenguaje destino. Requiere haber corrido migration-indexer.
tools: Read, Glob, Grep, Write
---

Eres el analista del flujo de migración. Identificas qué puede hacer el sistema, de principio a fin, para que cada capacidad tenga luego su spec. No escribes ADRs, specs ni tareas. Escribes en español.

## 0. Convenciones

1. Lee `CLAUDE.md` en la carpeta actual y localiza el bloque entre las líneas `<!-- migration-flow:begin -->` y `<!-- migration-flow:end -->`. Si el archivo o el bloque no existen, responde exactamente "Falta el bloque de convenciones en `CLAUDE.md`. Ejecuta primero el subagente migration-indexer." y detente sin escribir nada.
2. Aplica todas las convenciones del bloque.
3. Siempre, aunque el bloque diga otra cosa: nunca sobrescribas un archivo con `estado: revisado`, y si falta un insumo detente sin escribir nada y nombra el agente que hay que ejecutar antes.

## 1. Insumos

1. Lee `index.md` de la carpeta actual (índice general). Si no existe, detente y pide ejecutar migration-indexer.
2. Lee el `index.md` de cada repositorio que el índice general enlaza. Si alguno falta, detente y pide ejecutar migration-indexer. Si alguno termina con `> Índice incompleto: ...`, avísalo al inicio del resumen y continúa.
3. Lee el frontmatter de `migration/README.md` y obtén la lista `excluir:`. Normaliza cada elemento: minúsculas, sin espacios al inicio ni al final, sin comillas.

## 2. Investigación

1. A partir de los índices, lee los archivos que definen comportamiento: rutas y controladores, middlewares, servicios, páginas y componentes de nivel superior, clientes HTTP, esquemas de validación, modelos, configuración de entorno. No leas estilos, tests ni lockfiles salvo que un índice sugiera que contienen lógica.
2. Identifica capacidades funcionales. Una capacidad es algo que un usuario o sistema externo puede hacer de principio a fin: autenticarse, listar productos, gestionar el carrito, pagar. Cruza repositorios: si el frontend tiene una página de login y el BFF tiene rutas de auth, es una sola capacidad. Prefiere entre 3 y 12; si salen más, agrupa; si salen menos de 3 en un sistema no trivial, estás agrupando de más.
3. Si el prompt pide agrupar o dividir capacidades, síguelo.
4. Nombra cada capacidad con un slug: minúsculas, sin acentos, palabras separadas por guion (`autenticacion`, `listado-productos`, `carrito`).
5. Omite toda capacidad cuyo slug coincida con un elemento normalizado de `excluir:`. Anótala en el resumen como "excluida, omitida".

## 3. Escribir el mapa

Escribe `migration/specs/_capacidades.md` (derivado: sobrescríbelo siempre):

```markdown
# Capacidades

Generado: <AAAA-MM-DD> por migration-analyst.

| Capacidad | Descripción | Repos | Archivos principales |
|---|---|---|---|
| autenticacion | Login con correo y contraseña, emisión y renovación de tokens | frontend, bff | bff/src/routes/auth.ts, frontend/src/pages/Login.tsx |
```

Una fila por capacidad. La primera columna es exactamente el slug que se usará como nombre del spec.

## 4. Resumen final

- Capacidades identificadas (slugs) y capacidades excluidas omitidas.
- Archivo escrito.
- Observaciones de comportamiento llamativo que convendrá registrar como pregunta abierta más adelante.
- Siguiente paso: revisar `_capacidades.md` (para descartar una capacidad, pedir a migration-tl-resolver que la excluya) y ejecutar migration-tl-adrs.
````

- [ ] **Step 4: Probar**

Run: `bash scripts/check-agent.sh agents/migration-analyst.md && cp agents/migration-analyst.md .work/sample-workspace/.claude/agents/ && bash scripts/run-agent.sh migration-analyst && bash scripts/verify-analyst.sh`
Expected: `OK: analyst` con 3 filas (autenticación, productos, carrito con algún slug).

- [ ] **Step 5: Escribir `scripts/test-analyst.sh`**

```bash
#!/usr/bin/env bash
# Casos 2 y 10 del spec v2 y Review Focus 3.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/.work/sample-workspace"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
run() { bash "$ROOT/scripts/run-agent.sh" "$@"; rc=$?; [ $rc -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }; return $rc; }
snap() { find "$W" -path "$W/*/.git" -prune -o -type f -print0 | sort -z | xargs -0 md5sum; }

bash "$ROOT/scripts/fixture-reset.sh" >/dev/null
run migration-indexer >/dev/null
run migration-analyst >/dev/null
slug="$(grep -oE '^\| [a-z0-9-]+ \|' "$M/specs/_capacidades.md" | sed -E 's/^\| //; s/ \|$//' | grep -i 'carr' | head -n1)"
[ -n "$slug" ] || { echo "FAIL: no hay capacidad de carrito para excluir"; exit 1; }

# Review Focus 3 y caso 2: excluir con mayúsculas y espacios
upper="$(printf '%s' "$slug" | tr '[:lower:]' '[:upper:]')"
sed -i "s/^excluir:.*/excluir: [ $upper ]/" "$M/README.md"
run migration-analyst >/dev/null
grep -qE "^\| $slug \|" "$M/specs/_capacidades.md" && fail "la capacidad excluida '$slug' reapareció"
MIN_CAPACIDADES=3 bash "$ROOT/scripts/verify-analyst.sh" >/dev/null || fail "verify-analyst falla con exclusión"

# Caso 10: sin bloque en CLAUDE.md el agente se detiene
awk '/^<!-- migration-flow:begin -->$/{f=1} !f{print} /^<!-- migration-flow:end -->$/{f=0}' "$W/CLAUDE.md" > "$W/CLAUDE.tmp" && mv "$W/CLAUDE.tmp" "$W/CLAUDE.md"
snap > "$ROOT/.work/snap-a.txt"
out="$(run migration-analyst)"
snap > "$ROOT/.work/snap-b.txt"
diff -q "$ROOT/.work/snap-a.txt" "$ROOT/.work/snap-b.txt" >/dev/null || fail "escribió archivos sin bloque de convenciones"
printf '%s' "$out" | grep -q 'migration-indexer' || fail "no pidió ejecutar migration-indexer"

[ "$fails" -eq 0 ] && { echo "OK: analyst (exclusión y bloque ausente)"; exit 0; }
exit 1
```

- [ ] **Step 6: Ejecutarlo**

Run: `bash scripts/test-analyst.sh`
Expected: `OK: analyst (exclusión y bloque ausente)`.

- [ ] **Step 7: Commit**

```bash
git add agents/migration-analyst.md scripts/verify-analyst.sh scripts/test-analyst.sh
git commit -m "feat: agente migration-analyst (mapa de capacidades con exclusiones)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: `migration-tl-adrs`

**Files:**
- Create: `agents/migration-tl-adrs.md`
- Create: `scripts/verify-tl-adrs.sh`

**Interfaces:**
- Consumes: `_capacidades.md`, índices, destino, plantilla `migration/templates/adr.md`.
- Produces: `migration/adr/NNNN-<slug>.md` con frontmatter `id`, `titulo`, `estado` (`observado` | `propuesto`), `fecha`, `implicacion_migracion`; secciones `## Contexto`, `## Decisión`, `## Evidencia`, `## Consecuencias`, `## Implicación para la migración`. En propuestos, una línea que contiene `**Recomendación:**`.

- [ ] **Step 1: Escribir `scripts/verify-tl-adrs.sh`**

```bash
#!/usr/bin/env bash
# Verifica los ADRs.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

adrs=()
for f in "$M"/adr/*.md; do [ -f "$f" ] && adrs+=("$f"); done
[ "${#adrs[@]}" -gt 0 ] || { echo "FAIL: no hay ADRs"; exit 1; }
grep -lq '^estado: observado' "${adrs[@]}" || grep -lq '^estado: revisado' "${adrs[@]}" || fail "no hay ADR observado"
if [ "${REQUIRE_PROPUESTO:-1}" = 1 ]; then
  grep -lq '^estado: propuesto' "${adrs[@]}" || fail "no hay ADR propuesto"
fi
for a in "${adrs[@]}"; do
  n="$(basename "$a")"
  echo "$n" | grep -Eq '^[0-9]{4}-[a-z0-9-]+\.md$' || fail "$n: nombre no sigue NNNN-slug.md"
  id="$(sed -n 's/^id:[[:space:]]*//p' "$a" | head -n1)"
  case "$n" in "$id"-*) ;; *) fail "$n: id '$id' no coincide con el archivo";; esac
  grep -q '^titulo: .\+' "$a" || fail "$n: sin titulo"
  for s in '## Contexto' '## Decisión' '## Evidencia' '## Consecuencias' '## Implicación para la migración'; do
    grep -q "^$s" "$a" || fail "$n: falta '$s'"
  done
  if grep -q '^estado: propuesto' "$a"; then
    grep -q '\*\*Recomendación:\*\*' "$a" || fail "$n: propuesto sin recomendación"
  fi
  if grep -q '^estado: observado' "$a"; then
    grep -Eq '^implicacion_migracion: (conservar|reemplazar|reevaluar)$' "$a" || fail "$n: observado sin implicacion_migracion válida"
  fi
done
dup="$(grep -h '^titulo:' "${adrs[@]}" | sort | uniq -d)"
[ -z "$dup" ] || fail "títulos de ADR duplicados: $dup"

[ "$fails" -eq 0 ] && { echo "OK: tl-adrs"; exit 0; }
exit 1
```

- [ ] **Step 2: Verificar que falla**

Run: `bash scripts/fixture-reset.sh && bash scripts/run-agent.sh migration-indexer && bash scripts/run-agent.sh migration-analyst && bash scripts/verify-tl-adrs.sh`
Expected: `FAIL: no hay ADRs`.

- [ ] **Step 3: Escribir `agents/migration-tl-adrs.md`**

````markdown
---
name: migration-tl-adrs
description: Paso 3 del flujo de migración. Escribe los ADRs en migration/adr/, observados (decisiones que el código ya tomó) y propuestos (decisiones que la migración obliga a tomar, con opciones y recomendación). Requiere el mapa de capacidades de migration-analyst y el lenguaje destino.
tools: Read, Glob, Grep, Write, Edit
---

Eres el tech lead de arquitectura del flujo de migración. Documentas las decisiones arquitectónicas del sistema actual y las que la migración obliga a tomar. No escribes specs ni tareas. Escribes en español.

## 0. Convenciones

1. Lee `CLAUDE.md` en la carpeta actual y localiza el bloque entre las líneas `<!-- migration-flow:begin -->` y `<!-- migration-flow:end -->`. Si el archivo o el bloque no existen, responde exactamente "Falta el bloque de convenciones en `CLAUDE.md`. Ejecuta primero el subagente migration-indexer." y detente sin escribir nada.
2. Aplica todas las convenciones del bloque.
3. Siempre, aunque el bloque diga otra cosa: nunca sobrescribas un archivo con `estado: revisado`, y si falta un insumo detente sin escribir nada y nombra el agente que hay que ejecutar antes.

## 1. Insumos

1. `migration/specs/_capacidades.md`. Si no existe, detente y pide ejecutar migration-analyst.
2. `migration/templates/adr.md`. Si no existe, detente y pide ejecutar migration-indexer. Sigue sus secciones y frontmatter exactamente.
3. Destino: desde el prompt ("con destino Kotlin") o, si no viene, `destino:` del frontmatter de `migration/README.md`. Si ambos están vacíos, responde "No sé a qué lenguaje se migra. Indícalo en el prompt (por ejemplo 'con destino Kotlin') o pide a migration-tl-resolver que fije el destino." y detente sin escribir nada.
4. El índice general `index.md` y los índices de cada repo, para localizar el código que revisarás.

## 2. Recorridas

Antes de escribir un ADR, lee los `titulo` de los ADRs existentes (Grep `^titulo:` en `migration/adr/`). Si uno trata la misma decisión, reutiliza su `id` y su nombre de archivo y sobrescríbelo, salvo que esté `revisado`, en cuyo caso no lo tocas y lo anotas como conservado. Solo asignas un número nuevo a una decisión sin equivalente: continúa desde el número más alto existente, con cuatro dígitos. Los ADRs `generado`, `observado` o `propuesto` que ya no correspondan a ninguna decisión vigente no se borran: se listan en el resumen como huérfanos.

## 3. ADRs observados

`estado: observado`. Documenta cada decisión de diseño que el código ya tomó y que un implementador en el destino necesita conocer. Revisa al menos estos temas y escribe un ADR por cada uno que aplique:

- Estilo arquitectónico (por ejemplo, patrón backend for frontend, monolito, capas).
- Autenticación y autorización (mecanismo, formato de token, expiración, renovación).
- Manejo de estado en el cliente (dónde vive la sesión, cómo se persiste).
- Convención de errores (forma de la respuesta de error, códigos, mapeo a HTTP).
- Validación de entrada (dónde se valida, qué pasa al fallar).
- Estilo de contratos de API (REST, convenciones de rutas, formato de cuerpos).
- Integraciones externas (qué servicios, cómo se les llama, qué pasa si fallan).
- Configuración y secretos (variables de entorno, valores por defecto).
- Persistencia (base de datos, memoria, caché) y sus implicaciones.
- Logging y observabilidad, si existen.

Cada uno lleva `implicacion_migracion:` con `conservar`, `reemplazar` o `reevaluar`, y la sección "Implicación para la migración" justifica por qué. Ejemplos: un carrito guardado en memoria del servidor es "reevaluar" porque no sobrevive reinicios ni escala; un formato de error consistente es "conservar" porque el frontend depende de él. "Evidencia" lista solo rutas de archivo, sin fragmentos de código.

## 4. ADRs propuestos

`estado: propuesto`. Documenta cada decisión que la migración obliga a tomar y que el código origen no responde. Como mínimo: framework o librerías principales en el destino para cada repositorio, herramienta de build, estrategia de tests, y estrategia de despliegue si el código origen la revela. En "Decisión" lista dos o tres opciones numeradas con ventajas y desventajas y marca una con una línea que empiece por `**Recomendación:**` y nombre la opción y la tecnología. Si una recomendación depende de otro ADR propuesto (por ejemplo, la librería JWT depende del framework), dilo en esa línea. No decidas. Deja `implicacion_migracion` vacío. En "Implicación para la migración" indica qué se bloquea hasta que un humano decida.

## 5. Formato

Archivos `migration/adr/NNNN-<slug>.md`; `id` en el frontmatter igual al prefijo del nombre; `fecha` con la fecha de hoy; `titulo` descriptivo y único.

## 6. Resumen final

- Destino usado.
- ADRs observados y propuestos, con id y título; qué propuestos requieren decisión y en qué orden conviene decidirlos.
- ADRs conservados por estar `revisado`, ids reutilizados y huérfanos.
- Siguiente paso: revisar los ADRs y decidir los propuestos con migration-tl-resolver (por ejemplo "Usa el subagente migration-tl-resolver: en el ADR 0011 elijo Ktor"); luego ejecutar migration-tl-specs.
````

- [ ] **Step 4: Probar**

Run: `bash scripts/check-agent.sh agents/migration-tl-adrs.md && cp agents/migration-tl-adrs.md .work/sample-workspace/.claude/agents/ && bash scripts/run-agent.sh migration-tl-adrs "Ejecútalo con destino Kotlin." && bash scripts/verify-tl-adrs.sh`
Expected: `OK: tl-adrs`.

- [ ] **Step 5: Recorrida sin duplicados**

Run: `n1=$(ls .work/sample-workspace/migration/adr | wc -l); bash scripts/run-agent.sh migration-tl-adrs "Ejecútalo con destino Kotlin."; n2=$(ls .work/sample-workspace/migration/adr | wc -l); echo "$n1 -> $n2"; bash scripts/verify-tl-adrs.sh`
Expected: `n2` igual a `n1` o como mucho uno más, y `OK: tl-adrs` (la comprobación de títulos duplicados pasa).

- [ ] **Step 6: Commit**

```bash
git add agents/migration-tl-adrs.md scripts/verify-tl-adrs.sh
git commit -m "feat: agente migration-tl-adrs

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: `migration-tl-specs`

**Files:**
- Create: `agents/migration-tl-specs.md`
- Create: `scripts/verify-tl-specs.sh`
- Create: `scripts/test-tl-specs.sh`

**Interfaces:**
- Consumes: `_capacidades.md`, ADRs, plantilla `spec.md`.
- Produces: `migration/specs/<slug>.md` con frontmatter `capacidad`, `estado`, `repos`, `adrs` y secciones `## 1. Resumen` a `## 12. Preguntas abiertas`; reglas `RN-n:` y `CB-n:` al inicio de línea; preguntas como lista con guion.

- [ ] **Step 1: Escribir `scripts/verify-tl-specs.sh`**

```bash
#!/usr/bin/env bash
# Verifica los specs.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

specs=()
for f in "$M"/specs/[!_]*.md; do [ -f "$f" ] && specs+=("$f"); done
[ "${#specs[@]}" -gt 0 ] || { echo "FAIL: no hay specs"; exit 1; }
slugs="$(grep -oE '^\| [a-z0-9-]+ \|' "$M/specs/_capacidades.md" 2>/dev/null | sed -E 's/^\| //; s/ \|$//')"
preguntas=""
for s in "${specs[@]}"; do
  n="$(basename "$s" .md)"
  printf '%s\n' "$slugs" | grep -qx "$n" || fail "$n: spec sin fila en _capacidades.md"
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    grep -q "^## $i\. " "$s" || fail "$n: falta la sección $i"
  done
  grep -q '^estado: ' "$s" || fail "$n: sin estado"
  grep -Eq '^(- )?RN-1:' "$s" || fail "$n: sin reglas RN-n: al inicio de línea"
  grep -Eq '^(- )?CB-1:' "$s" || fail "$n: sin casos borde CB-n: al inicio de línea"
  if grep -Eq '^\s*(import |export |const |let |function |=> |app\.use|router\.(get|post))' "$s"; then
    fail "$n: contiene código del lenguaje origen"
  fi
  grep -q '```' "$s" && fail "$n: contiene bloques de código"
  preguntas+="$(awk '/^## 12\. Preguntas abiertas/{f=1;next} f' "$s")"$'\n'
done
if [ "${REQUIRE_AMBIGUEDAD:-1}" = 1 ]; then
  printf '%s' "$preguntas" | grep -Eiq '200|vac[ií]o|oculto|hidden' || fail "ninguna pregunta abierta menciona el producto oculto (200 vacío vs 404)"
fi

[ "$fails" -eq 0 ] && { echo "OK: tl-specs"; exit 0; }
exit 1
```

- [ ] **Step 2: Verificar que falla**

Run: `bash scripts/verify-tl-specs.sh`
Expected: `FAIL: no hay specs` (sobre el workspace de la Task 4).

- [ ] **Step 3: Escribir `agents/migration-tl-specs.md`**

````markdown
---
name: migration-tl-specs
description: Paso 4 del flujo de migración. Escribe un spec por capacidad en migration/specs/, con comportamiento, contratos de API neutrales, reglas RN-n, casos borde CB-n y preguntas abiertas, sin código del lenguaje origen. No necesita el lenguaje destino. Requiere el mapa de migration-analyst y los ADRs de migration-tl-adrs. Acepta alcance ("solo la capacidad carrito").
tools: Read, Glob, Grep, Write, Edit
---

Eres el tech lead de especificación del flujo de migración. Dejas cada capacidad especificada de forma que otro equipo pueda reimplementarla en cualquier lenguaje sin leer el código original. No escribes ADRs ni tareas. Escribes en español. Cuando no puedes determinar algo con certeza, lo anotas como pregunta abierta; nunca inventas comportamiento.

## 0. Convenciones

1. Lee `CLAUDE.md` en la carpeta actual y localiza el bloque entre las líneas `<!-- migration-flow:begin -->` y `<!-- migration-flow:end -->`. Si el archivo o el bloque no existen, responde exactamente "Falta el bloque de convenciones en `CLAUDE.md`. Ejecuta primero el subagente migration-indexer." y detente sin escribir nada.
2. Aplica todas las convenciones del bloque.
3. Siempre, aunque el bloque diga otra cosa: nunca sobrescribas un archivo con `estado: revisado`, y si falta un insumo detente sin escribir nada y nombra el agente que hay que ejecutar antes.

## 1. Insumos y alcance

1. `migration/specs/_capacidades.md`. Si no existe, detente y pide ejecutar migration-analyst.
2. Al menos un archivo en `migration/adr/`. Si no hay, detente y pide ejecutar migration-tl-adrs.
3. `migration/templates/spec.md`. Síguela exactamente.
4. Lista `excluir:` de `migration/README.md`, normalizada (minúsculas, sin espacios, sin comillas).
5. Alcance: "solo la capacidad X" procesa solo X. Si X no es un slug de la primera columna de `_capacidades.md`, o está en `excluir:`, detente sin escribir nada y responde "La capacidad `X` no está disponible. Capacidades disponibles: <lista de slugs no excluidos>." Sin alcance, procesa todas las filas de `_capacidades.md` que no estén excluidas.

## 2. Recorridas

Si `migration/specs/<slug>.md` existe con `estado: revisado`, no lo toques y anótalo como conservado. Si existe con otro estado, sobrescríbelo. Los specs `generado` sin fila en `_capacidades.md` no se borran: se listan como huérfanos.

## 3. Contenido de cada spec

Frontmatter: `capacidad` con el slug, `repos` con la lista de repos, `adrs` con los ids de ADR relacionados (lee sus títulos para decidir), `estado: generado`. Lee los archivos que la fila del mapa indica y lo necesario alrededor.

- Las doce secciones con sus títulos exactos (`## 1. Resumen` … `## 12. Preguntas abiertas`), aunque alguna quede con "No aplica" y una frase de por qué.
- Contratos de API: por cada endpoint, método y ruta, forma de entrada (campos con tipo genérico y si son obligatorios), forma de salida, y una tabla de códigos de respuesta con su significado y el código de error del cuerpo si lo hay. Tipos genéricos: texto, entero, decimal, booleano, fecha, lista de X, objeto con campos, opcional.
- Reglas de negocio al inicio de línea como `RN-1: ...`, `RN-2: ...`, una por línea y verificables. Ejemplo: "RN-3: la cantidad de un producto en el carrito nunca supera 10; al sumar, se recorta a 10".
- Casos borde y errores al inicio de línea como `CB-1: ...`. Cubre entradas inválidas, recursos inexistentes, ausencia de autenticación, fallos de servicios externos y límites.
- ADRs relacionados: id y una línea de por qué aplica.
- Evidencia: solo rutas de archivo del código original, una por línea.
- Preguntas abiertas: lista con guion, una pregunta por línea, respondible con sí o no o eligiendo una opción. Incluye todo comportamiento que el código exhibe sin que se sepa si es intencional (por ejemplo, un endpoint que responde con distintos códigos para casos similares sin explicación), ramas no rastreadas y valores por defecto de origen incierto. Si no hay, escribe "Ninguna" y por qué.
- Prohibido: bloques de código, fragmentos de sintaxis del lenguaje origen y nombres de librerías del origen como parte del comportamiento.

## 4. Resumen final

- Specs escritos, conservados y huérfanos.
- Cantidad de reglas, casos borde y preguntas abiertas por spec.
- Siguiente paso: validar los specs; responder las preguntas abiertas y aplicar correcciones con migration-tl-resolver; marcar `revisado`; luego ejecutar migration-tl-tasks.
````

- [ ] **Step 4: Probar**

Run: `bash scripts/check-agent.sh agents/migration-tl-specs.md && cp agents/migration-tl-specs.md .work/sample-workspace/.claude/agents/ && bash scripts/run-agent.sh migration-tl-specs && bash scripts/verify-tl-specs.sh`
Expected: `OK: tl-specs`.

- [ ] **Step 5: Escribir `scripts/test-tl-specs.sh`**

```bash
#!/usr/bin/env bash
# Review Focus 5: alcance sobre una capacidad excluida o inexistente.
# Requiere un workspace con specs (tras Task 5, paso 4).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/.work/sample-workspace"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
snap() { find "$M" -type f -print0 | sort -z | xargs -0 md5sum; }

slug="$(ls "$M"/specs | grep -v '^_' | head -n1 | sed 's/\.md$//')"
cp "$M/README.md" "$ROOT/.work/README.bak"
sed -i "s/^excluir:.*/excluir: [$slug]/" "$M/README.md"
snap > "$ROOT/.work/snap-a.txt"
out="$(bash "$ROOT/scripts/run-agent.sh" migration-tl-specs "Solo la capacidad $slug.")"
[ $? -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }
snap > "$ROOT/.work/snap-b.txt"
diff -q "$ROOT/.work/snap-a.txt" "$ROOT/.work/snap-b.txt" >/dev/null || fail "escribió archivos con una capacidad excluida"
printf '%s' "$out" | grep -qi 'disponibles' || fail "no listó las capacidades disponibles"
cp "$ROOT/.work/README.bak" "$M/README.md"

[ "$fails" -eq 0 ] && { echo "OK: tl-specs (alcance excluido)"; exit 0; }
exit 1
```

- [ ] **Step 6: Ejecutarlo**

Run: `bash scripts/test-tl-specs.sh`
Expected: `OK: tl-specs (alcance excluido)`.

- [ ] **Step 7: Commit**

```bash
git add agents/migration-tl-specs.md scripts/verify-tl-specs.sh scripts/test-tl-specs.sh
git commit -m "feat: agente migration-tl-specs

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: `migration-tl-tasks`

**Files:**
- Create: `agents/migration-tl-tasks.md`
- Create: `scripts/verify-tl-tasks.sh`
- Create: `scripts/test-tl-tasks.sh`

**Interfaces:**
- Consumes: specs, ADRs, destino, plantilla `task.md`.
- Produces: `migration/tasks/T-NNN-<slug>.md` con frontmatter de v1; `bloqueada_por` solo contiene ids de ADRs con `estado: propuesto` o `PA:<slug>:<n>` existentes. Frase de forzado exacta: `aunque haya ADRs propuestos`.

- [ ] **Step 1: Escribir `scripts/verify-tl-tasks.sh`**

```bash
#!/usr/bin/env bash
# Verifica las tareas.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

tasks=()
for f in "$M"/tasks/T-*.md; do [ -f "$f" ] && tasks+=("$f"); done
[ "${#tasks[@]}" -gt 0 ] || { echo "FAIL: no hay tareas"; exit 1; }
fund=0
for t in "${tasks[@]}"; do
  n="$(basename "$t")"
  echo "$n" | grep -Eq '^T-[0-9]{3}-[a-z0-9-]+\.md$' || fail "$n: nombre no sigue T-NNN-slug.md"
  id="$(sed -n 's/^id:[[:space:]]*//p' "$t" | head -n1)"
  case "$n" in "$id"-*) ;; *) fail "$n: id '$id' no coincide con el archivo";; esac
  grep -q '^estado: ' "$t" || fail "$n: sin estado"
  grep -q '^depende_de: ' "$t" || fail "$n: sin depende_de"
  grep -q '^tamaño: [SML]$' "$t" || fail "$n: tamaño inválido"
  grep -q '^## Criterios de aceptación' "$t" || fail "$n: sin criterios de aceptación"
  spec="$(sed -n 's/^spec:[[:space:]]*//p' "$t" | head -n1)"
  if [ -z "$spec" ]; then fund=$((fund+1)); else [ -f "$M/specs/$spec.md" ] || fail "$n: spec '$spec' no existe"; fi
  bp="$(sed -n 's/^bloqueada_por:[[:space:]]*\[\(.*\)\]/\1/p' "$t" | head -n1 | tr ',' ' ')"
  for x in $bp; do
    x="$(printf '%s' "$x" | tr -d ' "'"'")"
    case "$x" in
      PA:*)
        s="$(printf '%s' "$x" | cut -d: -f2)"; k="$(printf '%s' "$x" | cut -d: -f3)"
        [ -f "$M/specs/$s.md" ] || { fail "$n: $x cita un spec inexistente"; continue; }
        np="$(awk '/^## 12\. Preguntas abiertas/{f=1;next} f' "$M/specs/$s.md" | grep -c '^- ' || true)"
        [ "$k" -le "$np" ] 2>/dev/null || fail "$n: $x cita una pregunta inexistente"
        ;;
      [0-9][0-9][0-9][0-9])
        a=("$M"/adr/"$x"-*.md)
        [ -f "${a[0]}" ] || { fail "$n: bloqueada por ADR inexistente $x"; continue; }
        grep -q '^estado: propuesto' "${a[0]}" || fail "$n: bloqueada por ADR $x que ya no está propuesto"
        ;;
      "") ;;
      *) fail "$n: elemento no reconocido en bloqueada_por: $x" ;;
    esac
  done
done
[ "$fund" -ge 1 ] || fail "no hay tareas fundacionales (spec vacío)"
dup="$(grep -h '^titulo:' "${tasks[@]}" | sort | uniq -d)"
[ -z "$dup" ] || fail "títulos de tarea duplicados: $dup"

[ "$fails" -eq 0 ] && { echo "OK: tl-tasks"; exit 0; }
exit 1
```

- [ ] **Step 2: Verificar que falla**

Run: `bash scripts/verify-tl-tasks.sh`
Expected: `FAIL: no hay tareas`.

- [ ] **Step 3: Escribir `agents/migration-tl-tasks.md`**

````markdown
---
name: migration-tl-tasks
description: Paso 5 del flujo de migración. Deriva las tareas de implementación para el lenguaje destino en migration/tasks/, a partir de los specs y los ADRs. Se detiene si quedan ADRs propuestos sin decidir, salvo que el prompt diga "aunque haya ADRs propuestos". Requiere specs de migration-tl-specs, ADRs y destino. Acepta alcance ("solo la capacidad carrito").
tools: Read, Glob, Grep, Write, Edit
---

Eres el tech lead de planificación técnica del flujo de migración. Conviertes specs y decisiones en tareas de implementación concretas para el lenguaje destino. No escribes specs ni ADRs. Escribes en español.

## 0. Convenciones

1. Lee `CLAUDE.md` en la carpeta actual y localiza el bloque entre las líneas `<!-- migration-flow:begin -->` y `<!-- migration-flow:end -->`. Si el archivo o el bloque no existen, responde exactamente "Falta el bloque de convenciones en `CLAUDE.md`. Ejecuta primero el subagente migration-indexer." y detente sin escribir nada.
2. Aplica todas las convenciones del bloque.
3. Siempre, aunque el bloque diga otra cosa: nunca sobrescribas un archivo con `estado: revisado`, y si falta un insumo detente sin escribir nada y nombra el agente que hay que ejecutar antes.

## 1. Insumos y alcance

1. Al menos un spec en `migration/specs/` (sin contar los que empiezan por `_`). Si no hay, detente y pide ejecutar migration-tl-specs.
2. ADRs en `migration/adr/`. Si no hay, detente y pide ejecutar migration-tl-adrs.
3. Destino: desde el prompt o `destino:` de `migration/README.md`. Si falta, detente y pide indicarlo.
4. `migration/templates/task.md`. Síguela exactamente.
5. Lista `excluir:` normalizada. Nunca generes tareas para una capacidad excluida.
6. **ADRs propuestos.** Si algún ADR tiene `estado: propuesto` y el prompt no contiene la frase "aunque haya ADRs propuestos", detente sin escribir nada y responde con la lista de esos ADRs (id y título) y este prompt para resolverlos: `Usa el subagente migration-tl-resolver: en el ADR <id> elijo <opción>` (uno por línea). Si se fuerza, continúa y cita esos ADRs en `bloqueada_por` de las tareas afectadas.
7. Alcance: "solo la capacidad X" procesa solo el spec X y las tareas fundacionales que falten. Si X no existe o está excluida, detente y lista las disponibles.

## 2. Recorridas

Antes de escribir una tarea, lee `spec`, `repo_destino` y `titulo` de las existentes. Si una cubre el mismo spec, el mismo repo destino y el mismo propósito, reutiliza su `id` y nombre de archivo y sobrescríbela, salvo que esté `revisado`. Las fundacionales se emparejan por `titulo`. Numera las nuevas desde el número más alto existente. Las tareas `generado` que ya no correspondan a ningún spec vigente se listan como huérfanas, sin borrarlas.

## 3. Tareas

1. **Fundacionales** primero, con `spec` vacío: estructura del proyecto destino por repositorio, build, configuración de entorno y secretos, convención de errores transversal, integración continua básica y esqueleto de tests. Una tarea por tema.
2. **Por capacidad**, en el orden de `_capacidades.md`: entre dos y seis por spec, normalmente una por repositorio destino más una de integración o tests. `spec` con el slug, `repo_destino` con el nombre del repositorio destino (el mismo que el origen salvo que un ADR revisado diga otra cosa), `depende_de` con las tareas previas necesarias (incluidas las fundacionales que apliquen), `tamaño` S, M o L, `adrs` con los ids relevantes.
3. Criterios de aceptación verificables que citan las `RN-n` y `CB-n` del spec. Entre todas las tareas de un spec quedan cubiertas todas sus RN y CB.
4. Notas para el destino: nombra el lenguaje y la tecnología que los ADRs `revisado` eligieron. Si un ADR relevante sigue `propuesto` (solo cuando se forzó), escribe las notas de forma neutral y cita el ADR en `bloqueada_por`.
5. `bloqueada_por`: ids de ADRs propuestos y `PA:<slug>:<n>` **solo** para preguntas abiertas sin responder cuya respuesta cambia qué se construye. Una pregunta con respuesta escrita debajo en el spec no bloquea. Una pregunta que se resuelve provisionalmente reproduciendo el comportamiento observado va en los criterios como "pregunta abierta n, paridad provisional". Formato: `bloqueada_por: [0004, PA:carrito:1]`.
6. `fase` y `prioridad` vacíos: los rellena migration-pm.

## 4. Resumen final

- Destino y alcance.
- Tareas creadas, reutilizadas, conservadas y huérfanas; cuántas fundacionales; cuántas bloqueadas y por qué.
- Siguiente paso: revisar las tareas y corregirlas con migration-tl-resolver si hace falta; luego ejecutar migration-qa y migration-pm.
````

- [ ] **Step 4: Escribir `scripts/test-tl-tasks.sh`**

```bash
#!/usr/bin/env bash
# Caso 3 del spec v2: se detiene con ADRs propuestos y continúa forzado.
# Requiere un workspace con specs y al menos un ADR propuesto (tras Task 5).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/.work/sample-workspace"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
run() { bash "$ROOT/scripts/run-agent.sh" "$@"; rc=$?; [ $rc -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }; return $rc; }
snap() { find "$M" -type f -print0 | sort -z | xargs -0 md5sum; }

grep -lq '^estado: propuesto' "$M"/adr/*.md || { echo "FAIL: el workspace no tiene ADRs propuestos"; exit 1; }
rm -rf "$M/tasks"
snap > "$ROOT/.work/snap-a.txt"
out="$(run migration-tl-tasks "Ejecútalo con destino Kotlin.")"
snap > "$ROOT/.work/snap-b.txt"
diff -q "$ROOT/.work/snap-a.txt" "$ROOT/.work/snap-b.txt" >/dev/null || fail "escribió tareas con ADRs propuestos"
printf '%s' "$out" | grep -q 'migration-tl-resolver' || fail "no dio el prompt para migration-tl-resolver"

run migration-tl-tasks "Ejecútalo con destino Kotlin, aunque haya ADRs propuestos." >/dev/null
bash "$ROOT/scripts/verify-tl-tasks.sh" || fail "verify-tl-tasks falla en la corrida forzada"

[ "$fails" -eq 0 ] && { echo "OK: tl-tasks (parada y forzado)"; exit 0; }
exit 1
```

- [ ] **Step 5: Probar**

Run: `bash scripts/check-agent.sh agents/migration-tl-tasks.md && cp agents/migration-tl-tasks.md .work/sample-workspace/.claude/agents/ && bash scripts/test-tl-tasks.sh`
Expected: `OK: tl-tasks` y `OK: tl-tasks (parada y forzado)`.

- [ ] **Step 6: Commit**

```bash
git add agents/migration-tl-tasks.md scripts/verify-tl-tasks.sh scripts/test-tl-tasks.sh
git commit -m "feat: agente migration-tl-tasks con parada ante ADRs propuestos

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: QA con hallazgos numerados y PM sin lista de pasos

**Files:**
- Modify: `agents/migration-qa.md`, `agents/migration-pm.md`
- Modify: `scripts/verify-qa.sh`, `scripts/verify-pm.sh`

**Interfaces:**
- Produces: en cada plan, la sección `## Hallazgos para el tech lead` contiene `Ninguno` o líneas `- **H-n**: ...`; los resueltos llevan `(resuelto: ...)`. `_cobertura.md` lista solo hallazgos no resueltos. `migration-pm` no escribe la lista de pasos en el README.

- [ ] **Step 1: Ampliar `scripts/verify-qa.sh`**

Antes de la línea `grep -q '```' "$p" && fail "$slug: contiene bloques de código"`, insertar:

```bash
  hall="$(awk '/^## Hallazgos para el tech lead/{f=1;next} /^## /{f=0} f' "$p" | grep -v '^[[:space:]]*$' || true)"
  if [ -n "$hall" ] && ! printf '%s\n' "$hall" | grep -qx 'Ninguno\.\?'; then
    bad="$(printf '%s\n' "$hall" | grep '^- ' | grep -Ev '^- \*\*H-[0-9]+\*\*:' || true)"
    [ -z "$bad" ] || fail "$slug: hallazgos sin numerar H-n"
  fi
```

- [ ] **Step 2: Ajustar `scripts/verify-pm.sh`**

Eliminar la línea `grep -q 'migration-pm' "$M/README.md" 2>/dev/null || fail "README no menciona migration-pm"` y añadir tras la de `Cómo empezar a implementar`:

```bash
grep -q '^## Flujo' "$M/README.md" 2>/dev/null && fail "README conserva la lista de pasos de v1"
```

- [ ] **Step 3: Modificar `agents/migration-qa.md`**

3a. `description:` → `Paso 6 del flujo de migración. A partir de los specs de migration/specs/, escribe un plan de pruebas por capacidad en formato Dado/Cuando/Entonces con trazabilidad a reglas de negocio, casos borde y tareas, más un resumen de cobertura; numera los hallazgos como H-n. Requiere specs de migration-tl-specs. Acepta alcance ("solo la capacidad carrito").`

3b. Insertar justo antes de `## 0. Verificar insumos`:

```markdown
## Convenciones

1. Lee `CLAUDE.md` en la carpeta actual y localiza el bloque entre las líneas `<!-- migration-flow:begin -->` y `<!-- migration-flow:end -->`. Si el archivo o el bloque no existen, responde exactamente "Falta el bloque de convenciones en `CLAUDE.md`. Ejecuta primero el subagente migration-indexer." y detente sin escribir nada.
2. Aplica todas las convenciones del bloque.
3. Siempre, aunque el bloque diga otra cosa: nunca sobrescribas un archivo con `estado: revisado`, y si falta un insumo detente sin escribir nada y nombra el agente que hay que ejecutar antes.
```

3c. Reemplazar `Ejecuta primero el subagente migration-techlead.` por `Ejecuta primero el subagente migration-tl-specs.` y, en el paso 4 de insumos, reemplazar `si no existe `migration/specs/X.md`,` por `si no existe `migration/specs/X.md` o X está en `excluir:` de `migration/README.md`,`.

3d. Reemplazar la sección `## 4. Hallazgos para el tech lead` completa por:

```markdown
## 4. Hallazgos para el tech lead

Si al leer el spec encuentras una ambigüedad que no está en las preguntas abiertas y que te impide escribir un caso con un "Entonces" verificable, anótala aquí numerada como `- **H-1**: <sección del spec afectada>: <qué necesitarías saber>.`, `- **H-2**: ...`. Si no hay, escribe "Ninguno". Nunca resuelvas la ambigüedad por tu cuenta.

Al regenerar un plan que ya tenía hallazgos: conserva la numeración de los que sigan vigentes, conserva tal cual los marcados `(resuelto: ...)` y numera los nuevos desde el más alto existente.
```

3e. En la sección 5, reemplazar `- Sección `## Hallazgos pendientes para el tech lead`: una línea por hallazgo con el formato `- <slug>: <resumen>.`` por `- Sección `## Hallazgos pendientes para el tech lead`: una línea por hallazgo no resuelto con el formato `- <slug> H-n: <resumen>.` Los marcados `(resuelto: ...)` no se listan.`

3f. En `## Resumen final`, reemplazar `revisar los hallazgos, devolverlos al tech lead si corresponde, y ejecutar `migration-pm` si aún no se ha hecho.` por `decidir los hallazgos y aplicarlos al spec con migration-tl-resolver (por ejemplo "Usa el subagente migration-tl-resolver: resuelve el hallazgo H-1 del plan carrito: <decisión>"), repetir migration-qa para esa capacidad y ejecutar migration-pm si aún no se ha hecho.`

- [ ] **Step 4: Modificar `agents/migration-pm.md`**

4a. `description:` → `Paso 7 del flujo de migración. Lee las tareas de migration/tasks/, construye el grafo de dependencias, prioriza con criterio fijo, agrupa en fases y escribe migration/backlog.md; rellena fase y prioridad en cada tarea y actualiza la sección "Cómo empezar a implementar" de migration/README.md. Requiere tareas de migration-tl-tasks. Se detiene si hay ciclos o dependencias rotas.`

4b. Insertar antes de `## 0. Verificar insumos` la misma sección `## Convenciones` del paso 3b, literal.

4c. Reemplazar `Ejecuta primero el subagente migration-techlead.` por `Ejecuta primero el subagente migration-tl-tasks.`

4d. Reemplazar la sección `## 6. Actualizar el README` completa (sus cuatro viñetas) por:

```markdown
## 6. Actualizar el README

En `migration/README.md` no toques el frontmatter ni la sección de repos. Reemplaza la sección `## Cómo continuar` por la línea "Consulta el subagente migration-orchestrator para saber el siguiente paso." y añade o reemplaza la sección `## Cómo empezar a implementar` con: enlace a `backlog.md`, la lista de tareas del Hito 0, la primera capacidad completa y su plan de pruebas, y la lista de bloqueos que conviene resolver antes de empezar.
```

- [ ] **Step 5: Probar QA y PM**

Run:
```bash
cp agents/migration-qa.md agents/migration-pm.md .work/sample-workspace/.claude/agents/
bash scripts/check-agent.sh
bash scripts/run-agent.sh migration-qa && bash scripts/verify-qa.sh
bash scripts/run-agent.sh migration-pm && bash scripts/verify-pm.sh
```
Expected: `OK: qa` y `OK: pm` (workspace de la Task 6, tareas forzadas).

- [ ] **Step 6: Commit**

```bash
git add agents/migration-qa.md agents/migration-pm.md scripts/verify-qa.sh scripts/verify-pm.sh
git commit -m "feat: qa numera hallazgos H-n; pm sin lista de pasos en el README

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: `migration-tl-resolver`

**Files:**
- Create: `agents/migration-tl-resolver.md`
- Create: `scripts/test-resolver.sh`

**Interfaces:**
- Consumes: workspace completo hasta QA.
- Produces: ediciones sobre los artefactos nombrados y un resumen con una tabla `| Archivo | Cambio | Estado final |` y una sección `No aplicado`.

- [ ] **Step 1: Escribir `scripts/test-resolver.sh`**

```bash
#!/usr/bin/env bash
# Casos 4 a 8 del spec v2 y Review Focus 1 y 2. Prepara su propio workspace.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/.work/sample-workspace"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
run() { bash "$ROOT/scripts/run-agent.sh" "$@"; rc=$?; [ $rc -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }; return $rc; }
R() { run migration-tl-resolver "$1"; }
adrfile() { ls "$M"/adr/"$1"-*.md 2>/dev/null | head -n1; }

if [ "${SKIP_SETUP:-0}" != 1 ]; then
  bash "$ROOT/scripts/fixture-reset.sh" >/dev/null
  run migration-indexer >/dev/null
  run migration-analyst >/dev/null
  run migration-tl-adrs "Ejecútalo con destino Kotlin." >/dev/null
  run migration-tl-specs >/dev/null
  run migration-tl-tasks "Ejecútalo con destino Kotlin, aunque haya ADRs propuestos." >/dev/null
  run migration-qa >/dev/null
fi

# Caso 4: decidir un ADR propuesto aceptando la recomendación
P="$(grep -l '^estado: propuesto' "$M"/adr/*.md | head -n1 | xargs basename | cut -c1-4)"
[ -n "$P" ] || { echo "FAIL: no hay ADR propuesto"; exit 1; }
R "En el ADR $P acepta la recomendación." >/dev/null
f="$(adrfile "$P")"
grep -q '^estado: revisado' "$f" || fail "caso 4: ADR $P no quedó revisado"
grep -q 'Recomendación:' "$f" && fail "caso 4: ADR $P conserva la recomendación"
grep -l "^bloqueada_por:.*\b$P\b" "$M"/tasks/*.md >/dev/null 2>&1 && fail "caso 4: alguna tarea sigue bloqueada por $P"

# Review Focus 2: cambiar una decisión ya revisada
before="$(md5sum < "$f")"
R "En el ADR $P cambio la decisión: elijo la primera opción de las alternativas." >/dev/null
[ "$(md5sum < "$f")" != "$before" ] || fail "RF2: la decisión del ADR $P no cambió"
grep -q '^estado: revisado' "$f" || fail "RF2: ADR $P dejó de estar revisado"
grep -q 'Recomendación:' "$f" && fail "RF2: reapareció la recomendación"

# Caso 5: responder una pregunta abierta sin renumerar
S="$(for s in "$M"/specs/[!_]*.md; do awk '/^## 12\. Preguntas abiertas/{f=1;next} f' "$s" | grep -q '^- ' && { basename "$s" .md; break; }; done)"
q1="$(awk '/^## 12\. Preguntas abiertas/{f=1;next} f' "$M/specs/$S.md" | grep '^- ' | head -n1)"
ids_before="$(grep -oE '^(- )?(RN|CB)-[0-9]+:' "$M/specs/$S.md" | sort)"
R "En el spec $S, respuesta a la pregunta abierta 1: se conserva el comportamiento actual." >/dev/null
grep -qF -- "$q1" "$M/specs/$S.md" || fail "caso 5: se borró la pregunta abierta 1"
ids_after="$(grep -oE '^(- )?(RN|CB)-[0-9]+:' "$M/specs/$S.md" | sort)"
[ -z "$(comm -23 <(printf '%s\n' "$ids_before") <(printf '%s\n' "$ids_after"))" ] || fail "caso 5: se perdieron o renumeraron RN/CB"
grep -l "PA:$S:1\b" "$M"/tasks/*.md >/dev/null 2>&1 && fail "caso 5: alguna tarea sigue bloqueada por PA:$S:1"

# Caso 6: se niega a editar un derivado
g="$(md5sum < "$W/index.md")"
out="$(R "En el index.md general añade una fila para un repo llamado pagos.")"
[ "$(md5sum < "$W/index.md")" = "$g" ] || fail "caso 6: editó el índice general"
printf '%s' "$out" | grep -q 'migration-indexer' || fail "caso 6: no indicó qué agente regenera el índice"

# Caso 7: se niega a añadir un caso de prueba sin respaldo en el spec
pl="$M/test-plans/$S.md"
b7="$(md5sum < "$pl")"
out="$(R "En el plan de prueba $S añade un caso: cuando el usuario paga con criptomonedas, la respuesta es 402.")"
[ "$(md5sum < "$pl")" = "$b7" ] || fail "caso 7: editó el plan sin respaldo en el spec"
printf '%s' "$out" | grep -qi 'spec' || fail "caso 7: no propuso añadirlo primero al spec"

# Review Focus 1: varias órdenes, una con id inexistente
S2="$(ls "$M"/specs | grep -v '^_' | grep -v "^$S.md$" | head -n1 | sed 's/\.md$//')"
out="$(R "En el ADR 9999 elijo Ktor. Marca revisado el spec $S2.")"
grep -q '^estado: revisado' "$M/specs/$S2.md" || fail "RF1: no aplicó la orden válida"
printf '%s' "$out" | grep -q '9999' || fail "RF1: no reportó el id inexistente"

# Caso 8: excluir una capacidad
X="$(ls "$M"/specs | grep -v '^_' | grep -v "^$S.md$" | grep -v "^$S2.md$" | head -n1 | sed 's/\.md$//')"
[ -n "$X" ] || X="$S2"
out="$(R "Excluye la capacidad $X.")"
grep -qE "^excluir:.*\b$X\b" "$M/README.md" || fail "caso 8: '$X' no está en excluir"
[ -f "$M/specs/$X.md" ] && fail "caso 8: el spec $X sigue existiendo"
[ -f "$M/test-plans/$X.md" ] && fail "caso 8: el plan $X sigue existiendo"
grep -l "^spec: $X$" "$M"/tasks/*.md >/dev/null 2>&1 && fail "caso 8: quedan tareas de $X"
grep -qE "^\| $X \|" "$M/specs/_capacidades.md" && fail "caso 8: $X sigue en el mapa"

[ "$fails" -eq 0 ] && { echo "OK: resolver"; exit 0; }
exit 1
```

- [ ] **Step 2: Verificar que falla sin el agente**

Run: `SKIP_SETUP=1 bash scripts/test-resolver.sh`
Expected: falla en el caso 4 (`claude` no encuentra el subagente o no edita), con varios `FAIL`.

- [ ] **Step 3: Escribir `agents/migration-tl-resolver.md`**

````markdown
---
name: migration-tl-resolver
description: Aplica decisiones y cambios descritos en lenguaje natural sobre ADRs, specs, tareas, planes de prueba y el README de migration/, en cualquier momento del flujo. Decide ADRs propuestos, responde preguntas abiertas, resuelve hallazgos de QA, excluye capacidades, fija el destino, marca revisado y hace ediciones libres. Solo toca lo que el prompt nombra y devuelve un resumen de cambios. No decide por el usuario ni regenera artefactos.
tools: Read, Glob, Grep, Write, Edit
---

Eres el agente que aplica las decisiones y correcciones del usuario sobre los artefactos de `migration/`. Ejecutas exactamente lo que el prompt pide, mantienes la trazabilidad y devuelves un resumen claro. No decides nada por el usuario, no regeneras artefactos y no editas nada que el prompt no nombre, salvo la limpieza de bloqueos que forma parte de algunas operaciones. Escribes en español.

## 0. Convenciones

1. Lee `CLAUDE.md` en la carpeta actual y localiza el bloque entre las líneas `<!-- migration-flow:begin -->` y `<!-- migration-flow:end -->`. Si el archivo o el bloque no existen, responde exactamente "Falta el bloque de convenciones en `CLAUDE.md`. Ejecuta primero el subagente migration-indexer." y detente sin escribir nada.
2. Aplica todas las convenciones del bloque.
3. Tú eres la vía para editar artefactos `revisado`: puedes editarlos cuando el prompt lo pide explícitamente. Nunca edites un artefacto que el prompt no nombra, salvo lo indicado en cada operación.

## 1. Interpretar el prompt

1. Divide el prompt en órdenes independientes. Cada orden nombra un artefacto (ADR por id, spec o plan por capacidad, tarea por id, README) y un cambio.
2. Localiza cada artefacto. Si un id o capacidad no existe, o la orden es ambigua (no se sabe qué opción, qué pregunta o qué regla), no apliques esa orden: anótala en "No aplicado" con el motivo y sigue con las demás.
3. Lee cada artefacto completo antes de editarlo.

## 2. Operaciones

**Decidir un ADR propuesto** ("en el ADR 0011 elijo Ktor", "acepta la recomendación del ADR 0012"):
- En `## Decisión`, escribe al principio `**Elegida: Opción <n>, <tecnología>.** <frase que describe la decisión>`, seguida de `Motivo: <motivo del prompt o, si no lo da, el de la opción>`.
- Elimina la línea que contiene `Recomendación:`.
- Deja las demás opciones bajo `Alternativas descartadas:` con su numeración original y una frase de por qué se descartan, tomada de sus desventajas.
- Reescribe `## Implicación para la migración` con lo que implica la decisión.
- `estado: revisado`; `implicacion_migracion` vacío.
- Quita el id de este ADR de `bloqueada_por` en todas las tareas de `migration/tasks/`, incluidas las `revisado`.
- Si la decisión cambia la base de otro ADR propuesto (por ejemplo, su recomendación dependía de esta), no lo edites: menciónalo en el resumen.
- Si el ADR ya estaba `revisado` y el prompt cambia la decisión, reescribe la decisión con las mismas reglas: la opción antes elegida pasa a alternativas descartadas.

**Corregir un ADR observado**: edita el texto o `implicacion_migracion` según el prompt y marca `revisado`.

**Responder una pregunta abierta** ("en el spec carrito, respuesta a la pregunta 3: ..."):
- Debajo de la pregunta n de `## 12. Preguntas abiertas`, añade una línea sangrada `  - Respuesta (<AAAA-MM-DD>): <respuesta>`. No borres ni muevas la pregunta.
- Si el prompt pide convertirla en regla o caso borde, añádela en la sección 7 u 8 con el siguiente número libre (`RN-n:` o `CB-n:`).
- Quita `PA:<capacidad>:<n>` de `bloqueada_por` en todas las tareas.

**Resolver un hallazgo de QA** ("resuelve el hallazgo H-2 del plan carrito: ..."):
- Aplica la decisión al spec de esa capacidad como regla (siguiente `RN-n:`), caso borde (siguiente `CB-n:`) o aclaración en la sección afectada.
- En el plan, añade al final de la línea del hallazgo `(resuelto: <qué cambió en el spec>)`.
- Recomienda repetir migration-qa para esa capacidad.

**Excluir una capacidad** ("excluye la capacidad pagos"):
- Añade el slug a `excluir:` de `migration/README.md` (lista YAML entre corchetes).
- Borra `migration/specs/<slug>.md`, `migration/test-plans/<slug>.md` y cada tarea cuyo `spec` sea ese slug. Borrar archivos es la única vía para excluir: hazlo con Write vaciando no; elimínalos. Si no puedes eliminar un archivo con tus herramientas, sobrescríbelo con una sola línea `(retirado <AAAA-MM-DD>: capacidad excluida)` y dilo en el resumen.
- Quita su fila de `migration/specs/_capacidades.md`.
- Lista, sin editarlos: specs que mencionan la capacidad, tareas cuyo `depende_de` apunta a tareas borradas, ADRs que solo trataban esa capacidad.

**Fijar destino**: escribe `destino: <lenguaje>` en el frontmatter de `migration/README.md`.

**Marcar revisado**: cambia `estado:` a `revisado` en los artefactos nombrados.

**Edición libre** sobre un ADR, spec, tarea o plan: aplica el cambio descrito (reglas, contratos, criterios, dependencias, tamaño, `fase`, `prioridad`, casos de prueba).

## 3. Reglas

- **Marca `revisado`** todo artefacto que edites, salvo que el prompt diga "sin marcar revisado".
- **No renumeres** ids. Lo nuevo toma el siguiente número libre. Lo eliminado se marca al final de su línea con `(retirado <AAAA-MM-DD>)`; no se borra la línea.
- **No propagues por tu cuenta.** Tras editar, busca con Grep los artefactos que citan lo cambiado (ids de reglas, casos, tareas, ADRs) y lístalos con el agente que conviene repetir. Solo los editas si el prompt los nombra. Excepción: la limpieza de `bloqueada_por` descrita en las operaciones.
- **Casos de prueba sin respaldo.** Si piden añadir o cambiar un caso de prueba cuyo comportamiento no está en el spec (ninguna regla, caso borde, contrato o flujo lo describe), no edites el plan. Explícalo y entrega el prompt para añadirlo primero al spec: `Usa el subagente migration-tl-resolver: en el spec <capacidad> añade <regla>`.
- **Derivados.** Niégate a editar `index.md` de cualquier repo, el `index.md` general, `_cobertura.md` y `backlog.md`, e indica qué agente los regenera (migration-indexer, migration-qa o migration-pm). `_capacidades.md` solo se toca al excluir una capacidad. El bloque de `CLAUDE.md` tampoco se edita.
- **Nunca decidas** una opción que el prompt no indica. "Acepta la recomendación" sí es una indicación.

## 4. Resumen final

```markdown
## Cambios aplicados

| Archivo | Cambio | Estado final |
|---|---|---|
| migration/adr/0011-framework-bff.md | Decisión: Ktor; recomendación eliminada | revisado |

## No aplicado
- <orden>: <motivo>   (o "Nada")

## Afectados sin editar
- <archivo>: cita <id cambiado>   (o "Nada")

## Siguiente paso
<agentes que conviene repetir, con su prompt>
```
````

Nota para el ejecutor: la herramienta Write no borra archivos. Si en la prueba del caso 8 el agente no puede eliminar, la regla de sobrescribir con la línea `(retirado ...)` se activa; en ese caso ajusta `test-resolver.sh` para aceptar un archivo cuyo único contenido empieza por `(retirado` y registra la decisión. Si preferís que borre de verdad, añade `Bash` a `tools` limitado en el prompt a `rm` sobre esos archivos.

- [ ] **Step 4: Probar**

Run: `bash scripts/check-agent.sh agents/migration-tl-resolver.md && bash scripts/test-resolver.sh`
Expected: `OK: resolver`.

- [ ] **Step 5: Ajustar si hace falta**

Si un caso falla, corrige el prompt (no el test, salvo la nota del caso 8) y repite con `SKIP_SETUP=1 bash scripts/test-resolver.sh` sobre un workspace nuevo preparado con el bloque de setup del script.

- [ ] **Step 6: Registrar los Review Focus cubiertos**

Los casos RF1 y RF2 ya están en el script. Confirmar en la salida que no aparece ningún `FAIL: RF`.

- [ ] **Step 7: Commit**

```bash
git add agents/migration-tl-resolver.md scripts/test-resolver.sh
git commit -m "feat: agente migration-tl-resolver para decisiones y cambios

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: `migration-orchestrator`

**Files:**
- Create: `agents/migration-orchestrator.md`
- Create: `scripts/test-orchestrator.sh`

**Interfaces:**
- Produces: salida con secciones `## Estado`, `## Pendiente de revisión`, `## Desactualizado`, `## Siguiente paso`; el prompt recomendado empieza por `Usa el subagente migration-`.

- [ ] **Step 1: Escribir `scripts/test-orchestrator.sh`**

```bash
#!/usr/bin/env bash
# Caso 9 del spec v2 y Review Focus 4. Prepara sus propios estados.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/.work/sample-workspace"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
run() { bash "$ROOT/scripts/run-agent.sh" "$@"; rc=$?; [ $rc -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }; return $rc; }
snap() { find "$W" -path "$W/*/.git" -prune -o -type f -print0 | sort -z | xargs -0 md5sum; }
orq() {
  snap > "$ROOT/.work/snap-a.txt"
  out="$(run migration-orchestrator)"
  snap > "$ROOT/.work/snap-b.txt"
  diff -q "$ROOT/.work/snap-a.txt" "$ROOT/.work/snap-b.txt" >/dev/null || fail "$1: el orquestador escribió archivos"
  for s in '## Estado' '## Pendiente de revisión' '## Desactualizado' '## Siguiente paso'; do
    printf '%s' "$out" | grep -q "^$s" || fail "$1: falta '$s'"
  done
  next="$(printf '%s' "$out" | awk '/^## Siguiente paso/{f=1;next} f')"
}

# RF4: carpeta sin CLAUDE.md
bash "$ROOT/scripts/fixture-reset.sh" >/dev/null
orq "sin indexar"
printf '%s' "$next" | grep -q 'migration-indexer' || fail "sin indexar: no recomienda migration-indexer"

# Estado 1: tras el indexador
run migration-indexer >/dev/null
orq "tras indexer"
printf '%s' "$next" | grep -q 'migration-analyst' || fail "tras indexer: no recomienda migration-analyst"

# Estado 2: ADRs propuestos pendientes
run migration-analyst >/dev/null
run migration-tl-adrs "Ejecútalo con destino Kotlin." >/dev/null
P="$(grep -l '^estado: propuesto' "$M"/adr/*.md | head -n1 | xargs basename | cut -c1-4)"
orq "ADRs propuestos"
printf '%s' "$out" | grep -q "$P" || fail "ADRs propuestos: no lista el ADR $P"
printf '%s' "$next" | grep -Eq 'migration-tl-resolver|migration-tl-specs' || fail "ADRs propuestos: siguiente paso inesperado"

# Estado 3: plan más antiguo que su spec
run migration-tl-specs >/dev/null
run migration-tl-tasks "Ejecútalo con destino Kotlin, aunque haya ADRs propuestos." >/dev/null
run migration-qa >/dev/null
S="$(ls "$M"/specs | grep -v '^_' | head -n1 | sed 's/\.md$//')"
sleep 2; touch "$M/specs/$S.md"
orq "plan desactualizado"
printf '%s' "$out" | awk '/^## Desactualizado/{f=1;next} /^## /{f=0} f' | grep -q "$S" || fail "plan desactualizado: no marca $S"

[ "$fails" -eq 0 ] && { echo "OK: orchestrator"; exit 0; }
exit 1
```

- [ ] **Step 2: Verificar que falla**

Run: `bash scripts/test-orchestrator.sh`
Expected: `FAIL: sin indexar: falta '## Estado'` y más (el subagente no existe).

- [ ] **Step 3: Escribir `agents/migration-orchestrator.md`**

````markdown
---
name: migration-orchestrator
description: Diagnostica el estado del flujo de migración leyendo los archivos de la carpeta actual y entrega el siguiente paso con el prompt exacto para copiar, más lo pendiente de revisión y lo desactualizado. Solo lectura, no ejecuta ni edita nada. Consultarlo en cualquier momento, incluso antes de empezar.
tools: Read, Glob, Grep
---

Eres el orquestador del flujo de migración. Diagnosticas en qué punto está el proceso y qué conviene hacer después. Solo lees: nunca escribes, editas ni ejecutas nada, y no guardas estado propio. Escribes en español.

## 1. Referencia del flujo

Si existe `CLAUDE.md` con el bloque entre `<!-- migration-flow:begin -->` y `<!-- migration-flow:end -->`, léelo y úsalo como referencia. Si no existe, el siguiente paso es siempre `Usa el subagente migration-indexer` (si hay repositorios en la carpeta) o abrir Claude Code en la carpeta padre de los repositorios (si no los hay).

Orden de pasos y qué los evidencia:

| Paso | Agente | Completado si existe |
|---|---|---|
| 1 | migration-indexer | bloque en `CLAUDE.md`, `index.md` general, `migration/README.md` |
| 2 | migration-analyst | `migration/specs/_capacidades.md` |
| 3 | migration-tl-adrs | algún `migration/adr/*.md` |
| 4 | migration-tl-specs | un spec por cada capacidad no excluida del mapa |
| 5 | migration-tl-tasks | algún `migration/tasks/T-*.md` |
| 6 | migration-qa | un plan por cada spec y `migration/test-plans/_cobertura.md` |
| 7 | migration-pm | `migration/backlog.md` |

## 2. Diagnóstico

1. **Paso actual:** el último paso completado sin huecos anteriores.
2. **Pendiente de revisión:**
   - `destino:` vacío en `migration/README.md`.
   - ADRs con `estado: propuesto` (id y título).
   - Artefactos en `estado: generado` del último paso completado.
   - Preguntas abiertas sin línea `Respuesta` debajo, por spec (cuántas y cuáles bloquean tareas según `bloqueada_por`).
   - Hallazgos `H-n` sin `(resuelto: ...)`, por plan.
   - Capacidades en `excluir:` que aún tienen spec, plan o tareas.
3. **Desactualizado** (compara fechas de modificación con Glob/Read de metadatos; si no puedes obtenerlas, compara con la fecha `Generado:` o `fecha:` del contenido):
   - Un plan más antiguo que su spec.
   - Tareas de un spec más antiguas que el spec, o más antiguas que un ADR que pasó a `revisado`.
   - `backlog.md` más antiguo que alguna tarea.
   - Planes cuya sección de hallazgos tiene viñetas sin `H-n` (formato v1).
   - Tareas con un id de ADR ya `revisado` en `bloqueada_por`.
4. **Siguiente paso**, uno solo, con esta prioridad:
   1. Si falta un paso anterior al actual, ese paso.
   2. Si hay ADRs propuestos y el siguiente agente es migration-tl-tasks, decidirlos con migration-tl-resolver.
   3. Si hay algo desactualizado, repetir el agente que lo regenera, con alcance si aplica.
   4. Si hay pendientes de revisión del último paso, revisarlos (y el prompt del resolver para aplicar decisiones).
   5. Si no, el siguiente agente del orden.
   Si hay otro camino igualmente válido, menciónalo en una línea.

El prompt que entregas es exacto y copiable, empieza por `Usa el subagente migration-...` e incluye destino y alcance cuando hagan falta. Si el paso es decidir, pon los ids reales y un marcador `<tu decisión>`, por ejemplo: `Usa el subagente migration-tl-resolver: en el ADR 0011 elijo <tu decisión>; en el ADR 0012 elijo <tu decisión>`.

## 3. Salida

Responde exactamente con esta estructura; una sección vacía lleva "Nada":

```markdown
## Estado
Paso actual: <n>, <agente> completado. <una frase de contexto>

## Pendiente de revisión
- <artefacto>: <qué falta>

## Desactualizado
- <artefacto>: <por qué>

## Siguiente paso
<una frase>

    <prompt exacto>

<camino alternativo en una línea, si lo hay>
```
````

- [ ] **Step 4: Probar**

Run: `bash scripts/check-agent.sh agents/migration-orchestrator.md && bash scripts/test-orchestrator.sh`
Expected: `OK: orchestrator`.

- [ ] **Step 5: Commit**

```bash
git add agents/migration-orchestrator.md scripts/test-orchestrator.sh
git commit -m "feat: agente migration-orchestrator de solo diagnóstico

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Retiro del tech lead, flujo completo y documentación

**Files:**
- Delete: `agents/migration-techlead.md`, `scripts/verify-techlead.sh`
- Modify: `scripts/run-all.sh`, `scripts/verify-idempotency.sh`, `scripts/test-verifiers.sh`
- Modify: `README.md`, `docs/tutorial.md`

**Interfaces:**
- Consumes: todos los agentes y verificadores anteriores.

- [ ] **Step 1: Actualizar `scripts/test-verifiers.sh`**

Reemplazar `for v in techlead qa pm; do` por `for v in analyst tl-adrs tl-specs tl-tasks qa pm; do`.

Run: `bash scripts/test-verifiers.sh`
Expected: `OK: verificadores`. Si `verify-analyst` o `verify-tl-tasks` fallan sobre el workspace sintético, ajustar `make_ws` (no los verificadores) para que sea un workspace válido y registrar la decisión.

- [ ] **Step 2: Reescribir `scripts/run-all.sh`**

```bash
#!/usr/bin/env bash
# Flujo completo v2 sobre el fixture, con una ronda del resolver.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
M=.work/sample-workspace/migration
bash scripts/check-agent.sh
bash scripts/fixture-reset.sh
bash scripts/run-agent.sh migration-indexer;   bash scripts/verify-indexer.sh
bash scripts/run-agent.sh migration-analyst;   bash scripts/verify-analyst.sh
bash scripts/run-agent.sh migration-tl-adrs "Ejecútalo con destino Kotlin."; bash scripts/verify-tl-adrs.sh
ids="$(grep -l '^estado: propuesto' "$M"/adr/*.md | xargs -n1 basename | cut -c1-4 | paste -sd, -)"
bash scripts/run-agent.sh migration-tl-resolver "Fija el destino en Kotlin. En los ADRs $ids acepta la recomendación."
REQUIRE_PROPUESTO=0 bash scripts/verify-tl-adrs.sh
bash scripts/run-agent.sh migration-tl-specs;  bash scripts/verify-tl-specs.sh
bash scripts/run-agent.sh migration-tl-tasks;  bash scripts/verify-tl-tasks.sh
bash scripts/run-agent.sh migration-qa;        bash scripts/verify-qa.sh
bash scripts/run-agent.sh migration-pm;        bash scripts/verify-pm.sh
echo "OK: flujo completo"
```

- [ ] **Step 3: Actualizar `scripts/verify-idempotency.sh`**

Reemplazar la línea del agente por:

```bash
bash "$ROOT/scripts/run-agent.sh" migration-tl-specs >/dev/null
```

y el comentario de cabecera por `# Un spec marcado revisado y editado a mano sobrevive a una segunda corrida de migration-tl-specs.` Añadir tras `W=` la lectura de `WORKDIR`: `W="${WORKDIR:-$ROOT/.work/sample-workspace}"`.

- [ ] **Step 4: Retirar el tech lead**

```bash
git rm agents/migration-techlead.md scripts/verify-techlead.sh
bash scripts/check-agent.sh
```

Expected: `OK: 9 agente(s) válido(s)`.

- [ ] **Step 5: Reescribir `README.md`**

````markdown
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
````

- [ ] **Step 6: Reescribir `docs/tutorial.md`**

````markdown
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
````

- [ ] **Step 7: Flujo completo e idempotencia**

Run: `bash scripts/run-all.sh && bash scripts/verify-idempotency.sh && bash scripts/test-install.sh && bash scripts/test-verifiers.sh`
Expected: `OK: flujo completo`, `OK: idempotencia (<slug> conservado)`, `OK: install`, `OK: verificadores`. El flujo tarda más de diez minutos: ejecútalo desacoplado (`nohup`) si el entorno limita la duración de un comando.

- [ ] **Step 8: Commit**

```bash
git add -A agents scripts README.md docs/tutorial.md
git commit -m "feat: flujo v2 completo; retiro de migration-techlead; README y tutorial

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Notas para el ejecutor

- Los agentes son prompts: si un test falla, la corrección suele estar en el prompt. Solo se ajusta un test si comprueba algo que el spec no exige, y se registra como decisión.
- Las corridas de agentes consumen minutos y tokens. No las repitas sin haber cambiado algo.
- Los tests de las tareas 3, 5, 6, 8 y 9 dejan el workspace en estados distintos; cada uno indica si prepara el suyo o requiere el de la tarea anterior.
