#!/usr/bin/env bash
# Review Focus 5: un spec marcado revisado y editado a mano sobrevive a una
# segunda corrida del tech lead. Requiere un workspace con specs ya generados.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/.work/sample-workspace"
M="$W/migration"
slug=$(ls "$M"/specs 2>/dev/null | grep -v '^_' | head -n1 | sed 's/\.md$//')
[ -n "$slug" ] || { echo "FAIL: no hay specs; corre run-all.sh primero"; exit 1; }
spec="$M/specs/$slug.md"
marker="MARCA-HUMANA-$(date +%s)"

sed -i 's/^estado: generado/estado: revisado/' "$spec"
printf '\n%s\n' "$marker" >> "$spec"
before="$(md5sum "$spec")"

bash "$ROOT/scripts/run-agent.sh" migration-techlead "Ejecútalo con destino Kotlin." >/dev/null

after="$(md5sum "$spec")"
if [ "$before" = "$after" ] && grep -q "$marker" "$spec"; then
  echo "OK: idempotencia ($slug conservado)"; exit 0
fi
echo "FAIL: el spec revisado $slug cambió"; exit 1
