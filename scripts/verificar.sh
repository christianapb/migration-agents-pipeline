#!/usr/bin/env bash
# Comprueba la estructura de todo lo que haya en migration/: campos del
# frontmatter, formato de identificadores, citas, versiones y secciones.
# No comprueba que el contenido sea correcto: para eso están tu revisión y
# migration-auditor.
#
# Uso: verificar.sh [carpeta]
#   carpeta: la del proyecto, la que contiene migration/. Por defecto, la actual.
#
# Ejecuta solo lo que aplica según qué exista y termina con un resumen por tipo
# de artefacto. Código de salida distinto de cero si algo falla.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
W="$(cd "${1:-$PWD}" 2>/dev/null && pwd)" || { echo "No existe la carpeta ${1:-}"; exit 2; }
M="$W/migration"
[ -d "$M" ] || { echo "No hay carpeta migration/ en $W. Ejecuta primero el subagente migration-indexer."; exit 2; }

hay() { ls $1 >/dev/null 2>&1; }
# <tipo de artefacto> <verificador> <aplica: 0 o 1>
TIPOS=()
ok=0; mal=0; omit=0
revisar() {
  local nombre="$1" v="$2" out rc
  [ -f "$HERE/verify-$v.sh" ] || { echo "  FALTA  $nombre: no está instalado verify-$v.sh"; mal=$((mal+1)); return; }
  out="$(WORKDIR="$W" FIXTURE=0 bash "$HERE/verify-$v.sh" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "  OK     $nombre"; ok=$((ok+1))
  else
    echo "  FALLA  $nombre"; mal=$((mal+1))
    printf '%s\n' "$out" | grep -E '^(FAIL|ERROR)' | sed -E 's/^(FAIL|ERROR): /           - /'
  fi
}
omitir() { echo "  —      $1: todavía no existe"; omit=$((omit+1)); }

echo "Verificación de $W"
if [ -f "$W/CLAUDE.md" ] || [ -f "$W/index.md" ]; then revisar "índices, README y bloque de CLAUDE.md" indexer; else omitir "índices y bloque de CLAUDE.md"; fi
if [ -f "$M/specs/_capacidades.md" ]; then revisar "mapa de capacidades" analyst; else omitir "mapa de capacidades"; fi
if hay "$M/adr/*.md"; then revisar "ADRs" tl-adrs; else omitir "ADRs"; fi
if hay "$M/specs/[!_]*.md"; then revisar "specs" tl-specs; else omitir "specs"; fi
if [ -f "$M/specs/_auditoria.md" ]; then revisar "auditoría" auditor; else omitir "auditoría (opcional)"; fi
if hay "$M/test-plans/*.md"; then revisar "planes de prueba" qa; else omitir "planes de prueba"; fi
if hay "$M/tasks/T-*.md"; then revisar "tareas" tl-tasks; else omitir "tareas"; fi
if [ -f "$M/backlog.md" ]; then revisar "backlog" pm; else omitir "backlog"; fi

echo
echo "Resumen: $ok correctos, $mal con fallos, $omit sin generar."
[ "$mal" -eq 0 ] || { echo "Corrige los fallos con migration-tl-resolver o repite el agente que genera ese artefacto."; exit 1; }
exit 0
