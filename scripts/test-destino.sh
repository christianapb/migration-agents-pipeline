#!/usr/bin/env bash
# Destino por repositorio: con el mapa {bff: Kotlin, frontend: conservar},
# migration-tl-adrs no propone nada sobre el frontend y migration-tl-tasks no
# le genera tareas de implementación; los specs no cambian. Con un mapa al que
# le falta un repositorio, migration-tl-tasks se detiene sin escribir.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
export WORKDIR="$W"
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
run() { bash "$ROOT/scripts/run-agent.sh" "$@"; rc=$?; [ $rc -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }; return $rc; }
hash_dir() { find "$1" -type f -print0 | sort -z | xargs -0 md5sum | md5sum; }

bash "$ROOT/scripts/snapshot.sh" restore tl-specs "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa tl-specs"; exit 1; }

# Línea base con destino único, de la instantánea restaurada
base_prop="$(grep -l '^estado: propuesto' "$M"/adr/*.md 2>/dev/null | wc -l)"
echo "--- destino único: $base_prop ADRs propuestos"

# --- Mapa con el frontend conservado
rm -rf "$M/adr" "$M/tasks"
sed -i 's/^destino:.*/destino: {bff: Kotlin, frontend: conservar}/' "$M/README.md"
grep -q '^destino: {bff: Kotlin, frontend: conservar}$' "$M/README.md" || { echo "FAIL: no se pudo fijar el mapa en el README"; exit 1; }
h_specs="$(hash_dir "$M/specs")"

run migration-tl-adrs >/dev/null
bash "$ROOT/scripts/verify-tl-adrs.sh" || fail "los ADRs con el mapa no pasan verify-tl-adrs"
prop="$(grep -l '^estado: propuesto' "$M"/adr/*.md 2>/dev/null | wc -l)"
[ "$prop" -ge 1 ] || fail "no hay ningún ADR propuesto para el bff"
malos="$(grep -l '^estado: propuesto' "$M"/adr/*.md 2>/dev/null | xargs -r grep -lE '^repos:.*\bfrontend\b' || true)"
[ -z "$malos" ] || fail "ADRs propuestos que incluyen el frontend: $(echo $malos | xargs -n1 basename | paste -sd' ' -)"
grep -l '^estado: observado' "$M"/adr/*.md 2>/dev/null | xargs -r grep -lE '^repos:.*\bfrontend\b' >/dev/null \
  || fail "ningún ADR observado documenta el frontend"

run migration-tl-tasks "Ejecútalo aunque haya ADRs propuestos." >/dev/null
bash "$ROOT/scripts/verify-tl-tasks.sh" || fail "las tareas con el mapa no pasan verify-tl-tasks"
total="$(ls "$M"/tasks/T-*.md 2>/dev/null | wc -l)"
[ "$total" -ge 1 ] || fail "no se generó ninguna tarea"
fe="$(grep -l '^repo_destino: frontend' "$M"/tasks/T-*.md 2>/dev/null | wc -l)"
fe_impl="$(grep -l '^repo_destino: frontend' "$M"/tasks/T-*.md 2>/dev/null | xargs -r grep -L '^tipo: adaptacion' | wc -l)"
[ "$fe_impl" -eq 0 ] || fail "$fe_impl tareas de implementación con repo_destino: frontend"

[ "$(hash_dir "$M/specs")" = "$h_specs" ] || fail "los specs cambiaron al generar ADRs y tareas"
[ "$(grep -hE '^(RN|CB)-[0-9]+:.*\[.*frontend/' "$M"/specs/[!_]*.md | wc -l)" -ge 1 ] || fail "los specs no describen el comportamiento del frontend"

echo "--- mapa {bff: Kotlin, frontend: conservar}: $prop ADRs propuestos, $total tareas ($fe en frontend, todas de adaptación)"

# --- Mapa al que le falta un repositorio: tl-tasks se detiene sin escribir
sed -i 's/^destino:.*/destino: {bff: Kotlin}/' "$M/README.md"
h_all="$(hash_dir "$M")"
out="$(run migration-tl-tasks "Ejecútalo aunque haya ADRs propuestos.")"
[ "$(hash_dir "$M")" = "$h_all" ] || fail "tl-tasks escribió archivos con un mapa incompleto"
printf '%s' "$out" | grep -q 'frontend' || fail "tl-tasks no nombró el repositorio que falta en el mapa"

[ "$fails" -eq 0 ] && { echo "OK: destino por repositorio"; exit 0; }
exit 1
