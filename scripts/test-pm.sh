#!/usr/bin/env bash
# migration-pm no calcula: usa backlog.sh. Ante un ciclo no escribe nada, y sin
# el script se detiene y lo dice. Parte de la etapa tl-tasks.
set -uo pipefail
export FIXTURE="${FIXTURE:-1}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
export WORKDIR="$W"
SNAP_TMP="$(mktemp -d)"
trap 'rm -rf "$SNAP_TMP"' EXIT
M="$W/migration"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
run() { bash "$ROOT/scripts/run-agent.sh" "$@"; rc=$?; [ $rc -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }; return $rc; }
snap() { find "$W" -path "$W/*/.git" -prune -o -type f -print0 | sort -z | xargs -0 md5sum; }
sin_cambios() { # <caso> <salida del agente>
  snap > "$SNAP_TMP/b.txt"
  diff -q "$SNAP_TMP/a.txt" "$SNAP_TMP/b.txt" >/dev/null || fail "$1: el PM escribió o modificó archivos: $(diff "$SNAP_TMP/a.txt" "$SNAP_TMP/b.txt" | grep '^[<>]' | sed 's/.* //' | sort -u | head -n3 | xargs -n1 basename | paste -sd' ' -)"
}

# --- 1. Ciclo plantado: dos tareas de la misma capacidad que dependen una de otra
bash "$ROOT/scripts/snapshot.sh" restore tl-tasks "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa tl-tasks"; exit 1; }
[ -f "$W/.claude/migration/backlog.sh" ] || { echo "FAIL: el workspace restaurado no tiene .claude/migration/backlog.sh"; exit 1; }
S="$(ls "$M"/specs | grep -v '^_' | head -n1 | sed 's/\.md$//')"
mapfile -t TS < <(grep -l "^spec: $S$" "$M"/tasks/T-*.md | head -n2)
[ "${#TS[@]}" -eq 2 ] || { echo "FAIL: no hay dos tareas del spec $S para plantar el ciclo"; exit 1; }
A="$(basename "${TS[0]}" | grep -oE '^T-[0-9]+')"; B="$(basename "${TS[1]}" | grep -oE '^T-[0-9]+')"
sed -i "s/^depende_de:.*/depende_de: [$B]/" "${TS[0]}"
sed -i "s/^depende_de:.*/depende_de: [$A]/" "${TS[1]}"
bash "$ROOT/scripts/backlog.sh" validar "$W" >/dev/null 2>&1 && { echo "FAIL: el ciclo plantado entre $A y $B no hace fallar a backlog.sh"; exit 1; }
echo "--- ciclo plantado entre $A y $B"
snap > "$SNAP_TMP/a.txt"
out="$(run migration-pm)"
sin_cambios "ciclo" "$out"
printf '%s' "$out" | grep -qi 'ciclo' || fail "ciclo: el PM no menciona el ciclo"
printf '%s' "$out" | grep -q "$A" || fail "ciclo: el PM no nombra $A"
printf '%s' "$out" | grep -q "$B" || fail "ciclo: el PM no nombra $B"
[ -f "$M/backlog.md" ] && fail "ciclo: el PM escribió backlog.md"

# --- 2. Dependencia a una tarea que no existe
bash "$ROOT/scripts/snapshot.sh" restore tl-tasks "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa tl-tasks"; exit 1; }
T1="$(grep -l "^spec: $S$" "$M"/tasks/T-*.md | head -n1)"
sed -i 's/^depende_de: \[\(.*\)\]/depende_de: [\1, T-999]/; s/^depende_de: \[, /depende_de: [/' "$T1"
snap > "$SNAP_TMP/a.txt"
out="$(run migration-pm)"
sin_cambios "dependencia rota" "$out"
printf '%s' "$out" | grep -q 'T-999' || fail "dependencia rota: el PM no nombra T-999"

# --- 3. Script ausente: se detiene y lo dice; no calcula a mano
bash "$ROOT/scripts/snapshot.sh" restore tl-tasks "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa tl-tasks"; exit 1; }
rm -rf "$W/.claude/migration"
snap > "$SNAP_TMP/a.txt"
out="$(run migration-pm)"
sin_cambios "script ausente" "$out"
printf '%s' "$out" | grep -q 'backlog.sh' || fail "script ausente: el PM no dice que falta backlog.sh"
[ -f "$M/backlog.md" ] && fail "script ausente: el PM escribió backlog.md sin el script"

[ "$fails" -eq 0 ] && { echo "OK: pm (ciclo, dependencia rota y script ausente)"; exit 0; }
exit 1
