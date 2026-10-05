#!/usr/bin/env bash
# Comprueba los specs generados contra los hechos y las trampas de un fixture.
# Es una comprobación de fidelidad propia de las pruebas de este repo: no se
# entrega a quien usa el flujo.
#
# Uso: verify-hechos.sh [archivo de hechos]
#   Carpeta: WORKDIR o, por defecto, la actual.
#   Archivo de hechos: el argumento, o HECHOS, o
#   fixtures/hechos/${FIXTURE_NAME:-sample-workspace}.txt de este repo.
#
# Formato del archivo y tipos de línea: ver fixtures/hechos/sample-workspace.txt.
# Aquí se tratan hecho, trampa, mejora y no-pregunta; indice y no-indice los
# trata verify-indexer.sh.
# CONOCIDOS: ids separados por espacio que, si fallan, se listan como fallo
# conocido y no cuentan para el código de salida.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
W="${WORKDIR:-$PWD}"
M="$W/migration"
H="${1:-${HECHOS:-$HERE/../fixtures/hechos/${FIXTURE_NAME:-sample-workspace}.txt}}"
[ -f "$H" ] || { echo "FAIL: no existe el archivo de hechos $H"; exit 1; }
specs=()
for f in "$M"/specs/[!_]*.md; do [ -f "$f" ] && specs+=("$f"); done
[ "${#specs[@]}" -gt 0 ] || { echo "FAIL: no hay specs que comprobar en $M/specs"; exit 1; }

gawk -v IGNORECASE=1 -v hechos="$H" -v conocidos="${CONOCIDOS:-}" '
function trim(s) { gsub(/^[ \t\r]+|[ \t\r]+$/, "", s); return s }
# ¿Cumple la línea todos los patrones (separados por " && ")?
function cumple(linea, patrones,   n, i, p) {
  gsub(/\\b/, "\\y", patrones)   # \b de las expresiones habituales es \y en gawk
  n = split(patrones, p, / +&& +/)
  for (i = 1; i <= n; i++) if (trim(p[i]) != "" && linea !~ trim(p[i])) return 0
  return 1
}
# Primera línea de la clase dada (R reglas, M mejoras, P preguntas), en specs cuya
# capacidad casa con la expresión, que cumple los patrones. "" si ninguna.
function busca(clase, capre, patrones,   i) {
  for (i = 1; i <= nl; i++) if (lclase[i] == clase && lslug[i] ~ capre && cumple(ltexto[i], patrones)) return lslug[i] ": " substr(ltexto[i], 1, 110)
  return ""
}
BEGINFILE { slug = FILENAME; sub(/.*[\/\\]/, "", slug); sub(/\.md$/, "", slug); sec = 0; slugs[slug] = 1 }
{ sub(/\r$/, "") }
/^## [0-9]+\. / { sec = $2 + 0; next }
/^(- )?(RN|CB)-[0-9]+:/ { if ($0 !~ /\(retirado/) { nl++; lclase[nl] = "R"; lslug[nl] = slug; t = $0; sub(/\[[^][]*\][ \t]*$/, "", t); ltexto[nl] = t }; next }
sec == 13 && /^(- )?MJ-[0-9]+:/ { nl++; lclase[nl] = "M"; lslug[nl] = slug; ltexto[nl] = $0; next }
sec == 12 && /^- / { if ($0 !~ /\(retirado/) { nl++; lclase[nl] = "P"; lslug[nl] = slug; ltexto[nl] = $0 }; next }
END {
  IGNORECASE = 0; nc = split(conocidos, ck, " "); for (i = 1; i <= nc; i++) esconocido[ck[i]] = 1; IGNORECASE = 1
  while ((getline l < hechos) > 0) {
    sub(/\r$/, "", l); if (l ~ /^[ \t]*(#|$)/) continue
    n = split(l, c, / \| /); if (n < 4) { print "FAIL: línea mal formada en el archivo de hechos: " l; malos++; continue }
    tipo = trim(c[1]); id = trim(c[2]); capre = trim(c[3]); pat = trim(c[4]); desc = trim(c[5])
    if (tipo == "indice" || tipo == "no-indice") continue
    total[tipo]++
    hay = 0; for (s in slugs) if (s ~ capre) hay = 1
    msg = ""
    if (tipo == "hecho") { if (!hay) msg = "ningún spec corresponde a la capacidad /" capre "/"; else if (busca("R", capre, pat) == "") msg = "ninguna RN/CB lo recoge" }
    else if (tipo == "mejora") { if (busca("M", capre, pat) == "") msg = "ninguna mejora MJ-n lo recoge" }
    else if (tipo == "trampa") { r = busca("R", capre, pat); if (r != "") msg = "una regla afirma lo falso: " r }
    else if (tipo == "no-pregunta") { r = busca("P", capre, pat); if (r != "") msg = "aparece como pregunta abierta: " r }
    else { print "FAIL: tipo desconocido \"" tipo "\" en el archivo de hechos"; malos++; continue }
    if (msg == "") { okn[tipo]++; continue }
    if (id in esconocido) { print "CONOCIDO: " tipo " " id " (" desc "): " msg; conoc++ }
    else { print "FAIL: " tipo " " id " (" desc "): " msg; malos++ }
  }
  close(hechos)
  printf "--- hechos %d/%d, trampas evitadas %d/%d, mejoras %d/%d, no-preguntas %d/%d%s\n", okn["hecho"], total["hecho"], okn["trampa"], total["trampa"], okn["mejora"], total["mejora"], okn["no-pregunta"], total["no-pregunta"], (conoc ? ", fallos conocidos " conoc : "")
  if (malos > 0) exit 1
  print "OK: hechos"
}' "${specs[@]}"
