#!/usr/bin/env bash
# Versiones de artefactos para los verificadores.
# `rev:` es un entero mayor que 0 en specs, ADRs y tareas; los derivados anotan
# la versión de sus insumos (spec_rev, adrs_rev, columna Rev, "Spec rev:").
# Uso: source scripts/lib-rev.sh

# Valor crudo de un campo del frontmatter. Vacío si no existe.
campo() { sed -n "s/^$2:[[:space:]]*//p" "$1" 2>/dev/null | head -n1 | sed 's/[[:space:]]*$//'; }

es_rev() { [[ "$1" =~ ^[1-9][0-9]*$ ]]; }

# rev de un artefacto, solo si es válido. Vacío en otro caso.
rev_de() { local r; r="$(campo "$1" rev)"; es_rev "$r" && echo "$r"; return 0; }

# Archivo del ADR con ese id, en el directorio de migración dado.
adr_file() { local f; for f in "$1"/adr/"$2"-*.md; do [ -f "$f" ] && { echo "$f"; return 0; }; done; return 0; }

# Pares "id versión" de un mapa en una línea: {0003: 1, 0011: 2}
mapa_pares() {
  printf '%s' "$1" | tr -d '{}' | tr ',' '\n' \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/[[:space:]]*:[[:space:]]*/ /' | grep -v '^$' || true
}

# Elementos de una lista en una línea: [T-001, T-002]
lista() { printf '%s' "$1" | tr -d '[]"'"'" | tr ',' '\n' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | grep -v '^$' || true; }

# ---- Preguntas abiertas (sección 12 de un spec)
# Formato actual: "- PA-3: <pregunta>", con el id escrito. Formato anterior:
# viñetas sin id, que se citaban por su lugar en la lista.
sec12() { awk '/^## 12\. /{f=1;next} /^## /{f=0} f' "$1" 2>/dev/null | tr -d '\r'; }

# nuevo (todas con id) | antiguo (ninguna con id) | mixto | ninguna
pa_formato() {
  local v con sin
  v="$(sec12 "$1" | grep '^- ' || true)"
  [ -n "$v" ] || { echo ninguna; return 0; }
  con="$(printf '%s\n' "$v" | grep -cE '^- PA-[0-9]+:' || true)"
  sin="$(printf '%s\n' "$v" | grep -vcE '^- PA-[0-9]+:' || true)"
  if [ "$con" -gt 0 ] && [ "$sin" -gt 0 ]; then echo mixto
  elif [ "$con" -gt 0 ]; then echo nuevo
  else echo antiguo; fi
}

# Línea de la pregunta n: por id si el spec tiene ids; por su lugar en la
# lista solo en la vía de compatibilidad, para un spec del formato anterior.
pa_linea() {
  if [ "$(pa_formato "$1")" = antiguo ]; then
    sec12 "$1" | grep '^- ' | sed -n "${2}p"   # compatibilidad: formato anterior
  else
    sec12 "$1" | grep -m1 -E "^- PA-$2:" || true
  fi
}

# Números de id de todas las preguntas con id, uno por línea (con repetidos si los hay)
pa_ids() { sec12 "$1" | grep -oE '^- PA-[0-9]+:' | grep -oE '[0-9]+' || true; }

# Números de id de las preguntas que siguen abiertas: sin marca de retirada y sin Respuesta debajo
pa_abiertas() {
  sec12 "$1" | awk '
    function fin() { if (id != "" && !ret && !resp) print id; id = "" }
    /^- / { fin(); if (match($0, /^- PA-[0-9]+:/)) { id = substr($0, 6, RLENGTH - 6); ret = ($0 ~ /\(retirado/); resp = 0 } next }
    /^[ \t]+- Respuesta \(/ { resp = 1 }
    END { fin() }'
}
