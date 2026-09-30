#!/usr/bin/env bash
# Resultados guardados por etapa de la cadena de agentes, para no regenerarlos
# en cada prueba.
#
# Uso:
#   scripts/snapshot.sh build <etapa>            construye (o reutiliza) hasta la etapa
#   scripts/snapshot.sh restore <etapa> [destino] deja en destino el workspace de la etapa
#   scripts/snapshot.sh list                     etapas disponibles
#
# Etapas, en orden: fixture indexer analyst tl-adrs tl-specs tl-tasks qa pm.
# Cada etapa guarda una huella del fixture, de los prompts de los agentes que
# la produjeron y de los prompts usados. Si la huella cambia, la etapa y las
# posteriores se rehacen; las anteriores se reutilizan.
#
# Variables: SNAPSHOT_DIR (por defecto .work/snapshots), AGENTS_DIR (por
# defecto agents/), WORKDIR (destino por defecto de restore).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SNAPS="${SNAPSHOT_DIR:-$ROOT/.work/snapshots}"
AGENTS="${AGENTS_DIR:-$ROOT/agents}"

STAGES=(fixture indexer analyst tl-adrs tl-specs tl-tasks qa pm)
declare -A PROMPT=(
  [indexer]=""
  [analyst]=""
  [tl-adrs]="Ejecútalo con destino Kotlin."
  [tl-specs]=""
  [tl-tasks]="Ejecútalo con destino Kotlin, aunque haya ADRs propuestos."
  [qa]=""
  [pm]=""
)

die() { echo "ERROR: $*" >&2; exit 1; }

stage_index() {
  local i
  for i in "${!STAGES[@]}"; do [ "${STAGES[$i]}" = "$1" ] && { echo "$i"; return 0; }; done
  return 1
}

# Vacía un directorio (tolera handles abiertos en Windows) o lo crea.
empty_dir() {
  local d="$1"
  mkdir -p "$d"
  find "$d" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
  [ -z "$(ls -A "$d" 2>/dev/null)" ] || die "no se pudo vaciar $d"
}

# Huella acumulada hasta la etapa i: fixture + prompts de agentes + textos de prompt.
key_for() {
  local i="$1" j s
  {
    (cd "$ROOT/fixtures/sample-workspace" && find . -type f -print0 | sort -z | xargs -0 sha256sum)
    for ((j=1; j<=i; j++)); do
      s="${STAGES[$j]}"
      sha256sum < "$AGENTS/migration-$s.md"
      printf '%s\n' "${PROMPT[$s]}"
    done
  } | sha256sum | cut -d' ' -f1
}

copy_agents() {
  mkdir -p "$1/.claude/agents"
  cp "$AGENTS"/*.md "$1/.claude/agents/"
}

build_fixture() {
  local d="$1" repo
  empty_dir "$d"
  cp -r "$ROOT/fixtures/sample-workspace/." "$d/"
  for repo in "$d"/*/; do
    (
      cd "$repo" || exit 1
      git init -q
      git config core.autocrlf false
      git add -A
      git -c user.name=fixture -c user.email=fixture@example.com commit -qm "fixture"
    ) || die "no se pudo inicializar git en $repo"
  done
}

build() {
  local target="$1" ti i s key prev
  ti="$(stage_index "$target")" || die "etapa desconocida: $target (etapas: ${STAGES[*]})"
  mkdir -p "$SNAPS"
  for ((i=0; i<=ti; i++)); do
    s="${STAGES[$i]}"
    key="$(key_for "$i")"
    if [ -f "$SNAPS/$s/.snapshot-key" ] && [ "$(cat "$SNAPS/$s/.snapshot-key")" = "$key" ]; then
      echo "reutilizada: $s"
      continue
    fi
    echo "construyendo: $s"
    if [ "$i" -eq 0 ]; then
      build_fixture "$SNAPS/$s"
    else
      prev="${STAGES[$((i-1))]}"
      empty_dir "$SNAPS/$s"
      cp -r "$SNAPS/$prev/." "$SNAPS/$s/"
      rm -f "$SNAPS/$s/.snapshot-key"
      copy_agents "$SNAPS/$s"
      WORKDIR="$SNAPS/$s" bash "$ROOT/scripts/run-agent.sh" "migration-$s" ${PROMPT[$s]:+"${PROMPT[$s]}"} > "$SNAPS/$s.log" 2>&1
      local rc=$?
      [ "$rc" -eq 0 ] || die "la etapa $s falló (código $rc); ver $SNAPS/$s.log"
    fi
    echo "$key" > "$SNAPS/$s/.snapshot-key"
  done
}

restore() {
  local s="$1" dest="${2:-${WORKDIR:-$ROOT/.work/sample-workspace}}"
  stage_index "$s" >/dev/null || die "etapa desconocida: $s (etapas: ${STAGES[*]})"
  build "$s" >/dev/null || exit 1
  empty_dir "$dest"
  cp -r "$SNAPS/$s/." "$dest/"
  rm -f "$dest/.snapshot-key"
  copy_agents "$dest"
  echo "restaurada: $s en $dest"
}

case "${1:-}" in
  build)   [ $# -ge 2 ] || die "uso: snapshot.sh build <etapa>"; build "$2" ;;
  restore) [ $# -ge 2 ] || die "uso: snapshot.sh restore <etapa> [destino]"; restore "$2" "${3:-}" ;;
  list)    printf '%s\n' "${STAGES[@]}" ;;
  *)       die "uso: snapshot.sh build|restore|list" ;;
esac
