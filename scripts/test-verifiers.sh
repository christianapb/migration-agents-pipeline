#!/usr/bin/env bash
# Pruebas de los verificadores y de run-agent.sh sobre workspaces sintéticos.
# No ejecuta agentes reales.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

# --- Workspace sintético mínimo que pasa verify-techlead, verify-qa y verify-pm
make_ws() {
  local W="$1"
  mkdir -p "$W/migration/specs" "$W/migration/adr" "$W/migration/tasks" "$W/migration/test-plans"
  cat > "$W/migration/README.md" <<'EOF'
---
destino: Kotlin
excluir: []
politica: paridad
---
# Migración
1. [x] migration-indexer
4. [x] migration-pm
## Cómo empezar a implementar
Ver backlog.md.
EOF
  cat > "$W/migration/specs/_capacidades.md" <<'EOF'
# Capacidades
| Capacidad | Descripción | Repos | Archivos principales |
|---|---|---|---|
| alfa | Uno | bff | bff/a.ts |
| beta | Dos | bff | bff/b.ts |
| gamma | Tres | bff | bff/c.ts |
EOF
  for c in alfa beta gamma; do
    cat > "$W/migration/specs/$c.md" <<EOF
---
capacidad: $c
estado: generado
---
# Spec: $c
## 1. Resumen
x
## 2. Actores
x
## 3. Alcance por repo
x
## 4. Flujos de comportamiento
x
## 5. Contratos de API
x
## 6. Modelos de datos
x
## 7. Reglas de negocio
RN-1: regla uno.
RN-10: regla diez.
## 8. Casos borde y errores
CB-1: un producto oculto responde 200 sin cuerpo.
## 9. Dependencias externas
x
## 10. ADRs relacionados
x
## 11. Evidencia en el código original
bff/a.ts
## 12. Preguntas abiertas
- ¿Qué responde el servicio de identidad si la cuenta está bloqueada?
## 13. Posibles mejoras
MJ-1: responder 404 para un producto oculto. Comportamiento actual: CB-1.
EOF
    cat > "$W/migration/test-plans/$c.md" <<EOF
---
capacidad: $c
spec: $c
estado: generado
---
# Plan de pruebas: $c
## Alcance y supuestos
x
## Matriz de cobertura
| Requisito | Casos |
|---|---|
| RN-1 | TC-$c-001 |
| RN-10 | TC-$c-002 |
| CB-1 | TC-$c-003 |
## Casos: camino feliz
### TC-$c-001: uno
- Prioridad: alta
- Nivel sugerido: unitario
- Cubre: RN-1
- Tareas: T-002
- Dado a
- Cuando b
- Entonces c
### TC-$c-002: dos
- Prioridad: alta
- Nivel sugerido: unitario
- Cubre: RN-10
- Tareas: T-002
- Dado a
- Cuando b
- Entonces c
## Casos: casos borde
### TC-$c-003: tres
- Prioridad: alta
- Nivel sugerido: unitario
- Cubre: CB-1
- Tareas: T-002
- Dado a
- Cuando b
- Entonces c
## Casos: errores
## Casos: contratos de API
## Casos pendientes de definición
- **Pendiente 1**: ¿Qué responde el servicio de identidad si la cuenta está bloqueada?
## Hallazgos para el tech lead
Ninguno.
EOF
  done
  cat > "$W/migration/test-plans/_cobertura.md" <<'EOF'
# Cobertura de pruebas
## Huecos
EOF
  cat > "$W/migration/adr/0001-uno.md" <<'EOF'
---
id: 0001
titulo: Uno
estado: observado
implicacion_migracion: conservar
---
# ADR 0001: uno
## Contexto
x
## Decisión
x
## Consecuencias
x
## Evidencia
bff/a.ts
## Implicación para la migración
Conservar.
EOF
  cat > "$W/migration/adr/0002-dos.md" <<'EOF'
---
id: 0002
titulo: Dos
estado: propuesto
implicacion_migracion:
---
# ADR 0002: dos
## Contexto
x
## Decisión
x
**Recomendación:** opción 1.
## Consecuencias
x
## Evidencia
bff/a.ts
## Implicación para la migración
Decidir.
EOF
  cat > "$W/migration/tasks/T-001-base.md" <<'EOF'
---
id: T-001
spec:
depende_de: []
tamaño: S
estado: generado
fase: 0
prioridad: 1
bloqueada_por: []
---
# T-001: base
## Criterios de aceptación
- x
EOF
  cat > "$W/migration/tasks/T-002-alfa.md" <<'EOF'
---
id: T-002
spec: alfa
depende_de: [T-001]
tamaño: M
estado: generado
fase: 1
prioridad: 2
bloqueada_por: [0002]
---
# T-002: alfa
## Criterios de aceptación
- RN-1, RN-10, CB-1
EOF
  cat > "$W/migration/backlog.md" <<'EOF'
# Backlog
### Hito 0: fundaciones
| 1 | T-001 |
### Hito 1: alfa
| 2 | T-002 |
## Bloqueos
| T-002 | 0002 | aceptar |
## Riesgos
Ninguno.
EOF
}

# 1. Los verificadores funcionan con espacios en la ruta del workspace
WS="$TMP/con espacio/ws"
make_ws "$WS"
for v in analyst tl-adrs tl-specs tl-tasks qa pm; do
  if ! WORKDIR="$WS" bash "$ROOT/scripts/verify-$v.sh" >/dev/null 2>&1; then
    fail "verify-$v.sh falla con espacios en la ruta"
  fi
done

# 2. verify-qa no da OK cuando RN-1 solo aparece como prefijo de RN-10
WS2="$TMP/prefijo"
make_ws "$WS2"
# RN-1 deja de estar cubierta; solo sobrevive como prefijo de RN-10
sed -i '/^| RN-1 |/d; s/^- Cubre: RN-1$/- Cubre: RN-10/' "$WS2/migration/test-plans/alfa.md"
if WORKDIR="$WS2" bash "$ROOT/scripts/verify-qa.sh" >/dev/null 2>&1; then
  fail "verify-qa.sh acepta RN-1 sin cubrir porque RN-10 contiene el prefijo"
fi

# 3. verify-qa falla si el spec no tiene ninguna RN/CB con formato 'RN-n:'
WS3="$TMP/sinformato"
make_ws "$WS3"
sed -i 's/^RN-1: /**RN-1**: /; s/^RN-10: /**RN-10**: /; s/^CB-1: /**CB-1**: /' "$WS3/migration/specs/alfa.md"
if WORKDIR="$WS3" bash "$ROOT/scripts/verify-qa.sh" >/dev/null 2>&1; then
  fail "verify-qa.sh acepta un spec sin RN/CB en formato 'RN-n:' (comprobación vacía)"
fi

# 4. run-agent.sh: solo el aviso real de límite de Claude produce exit 2
FAKE="$TMP/bin"; mkdir -p "$FAKE"
cat > "$FAKE/claude" <<'EOF'
#!/usr/bin/env bash
cat "$FAKE_OUTPUT"
EOF
chmod +x "$FAKE/claude"
printf '%s\n' "Resumen final: el BFF aplica rate limit de 100 req/min con express-rate-limit y respeta el usage limit del servicio de identidad. Se indexaron 20 archivos." > "$TMP/legit.txt"
printf '%s\n' "You've hit your weekly limit · resets 8am (America/Santiago)" > "$TMP/limit.txt"
mkdir -p "$TMP/wd"
PATH="$FAKE:$PATH" FAKE_OUTPUT="$TMP/legit.txt" WORKDIR="$TMP/wd" bash "$ROOT/scripts/run-agent.sh" x >/dev/null 2>&1
[ $? -eq 0 ] || fail "run-agent.sh trata una salida legítima que menciona 'rate limit' como límite de uso"
PATH="$FAKE:$PATH" FAKE_OUTPUT="$TMP/limit.txt" WORKDIR="$TMP/wd" bash "$ROOT/scripts/run-agent.sh" x >/dev/null 2>&1
[ $? -eq 2 ] || fail "run-agent.sh no detecta el aviso real de límite de uso"

# 5. run-agent.sh arranca el agente directamente, sin sesión intermedia que delegue
cat > "$FAKE/claude" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$FAKE_ARGS"
echo "Resumen"
EOF
PATH="$FAKE:$PATH" FAKE_ARGS="$TMP/args.txt" WORKDIR="$TMP/wd" bash "$ROOT/scripts/run-agent.sh" migration-qa "Solo la capacidad carrito." >/dev/null 2>&1
grep -qx -- '--agent' "$TMP/args.txt" && grep -qx 'migration-qa' "$TMP/args.txt" || fail "run-agent.sh no usa --agent <nombre>"
grep -qx -- '--no-session-persistence' "$TMP/args.txt" || fail "run-agent.sh no usa --no-session-persistence"
grep -q 'Solo la capacidad carrito.' "$TMP/args.txt" || fail "run-agent.sh no pasa el texto adicional al agente"
grep -q 'Invoca el subagente' "$TMP/args.txt" && fail "run-agent.sh sigue delegando desde una sesión principal"

# 6. Política de paridad: lo que los verificadores deben rechazar
expect_fail() { # <verificador> <workspace> <mensaje>
  if WORKDIR="$2" bash "$ROOT/scripts/verify-$1.sh" >/dev/null 2>&1; then fail "$3"; fi
}
SP="migration/specs/alfa.md"
W6="$TMP/p1"; make_ws "$W6"; sed -i '/^## 13\. Posibles mejoras/,$d' "$W6/$SP"
expect_fail tl-specs "$W6" "verify-tl-specs acepta un spec sin sección 13"
W6="$TMP/p2"; make_ws "$W6"; sed -i 's/Comportamiento actual: CB-1\./Comportamiento actual: CB-99./' "$W6/$SP"
expect_fail tl-specs "$W6" "verify-tl-specs acepta una MJ que cita una regla inexistente"
W6="$TMP/p3"; make_ws "$W6"; sed -i 's/^- ¿Qué responde el servicio de identidad.*/- Al quitar una línea que no existe, ¿se mantiene 204 o debe responderse 404?/' "$W6/$SP"
expect_fail tl-specs "$W6" "verify-tl-specs acepta una pregunta con fórmula de mejora"
W6="$TMP/p4"; make_ws "$W6"; sed -i 's/^- ¿Qué responde el servicio de identidad.*/- ¿Uno?\n- ¿Dos?\n- ¿Tres?\n- ¿Cuatro?\n- ¿Cinco?\n- ¿Seis?/' "$W6/$SP"
expect_fail tl-specs "$W6" "verify-tl-specs acepta más preguntas que MAX_PREGUNTAS"
MAX_PREGUNTAS=6 WORKDIR="$W6" bash "$ROOT/scripts/verify-tl-specs.sh" >/dev/null 2>&1 || fail "verify-tl-specs no respeta MAX_PREGUNTAS"
W6="$TMP/p5"; make_ws "$W6"; sed -i 's/^- ¿Qué responde el servicio de identidad.*/- ¿Qué pasa con un producto oculto?/' "$W6/$SP"
expect_fail tl-specs "$W6" "verify-tl-specs acepta el producto oculto como pregunta abierta"
W6="$TMP/p6"; make_ws "$W6"; for c in alfa beta gamma; do sed -i '/^MJ-1:/d' "$W6/migration/specs/$c.md"; echo "Ninguna" >> "$W6/migration/specs/$c.md"; done
expect_fail tl-specs "$W6" "verify-tl-specs acepta que el producto oculto no esté entre las mejoras"

# Una viñeta en la sección 13 no es una pregunta: PA:alfa:2 no existe
W6="$TMP/p7"; make_ws "$W6"; echo "- nota suelta en la sección 13" >> "$W6/$SP"
sed -i 's/^bloqueada_por: \[0002\]/bloqueada_por: [0002, PA:alfa:2]/' "$W6/migration/tasks/T-002-alfa.md"
expect_fail tl-tasks "$W6" "verify-tl-tasks cuenta viñetas de la sección 13 como preguntas"
W6="$TMP/p8"; make_ws "$W6"; echo "- RN-1: pregunta abierta 1, paridad provisional." >> "$W6/migration/tasks/T-002-alfa.md"
expect_fail tl-tasks "$W6" "verify-tl-tasks acepta 'paridad provisional'"
W6="$TMP/p9"; make_ws "$W6"; sed -i 's/^bloqueada_por: \[0002\]/bloqueada_por: [0002, MJ-1]/' "$W6/migration/tasks/T-002-alfa.md"
expect_fail tl-tasks "$W6" "verify-tl-tasks acepta una MJ en bloqueada_por"

PL="migration/test-plans/alfa.md"
W6="$TMP/p10"; make_ws "$W6"; sed -i 's/^- \*\*Pendiente 1\*\*: .*/&\n- **Pendiente 2**: MJ-1 responder 404 para un producto oculto./' "$W6/$PL"
expect_fail qa "$W6" "verify-qa acepta mejoras entre los casos pendientes"
W6="$TMP/p11"; make_ws "$W6"; sed -i 's/^- \*\*Pendiente 1\*\*: .*/&\n- **Pendiente 2**: otra cosa./' "$W6/$PL"
expect_fail qa "$W6" "verify-qa acepta más pendientes que preguntas abiertas"
# Sin preguntas abiertas ni pendientes: válido bajo paridad
W6="$TMP/p12"; make_ws "$W6"
for c in alfa beta gamma; do
  sed -i 's/^- ¿Qué responde el servicio de identidad.*/Ninguna./' "$W6/migration/specs/$c.md"
  sed -i 's/^- \*\*Pendiente 1\*\*: .*/Ninguno./' "$W6/migration/test-plans/$c.md"
done
WORKDIR="$W6" bash "$ROOT/scripts/verify-qa.sh" >/dev/null 2>&1 || fail "verify-qa rechaza un workspace sin preguntas abiertas"
WORKDIR="$W6" bash "$ROOT/scripts/verify-tl-specs.sh" >/dev/null 2>&1 || fail "verify-tl-specs rechaza un workspace sin preguntas abiertas"

[ "$fails" -eq 0 ] && { echo "OK: verificadores"; exit 0; }
exit 1
