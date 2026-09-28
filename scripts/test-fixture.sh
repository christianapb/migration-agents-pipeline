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
grep -q 'status(200).end()' "$W/bff/src/routes/products.ts" || fail "falta la ambigüedad 200 vacío"
grep -q 'getPriceCents' "$W/bff/src/routes/cart.ts" || fail "falta dependencia cruzada carrito→catálogo"

[ "$fails" -eq 0 ] && { echo "OK: fixture"; exit 0; }
exit 1
