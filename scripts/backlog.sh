#!/usr/bin/env bash
# Calcula el backlog de la migración a partir de las tareas: valida el grafo de
# dependencias, asigna fases y prioridades con reglas fijas y, si se pide, las
# escribe en las tareas. Con la misma entrada da siempre la misma salida.
#
# Uso: backlog.sh <validar|calcular|aplicar> [--tsv] [carpeta]
#   validar   comprueba referencias y ciclos; código distinto de cero si hay problemas
#   calcular  imprime las tablas de fases, los bloqueos y los datos, sin tocar nada
#             (--tsv: solo "id<TAB>fase<TAB>prioridad")
#   aplicar   escribe fase y prioridad en las tareas; no cambia rev ni nada más
# La carpeta es la del proyecto (la que contiene migration/); por defecto, la actual.
#
# Las reglas están en docs/specs/2026-10-05-backlog-por-script-design.md, sección 3.
# Requiere bash 4 y gawk. BACKLOG_LISTA (solo para pruebas): archivo con la lista
# de tareas, una ruta por línea, en lugar de migration/tasks/T-*.md.
set -uo pipefail

modo="${1:-}"; shift || true
tsv=0; dir=""
for a in "$@"; do
  case "$a" in --tsv) tsv=1 ;; *) dir="$a" ;; esac
done
case "$modo" in validar|calcular|aplicar) ;; *) echo "uso: backlog.sh <validar|calcular|aplicar> [--tsv] [carpeta]" >&2; exit 2 ;; esac
W="${dir:-$PWD}"
M="$W/migration"
[ -d "$M/tasks" ] || { echo "No hay tareas: no existe $M/tasks"; exit 2; }
command -v gawk >/dev/null 2>&1 || { echo "backlog.sh necesita gawk"; exit 2; }

{
  if [ -n "${BACKLOG_LISTA:-}" ]; then
    cat "$BACKLOG_LISTA"
  else
    for f in "$M"/tasks/T-*.md; do [ -f "$f" ] && printf 'T\t%s\n' "$f"; done
  fi | sed 's/^\([^T]\|T[^\t]\)/T\t&/'
  for f in "$M"/adr/*.md; do [ -f "$f" ] && printf 'A\t%s\n' "$f"; done
  [ -f "$M/specs/_capacidades.md" ] && printf 'C\t%s\n' "$M/specs/_capacidades.md"
} | gawk -v BINMODE=3 -v modo="$modo" -v tsv="$tsv" -v M="$M" '
function trim(s) { gsub(/^[ \t\r]+|[ \t\r]+$/, "", s); return s }
function num(id,   m) { return match(id, /[0-9]+/) ? substr(id, RSTART, RLENGTH) + 0 : 0 }
# Orden de ids: por número y, a igualdad, como texto
function menor(a, b) { if (num(a) != num(b)) return num(a) < num(b); return a < b }
function ordenar(arr, n,   i, j, t) {
  for (i = 2; i <= n; i++) { t = arr[i]; for (j = i - 1; j >= 1 && menor(t, arr[j]); j--) arr[j + 1] = arr[j]; arr[j + 1] = t }
}
function lista(s, out,   n, i, k, parts) {
  gsub(/[\[\]"\x27]/, "", s); n = split(s, parts, ","); k = 0
  for (i = 1; i <= n; i++) { parts[i] = trim(parts[i]); if (parts[i] != "") out[++k] = parts[i] }
  return k
}
function existe(f,   l, r) { r = (getline l < f); close(f); return r >= 0 }
# Lee el frontmatter de un archivo en fm[campo]
function leer_fm(f, fm,   l, n, p) {
  delete fm; n = 0
  while ((getline l < f) > 0) {
    sub(/\r$/, "", l); n++
    if (n == 1) { if (l != "---") break; continue }
    if (l == "---") break
    p = index(l, ":"); if (p > 1) fm[substr(l, 1, p - 1)] = trim(substr(l, p + 1))
  }
  close(f)
}
function puntos(t) { return t == "S" ? 1 : (t == "L" ? 4 : 2) }
function problema(s) { prob[++nprob] = s }

{ tipo = $0; sub(/\t.*/, "", tipo); ruta = $0; sub(/^[^\t]*\t/, "", ruta); sub(/\r$/, "", ruta)
  if (tipo == "T") trutas[++ntr] = ruta
  else if (tipo == "A") arutas[++nar] = ruta
  else if (tipo == "C") cruta = ruta }

END {
  # ---------- Lectura
  for (i = 1; i <= ntr; i++) {
    leer_fm(trutas[i], fm); id = fm["id"]
    if (id == "") { problema("sin id: " trutas[i]); continue }
    if (id in archivo) { problema("id duplicado: " id " en " archivo[id] " y " trutas[i]); continue }
    ids[++n] = id; archivo[id] = trutas[i]
    titulo[id] = fm["titulo"]; rev[id] = fm["rev"]; spec[id] = fm["spec"]; estado[id] = fm["estado"]
    tam[id] = fm["tamaño"]; if (tam[id] !~ /^[SML]$/) { aviso[++navi] = id ": tamaño \"" tam[id] "\" no reconocido; cuenta como M"; }
    pts[id] = puntos(tam[id])
    ndep[id] = lista(fm["depende_de"], tmp); for (j = 1; j <= ndep[id]; j++) dep[id, j] = tmp[j]; delete tmp
    nadr[id] = lista(fm["adrs"], tmp); for (j = 1; j <= nadr[id]; j++) tadr[id, j] = tmp[j]; delete tmp
    nblq[id] = lista(fm["bloqueada_por"], tmp); for (j = 1; j <= nblq[id]; j++) blq[id, j] = tmp[j]; delete tmp
    fija[id] = (fm["estado"] == "revisado" && fm["fase"] ~ /^[0-9]+$/ && fm["prioridad"] ~ /^[0-9]+$/)
    if (fija[id]) { ffase[id] = fm["fase"] + 0; fprio[id] = fm["prioridad"] + 0 }
  }
  if (n == 0 && nprob == 0) { print "No hay tareas en " M "/tasks"; exit 2 }
  ordenar(ids, n)
  for (i = 1; i <= nar; i++) {
    leer_fm(arutas[i], fm); a = fm["id"]; if (a == "") continue
    atitulo[a] = fm["titulo"]; aimp[a] = fm["implicacion_migracion"]
  }
  ncap0 = 0
  if (cruta != "") { while ((getline l < cruta) > 0) if (match(l, /^\| *[a-z0-9-]+ *\|/)) { c = l; sub(/^\| */, "", c); sub(/ *\|.*/, "", c); sub(/\r$/, "", c); if (!(c in capos)) capos[c] = ++ncap0 }; close(cruta) }

  # ---------- Validación
  for (i = 1; i <= n; i++) { id = ids[i]
    for (j = 1; j <= ndep[id]; j++) { d = dep[id, j]
      if (!(d in archivo)) problema("no existe: " id " depende de " d ", que no es ninguna tarea")
      else if (spec[id] == "" && spec[d] != "") problema("fundacional depende de capacidad: " id " no tiene spec y depende de " d " (" spec[d] ")")
    }
  }
  # Ciclos: se retiran las tareas sin dependencias pendientes y las que nadie pendiente necesita
  for (i = 1; i <= n; i++) viva[ids[i]] = 1
  do { cambio = 0
    for (i = 1; i <= n; i++) { id = ids[i]; if (!viva[id]) continue
      ent = 0; for (j = 1; j <= ndep[id]; j++) if (viva[dep[id, j]]) ent++
      if (ent == 0) { viva[id] = 0; cambio = 1 } }
    for (i = 1; i <= n; i++) usada[ids[i]] = 0
    for (i = 1; i <= n; i++) { id = ids[i]; if (!viva[id]) continue; for (j = 1; j <= ndep[id]; j++) if (viva[dep[id, j]]) usada[dep[id, j]] = 1 }
    for (i = 1; i <= n; i++) { id = ids[i]; if (viva[id] && !usada[id]) { viva[id] = 0; cambio = 1 } }
  } while (cambio)
  enciclo = ""; primero = ""
  for (i = 1; i <= n; i++) if (viva[ids[i]]) { enciclo = enciclo (enciclo == "" ? "" : ", ") ids[i]; if (primero == "") primero = ids[i] }
  if (enciclo != "") {
    camino = primero; cur = primero; delete visto; visto[cur] = 1
    while (1) { sig = ""
      for (j = 1; j <= ndep[cur]; j++) { d = dep[cur, j]; if (viva[d] && (sig == "" || menor(d, sig))) sig = d }
      if (sig == "") break
      camino = camino " → " sig; if (sig in visto) break; visto[sig] = 1; cur = sig }
    problema("ciclo: las tareas " enciclo " dependen unas de otras (por ejemplo " camino ")")
  }
  if (nprob > 0) {
    print "El grafo de tareas tiene " nprob " problema(s). No se calculó ni se escribió nada:"
    for (i = 1; i <= nprob; i++) print "- " prob[i]
    exit 1
  }
  if (modo == "validar") { print "OK: " n " tareas, sin ciclos, sin referencias rotas"; for (i = 1; i <= navi; i++) print "AVISO: " aviso[i]; exit 0 }

  # ---------- Orden topológico por id
  for (i = 1; i <= n; i++) hecho[ids[i]] = 0
  nt = 0
  while (nt < n) for (i = 1; i <= n; i++) { id = ids[i]; if (hecho[id]) continue
    ok = 1; for (j = 1; j <= ndep[id]; j++) if (!hecho[dep[id, j]]) { ok = 0; break }
    if (ok) { hecho[id] = 1; topo[++nt] = id } }

  # ---------- Dependientes transitivos por tarea (en orden topológico inverso)
  for (i = nt; i >= 1; i--) { id = topo[i]; tdep[id] = 0
    for (k = 1; k <= n; k++) alc[id, ids[k]] = 0 }
  for (i = nt; i >= 1; i--) { id = topo[i]
    # quién depende directamente de id
    for (k = 1; k <= n; k++) { o = ids[k]
      for (j = 1; j <= ndep[o]; j++) if (dep[o, j] == id) { alc[id, o] = 1; for (q = 1; q <= n; q++) if (alc[o, ids[q]]) alc[id, ids[q]] = 1; break } }
    for (k = 1; k <= n; k++) if (alc[id, ids[k]]) tdep[id]++ }

  # ---------- Riesgo por ADR
  for (i = 1; i <= n; i++) { id = ids[i]; riesgo[id] = 0
    for (j = 1; j <= nadr[id]; j++) if (aimp[tadr[id, j]] ~ /^(reemplazar|reevaluar)$/) riesgo[id] = 1 }

  # ---------- Capacidades y sus dependencias
  nc = 0
  for (i = 1; i <= n; i++) { c = spec[ids[i]]; if (c != "" && !(c in cidx)) { caps[++nc] = c; cidx[c] = nc; cpts[c] = 0; criesgo[c] = 0 } }
  for (i = 1; i <= n; i++) { id = ids[i]; c = spec[id]; if (c == "") continue
    cpts[c] += pts[id]; if (riesgo[id]) criesgo[c] = 1
    for (j = 1; j <= ndep[id]; j++) { o = spec[dep[id, j]]; if (o != "" && o != c) cdep[c, o] = 1 } }
  # cierre transitivo: calc[a, b] = a depende de b
  for (a = 1; a <= nc; a++) for (b = 1; b <= nc; b++) calc[caps[a], caps[b]] = ((caps[a], caps[b]) in cdep) ? 1 : 0
  for (k = 1; k <= nc; k++) for (a = 1; a <= nc; a++) for (b = 1; b <= nc; b++)
    if (calc[caps[a], caps[k]] && calc[caps[k], caps[b]]) calc[caps[a], caps[b]] = 1
  for (b = 1; b <= nc; b++) { cdn[caps[b]] = 0; for (a = 1; a <= nc; a++) if (a != b && calc[caps[a], caps[b]]) cdn[caps[b]]++ }
  for (a = 1; a <= nc; a++) cposi[caps[a]] = (caps[a] in capos) ? capos[caps[a]] : 1000000

  # ---------- Orden de las capacidades
  for (a = 1; a <= nc; a++) cpuesta[caps[a]] = 0
  for (k = 1; k <= nc; k++) {
    mejor = ""; for (pasada = 1; pasada <= 2 && mejor == ""; pasada++)
      for (a = 1; a <= nc; a++) { c = caps[a]; if (cpuesta[c]) continue
        if (pasada == 1) { lista_ok = 1; for (b = 1; b <= nc; b++) if (((c, caps[b]) in cdep) && !cpuesta[caps[b]]) { lista_ok = 0; break }; if (!lista_ok) continue }
        if (mejor == "" || cdn[c] > cdn[mejor] || (cdn[c] == cdn[mejor] && (criesgo[c] > criesgo[mejor] || (criesgo[c] == criesgo[mejor] && (cposi[c] < cposi[mejor] || (cposi[c] == cposi[mejor] && c < mejor)))))) mejor = c }
    cpuesta[mejor] = 1; corden[k] = mejor; cord[mejor] = k
  }

  # ---------- Reparto de capacidades en fases (límite de 12 puntos para juntar)
  f = 1; acum = 0
  for (k = 1; k <= nc; k++) { c = corden[k]
    if (acum > 0 && acum + cpts[c] > 12) { f++; acum = 0 }
    cfase[c] = f; acum += cpts[c] }

  # ---------- Fase de cada tarea
  for (i = 1; i <= nt; i++) { id = topo[i]
    base = (spec[id] == "") ? 0 : cfase[spec[id]]; mx = 0
    for (j = 1; j <= ndep[id]; j++) if (fase[dep[id, j]] > mx) mx = fase[dep[id, j]]
    if (fija[id]) { fase[id] = ffase[id]; if (ffase[id] < mx) conf[++nconf] = id " está fijada en la fase " ffase[id] " y depende de una tarea de la fase " mx }
    else fase[id] = (mx > base) ? mx : base
    if (spec[id] != "" && fase[id] != cfase[spec[id]]) partida[spec[id]] = 1
    if (!(fase[id] in hayfase)) { hayfase[fase[id]] = 1; fases[++nf] = fase[id] } }
  for (i = 2; i <= nf; i++) { t = fases[i]; for (j = i - 1; j >= 1 && fases[j] > t; j--) fases[j + 1] = fases[j]; fases[j + 1] = t }

  # ---------- Prioridad
  for (i = 1; i <= n; i++) if (fija[ids[i]]) { if (fprio[ids[i]] in reservada) conf[++nconf] = ids[i] " y " reservada[fprio[ids[i]]] " están fijadas con la misma prioridad " fprio[ids[i]]; else reservada[fprio[ids[i]]] = ids[i] }
  sigp = 1
  for (x = 1; x <= nf; x++) { fx = fases[x]; quedan = 0
    for (i = 1; i <= n; i++) { numerada[ids[i]] = (fase[ids[i]] != fx); if (fase[ids[i]] == fx) quedan++ }
    while (quedan > 0) { mejor = ""
      for (i = 1; i <= n; i++) { id = ids[i]; if (numerada[id]) continue
        ok = 1; for (j = 1; j <= ndep[id]; j++) if (!numerada[dep[id, j]]) { ok = 0; break }
        if (!ok) continue
        ci = (spec[id] == "") ? 0 : cord[spec[id]]; cm = (mejor == "") ? 0 : ((spec[mejor] == "") ? 0 : cord[spec[mejor]])
        if (mejor == "" || tdep[id] > tdep[mejor] || (tdep[id] == tdep[mejor] && (riesgo[id] > riesgo[mejor] || (riesgo[id] == riesgo[mejor] && (ci < cm || (ci == cm && menor(id, mejor))))))) mejor = id }
      numerada[mejor] = 1; quedan--
      if (fija[mejor]) prio[mejor] = fprio[mejor]
      else { while (sigp in reservada) sigp++; prio[mejor] = sigp++ }
      orden[fx, ++nen[fx]] = mejor } }
  for (i = 1; i <= n; i++) { id = ids[i]; if (!fija[id]) continue
    for (j = 1; j <= ndep[id]; j++) if (prio[dep[id, j]] > prio[id]) conf[++nconf] = id " está fijada con prioridad " prio[id] " y depende de " dep[id, j] ", con prioridad " prio[dep[id, j]] }

  if (modo == "calcular" && tsv) { for (i = 1; i <= n; i++) printf "%s\t%d\t%d\n", ids[i], fase[ids[i]], prio[ids[i]]; exit 0 }

  # ---------- Aplicar: solo las líneas fase y prioridad del frontmatter
  if (modo == "aplicar") { nesc = 0
    for (i = 1; i <= n; i++) { id = ids[i]; if (fija[id]) continue
      f = archivo[id]; nl = 0; RS = "\n"
      while ((getline l < f) > 0) { linea[++nl] = l; fin[nl] = RT }
      close(f)
      enfm = 0; cierre = 0; vf = 0; vp = 0; cambia = 0
      for (k = 1; k <= nl; k++) { l = linea[k]; cr = (l ~ /\r$/) ? "\r" : ""; s = l; sub(/\r$/, "", s)
        if (k == 1 && s == "---") { enfm = 1; continue }
        if (enfm && s == "---") { cierre = k; break }
        if (enfm && s ~ /^fase:/) { vf = 1; nv = "fase: " fase[id] cr; if (linea[k] != nv) { linea[k] = nv; cambia = 1 } }
        if (enfm && s ~ /^prioridad:/) { vp = 1; nv = "prioridad: " prio[id] cr; if (linea[k] != nv) { linea[k] = nv; cambia = 1 } } }
      if (cierre && (!vf || !vp)) { cr = (linea[cierre] ~ /\r$/) ? "\r" : ""; extra = ""
        if (!vf) extra = extra "fase: " fase[id] cr "\n"
        if (!vp) extra = extra "prioridad: " prio[id] cr "\n"
        linea[cierre] = extra linea[cierre]; cambia = 1 }
      if (cambia) { printf "" > f; for (k = 1; k <= nl; k++) printf "%s%s", linea[k], fin[k] > f; close(f); nesc++ }
      delete linea; delete fin }
    nfij = 0; for (i = 1; i <= n; i++) if (fija[ids[i]]) nfij++
    print "OK: fase y prioridad escritas en " nesc " tareas; " (n - nesc - nfij) " ya las tenían; " nfij " fijadas (revisado) sin tocar"
    exit 0 }

  # ---------- Salida de calcular
  print "## Fases"
  total = 0
  for (x = 1; x <= nf; x++) { fx = fases[x]; p = 0; nombre = ""
    for (k = 1; k <= nen[fx]; k++) p += pts[orden[fx, k]]
    fpts[fx] = p; total += p
    if (fx == 0) nombre = "fundaciones"
    else { for (k = 1; k <= nc; k++) if (cfase[corden[k]] == fx) nombre = nombre (nombre == "" ? "" : ", ") corden[k]; if (nombre == "") nombre = "tareas desplazadas" }
    print ""; print "### Hito " fx ": " nombre; print ""; print "Puntos: " p; print ""
    print "| Orden | Tarea | Rev | Título | Tamaño | Depende de | Plan de pruebas |"; print "|---|---|---|---|---|---|---|"
    # filas por prioridad ascendente
    for (k = 1; k <= nen[fx]; k++) fila[k] = orden[fx, k]
    for (a = 2; a <= nen[fx]; a++) { t = fila[a]; for (b = a - 1; b >= 1 && prio[fila[b]] > prio[t]; b--) fila[b + 1] = fila[b]; fila[b + 1] = t }
    for (k = 1; k <= nen[fx]; k++) { id = fila[k]; d = ""
      for (j = 1; j <= ndep[id]; j++) tmp[j] = dep[id, j]; ordenar(tmp, ndep[id])
      for (j = 1; j <= ndep[id]; j++) d = d (d == "" ? "" : ", ") tmp[j]; delete tmp
      plan = "—"; if (spec[id] != "" && existe(M "/test-plans/" spec[id] ".md")) plan = "test-plans/" spec[id] ".md"
      print "| " prio[id] " | " id " | " rev[id] " | " titulo[id] " | " tam[id] " | " (d == "" ? "—" : d) " | " plan " |" }
    delete fila }

  print ""; print "## Bloqueos"; print ""; print "### Bloqueadas por decisiones pendientes (ADRs propuestos)"; print ""
  nba = 0; nbp = 0; soloadr = 0; conpa = 0
  for (i = 1; i <= n; i++) { id = ids[i]; ta = 0; tp = 0
    for (j = 1; j <= nblq[id]; j++) { b = blq[id, j]; if (b ~ /^PA:/) { tp = 1; bpa[++nbp] = id SUBSEP b } else { ta = 1; bad[++nba] = id SUBSEP b; cuenta[b]++ } }
    if (ta && !tp) soloadr++; if (tp) conpa++ }
  if (nba == 0) print "Ninguna"
  else { print "| Tarea | ADR | Decisión pendiente | Para desbloquear |"; print "|---|---|---|---|"
    for (i = 1; i <= nba; i++) { split(bad[i], pr, SUBSEP); print "| " pr[1] " | " pr[2] " | " (pr[2] in atitulo ? atitulo[pr[2]] : "ADR no encontrado") " | Decidir el ADR " pr[2] " con migration-tl-resolver |" }
    print ""; print "| ADR | Decisión pendiente | Tareas que desbloquea |"; print "|---|---|---|"
    na = 0; for (b in cuenta) la[++na] = b
    for (a = 2; a <= na; a++) { t = la[a]; for (b = a - 1; b >= 1 && (cuenta[la[b]] < cuenta[t] || (cuenta[la[b]] == cuenta[t] && la[b] > t)); b--) la[b + 1] = la[b]; la[b + 1] = t }
    for (a = 1; a <= na; a++) print "| " la[a] " | " (la[a] in atitulo ? atitulo[la[a]] : "ADR no encontrado") " | " cuenta[la[a]] " |" }
  print ""; print "### Bloqueadas por preguntas abiertas"; print ""
  if (nbp == 0) print "Ninguna"
  else { print "| Tarea | Pregunta | Texto de la pregunta |"; print "|---|---|---|"
    for (i = 1; i <= nbp; i++) { split(bpa[i], pr, SUBSEP); split(pr[2], pa, ":"); texto = "pregunta no encontrada en el spec"; sf = M "/specs/" pa[2] ".md"; en12 = 0; q = 0
      while ((getline l < sf) > 0) { sub(/\r$/, "", l)
        if (l ~ /^## 12\. /) { en12 = 1; continue }
        if (en12 && l ~ /^## /) break
        if (en12 && l ~ /^- /) { q++; if (q == pa[3] + 0) { texto = substr(l, 3); break } } }
      close(sf)
      print "| " pr[1] " | " pr[2] " | " texto " |" } }

  # Camino crítico
  for (i = 1; i <= nt; i++) { id = topo[i]; peso[id] = pts[id]; ant[id] = ""
    for (j = 1; j <= ndep[id]; j++) { d = dep[id, j]; if (ant[id] == "" || peso[d] > peso[ant[id]] || (peso[d] == peso[ant[id]] && menor(d, ant[id]))) ant[id] = d }
    if (ant[id] != "") peso[id] += peso[ant[id]] }
  finc = ""; for (i = 1; i <= n; i++) { id = ids[i]; if (finc == "" || peso[id] > peso[finc]) finc = id }
  cc = ""; ccl = ""; for (id = finc; id != ""; id = ant[id]) { cc = id (cc == "" ? "" : " → " cc); if (tam[id] == "L") ccl = id (ccl == "" ? "" : ", " ccl) }

  print ""; print "## Datos"; print ""
  print "- Tareas: " n ". Fases: " nf ". Puntos totales: " total " (S=1, M=2, L=4)."
  s = ""; for (x = 1; x <= nf; x++) s = s (s == "" ? "" : "; ") "hito " fases[x] ": " fpts[fases[x]]; print "- Puntos por fase: " s "."
  print "- Tareas bloqueadas solo por ADRs propuestos: " soloadr ". Tareas bloqueadas por preguntas abiertas: " conpa "."
  print "- Camino crítico (" peso[finc] " puntos): " cc "."
  print "- Tareas L en el camino crítico: " (ccl == "" ? "ninguna" : ccl) "."
  s = ""; for (k = 1; k <= nc; k++) if (corden[k] in partida) s = s (s == "" ? "" : ", ") corden[k]; print "- Capacidades partidas entre fases: " (s == "" ? "ninguna" : s) "."
  s = ""; for (k = 1; k <= nc; k++) if (!existe(M "/test-plans/" corden[k] ".md")) s = s (s == "" ? "" : ", ") corden[k]; print "- Capacidades sin plan de pruebas: " (s == "" ? "ninguna" : s) "."
  s = ""; for (x = 1; x <= nf; x++) if (fases[x] > 0 && fpts[fases[x]] > 12) s = s (s == "" ? "" : ", ") "hito " fases[x] " (" fpts[fases[x]] ")"; print "- Fases que superan 12 puntos: " (s == "" ? "ninguna" : s) "."
  if (nconf == 0) print "- Conflictos con tareas revisado: ninguno."; else for (i = 1; i <= nconf; i++) print "- Conflicto con una tarea revisado: " conf[i] "."
  for (i = 1; i <= navi; i++) print "- Aviso: " aviso[i] "."
  s = ""; for (a = 1; a <= nc; a++) for (b = 1; b <= nc; b++) if ((corden[a], corden[b]) in cdep) s = s (s == "" ? "" : "; ") corden[a] " → " corden[b]; print "- Dependencias entre capacidades: " (s == "" ? "ninguna" : s) "."
  s = ""; for (k = 1; k <= nc; k++) s = s (s == "" ? "" : "; ") corden[k] " (" cdn[corden[k]] " dependientes, " cpts[corden[k]] " puntos)"; print "- Orden de las capacidades: " (s == "" ? "ninguna" : s) "."
  print ""; print "| Tarea | Dependientes transitivos |"; print "|---|---|"
  for (i = 1; i <= n; i++) print "| " ids[i] " | " tdep[ids[i]] " |"
}'
