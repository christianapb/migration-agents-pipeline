#!/usr/bin/env bash
# Prueba del auditor con errores plantados.
#  1. Sobre los specs sin alterar, no debe reportar contradicciones.
#  2. Se plantan tres errores en el spec de carrito: un valor cambiado en una
#     regla verdadera, una regla inventada con una cita plausible y una regla
#     cuya cita apunta a un archivo que no existe.
#  3. El auditor, con alcance sobre esa capacidad, debe marcar cada una en su
#     categoría, no marcar como contradichas las reglas no tocadas, no modificar
#     ningún spec y conservar las secciones de las demás capacidades.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="${WORKDIR:-$ROOT/.work/sample-workspace}"
export WORKDIR="$W"
M="$W/migration"
A="$M/specs/_auditoria.md"
fails=0
fail() { echo "FAIL: $*"; fails=$((fails+1)); }
run() { bash "$ROOT/scripts/run-agent.sh" "$@"; rc=$?; [ $rc -eq 2 ] && { echo "ERROR: límite de uso, repetir"; exit 2; }; return $rc; }
seccion() { awk -v h="## $1" '$0==h {f=1; next} /^## /{f=0} f' "$A"; }
veredicto() { seccion "$1" | grep -E "^\| $2 \|" | head -n1 | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}'; }
hash_specs() { find "$M/specs" -type f ! -name '_auditoria.md' -print0 | sort -z | xargs -0 md5sum | md5sum; }

bash "$ROOT/scripts/snapshot.sh" restore tl-specs "$W" >/dev/null || { echo "FAIL: no se pudo restaurar la etapa tl-specs"; exit 1; }
bash "$ROOT/scripts/verify-tl-specs.sh" >/dev/null || fail "los specs de partida no pasan verify-tl-specs (citas)"

# --- 1. Specs sin alterar: sin contradicciones falsas
h0="$(hash_specs)"
run migration-auditor >/dev/null
bash "$ROOT/scripts/verify-auditor.sh" || fail "la auditoría sin alterar no pasa verify-auditor"
[ "$(hash_specs)" = "$h0" ] || fail "el auditor modificó specs en la auditoría completa"
falsas="$(grep -E '^\| (RN|CB)-[0-9]+ \| contradicha \|' "$A" 2>/dev/null || true)"
if [ -n "$falsas" ]; then
  fail "contradicciones sobre specs sin alterar (investigar si el error es del auditor o del spec):"
  printf '%s\n' "$falsas" | sed 's/^/        /'
fi
echo "--- resumen de la auditoría sin alterar"
awk '/^## Resumen/{f=1;next} /^## /{f=0} f' "$A" | grep '^|'
negativas="$(grep -E '^\| (RN|CB)-[0-9]+ \| (sin respaldo|cita no localizable) \|' "$A" 2>/dev/null || true)"
if [ -n "$negativas" ]; then
  fail "reglas sin respaldo o no localizables sobre specs sin alterar (investigar antes de tocar nada):"
  printf '%s\n' "$negativas" | sed 's/^/        /'
fi
cp "$A" "$A.sin-alterar"

# --- 2. Plantar tres errores en el spec de carrito
C="$(ls "$M"/specs | grep -v '^_' | grep -i 'carr' | head -n1 | sed 's/\.md$//')"
[ -n "$C" ] || { echo "FAIL: no hay spec de carrito"; exit 1; }
SP="$M/specs/$C.md"
OTRA="$(ls "$M"/specs | grep -v '^_' | grep -v "^$C.md$" | head -n1 | sed 's/\.md$//')"

# a) valor cambiado: el tope de cantidad, de 10 a 20
ln="$(grep -nE '^RN-[0-9]+:' "$SP" | grep -Ei 'supera 10|nunca supera|tope' | grep '10' | head -n1 | cut -d: -f1)"
[ -n "$ln" ] || { echo "FAIL: no se encontró la regla del tope de 10 en $C"; exit 1; }
linea="$(sed -n "${ln}p" "$SP")"
TOPE="$(printf '%s' "$linea" | grep -oE '^RN-[0-9]+')"
texto="${linea%[*}"; cita="[${linea##*[}"
NUEVA="${texto//10/20}$cita" awk -v n="$ln" 'NR==n {print ENVIRON["NUEVA"]; next} {print}' "$SP" > "$SP.tmp" && mv "$SP.tmp" "$SP"

# b) regla inventada con una cita plausible (la misma línea real que la del tope)
maxrn="$(grep -oE '^RN-[0-9]+' "$SP" | grep -oE '[0-9]+' | sort -n | tail -n1)"
INV="RN-$((maxrn+1))"
lnrn="$(grep -nE '^RN-[0-9]+:' "$SP" | tail -n1 | cut -d: -f1)"
EXTRA="$INV: a partir del quinto producto distinto en el carrito se aplica un descuento del 15 % sobre el total. $cita" \
  awk -v n="$lnrn" '{print} NR==n {print ENVIRON["EXTRA"]}' "$SP" > "$SP.tmp" && mv "$SP.tmp" "$SP"

# c) cita a un archivo que no existe
maxcb="$(grep -oE '^CB-[0-9]+' "$SP" | grep -oE '[0-9]+' | sort -n | tail -n1)"
NOLOC="CB-$((maxcb+1))"
lncb="$(grep -nE '^CB-[0-9]+:' "$SP" | tail -n1 | cut -d: -f1)"
EXTRA="$NOLOC: un cupón caducado responde 410 con el código COUPON_EXPIRED. [bff/src/routes/cupones.ts:12]" \
  awk -v n="$lncb" '{print} NR==n {print ENVIRON["EXTRA"]}' "$SP" > "$SP.tmp" && mv "$SP.tmp" "$SP"
echo "--- plantados en $C: $TOPE (valor), $INV (inventada), $NOLOC (cita inexistente)"

# --- 3. Auditoría con alcance
h1="$(hash_specs)"
otra_antes="$(seccion "$OTRA" | md5sum)"
run migration-auditor "Solo la capacidad $C." >/dev/null
[ "$(hash_specs)" = "$h1" ] || fail "el auditor modificó specs"
[ "$(seccion "$OTRA" | md5sum)" = "$otra_antes" ] || fail "la auditoría con alcance no conservó la sección de $OTRA"
bash "$ROOT/scripts/verify-auditor.sh" || fail "la auditoría con errores plantados no pasa verify-auditor"

v="$(veredicto "$C" "$TOPE")";  [ "$v" = "contradicha" ] || fail "$TOPE (tope cambiado a 20) quedó como '$v', se esperaba contradicha"
v="$(veredicto "$C" "$INV")";   case "$v" in "sin respaldo"|"contradicha") ;; *) fail "$INV (regla inventada) quedó como '$v', se esperaba sin respaldo";; esac
v="$(veredicto "$C" "$NOLOC")"; [ "$v" = "cita no localizable" ] || fail "$NOLOC (archivo inexistente) quedó como '$v', se esperaba cita no localizable"

otras="$(seccion "$C" | grep -E '^\| (RN|CB)-[0-9]+ \| contradicha \|' | grep -Ev "^\| ($TOPE|$INV) \|" || true)"
[ -z "$otras" ] || { fail "reglas no tocadas marcadas como contradichas:"; printf '%s\n' "$otras" | sed 's/^/        /'; }

hall="$(seccion "$C" | awk '/^### Hallazgos/{f=1;next} /^### /{f=0} f' | grep -E '^- \*\*AU-[0-9]+\*\*')"
for id in "$TOPE" "$INV" "$NOLOC"; do
  printf '%s\n' "$hall" | grep -Eq "\b$id\b" || fail "ningún hallazgo AU-n nombra $id"
done

echo "--- veredictos en $C tras plantar"
seccion "$C" | grep -E '^\| (RN|CB)-[0-9]+ \|' | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}' | sort | uniq -c

[ "$fails" -eq 0 ] && { echo "OK: auditor (errores plantados)"; exit 0; }
exit 1
