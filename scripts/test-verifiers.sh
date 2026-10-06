#!/usr/bin/env bash
# Pruebas de los verificadores y de run-agent.sh sobre workspaces sintéticos.
# No ejecuta agentes reales.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
# Las comprobaciones propias del fixture están apagadas por defecto; aquí se prueban
export FIXTURE=1
# Hechos y trampas del workspace sintético (el de verdad está en fixtures/hechos/)
export HECHOS="$TMP/hechos-sinteticos.txt"
cat > "$HECHOS" <<'EOF'
# tipo | id | capacidad | patrones | descripción
hecho | S1 | alfa|beta|gamma | ocult && \b200\b | un producto oculto responde 200
mejora | S2 | . | ocult | el producto oculto figura como mejora
no-pregunta | S3 | . | ocult | el producto oculto no es una pregunta abierta
trampa | S4 | . | cup.*n && \b410\b | ningún código responde 410 por un cupón caducado
EOF

# --- Workspace sintético mínimo que pasa verify-techlead, verify-qa y verify-pm
make_ws() {
  local W="$1"
  mkdir -p "$W/migration/specs" "$W/migration/adr" "$W/migration/tasks" "$W/migration/test-plans" "$W/bff" "$W/frontend"
  printf 'linea 1\nlinea 2\nlinea 3\nlinea 4\nlinea 5\n' > "$W/bff/a.ts"
  printf 'pantalla\n' > "$W/frontend/p.tsx"
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
rev: 1
commits: {bff: abc1234}
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
RN-1: regla uno. [bff/a.ts:1]
RN-10: regla diez. [bff/a.ts:2-3, bff/a.ts:5]
## 8. Casos borde y errores
CB-1: un producto oculto responde 200 sin cuerpo. [ausente: bff/a.ts]
## 9. Dependencias externas
x
## 10. ADRs relacionados
x
## 11. Evidencia en el código original
bff/a.ts
## 12. Preguntas abiertas
- PA-1: ¿Qué responde el servicio de identidad si la cuenta está bloqueada?
## 13. Posibles mejoras
MJ-1: responder 404 para un producto oculto. Comportamiento actual: CB-1.
EOF
    cat > "$W/migration/test-plans/$c.md" <<EOF
---
capacidad: $c
spec: $c
spec_rev: 1
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
- Dado a
- Cuando b
- Entonces c
### TC-$c-002: dos
- Prioridad: alta
- Nivel sugerido: unitario
- Cubre: RN-10
- Dado a
- Cuando b
- Entonces c
## Casos: casos borde
### TC-$c-003: tres
- Prioridad: alta
- Nivel sugerido: unitario
- Cubre: CB-1
- Dado a
- Cuando b
- Entonces c
## Casos: errores
## Casos: contratos de API
## Casos pendientes de definición
- **Pendiente PA-1**: ¿Qué responde el servicio de identidad si la cuenta está bloqueada?
## Hallazgos para el tech lead
Ninguno.
EOF
  done
  cat > "$W/migration/test-plans/_cobertura.md" <<'EOF'
# Cobertura de pruebas
| Capacidad | Spec rev | Camino feliz | Borde | Errores | Contratos | Pendientes | RN sin cubrir | CB sin cubrir |
|---|---|---|---|---|---|---|---|---|
| alfa | 1 | 2 | 1 | 0 | 0 | 1 | ninguna | ninguno |
| beta | 1 | 2 | 1 | 0 | 0 | 1 | ninguna | ninguno |
| gamma | 1 | 2 | 1 | 0 | 0 | 1 | ninguna | ninguno |
## Huecos
EOF
  cat > "$W/migration/adr/0001-uno.md" <<'EOF'
---
id: 0001
titulo: Uno
rev: 1
repos: [bff, frontend]
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
rev: 1
repos: [bff]
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
rev: 1
spec:
spec_rev:
adrs: []
adrs_rev: {}
repo_destino: bff
tipo: implementacion
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
rev: 1
spec: alfa
spec_rev: 1
adrs: [0002]
adrs_rev: {0002: 1}
repo_destino: bff
tipo: implementacion
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
| 1 | T-001 | 1 |
### Hito 1: alfa
| 2 | T-002 | 1 |
## Bloqueos
| T-002 | 0002 | aceptar |
## Riesgos
Ninguno.
EOF
  {
    printf '# Auditoría de specs\n\nGenerado: 2026-10-01 por migration-auditor.\n\n## Resumen\n\n'
    printf '| Capacidad | Reglas | Respaldadas | Sin respaldo | Contradichas | No localizables | Decisiones | Omitidos |\n|---|---|---|---|---|---|---|---|\n'
    printf '| alfa | 3 | 2 | 0 | 1 | 0 | 0 | 0 |\n| beta | 3 | 3 | 0 | 0 | 0 | 0 | 0 |\n| gamma | 3 | 3 | 0 | 0 | 0 | 0 | 0 |\n'
    for c in alfa beta gamma; do
      printf '\n## %s\n\nAuditada: 2026-10-01. Spec rev: 1.\n\n| Regla | Veredicto | Cita | Nota |\n|---|---|---|---|\n' "$c"
      if [ "$c" = alfa ]; then
        printf '| RN-1 | respaldada | bff/a.ts:1 | |\n| RN-10 | contradicha | bff/a.ts:2-3 | El código dice otra cosa. |\n| CB-1 | respaldada | ausente: bff/a.ts | |\n'
        printf '\n### Hallazgos\n\n- **AU-1** (contradicha, RN-10): el código dice otra cosa.\n  Corrección: `Usa el subagente migration-tl-resolver: en el spec alfa, RN-10: corrige el valor`\n'
      else
        printf '| RN-1 | respaldada | bff/a.ts:1 | |\n| RN-10 | respaldada | bff/a.ts:2-3 | |\n| CB-1 | respaldada | ausente: bff/a.ts | |\n'
        printf '\n### Hallazgos\n\nNinguno.\n'
      fi
    done
  } > "$W/migration/specs/_auditoria.md"
}

# 1. Los verificadores funcionan con espacios en la ruta del workspace
WS="$TMP/con espacio/ws"
make_ws "$WS"
for v in analyst tl-adrs tl-specs tl-tasks qa pm auditor; do
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
W6="$TMP/p3"; make_ws "$W6"; sed -i 's/^- PA-1: ¿Qué responde el servicio de identidad.*/- Al quitar una línea que no existe, ¿se mantiene 204 o debe responderse 404?/' "$W6/$SP"
expect_fail tl-specs "$W6" "verify-tl-specs acepta una pregunta con fórmula de mejora"
W6="$TMP/p4"; make_ws "$W6"; sed -i 's/^- PA-1: ¿Qué responde el servicio de identidad.*/- ¿Uno?\n- ¿Dos?\n- ¿Tres?\n- ¿Cuatro?\n- ¿Cinco?\n- ¿Seis?/' "$W6/$SP"
expect_fail tl-specs "$W6" "verify-tl-specs acepta más preguntas que MAX_PREGUNTAS"
MAX_PREGUNTAS=6 WORKDIR="$W6" bash "$ROOT/scripts/verify-tl-specs.sh" >/dev/null 2>&1 || fail "verify-tl-specs no respeta MAX_PREGUNTAS"
W6="$TMP/p5"; make_ws "$W6"; sed -i 's/^- PA-1: ¿Qué responde el servicio de identidad.*/- ¿Qué pasa con un producto oculto?/' "$W6/$SP"
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
W6="$TMP/p10"; make_ws "$W6"; sed -i 's/^- \*\*Pendiente PA-1\*\*: .*/&\n- **Pendiente PA-2**: MJ-1 responder 404 para un producto oculto./' "$W6/$PL"
expect_fail qa "$W6" "verify-qa acepta mejoras entre los casos pendientes"
W6="$TMP/p11"; make_ws "$W6"; sed -i 's/^- \*\*Pendiente PA-1\*\*: .*/&\n- **Pendiente PA-2**: otra cosa./' "$W6/$PL"
expect_fail qa "$W6" "verify-qa acepta más pendientes que preguntas abiertas"
# Sin preguntas abiertas ni pendientes: válido bajo paridad
W6="$TMP/p12"; make_ws "$W6"
for c in alfa beta gamma; do
  sed -i 's/^- PA-1: ¿Qué responde el servicio de identidad.*/Ninguna./' "$W6/migration/specs/$c.md"
  sed -i 's/^- \*\*Pendiente PA-1\*\*: .*/Ninguno./' "$W6/migration/test-plans/$c.md"
done
WORKDIR="$W6" bash "$ROOT/scripts/verify-qa.sh" >/dev/null 2>&1 || fail "verify-qa rechaza un workspace sin preguntas abiertas"
WORKDIR="$W6" bash "$ROOT/scripts/verify-tl-specs.sh" >/dev/null 2>&1 || fail "verify-tl-specs rechaza un workspace sin preguntas abiertas"

# 7. Evidencia por regla: lo que verify-tl-specs debe rechazar
W7="$TMP/e1"; make_ws "$W7"; sed -i 's/^RN-1: regla uno\. \[bff\/a\.ts:1\]/RN-1: regla uno./' "$W7/$SP"
expect_fail tl-specs "$W7" "verify-tl-specs acepta una regla sin cita"
W7="$TMP/e2"; make_ws "$W7"; sed -i 's/\[bff\/a\.ts:1\]/[bff\/no-existe.ts:1]/' "$W7/$SP"
expect_fail tl-specs "$W7" "verify-tl-specs acepta una cita a un archivo inexistente"
W7="$TMP/e3"; make_ws "$W7"; sed -i 's/\[bff\/a\.ts:1\]/[bff\/a.ts:99]/' "$W7/$SP"
expect_fail tl-specs "$W7" "verify-tl-specs acepta una línea fuera del archivo"
W7="$TMP/e4"; make_ws "$W7"; sed -i 's/\[bff\/a\.ts:1\]/[ver bff\/a.ts]/' "$W7/$SP"
expect_fail tl-specs "$W7" "verify-tl-specs acepta una cita con formato inválido"
W7="$TMP/e5"; make_ws "$W7"; sed -i '/^commits:/d' "$W7/$SP"
expect_fail tl-specs "$W7" "verify-tl-specs acepta un spec sin commits"
W7="$TMP/e6"; make_ws "$W7"; sed -i 's/\[bff\/a\.ts:1\]/[decisión: MJ-1]/' "$W7/$SP"
WORKDIR="$W7" bash "$ROOT/scripts/verify-tl-specs.sh" >/dev/null 2>&1 || fail "verify-tl-specs rechaza una regla marcada como decisión"
W7="$TMP/e8"; make_ws "$W7"; sed -i 's/\[ausente: bff\/a\.ts\]/[ausente: bff\/a.ts, bff\/a.ts:4]/' "$W7/$SP"
WORKDIR="$W7" bash "$ROOT/scripts/verify-tl-specs.sh" >/dev/null 2>&1 || fail "verify-tl-specs rechaza una cita que combina ausente y línea"
W7="$TMP/e9"; make_ws "$W7"; sed -i 's/\[ausente: bff\/a\.ts\]/[ausente: bff\/a.ts, bff\/a.ts:99]/' "$W7/$SP"
expect_fail tl-specs "$W7" "verify-tl-specs acepta una línea fuera de rango en una cita combinada"
W7="$TMP/e7"; make_ws "$W7"; sed -i 's/^RN-1: regla uno\. \[bff\/a\.ts:1\]/RN-1: regla uno. (retirado 2026-10-01)/' "$W7/$SP"
WORKDIR="$W7" bash "$ROOT/scripts/verify-tl-specs.sh" >/dev/null 2>&1 || fail "verify-tl-specs exige cita a una regla retirada"

# 8. verify-auditor
AUD="migration/specs/_auditoria.md"
W8="$TMP/a1"; make_ws "$W8"; sed -i '0,/^| RN-1 | respaldada/{/^| RN-1 | respaldada/d}' "$W8/$AUD"
expect_fail auditor "$W8" "verify-auditor acepta que falte una regla en la tabla"
W8="$TMP/a2"; make_ws "$W8"; sed -i '0,/| RN-1 | respaldada/s/| RN-1 | respaldada/| RN-1 | probable/' "$W8/$AUD"
expect_fail auditor "$W8" "verify-auditor acepta un veredicto desconocido"
W8="$TMP/a3"; make_ws "$W8"; sed -i '/Corrección: /d' "$W8/$AUD"
expect_fail auditor "$W8" "verify-auditor acepta un hallazgo sin prompt del resolver"
W8="$TMP/a4"; make_ws "$W8"; sed -i '/^- \*\*AU-1\*\*/,+1d' "$W8/$AUD"
expect_fail auditor "$W8" "verify-auditor acepta una regla contradicha sin hallazgo"
W8="$TMP/a5"; make_ws "$W8"; sed -i 's/^| alfa | 3 | 2 | 0 | 1 |/| alfa | 3 | 3 | 0 | 0 |/' "$W8/$AUD"
expect_fail auditor "$W8" "verify-auditor acepta un resumen que no cuadra"
W8="$TMP/a6"; make_ws "$W8"; sed -i '/^## gamma$/,$d' "$W8/$AUD"
expect_fail auditor "$W8" "verify-auditor acepta que falte la sección de una capacidad"
W8="$TMP/a7"; make_ws "$W8"; rm "$W8/$AUD"
expect_fail auditor "$W8" "verify-auditor acepta que no exista _auditoria.md"

# 9. Comportamientos por defecto: un spec con endpoints debe cubrir los cuatro
con_endpoint() { sed -i 's/^## 5\. Contratos de API$/&\nPOST \/alfa: crea un alfa./' "$1/$SP"; }
por_defecto() { # <workspace> <frases separadas por |>
  local IFS='|' f
  for f in $2; do
    sed -i "s/^## 9\. Dependencias externas\$/CB-9$RANDOM: $f: se responde 404. [bff\/a.ts:2]\n&/" "$1/$SP"
  done
}
W9="$TMP/d1"; make_ws "$W9"; con_endpoint "$W9"
expect_fail tl-specs "$W9" "verify-tl-specs acepta un spec con endpoints sin comportamientos por defecto"
W9="$TMP/d2"; make_ws "$W9"; con_endpoint "$W9"; por_defecto "$W9" "Ruta no definida|Método no permitido|Cuerpo ausente"
expect_fail tl-specs "$W9" "verify-tl-specs acepta que falte uno de los cuatro comportamientos por defecto"
W9="$TMP/d3"; make_ws "$W9"; con_endpoint "$W9"; por_defecto "$W9" "Ruta no definida|Método no permitido|Cuerpo ausente|Cuerpo mal formado"
WORKDIR="$W9" bash "$ROOT/scripts/verify-tl-specs.sh" >/dev/null 2>&1 || fail "verify-tl-specs rechaza un spec con los cuatro comportamientos por defecto"
# Uno de los cuatro puede quedar como pregunta abierta si no se puede determinar
W9="$TMP/d4"; make_ws "$W9"; con_endpoint "$W9"; por_defecto "$W9" "Ruta no definida|Método no permitido|Cuerpo ausente"
sed -i 's/^- PA-1: ¿Qué responde el servicio de identidad.*/&\n- PA-2: Cuerpo mal formado: ¿qué responde el servicio cuando el cuerpo no es JSON válido?/' "$W9/$SP"
WORKDIR="$W9" bash "$ROOT/scripts/verify-tl-specs.sh" >/dev/null 2>&1 || fail "verify-tl-specs rechaza un comportamiento por defecto planteado como pregunta abierta"
# Mencionar un POST de otra capacidad no obliga a los casos de cuerpo: solo los endpoints declarados
W9="$TMP/d6"; make_ws "$W9"; sed -i 's/^## 5\. Contratos de API$/&\n### GET \/alfa\n- Salida: página con un formulario que se envía por POST a \/beta./' "$W9/$SP"; por_defecto "$W9" "Ruta no definida|Método no permitido"
WORKDIR="$W9" bash "$ROOT/scripts/verify-tl-specs.sh" >/dev/null 2>&1 || fail "verify-tl-specs exige los casos de cuerpo a un spec que solo declara un GET y menciona un POST ajeno"
# Un spec sin endpoints no está obligado
W9="$TMP/d5"; make_ws "$W9"
WORKDIR="$W9" bash "$ROOT/scripts/verify-tl-specs.sh" >/dev/null 2>&1 || fail "verify-tl-specs exige comportamientos por defecto a un spec sin endpoints"

# 10. Destino por repositorio
RD="migration/README.md"
mapa() { sed -i "s/^destino:.*/destino: $2/" "$1/$RD"; }
ok_ws() { # <verificador> <workspace> <mensaje>
  WORKDIR="$2" bash "$ROOT/scripts/verify-$1.sh" >/dev/null 2>&1 || fail "$3"
}
T2="migration/tasks/T-002-alfa.md"; A2="migration/adr/0002-dos.md"
W10="$TMP/r1"; make_ws "$W10"; mapa "$W10" "{bff: Kotlin, frontend: conservar}"
ok_ws tl-adrs "$W10" "verify-tl-adrs rechaza un mapa de destino completo"
ok_ws tl-tasks "$W10" "verify-tl-tasks rechaza un mapa de destino completo"
W10="$TMP/r2"; make_ws "$W10"; mapa "$W10" "{bff: Kotlin}"
expect_fail tl-adrs "$W10" "verify-tl-adrs acepta un mapa al que le falta un repositorio"
expect_fail tl-tasks "$W10" "verify-tl-tasks acepta un mapa al que le falta un repositorio"
W10="$TMP/r3"; make_ws "$W10"; mapa "$W10" "{bff: Kotlin, frontend: conservar, pagos: Kotlin}"
expect_fail tl-adrs "$W10" "verify-tl-adrs acepta un mapa con una clave que no es un repositorio"
W10="$TMP/r4"; make_ws "$W10"; mapa "$W10" "{bff: Kotlin, frontend: conservar}"; sed -i 's/^repos: \[bff\]/repos: [frontend]/' "$W10/$A2"
expect_fail tl-adrs "$W10" "verify-tl-adrs acepta un ADR propuesto sobre un repositorio conservado"
W10="$TMP/r5"; make_ws "$W10"; sed -i '/^repos:/d' "$W10/$A2"
expect_fail tl-adrs "$W10" "verify-tl-adrs acepta un ADR sin repos"
W10="$TMP/r6"; make_ws "$W10"; mapa "$W10" "{bff: Kotlin, frontend: conservar}"; sed -i 's/^repo_destino: bff/repo_destino: frontend/' "$W10/$T2"
expect_fail tl-tasks "$W10" "verify-tl-tasks acepta una tarea de implementación en un repositorio conservado"
sed -i 's/^tipo: implementacion/tipo: adaptacion/' "$W10/$T2"
ok_ws tl-tasks "$W10" "verify-tl-tasks rechaza una tarea de adaptación en un repositorio conservado"
W10="$TMP/r7"; make_ws "$W10"; sed -i '/^tipo:/d' "$W10/$T2"
expect_fail tl-tasks "$W10" "verify-tl-tasks acepta una tarea sin tipo"
# Con valor simple, una tarea en frontend es válida: todos los repositorios se migran
W10="$TMP/r8"; make_ws "$W10"; sed -i 's/^repo_destino: bff/repo_destino: frontend/' "$W10/$T2"
ok_ws tl-tasks "$W10" "verify-tl-tasks rechaza una tarea en frontend con destino único"

# 11. Versiones de artefactos
PLN="migration/test-plans/alfa.md"; A1="migration/adr/0001-uno.md"; BL="migration/backlog.md"
W11="$TMP/v1"; make_ws "$W11"; sed -i 's/^rev: 1$/rev: uno/' "$W11/$SP"
expect_fail tl-specs "$W11" "verify-tl-specs acepta un rev no numérico"
W11="$TMP/v2"; make_ws "$W11"; sed -i '/^rev:/d' "$W11/$SP"
expect_fail tl-specs "$W11" "verify-tl-specs acepta un spec sin rev"
W11="$TMP/v3"; make_ws "$W11"; sed -i 's/^rev: 1$/rev: 1.5/' "$W11/$A1"
expect_fail tl-adrs "$W11" "verify-tl-adrs acepta un rev no entero"
W11="$TMP/v4"; make_ws "$W11"; sed -i 's/^spec_rev: 1$/spec_rev: 2/' "$W11/$T2"
expect_fail tl-tasks "$W11" "verify-tl-tasks acepta un spec_rev mayor que el rev del spec"
W11="$TMP/v5"; make_ws "$W11"; sed -i 's/^adrs_rev: {0002: 1}/adrs_rev: {}/' "$W11/$T2"
expect_fail tl-tasks "$W11" "verify-tl-tasks acepta un ADR citado sin entrada en adrs_rev"
W11="$TMP/v6"; make_ws "$W11"; sed -i 's/^adrs_rev: {0002: 1}/adrs_rev: {0002: 5}/' "$W11/$T2"
expect_fail tl-tasks "$W11" "verify-tl-tasks acepta una entrada de adrs_rev mayor que el rev del ADR"
W11="$TMP/v7"; make_ws "$W11"; sed -i '/^rev:/d' "$W11/$T2"
expect_fail tl-tasks "$W11" "verify-tl-tasks acepta una tarea sin rev"
W11="$TMP/v8"; make_ws "$W11"; sed -i 's/^spec_rev: 1$/spec_rev:/' "$W11/$T2"
expect_fail tl-tasks "$W11" "verify-tl-tasks acepta una tarea de capacidad sin spec_rev"
W11="$TMP/v9"; make_ws "$W11"; sed -i 's/^spec_rev: 1$/spec_rev: 2/' "$W11/$PLN"
expect_fail qa "$W11" "verify-qa acepta un spec_rev mayor que el rev del spec"
# Un plan del orden anterior, con tareas: y líneas "- Tareas:", sigue siendo válido
W11="$TMP/v10"; make_ws "$W11"; sed -i 's/^spec_rev: 1$/spec_rev: 1\ntareas: [T-002, T-099]/; s/^- Cubre: RN-1$/- Cubre: RN-1\n- Tareas: T-002/' "$W11/$PLN"
ok_ws qa "$W11" "verify-qa rechaza un plan antiguo con tareas: y líneas Tareas"
W11="$TMP/v11"; make_ws "$W11"; sed -i '/^spec_rev:/d' "$W11/$PLN"
expect_fail qa "$W11" "verify-qa acepta un plan sin spec_rev"
W11="$TMP/v12"; make_ws "$W11"; sed -i 's/^| 2 | T-002 | 1 |/| 2 | T-002 | 2 |/' "$W11/$BL"
expect_fail pm "$W11" "verify-pm acepta un Rev del backlog distinto del rev de la tarea"
W11="$TMP/v13"; make_ws "$W11"; sed -i 's/^| 2 | T-002 | 1 |/| 2 | T-002 |/' "$W11/$BL"
expect_fail pm "$W11" "verify-pm acepta una fila del backlog sin Rev"
W11="$TMP/v14"; make_ws "$W11"; sed -i 's/ Spec rev: 1\././' "$W11/$AUD"
expect_fail auditor "$W11" "verify-auditor acepta una sección sin Spec rev"
W11="$TMP/v15"; make_ws "$W11"; sed -i 's/Spec rev: 1\./Spec rev: 3./' "$W11/$AUD"
expect_fail auditor "$W11" "verify-auditor acepta un Spec rev mayor que el rev del spec"
# Un derivado atrasado es válido: está desactualizado, no mal formado
W11="$TMP/v16"; make_ws "$W11"; sed -i 's/^rev: 1$/rev: 3/' "$W11/$SP"
for v in tl-specs tl-tasks qa auditor; do ok_ws "$v" "$W11" "verify-$v rechaza un derivado con una versión anterior de su insumo"; done

# 12. Cobertura consolidada: una fila por plan con su spec_rev
COB="migration/test-plans/_cobertura.md"
W12="$TMP/c1"; make_ws "$W12"; sed -i '/^| gamma |/d' "$W12/$COB"
expect_fail qa "$W12" "verify-qa acepta una cobertura sin la fila de un plan"
W12="$TMP/c2"; make_ws "$W12"; sed -i 's/^| alfa | 1 |/| alfa | 7 |/' "$W12/$COB"
expect_fail qa "$W12" "verify-qa acepta una cobertura con un Spec rev distinto del plan"

# 13. Comprobaciones propias del fixture: apagadas por defecto, las activa FIXTURE=1
W13="$TMP/f1"; make_ws "$W13"; sed -i 's/^estado: propuesto/estado: revisado/' "$W13/migration/adr/0002-dos.md"; sed -i 's/^bloqueada_por: \[0002\]/bloqueada_por: []/' "$W13/migration/tasks/T-002-alfa.md"; sed -i '/^| T-002 | 0002 |/d' "$W13/migration/backlog.md"
FIXTURE=0 WORKDIR="$W13" bash "$ROOT/scripts/verify-tl-adrs.sh" >/dev/null 2>&1 || fail "sin FIXTURE, verify-tl-adrs exige un ADR propuesto"
expect_fail tl-adrs "$W13" "con FIXTURE=1, verify-tl-adrs acepta que no haya ningún ADR propuesto"
W13="$TMP/f2"; make_ws "$W13"; for c in alfa beta gamma; do sed -i '/^MJ-1:/d; s/^CB-1: un producto oculto/CB-1: un producto retirado/' "$W13/migration/specs/$c.md"; echo "Ninguna" >> "$W13/migration/specs/$c.md"; done
FIXTURE=0 WORKDIR="$W13" bash "$ROOT/scripts/verify-tl-specs.sh" >/dev/null 2>&1 || fail "sin FIXTURE, verify-tl-specs exige el producto oculto del fixture"
W13="$TMP/f3"; make_ws "$W13"; sed -i '/^| beta |/d; /^| gamma |/d' "$W13/migration/specs/_capacidades.md"
FIXTURE=0 WORKDIR="$W13" bash "$ROOT/scripts/verify-analyst.sh" >/dev/null 2>&1 || fail "sin FIXTURE, verify-analyst exige tres capacidades"
expect_fail analyst "$W13" "con FIXTURE=1, verify-analyst acepta menos de tres capacidades"

# 14. verify-pm compara el backlog y las tareas con el cálculo de backlog.sh
W14="$TMP/b1"; make_ws "$W14"; sed -i 's/^prioridad: 2$/prioridad: 7/' "$W14/migration/tasks/T-002-alfa.md"
expect_fail pm "$W14" "verify-pm acepta una prioridad distinta de la que calcula backlog.sh"
W14="$TMP/b2"; make_ws "$W14"; sed -i 's/^fase: 1$/fase: 3/' "$W14/migration/tasks/T-002-alfa.md"
expect_fail pm "$W14" "verify-pm acepta una fase distinta de la que calcula backlog.sh"
W14="$TMP/b3"; make_ws "$W14"; sed -i 's/^| 2 | T-002 | 1 |/| 9 | T-002 | 1 |/' "$W14/migration/backlog.md"
expect_fail pm "$W14" "verify-pm acepta una fila del backlog con un Orden distinto de la prioridad"
W14="$TMP/b4"; make_ws "$W14"; sed -i 's/^depende_de: \[T-001\]/depende_de: [T-002]/' "$W14/migration/tasks/T-002-alfa.md"
expect_fail pm "$W14" "verify-pm acepta un backlog sobre tareas con un ciclo"

# 15. verificar.sh: punto de entrada para quien usa el flujo
. "$ROOT/scripts/lib-dist.sh"
W15="$TMP/u1"; make_ws "$W15"
out="$(bash "$ROOT/scripts/verificar.sh" "$W15" 2>&1)" || fail "verificar.sh falla sobre un workspace válido: $(printf '%s' "$out" | grep -m3 'FALLA\|-' | tr '\n' ' ')"
for k in 'OK     ADRs' 'OK     specs' 'OK     planes de prueba' 'OK     tareas' 'OK     auditoría' 'OK     backlog' 'Resumen:'; do
  printf '%s' "$out" | grep -qF -- "$k" || fail "verificar.sh: la salida no contiene '$k'"
done
sed -i '/^rev:/d' "$W15/migration/specs/alfa.md"
out="$(bash "$ROOT/scripts/verificar.sh" "$W15" 2>&1)" && fail "verificar.sh acepta un spec sin rev"
printf '%s' "$out" | grep -q 'FALLA  specs' || fail "verificar.sh no marca los specs como fallidos"
printf '%s' "$out" | grep -q 'alfa' || fail "verificar.sh no dice qué archivo falla"
printf '%s' "$out" | grep -q 'OK     ADRs' || fail "verificar.sh deja de informar del resto cuando un tipo falla"
bash "$ROOT/scripts/verificar.sh" "$TMP/no-existe" >/dev/null 2>&1 && fail "verificar.sh acepta una carpeta que no existe"
# Fuera del repo: los scripts copiados a otra carpeta funcionan solos
PROY="$TMP/proyecto de usuario"; make_ws "$PROY"; copiar_scripts "$ROOT/scripts" "$PROY" || fail "copiar_scripts falló"
for s in "${DIST_SCRIPTS[@]}"; do [ -f "$PROY/.claude/migration/$s" ] || fail "no se instaló $s"; done
grep -l '\.work/\|\$ROOT' "$PROY"/.claude/migration/*.sh 2>/dev/null | grep -q . && fail "algún script instalado depende de la raíz del repo: $(grep -l '\.work/\|\$ROOT' "$PROY"/.claude/migration/*.sh | xargs -n1 basename | paste -sd' ' -)"
[ -f "$PROY/.claude/migration/verify-hechos.sh" ] && fail "se entregó verify-hechos.sh, que es solo para las pruebas de este repo"
out="$(cd "$PROY" && env -u WORKDIR -u FIXTURE bash .claude/migration/verificar.sh 2>&1)" || fail "verificar.sh instalado en un proyecto falla: $(printf '%s' "$out" | grep -m3 -- '- ' | tr '\n' ' ')"
(cd "$PROY" && env -u WORKDIR bash .claude/migration/backlog.sh validar >/dev/null 2>&1) || fail "backlog.sh instalado en un proyecto falla"

# 16. Hechos y trampas: un spec que cumple, uno al que le falta un hecho y uno que cae en una trampa
W16="$TMP/h1"; make_ws "$W16"
out="$(WORKDIR="$W16" bash "$ROOT/scripts/verify-hechos.sh" 2>&1)" || fail "verify-hechos falla sobre specs que cumplen: $(printf '%s' "$out" | head -n2 | tr '\n' ' ')"
printf '%s' "$out" | grep -q 'hechos 1/1, trampas evitadas 1/1, mejoras 1/1, no-preguntas 1/1' || fail "verify-hechos no resume lo comprobado: $(printf '%s' "$out" | grep '^---')"
W16="$TMP/h2"; make_ws "$W16"; for c in alfa beta gamma; do sed -i 's/^CB-1: un producto oculto responde 200 sin cuerpo/CB-1: un producto oculto responde 404/' "$W16/migration/specs/$c.md"; done
out="$(WORKDIR="$W16" bash "$ROOT/scripts/verify-hechos.sh" 2>&1)" && fail "verify-hechos acepta specs a los que les falta un hecho"
printf '%s' "$out" | grep -q '^FAIL: hecho S1 ' || fail "verify-hechos no nombra el hecho que falta"
expect_fail tl-specs "$W16" "verify-tl-specs con FIXTURE=1 acepta specs a los que les falta un hecho"
FIXTURE=0 WORKDIR="$W16" bash "$ROOT/scripts/verify-tl-specs.sh" >/dev/null 2>&1 || fail "sin FIXTURE, verify-tl-specs comprueba los hechos del fixture"
W16="$TMP/h3"; make_ws "$W16"; sed -i 's/^## 9\. Dependencias externas$/CB-2: un cupón caducado responde 410 con el código COUPON_EXPIRED. [bff\/a.ts:2]\n&/' "$W16/migration/specs/beta.md"
out="$(WORKDIR="$W16" bash "$ROOT/scripts/verify-hechos.sh" 2>&1)" && fail "verify-hechos acepta un spec que cae en una trampa"
printf '%s' "$out" | grep '^FAIL: trampa S4 ' | grep -q 'beta' || fail "verify-hechos no dice qué spec afirma lo falso"
# La trampa como pregunta abierta o como mejora es correcta
W16="$TMP/h4"; make_ws "$W16"; sed -i 's/^- PA-1: ¿Qué responde el servicio de identidad.*/&\n- PA-2: ¿Existe un código 410 para un cupón caducado?/' "$W16/migration/specs/beta.md"
WORKDIR="$W16" bash "$ROOT/scripts/verify-hechos.sh" >/dev/null 2>&1 || fail "verify-hechos rechaza una trampa planteada como pregunta abierta"
# Una regla retirada no cuenta ni como hecho ni como trampa
W16="$TMP/h5"; make_ws "$W16"; sed -i 's/^## 9\. Dependencias externas$/CB-2: un cupón caducado responde 410. (retirado 2026-10-05) [bff\/a.ts:2]\n&/' "$W16/migration/specs/beta.md"
WORKDIR="$W16" bash "$ROOT/scripts/verify-hechos.sh" >/dev/null 2>&1 || fail "verify-hechos cuenta una regla retirada como trampa"
# Patrón negado: una regla que dice la verdad sobre la trampa no la dispara
W16="$TMP/h6"; make_ws "$W16"; sed -i 's/^## 9\. Dependencias externas$/CB-2: el cupón no tiene código propio: nunca se responde 410. [bff\/a.ts:2]\n&/' "$W16/migration/specs/beta.md"
printf 'trampa | N1 | . | cup.*n && \\b410\\b && !nunca | con negación\n' > "$TMP/hechos-neg.txt"
WORKDIR="$W16" bash "$ROOT/scripts/verify-hechos.sh" "$TMP/hechos-neg.txt" >/dev/null 2>&1 || fail "verify-hechos dispara una trampa con una regla que cumple el patrón negado"
WORKDIR="$TMP/h3" bash "$ROOT/scripts/verify-hechos.sh" "$TMP/hechos-neg.txt" >/dev/null 2>&1 && fail "verify-hechos con patrón negado deja pasar una regla que afirma lo falso"
# Fallo conocido: se informa y no hace fallar
out="$(CONOCIDOS="S4" WORKDIR="$TMP/h3" bash "$ROOT/scripts/verify-hechos.sh" 2>&1)" || fail "CONOCIDOS no evita el fallo de un id declarado como conocido"
printf '%s' "$out" | grep -q '^CONOCIDO: trampa S4 ' || fail "un fallo conocido no se informa"
# Los hechos del fixture real están bien formados
bad="$(grep -v '^[[:space:]]*\(#\|$\)' "$ROOT"/fixtures/hechos/*.txt | awk -F' \\| ' 'NF < 5 || $1 !~ /(^|:)(hecho|trampa|mejora|no-pregunta|indice|no-indice)$/' | head -n3)"
[ -z "$bad" ] || fail "línea mal formada en fixtures/hechos: $bad"

# 17. Sin código del lenguaje origen: JavaScript, Python y familia de Java; la prosa pasa
codigo() { sed -i "s|^## 4\\. Flujos de comportamiento\$|&\\n$1|" "$2/$SP"; }
n=0
while IFS= read -r muestra; do
  n=$((n+1)); W17="$TMP/cod$n"; make_ws "$W17"
  MUESTRA="$muestra" awk '{print} /^## 4\. Flujos de comportamiento$/ {print ENVIRON["MUESTRA"]}' "$W17/$SP" > "$W17/$SP.tmp" && mv "$W17/$SP.tmp" "$W17/$SP"
  expect_fail tl-specs "$W17" "verify-tl-specs no reconoce como código: $muestra"
done <<'EOF'
const tope = 10;
import express from "express";
def crear_reserva(sala_id, inicio, fin):
    return jsonify(error="solapada"), 409
from flask import Flask, request
class Reserva(db.Model):
@app.route("/salas", methods=["GET"])
    if reserva.estado == "pendiente":
public class ReservaService {
private final int MAX_HORAS = 4;
    public Reserva crear(Sala sala) {
fun crear(sala: Sala): Reserva {
val tope = 10
package com.acme.reservas;
    if (horas > MAX_HORAS) {
EOF
n=0
while IFS= read -r muestra; do
  n=$((n+1)); W17="$TMP/pro$n"; make_ws "$W17"
  MUESTRA="$muestra" awk '{print} /^## 4\. Flujos de comportamiento$/ {print ENVIRON["MUESTRA"]}' "$W17/$SP" > "$W17/$SP.tmp" && mv "$W17/$SP.tmp" "$W17/$SP"
  ok_ws tl-specs "$W17" "verify-tl-specs toma por código una frase normal: $muestra"
done <<'EOF'
Importa que la sala esté libre en todo el intervalo.
La clase de sala determina el aforo máximo.
1. El usuario elige la sala y el intervalo; si la sala está libre:
El valor de retorno del proceso es el número de reservas caducadas.
- privado: solo quien creó la reserva puede cancelarla.
Para cada reserva pendiente con más de 30 minutos, el proceso la marca como caducada.
El campo `class` del formulario no se envía; `def` tampoco.
Si la consulta no devuelve filas, responde 404.
Variable de entorno `MAX_HORAS`: valor por defecto 4.
- from: fecha de inicio (texto, opcional).
EOF

# 18. Preguntas abiertas con id propio
T2="migration/tasks/T-002-alfa.md"
tres_preguntas() { # <ws>: alfa con PA-1, PA-2 y PA-3, y T-002 bloqueada por la tercera
  sed -i 's/^- PA-1: ¿Qué responde el servicio de identidad.*/- PA-1: ¿Uno?\n- PA-2: ¿Dos?\n- PA-3: ¿Tres?/' "$1/$SP"
  sed -i 's/^- \*\*Pendiente PA-1\*\*: .*/- **Pendiente PA-1**: ¿Uno?\n- **Pendiente PA-2**: ¿Dos?\n- **Pendiente PA-3**: ¿Tres?/' "$1/migration/test-plans/alfa.md"
  sed -i 's/^bloqueada_por: \[0002\]/bloqueada_por: [0002, PA:alfa:3]/' "$1/$T2"
  sed -i 's/^| T-002 | 0002 | aceptar |/&\n| T-002 | PA:alfa:3 | responder |/' "$1/migration/backlog.md"
}
cita() { bash "$ROOT/scripts/backlog.sh" calcular "$1" 2>/dev/null | grep 'PA:alfa:3'; }
W18="$TMP/q0"; make_ws "$W18"; tres_preguntas "$W18"
for v in tl-specs tl-tasks qa; do ok_ws "$v" "$W18" "verify-$v rechaza un spec con tres preguntas numeradas"; done
cita "$W18" | grep -q '¿Tres?' || fail "backlog.sh no cita el texto de PA-3: $(cita "$W18")"
# 18.1 Borrar a mano la línea de PA-2: la referencia a PA-3 no cambia de pregunta
W18="$TMP/q1"; make_ws "$W18"; tres_preguntas "$W18"; sed -i '/^- PA-2: /d' "$W18/$SP"
ok_ws tl-tasks "$W18" "verify-tl-tasks rechaza PA:alfa:3 tras borrar la línea de PA-2"
cita "$W18" | grep -q '¿Tres?' || fail "tras borrar PA-2, backlog.sh ya no cita el texto de PA-3: $(cita "$W18")"
# 18.2 Insertar una pregunta nueva al principio
W18="$TMP/q2"; make_ws "$W18"; tres_preguntas "$W18"; sed -i 's/^- PA-1: ¿Uno?/- PA-4: ¿Cuatro, añadida arriba?\n&/' "$W18/$SP"
ok_ws tl-tasks "$W18" "verify-tl-tasks rechaza PA:alfa:3 tras insertar una pregunta al principio"
cita "$W18" | grep -q '¿Tres?' || fail "tras insertar una pregunta al principio, backlog.sh cita otra: $(cita "$W18")"
# 18.3 Referencia a un id que no existe
W18="$TMP/q3"; make_ws "$W18"; tres_preguntas "$W18"; sed -i 's/PA:alfa:3/PA:alfa:9/' "$W18/$T2"
out="$(WORKDIR="$W18" bash "$ROOT/scripts/verify-tl-tasks.sh" 2>&1)" && fail "verify-tl-tasks acepta una referencia a una pregunta que no existe"
printf '%s' "$out" | grep -q 'PA:alfa:9' || fail "verify-tl-tasks no nombra la referencia rota"
# Con ids, borrar la pregunta citada rompe la referencia y se detecta (antes pasaba a apuntar a otra)
W18="$TMP/q3b"; make_ws "$W18"; tres_preguntas "$W18"; sed -i '/^- PA-3: /d' "$W18/$SP"
expect_fail tl-tasks "$W18" "verify-tl-tasks acepta una referencia a una pregunta borrada"
# 18.4 Ids duplicados y formatos mezclados
W18="$TMP/q4"; make_ws "$W18"; tres_preguntas "$W18"; sed -i 's/^- PA-3: ¿Tres?/- PA-2: ¿Tres?/' "$W18/$SP"
out="$(WORKDIR="$W18" bash "$ROOT/scripts/verify-tl-specs.sh" 2>&1)" && fail "verify-tl-specs acepta ids de pregunta repetidos"
printf '%s' "$out" | grep -q 'PA-2' || fail "verify-tl-specs no nombra el id repetido"
W18="$TMP/q5"; make_ws "$W18"; tres_preguntas "$W18"; sed -i 's/^- PA-2: ¿Dos?/- ¿Dos, sin id?/' "$W18/$SP"
expect_fail tl-specs "$W18" "verify-tl-specs acepta una sección 12 con formatos mezclados"
# 18.5 Formato anterior, sin ids: se acepta y se resuelve por el lugar en la lista
W18="$TMP/q6"; make_ws "$W18"; tres_preguntas "$W18"; sed -i -E 's/^- PA-[0-9]+: /- /' "$W18/$SP"; sed -i -E 's/\*\*Pendiente PA-([0-9]+)\*\*/**Pendiente \1**/' "$W18/migration/test-plans/alfa.md"
for v in tl-specs tl-tasks qa; do ok_ws "$v" "$W18" "verify-$v rechaza un spec del formato anterior, sin ids de pregunta"; done
cita "$W18" | grep -q '¿Tres?' || fail "backlog.sh no resuelve por lugar un spec del formato anterior: $(cita "$W18")"
# Un plan con el formato anterior de pendientes sigue valiendo tras numerar su spec
W18="$TMP/q7"; make_ws "$W18"; tres_preguntas "$W18"; sed -i -E 's/\*\*Pendiente PA-([0-9]+)\*\*/**Pendiente \1**/' "$W18/migration/test-plans/alfa.md"
ok_ws qa "$W18" "verify-qa rechaza 'Pendiente 3' cuando el spec ya tiene PA-3"
# Una pregunta respondida o retirada no pide caso pendiente; una abierta sin pendiente sí
W18="$TMP/q8"; make_ws "$W18"; tres_preguntas "$W18"; sed -i 's/^- PA-2: ¿Dos?/&\n  - Respuesta (2026-10-05): sí./; s/^- PA-3: ¿Tres?/& (retirado 2026-10-05: movida a MJ-2)/' "$W18/$SP"; sed -i '/Pendiente PA-2/d; /Pendiente PA-3/d' "$W18/migration/test-plans/alfa.md"
ok_ws qa "$W18" "verify-qa exige caso pendiente a una pregunta respondida o retirada"
sed -i '/Pendiente PA-1/d' "$W18/migration/test-plans/alfa.md"
expect_fail qa "$W18" "verify-qa acepta una pregunta abierta sin caso pendiente"

[ "$fails" -eq 0 ] && { echo "OK: verificadores"; exit 0; }
exit 1
