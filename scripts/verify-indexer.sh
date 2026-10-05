#!/usr/bin/env bash
# Verifica los artefactos del indexador: índice de cada repositorio, índice
# general, migration/README.md, plantillas y bloque de CLAUDE.md.
# Carpeta: WORKDIR o, por defecto, la actual.
# FIXTURE=1 añade las comprobaciones propias del fixture (qué archivos deben y
# no deben aparecer en cada índice, según fixtures/hechos/<fixture>.txt, y los
# campos de las plantillas de la versión actual de los agentes).
set -uo pipefail
W="${WORKDIR:-$PWD}"
FX="${FIXTURE:-0}"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

# Repositorios: subcarpetas directas con alguno de los archivos que los identifican
repos=()
for d in "$W"/*/; do
  [ -d "$d" ] || continue
  r="$(basename "$d")"
  [ "$r" = migration ] && continue
  for m in .git package.json pom.xml build.gradle build.gradle.kts go.mod pyproject.toml Cargo.toml composer.json; do
    [ -e "$d$m" ] && { repos+=("$r"); break; }
  done
done
[ "${#repos[@]}" -gt 0 ] || fail "no se detectó ningún repositorio en $W"

for r in "${repos[@]}"; do
  f="$W/$r/index.md"
  [ -f "$f" ] || { fail "$r/index.md no existe"; continue; }
  grep -q "^# Índice: $r" "$f" || fail "$r/index.md sin encabezado '# Índice: $r'"
  for k in "Stack:" "Entrada:" "Build:" "Dependencias clave:" "Commit:" "Generado:"; do
    grep -q "^$k" "$f" || fail "$r/index.md sin línea '$k'"
  done
  grep -q '^## ' "$f" || fail "$r/index.md sin secciones por carpeta"
  grep -q 'Índice incompleto' "$f" && fail "$r/index.md marcado incompleto"
done

# Qué debe y qué no debe aparecer en cada índice: propio de cada fixture, en
# las líneas indice y no-indice de fixtures/hechos/<fixture>.txt
HECHOS_F="${HECHOS:-$(cd "$(dirname "$0")" && pwd)/../fixtures/hechos/${FIXTURE_NAME:-sample-workspace}.txt}"
if [ "$FX" = 1 ] && [ -f "$HECHOS_F" ]; then
  while IFS= read -r l; do
    tipo="$(printf '%s' "$l" | awk -F' \\| ' '{print $1}')"
    case "$tipo" in indice|no-indice) ;; *) continue ;; esac
    r="$(printf '%s' "$l" | awk -F' \\| ' '{print $3}')"; arch="$(printf '%s' "$l" | awk -F' \\| ' '{print $4}')"
    [ -f "$W/$r/index.md" ] || continue
    case "$arch" in '`'*) pat="$arch" ;; *) pat="\`$arch\`" ;; esac
    if [ "$tipo" = indice ]; then
      grep -qF -- "$pat" "$W/$r/index.md" || fail "$r: falta $arch en el índice"
    else
      grep -qF -- "$pat" "$W/$r/index.md" && fail "$r: $arch está en el índice y no debería"
    fi
  done < <(tr -d '\r' < "$HECHOS_F" | grep -E '^(indice|no-indice) ')
fi

# Bootstrap de migration/
[ -f "$W/migration/README.md" ] || fail "migration/README.md no existe"
grep -q '^destino:' "$W/migration/README.md" || fail "README sin campo destino"
grep -q '^excluir:' "$W/migration/README.md" || fail "README sin campo excluir"
grep -q '^politica: paridad$' "$W/migration/README.md" || fail "README sin 'politica: paridad'"
grep -q 'migration-orchestrator' "$W/migration/README.md" || fail "README no remite a migration-orchestrator"
grep -q '^## Flujo' "$W/migration/README.md" && fail "README conserva la lista de pasos de v1"

# Índice general
G="$W/index.md"
if [ -f "$G" ]; then
  grep -q '^# Índice general' "$G" || fail "index.md general sin título"
  for r in "${repos[@]}"; do
    grep -q "($r/index.md)" "$G" || fail "índice general sin enlace a $r/index.md"
  done
  grep -q '(migration/README.md)' "$G" || fail "índice general sin enlace a migration/README.md"
  grep -Eq '^\|.*Commit' "$G" || fail "índice general sin columna Commit"
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
  for k in 'revisado' 'excluir:' 'RN-n' 'MJ-n' 'politica:' 'aplica la mejora MJ-n' 'AU-n' '_auditoria.md' 'migration-auditor' '[ausente: ' 'conservar' 'con destino <repo>=<lenguaje>' 'rev: <entero>' 'spec_rev' 'adrs_rev' 'registra las versiones' 'solo el repo <nombre>' 'solo la cobertura' 'reabre <artefacto>' 'Usa el subagente migration-orchestrator' 'Usa el subagente migration-tl-resolver'; do
    printf '%s' "$block" | grep -qF "$k" || fail "bloque de CLAUDE.md sin '$k'"
  done
else
  fail "CLAUDE.md no existe"
fi

# Plantillas. Su contenido solo se comprueba con FIXTURE=1: el indexador no
# sobrescribe plantillas existentes, así que un proyecto empezado con una
# versión anterior de los agentes tiene, legítimamente, plantillas anteriores.
T="$W/migration/templates"
for t in adr spec task test-plan backlog; do
  [ -f "$T/$t.md" ] || fail "falta plantilla $t.md"
done
if [ "$FX" = 1 ]; then
  grep -q '^## 12\. Preguntas abiertas' "$T/spec.md" || fail "spec.md sin sección 12"
  grep -q '^## 13\. Posibles mejoras' "$T/spec.md" || fail "spec.md sin sección 13"
  grep -q '^commits:' "$T/spec.md" || fail "spec.md sin commits en el frontmatter"
  grep -q '^bloqueada_por:' "$T/task.md" || fail "task.md sin bloqueada_por"
  grep -q '^implicacion_migracion:' "$T/adr.md" || fail "adr.md sin implicacion_migracion"
  grep -q '^repos:' "$T/adr.md" || fail "adr.md sin repos en el frontmatter"
  grep -q '^tipo: implementacion' "$T/task.md" || fail "task.md sin tipo en el frontmatter"
  for tpl in adr spec task; do
    grep -q '^rev: 1$' "$T/$tpl.md" || fail "$tpl.md sin rev en el frontmatter"
  done
  grep -q '^spec_rev:' "$T/task.md" || fail "task.md sin spec_rev"
  grep -q '^adrs_rev: {}' "$T/task.md" || fail "task.md sin adrs_rev"
  grep -q '^spec_rev:' "$T/test-plan.md" || fail "test-plan.md sin spec_rev"
  grep -qE '^tareas:|^- Tareas:' "$T/test-plan.md" && fail "test-plan.md conserva la referencia a tareas"
  grep -q '^## Pruebas' "$T/task.md" || fail "task.md sin sección Pruebas"
  grep -q '| Tarea | Rev |' "$T/backlog.md" || fail "backlog.md sin columna Rev"
fi

[ "$fails" -eq 0 ] && { echo "OK: indexer"; exit 0; }
exit 1
