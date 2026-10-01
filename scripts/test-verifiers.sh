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
    local tareas="[]"; [ "$c" = alfa ] && tareas="[T-002]"
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
- ¿Qué responde el servicio de identidad si la cuenta está bloqueada?
## 13. Posibles mejoras
MJ-1: responder 404 para un producto oculto. Comportamiento actual: CB-1.
EOF
    cat > "$W/migration/test-plans/$c.md" <<EOF
---
capacidad: $c
spec: $c
spec_rev: 1
tareas: $tareas
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
sed -i 's/^- ¿Qué responde el servicio de identidad.*/&\n- Cuerpo mal formado: ¿qué responde el servicio cuando el cuerpo no es JSON válido?/' "$W9/$SP"
WORKDIR="$W9" bash "$ROOT/scripts/verify-tl-specs.sh" >/dev/null 2>&1 || fail "verify-tl-specs rechaza un comportamiento por defecto planteado como pregunta abierta"
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
W11="$TMP/v10"; make_ws "$W11"; sed -i 's/^tareas: \[T-002\]/tareas: [T-099]/' "$W11/$PLN"
expect_fail qa "$W11" "verify-qa acepta en tareas un id que no existe"
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

[ "$fails" -eq 0 ] && { echo "OK: verificadores"; exit 0; }
exit 1
