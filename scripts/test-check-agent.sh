#!/usr/bin/env bash
# Prueba scripts/check-agent.sh con un archivo válido y varios inválidos.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0

cat > "$TMP/migration-ok.md" <<'EOF'
---
name: migration-ok
description: Agente de prueba válido.
tools: Read, Glob
---
Cuerpo del agente.

## 1. Sección
Contenido.
EOF

cat > "$TMP/migration-badname.md" <<'EOF'
---
name: otro-nombre
description: Nombre no coincide con el archivo.
tools: Read
---
## 1. Sección
EOF

cat > "$TMP/migration-notools.md" <<'EOF'
---
name: migration-notools
description: Sin tools.
---
## 1. Sección
EOF

cat > "$TMP/migration-nobody.md" <<'EOF'
---
name: migration-nobody
description: Sin cuerpo.
tools: Read
---
EOF

if ! "$ROOT/scripts/check-agent.sh" "$TMP/migration-ok.md" >/dev/null; then
  echo "FAIL: el agente válido fue rechazado"; fails=$((fails+1))
fi
for bad in badname notools nobody; do
  if "$ROOT/scripts/check-agent.sh" "$TMP/migration-$bad.md" >/dev/null 2>&1; then
    echo "FAIL: migration-$bad.md fue aceptado"; fails=$((fails+1))
  fi
done

if [ "$fails" -eq 0 ]; then echo "OK: check-agent.sh"; exit 0; fi
exit 1
