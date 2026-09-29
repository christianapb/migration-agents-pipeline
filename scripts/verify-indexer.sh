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
grep -q 'migration-indexer' "$W/migration/README.md" || fail "README sin flujo"
for t in adr spec task test-plan backlog; do
  [ -f "$W/migration/templates/$t.md" ] || fail "falta plantilla $t.md"
done
grep -q '^## 12\. Preguntas abiertas' "$W/migration/templates/spec.md" || fail "spec.md sin sección 12"
grep -q '^bloqueada_por:' "$W/migration/templates/task.md" || fail "task.md sin bloqueada_por"
grep -q '^implicacion_migracion:' "$W/migration/templates/adr.md" || fail "adr.md sin implicacion_migracion"

[ "$fails" -eq 0 ] && { echo "OK: indexer"; exit 0; }
exit 1
