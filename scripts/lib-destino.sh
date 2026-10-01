#!/usr/bin/env bash
# Lectura del destino de migration/README.md para los verificadores.
# `destino:` es un valor simple (aplica a todos los repositorios) o un mapa en
# una línea: destino: {bff: Kotlin, frontend: conservar}
# Uso: source scripts/lib-destino.sh; las funciones reciben el workspace.

# Valor crudo del campo, sin espacios finales. Vacío si no existe.
destino_raw() {
  sed -n 's/^destino:[[:space:]]*//p' "$1/migration/README.md" 2>/dev/null | head -n1 | sed 's/[[:space:]]*$//'
}

destino_es_mapa() { case "$(destino_raw "$1")" in "{"*) return 0 ;; *) return 1 ;; esac; }

# Repositorios del workspace: subcarpetas directas, sin migration ni ocultas.
destino_repos() {
  local d b
  for d in "$1"/*/; do
    [ -d "$d" ] || continue
    b="$(basename "$d")"
    [ "$b" = "migration" ] && continue
    echo "$b"
  done
}

# Pares "repo valor" del mapa, uno por línea. Vacío si no es un mapa.
destino_pares() {
  destino_es_mapa "$1" || return 0
  destino_raw "$1" | tr -d '{}' | tr ',' '\n' \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/[[:space:]]*:[[:space:]]*/ /' | grep -v '^$'
}

# Destino de un repositorio: su entrada del mapa, o el valor simple.
destino_de() {
  if destino_es_mapa "$1"; then
    destino_pares "$1" | awk -v r="$2" '$1==r {print $2}'
  else
    destino_raw "$1"
  fi
}

# Repositorios conservados, uno por línea.
destino_conservados() {
  local r
  for r in $(destino_repos "$1"); do
    [ "$(destino_de "$1" "$r")" = "conservar" ] && echo "$r"
  done
  return 0
}

# Valida un mapa: cada repositorio tiene entrada y cada clave es un repositorio.
# Imprime un problema por línea. Un valor simple o vacío no se valida aquí.
destino_problemas() {
  destino_es_mapa "$1" || return 0
  local r k repos claves
  repos="$(destino_repos "$1")"
  claves="$(destino_pares "$1" | awk '{print $1}')"
  for r in $repos; do
    printf '%s\n' "$claves" | grep -qx "$r" || echo "el mapa de destino no cubre el repositorio '$r'"
  done
  for k in $claves; do
    printf '%s\n' "$repos" | grep -qx "$k" || echo "'$k' está en el mapa de destino y no es un repositorio detectado"
  done
}
