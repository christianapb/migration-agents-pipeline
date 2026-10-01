#!/usr/bin/env bash
# Verifica los artefactos del indexador en .work/sample-workspace.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

for r in frontend bff; do
  f="$W/$r/index.md"
  [ -f "$f" ] || { fail "$r/index.md no existe"; continue; }
  grep -q "^# Índice: $r" "$f" || fail "$r/index.md sin encabezado '# Índice: $r'"
  for k in "Stack:" "Entrada:" "Build:" "Dependencias clave:" "Generado:"; do
    grep -q "^$k" "$f" || fail "$r/index.md sin línea '$k'"
  done
  grep -q '^## ' "$f" || fail "$r/index.md sin secciones por carpeta"
  grep -q 'Índice incompleto' "$f" && fail "$r/index.md marcado incompleto"
done

# Exclusiones fijas (los archivos están trackeados en git, así que solo la lista fija los saca)
grep -q 'package-lock.json' "$W/bff/index.md" && fail "bff: lockfile indexado"
grep -q 'package-lock.json' "$W/frontend/index.md" && fail "frontend: lockfile indexado"
grep -q '\.snap' "$W/bff/index.md" && fail "bff: snapshot indexado"
grep -q 'logo.png' "$W/frontend/index.md" && fail "frontend: imagen indexada"
grep -q '`server.js`' "$W/bff/index.md" && fail "bff: dist/server.js indexado"

# Inclusiones: todo archivo de código y de configuración relevante
for f in server.ts errors.ts auth.ts products.ts cart.ts identity.ts catalog.ts cart.test.ts package.json tsconfig.json .env.example; do
  grep -q "\`$f\`" "$W/bff/index.md" || fail "bff: falta $f en el índice"
done
for f in main.tsx client.ts session.ts Login.tsx Products.tsx Cart.tsx package.json vite.config.ts index.html; do
  grep -q "\`$f\`" "$W/frontend/index.md" || fail "frontend: falta $f en el índice"
done

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
  for r in frontend bff; do
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
  for k in 'revisado' 'excluir:' 'RN-n' 'MJ-n' 'politica:' 'aplica la mejora MJ-n' 'AU-n' '_auditoria.md' 'migration-auditor' '[ausente: ' 'Usa el subagente migration-orchestrator' 'Usa el subagente migration-tl-resolver'; do
    printf '%s' "$block" | grep -qF "$k" || fail "bloque de CLAUDE.md sin '$k'"
  done
else
  fail "CLAUDE.md no existe"
fi
for t in adr spec task test-plan backlog; do
  [ -f "$W/migration/templates/$t.md" ] || fail "falta plantilla $t.md"
done
grep -q '^## 12\. Preguntas abiertas' "$W/migration/templates/spec.md" || fail "spec.md sin sección 12"
grep -q '^## 13\. Posibles mejoras' "$W/migration/templates/spec.md" || fail "spec.md sin sección 13"
grep -q '^commits:' "$W/migration/templates/spec.md" || fail "spec.md sin commits en el frontmatter"
grep -q '^bloqueada_por:' "$W/migration/templates/task.md" || fail "task.md sin bloqueada_por"
grep -q '^implicacion_migracion:' "$W/migration/templates/adr.md" || fail "adr.md sin implicacion_migracion"

[ "$fails" -eq 0 ] && { echo "OK: indexer"; exit 0; }
exit 1
