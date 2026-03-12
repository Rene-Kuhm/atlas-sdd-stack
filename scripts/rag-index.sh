#!/usr/bin/env bash
# rag-index.sh — Indexa documentos de rag/ en SQLite FTS5 para búsqueda instantánea
# Uso: ./scripts/rag-index.sh [--project nombre] [--category categoria]
# Sin args: indexa todo el directorio rag/ del proyecto actual

set -euo pipefail

PROJECT="${PROJECT:-global}"
FORCE_REINDEX=false
RAG_DIR=""
MEMORY_DB="${USERPROFILE:-$HOME}/.local/enterprise-ai/memory.db"

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --force)   FORCE_REINDEX=true; shift ;;
    --dir)     RAG_DIR="$2"; shift 2 ;;
    *) echo "Arg desconocido: $1"; exit 1 ;;
  esac
done

# Autodetectar rag/ si no se especificó
if [ -z "$RAG_DIR" ]; then
  if git rev-parse --git-dir &>/dev/null 2>&1; then
    RAG_DIR="$(git rev-parse --show-toplevel)/rag"
  else
    echo "ERROR: Especifica --dir o ejecuta desde un repo git."
    exit 1
  fi
fi

if [ ! -d "$RAG_DIR" ]; then
  echo "ERROR: Directorio RAG no encontrado: $RAG_DIR"
  echo "Crealo con: mkdir -p rag/{docs,patterns,runbooks,adrs,apis}"
  exit 1
fi

if ! command -v sqlite3 &>/dev/null; then
  echo "ERROR: sqlite3 no encontrado."
  exit 1
fi

if [ ! -f "$MEMORY_DB" ]; then
  echo "ERROR: DB no inicializada. Ejecutar: ./scripts/db-init.sh"
  exit 1
fi

echo ""
echo "╔══════════════════════════════════╗"
echo "║        RAG Indexer               ║"
echo "╚══════════════════════════════════╝"
echo "  Directorio: $RAG_DIR"
echo "  Proyecto:   $PROJECT"
echo ""

INDEXED=0
SKIPPED=0
ERRORS=0

# Mapeo de carpetas a categorías
get_category() {
  local path="$1"
  local dirname
  dirname=$(basename "$(dirname "$path")")
  case "$dirname" in
    runbooks)  echo "runbook" ;;
    patterns)  echo "pattern" ;;
    apis)      echo "api" ;;
    adrs)      echo "adr" ;;
    docs)      echo "doc" ;;
    *)         echo "doc" ;;
  esac
}

# Indexar archivos Markdown y YAML
# Usar archivo temporal para contadores (evita bug de subshell con pipe)
COUNTER_FILE=$(mktemp)
echo "0 0 0" > "$COUNTER_FILE"

while IFS= read -r FILE; do
  [ -f "$FILE" ] || continue

  # Calcular hash para skip si no cambió
  CURRENT_HASH=$(sha256sum "$FILE" | cut -d' ' -f1)
  FILE_ID="$CURRENT_HASH"

  if [ "$FORCE_REINDEX" = false ]; then
    EXISTING=$(sqlite3 "$MEMORY_DB" \
      "SELECT id FROM rag_docs WHERE source_path='$FILE' AND id='$FILE_ID';" 2>/dev/null || echo "")
    if [ -n "$EXISTING" ]; then
      SKIPPED=$((SKIPPED + 1))
      continue
    fi
  fi

  # Extraer título (primera línea que empieza con #, o el nombre del archivo)
  TITLE=$(grep -m1 '^#' "$FILE" 2>/dev/null | sed 's/^#\+\s*//' || basename "$FILE" .md)
  if [ -z "$TITLE" ]; then
    TITLE=$(basename "$FILE")
  fi

  # Leer contenido (limitar a 10000 chars para no inflar la DB)
  CONTENT=$(head -c 10000 "$FILE" 2>/dev/null || echo "")

  CATEGORY=$(get_category "$FILE")

  # Escape de comillas simples para SQLite
  TITLE_ESC=$(echo "$TITLE" | sed "s/'/''/g")
  CONTENT_ESC=$(echo "$CONTENT" | sed "s/'/''/g")
  FILE_ESC=$(echo "$FILE" | sed "s/'/''/g")

  # Upsert: eliminar viejo si misma ruta, insertar nuevo
  if sqlite3 "$MEMORY_DB" \
    "DELETE FROM rag_docs WHERE source_path='$FILE_ESC';
     INSERT INTO rag_docs (id, title, content, category, project, source_path)
     VALUES ('$FILE_ID', '$TITLE_ESC', '$CONTENT_ESC', '$CATEGORY', '$PROJECT', '$FILE_ESC');" \
    2>/dev/null; then
    echo "  ✓ [$CATEGORY] $TITLE"
    read -r i s e < "$COUNTER_FILE"; echo "$((i+1)) $s $e" > "$COUNTER_FILE"
  else
    echo "  ✗ ERROR: $FILE"
    read -r i s e < "$COUNTER_FILE"; echo "$i $s $((e+1))" > "$COUNTER_FILE"
  fi
done < <(find "$RAG_DIR" \( -name "*.md" -o -name "*.yaml" -o -name "*.yml" -o -name "*.txt" \) | sort)

read -r INDEXED SKIPPED ERRORS < "$COUNTER_FILE"
rm -f "$COUNTER_FILE"

# Reconstruir índice FTS5 para mantener consistencia
if [ "$INDEXED" -gt 0 ]; then
  sqlite3 "$MEMORY_DB" "INSERT INTO rag_docs_fts(rag_docs_fts) VALUES('rebuild');" 2>/dev/null || true
fi

echo ""
echo "Resultado: $INDEXED indexados | $SKIPPED sin cambios | $ERRORS errores"
echo ""
echo "Para buscar: sqlite3 $MEMORY_DB \"SELECT title, category FROM rag_docs_fts WHERE rag_docs_fts MATCH '<término>';\""
echo ""
