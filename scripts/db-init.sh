#!/usr/bin/env bash
# db-init.sh — Inicializa la base de datos SQLite con el schema completo
# Uso: ./scripts/db-init.sh
# Seguro de ejecutar múltiples veces (CREATE IF NOT EXISTS en todo)

set -euo pipefail

MEMORY_DB="${USERPROFILE:-$HOME}/.local/enterprise-ai/memory.db"
SCHEMA_FILE="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")/memory/schema.sql"

echo ""
echo "╔══════════════════════════════════╗"
echo "║     Enterprise AI — DB Init      ║"
echo "╚══════════════════════════════════╝"
echo "  DB:     $MEMORY_DB"
echo "  Schema: $SCHEMA_FILE"
echo ""

if ! command -v sqlite3 &>/dev/null; then
  echo "ERROR: sqlite3 no encontrado."
  echo "  Windows: winget install SQLite.SQLite"
  echo "  macOS:   brew install sqlite"
  echo "  Linux:   sudo apt install sqlite3"
  exit 1
fi

if [ ! -f "$SCHEMA_FILE" ]; then
  echo "ERROR: Schema no encontrado en $SCHEMA_FILE"
  exit 1
fi

# Crear directorio si no existe
mkdir -p "$(dirname "$MEMORY_DB")"

# Aplicar schema (idempotente)
sqlite3 "$MEMORY_DB" < "$SCHEMA_FILE"

# Verificar tablas creadas
TABLES=$(sqlite3 "$MEMORY_DB" ".tables" 2>/dev/null)
echo "  Tablas creadas:"
echo "$TABLES" | tr ' ' '\n' | grep -v '^$' | sort | while read -r t; do
  echo "    ✓ $t"
done

echo ""
echo "✓ Base de datos inicializada correctamente"
echo ""
echo "Próximos pasos:"
echo "  1. Indexar documentos: ./scripts/rag-index.sh"
echo "  2. Iniciar sesión:     ./scripts/session-start.sh <proyecto>"
echo ""
