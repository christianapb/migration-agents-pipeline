#!/usr/bin/env bash
# Pruebas que no ejecutan agentes, en paralelo. Correr en cada cambio.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
TESTS=(test-check-agent test-install test-verifiers test-backlog test-prompts test-snapshot test-runner test-fixture)

start=$(date +%s)
for t in "${TESTS[@]}"; do
  ( bash "$ROOT/scripts/$t.sh" > "$TMP/$t.log" 2>&1; echo $? > "$TMP/$t.rc" ) &
done
wait

failed=0
for t in "${TESTS[@]}"; do
  if [ "$(cat "$TMP/$t.rc")" = 0 ]; then
    echo "  OK    $t"
  else
    echo "  FAIL  $t"
    grep -E '^(FAIL|ERROR)' "$TMP/$t.log" | head -5 | sed 's/^/          /'
    failed=$((failed+1))
  fi
done
echo "($(( $(date +%s) - start )) s)"
[ "$failed" -eq 0 ] || { echo "$failed prueba(s) rápidas fallaron."; exit 1; }
echo "Pruebas rápidas: todas pasaron."
