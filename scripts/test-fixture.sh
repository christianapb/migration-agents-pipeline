#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/.work/sample-workspace"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

bash "$ROOT/scripts/fixture-reset.sh" >/dev/null || fail "fixture-reset.sh falló"

for r in frontend bff; do
  [ -d "$W/$r/.git" ] || fail "$r no es repo git"
  ( cd "$W/$r" && git log --oneline 2>/dev/null | grep -q fixture ) || fail "$r sin commit"
done
( cd "$W/bff" && git ls-files | grep -q '^dist/' ) && fail "bff/dist está trackeado; debe estar en .gitignore"
( cd "$W/bff" && git ls-files | grep -q 'package-lock.json' ) || fail "bff lockfile debería estar trackeado (prueba exclusión fija)"
( cd "$W/bff" && git ls-files | grep -q '__snapshots__' ) || fail "bff snapshot debería estar trackeado"
( cd "$W/frontend" && git ls-files | grep -q 'public/logo.png' ) || fail "frontend logo.png debería estar trackeado"
[ -d "$W/.claude/agents" ] || fail "no se copiaron los agentes"
[ -f "$W/bff/src/routes/products.ts" ] || fail "falta products.ts"
[ -f "$W/bff/dist/server.js" ] || fail "falta bff/dist/server.js en disco (debe existir para probar la exclusión)"
git -C "$ROOT" ls-files --error-unmatch fixtures/sample-workspace/bff/dist/server.js >/dev/null 2>&1 || fail "fixtures/sample-workspace/bff/dist/server.js no está versionado en spec-agent (usar git add -f)"
grep -q 'status(200).end()' "$W/bff/src/routes/products.ts" || fail "falta la ambigüedad 200 vacío"
grep -q 'getPriceCents' "$W/bff/src/routes/cart.ts" || fail "falta dependencia cruzada carrito→catálogo"

# Segundo fixture: monolito Flask con base de datos, proceso programado, ruido y trampas
R="$ROOT/fixtures/reservas-workspace/reservas"
for f in pyproject.toml app.py schema.sql migrations/001_inicial.sql scripts/caducar_reservas.py crontab.txt poetry.lock static/logo.png build/lib/app.py; do
  [ -f "$R/$f" ] || fail "reservas: falta $f"
done
git -C "$ROOT" ls-files --error-unmatch fixtures/reservas-workspace/reservas/build/lib/app.py >/dev/null 2>&1 || fail "reservas: build/lib/app.py no está versionado en spec-agent (usar git add -f)"
grep -q '^build/' "$R/.gitignore" || fail "reservas: build/ debe estar en su .gitignore"
n="$(find "$R" -type f \( -name '*.py' -o -name '*.sql' -o -name '*.html' -o -name '*.css' \) ! -path '*/build/*' ! -name '__init__.py' | wc -l)"
[ "$n" -ge 20 ] && [ "$n" -le 30 ] || fail "reservas: $n archivos de código, se esperaban entre 20 y 30"
# Las trampas siguen plantadas
grep -q 'Máximo 8 horas' "$R/services/reservas.py" && grep -q '^MAX_HORAS = 4$' "$R/services/reservas.py" || fail "reservas: falta la trampa del comentario que contradice al código"
grep -q 'def recargo_fin_de_semana' "$R/utils/fechas.py" || fail "reservas: falta la función sin uso"
[ "$(grep -rl 'recargo_fin_de_semana' "$R" --include='*.py' | wc -l)" -eq 1 ] || fail "reservas: recargo_fin_de_semana debería no usarse en ningún otro archivo"
grep -q '\.ics' "$R/README.md" && ! grep -rq 'ics' "$R" --include='*.py' || fail "reservas: falta la trampa del README que describe una función inexistente"
grep -q 'MAX_RESERVAS_DIA' "$R/config.py" && [ "$(grep -rl 'MAX_RESERVAS_DIA' "$R" --include='*.py' | wc -l)" -eq 1 ] || fail "reservas: MAX_RESERVAS_DIA debe declararse y no leerse"
grep -q 'url_prefix="/admin"' "$R/routes/admin.py" && ! grep -q 'admin' "$R/app.py" || fail "reservas: el blueprint de admin debe existir y no registrarse"
# Los hechos de cada fixture viven fuera de la carpeta que se copia como workspace
for fx in sample-workspace reservas-workspace; do
  [ -f "$ROOT/fixtures/hechos/$fx.txt" ] || fail "falta fixtures/hechos/$fx.txt"
  find "$ROOT/fixtures/$fx" -name '*hechos*' | grep -q . && fail "$fx: hay un archivo de hechos dentro del workspace"
done

[ "$fails" -eq 0 ] && { echo "OK: fixture"; exit 0; }
exit 1
