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
