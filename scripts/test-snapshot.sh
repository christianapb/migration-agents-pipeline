#!/usr/bin/env bash
# Prueba snapshot.sh con un claude falso: construcción, reutilización,
# invalidación parcial al cambiar un prompt y restauración.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

# claude falso: deja una marca por agente en la carpeta actual y registra la llamada
mkdir -p "$TMP/bin"
cat > "$TMP/bin/claude" <<'EOF'
#!/usr/bin/env bash
agent=""
all="$*"
while [ $# -gt 0 ]; do
  case "$1" in --agent) agent="$2"; shift ;; esac
  shift
done
[ -n "$agent" ] || agent="$(printf '%s' "$all" | grep -o 'migration-[a-z-]*' | head -n1)"
touch "hecho-$agent"
echo "$agent" >> "$FAKE_CALLS"
echo "Resumen de $agent"
EOF
chmod +x "$TMP/bin/claude"
export PATH="$TMP/bin:$PATH" FAKE_CALLS="$TMP/calls.txt"
export SNAPSHOT_DIR="$TMP/snaps" AGENTS_DIR="$TMP/agents"
cp -r "$ROOT/agents" "$AGENTS_DIR"
calls() { local n; n="$(grep -c . "$FAKE_CALLS" 2>/dev/null)"; echo "${n:-0}"; }

# 1. Construir hasta pm: siete agentes
bash "$ROOT/scripts/snapshot.sh" build pm >/dev/null || fail "build pm falló"
[ "$(calls)" -eq 7 ] || fail "build pm hizo $(calls) llamadas, se esperaban 7"

# 2. Reconstruir sin cambios: ninguna llamada
: > "$FAKE_CALLS"
bash "$ROOT/scripts/snapshot.sh" build pm >/dev/null || fail "rebuild falló"
[ "$(calls)" -eq 0 ] || fail "rebuild sin cambios hizo $(calls) llamadas"

# 3. Cambiar el prompt de tl-specs: se rehacen tl-specs, qa, tl-tasks y pm
: > "$FAKE_CALLS"
echo "cambio" >> "$AGENTS_DIR/migration-tl-specs.md"
bash "$ROOT/scripts/snapshot.sh" build pm >/dev/null || fail "rebuild tras cambio falló"
got="$(paste -sd, "$FAKE_CALLS")"
[ "$got" = "migration-tl-specs,migration-qa,migration-tl-tasks,migration-pm" ] || fail "invalidación parcial incorrecta: $got"

# 4. Cambiar un agente fuera de la cadena (resolver): nada que rehacer
: > "$FAKE_CALLS"
echo "cambio" >> "$AGENTS_DIR/migration-tl-resolver.md"
bash "$ROOT/scripts/snapshot.sh" build pm >/dev/null || fail "rebuild tras cambiar resolver falló"
[ "$(calls)" -eq 0 ] || fail "cambiar el resolver rehízo $(calls) etapas"

# 5. Restaurar qa en un destino con espacios: marcas hasta qa, sin pm, agentes actuales
D="$TMP/con espacio/ws"
bash "$ROOT/scripts/snapshot.sh" restore qa "$D" >/dev/null || fail "restore qa falló"
[ -f "$D/hecho-migration-qa" ] || fail "restore qa: falta la marca de qa"
[ -f "$D/hecho-migration-pm" ] && fail "restore qa: contiene la etapa pm"
[ -f "$D/hecho-migration-tl-tasks" ] && fail "restore qa: contiene la etapa tl-tasks, que ahora va después"
[ -d "$D/bff/.git" ] || fail "restore qa: el repo bff no conserva .git"
cmp -s "$AGENTS_DIR/migration-tl-resolver.md" "$D/.claude/agents/migration-tl-resolver.md" || fail "restore: no copió los agentes actuales"

# 6. Restaurar la etapa fixture: repos inicializados y sin marcas
D2="$TMP/ws2"
bash "$ROOT/scripts/snapshot.sh" restore fixture "$D2" >/dev/null || fail "restore fixture falló"
[ -d "$D2/frontend/.git" ] || fail "restore fixture: frontend sin .git"
ls "$D2"/hecho-* >/dev/null 2>&1 && fail "restore fixture: contiene marcas de agentes"

# 7. Etapa desconocida: error
bash "$ROOT/scripts/snapshot.sh" restore inventada "$TMP/x" >/dev/null 2>&1 && fail "aceptó una etapa desconocida"

[ "$fails" -eq 0 ] && { echo "OK: snapshot"; exit 0; }
exit 1
