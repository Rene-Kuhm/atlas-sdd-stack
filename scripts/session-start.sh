#!/usr/bin/env bash
# session-start.sh — Carga contexto del día al inicio de trabajo
# Uso: ./scripts/session-start.sh [proyecto]
# Muestra: dashboard de tareas, última sesión, worktrees activos, docs RAG disponibles

set -euo pipefail

PROJECT="${1:-}"
MEMORY_DB="${USERPROFILE:-$HOME}/.local/enterprise-ai/memory.db"
DB_AVAILABLE=false

if command -v sqlite3 &>/dev/null && [ -f "$MEMORY_DB" ]; then
  DB_AVAILABLE=true
fi

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║        ENTERPRISE AI STACK — SESSION START   ║"
echo "╚══════════════════════════════════════════════╝"
echo "  $(date '+%Y-%m-%d %H:%M') | Proyecto: ${PROJECT:-todos}"
echo ""

# ─────────────────────────────────────────────
# 1. Dashboard de tareas
# ─────────────────────────────────────────────
echo "┌─ DASHBOARD ────────────────────────────────┐"

if [ "$DB_AVAILABLE" = true ]; then
  sqlite3 "$MEMORY_DB" -column -header \
    "SELECT en_progreso, bloqueadas, pendientes, completadas_hoy FROM daily_dashboard;" \
    2>/dev/null || echo "  (sin datos aún)"

  echo ""
  echo "  Tareas activas:"
  ACTIVE=$(sqlite3 "$MEMORY_DB" \
    "SELECT '  [' || upper(status) || '] ' || title || ' (' || priority || ')' || COALESCE(' → worktree: ' || worktree, '')
     FROM active_tasks
     ${PROJECT:+WHERE project = '$PROJECT'}
     LIMIT 10;" 2>/dev/null)

  if [ -n "$ACTIVE" ]; then
    echo "$ACTIVE"
  else
    echo "  (sin tareas activas)"
  fi
else
  echo "  SQLite no disponible. Inicializar con: ./scripts/db-init.sh"
fi

echo "└────────────────────────────────────────────┘"
echo ""

# ─────────────────────────────────────────────
# 2. Última sesión registrada
# ─────────────────────────────────────────────
echo "┌─ ÚLTIMA SESIÓN ────────────────────────────┐"

if [ "$DB_AVAILABLE" = true ]; then
  LAST_SESSION=$(sqlite3 "$MEMORY_DB" \
    "SELECT '  Proyecto: ' || project || char(10) ||
            '  Fecha:    ' || created_at || char(10) ||
            '  Qué se hizo: ' || summary || char(10) ||
            CASE WHEN next_steps IS NOT NULL
                 THEN '  Pendiente: ' || next_steps
                 ELSE '' END
     FROM sessions
     ${PROJECT:+WHERE project = '$PROJECT'}
     ORDER BY created_at DESC
     LIMIT 1;" 2>/dev/null)

  if [ -n "$LAST_SESSION" ]; then
    echo "$LAST_SESSION"
  else
    echo "  (sin sesiones previas registradas)"
  fi
else
  echo "  SQLite no disponible."
fi

echo "└────────────────────────────────────────────┘"
echo ""

# ─────────────────────────────────────────────
# 3. Worktrees activos
# ─────────────────────────────────────────────
echo "┌─ WORKTREES ACTIVOS ────────────────────────┐"

if git rev-parse --git-dir &>/dev/null 2>&1; then
  WORKTREES=$(git worktree list 2>/dev/null)
  if [ -n "$WORKTREES" ]; then
    echo "$WORKTREES" | while IFS= read -r line; do
      echo "  $line"
    done
  else
    echo "  (sin worktrees activos)"
  fi
else
  echo "  (no estás en un repositorio git)"
fi

echo "└────────────────────────────────────────────┘"
echo ""

# ─────────────────────────────────────────────
# 4. Observaciones recientes (memoria estilo Engram)
# ─────────────────────────────────────────────
echo "┌─ MEMORIA RECIENTE (observaciones) ─────────┐"

if [ "$DB_AVAILABLE" = true ]; then
  # Mostrar últimas 5 observaciones (progressive disclosure: solo título + tipo)
  OBS=$(sqlite3 "$MEMORY_DB" \
    "SELECT '  [' || upper(type) || '] ' || title || ' (' || substr(updated_at,1,10) || ')' ||
            CASE WHEN revision_count > 0 THEN ' rev.' || revision_count ELSE '' END
     FROM observations
     WHERE deleted_at IS NULL
     ${PROJECT:+AND project = '$PROJECT'}
     ORDER BY updated_at DESC
     LIMIT 5;" 2>/dev/null)

  if [ -n "$OBS" ]; then
    echo "$OBS"
    TOTAL_OBS=$(sqlite3 "$MEMORY_DB" "SELECT COUNT(*) FROM observations WHERE deleted_at IS NULL;" 2>/dev/null || echo "0")
    echo "  — Total: $TOTAL_OBS observaciones guardadas"
  else
    # Fallback: mostrar ADRs si no hay observations
    DECISIONS=$(sqlite3 "$MEMORY_DB" \
      "SELECT '  [ADR] ' || title || ' (' || substr(created_at,1,10) || ')'
       FROM decisions
       WHERE status = 'active' AND deleted_at IS NULL
       ORDER BY created_at DESC
       LIMIT 3;" 2>/dev/null)

    if [ -n "$DECISIONS" ]; then
      echo "$DECISIONS"
    else
      echo "  (sin observaciones — usa INSERT INTO observations... para guardar)"
    fi
  fi
fi

echo "└────────────────────────────────────────────┘"
echo ""

# ─────────────────────────────────────────────
# 5. RAG docs disponibles
# ─────────────────────────────────────────────
echo "┌─ KNOWLEDGE BASE (RAG) ─────────────────────┐"

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
RAG_DIR="${GIT_ROOT}/rag"

if [ -n "$GIT_ROOT" ] && [ -d "$RAG_DIR" ]; then
  DOC_COUNT=$(find "$RAG_DIR" \( -name "*.md" -o -name "*.yaml" -o -name "*.txt" \) 2>/dev/null | wc -l | tr -d ' ')
  echo "  Documentos en rag/: $DOC_COUNT archivos"
  echo "  Categorías:"
  for dir in "$RAG_DIR"/*/; do
    [ -d "$dir" ] && echo "    • $(basename "$dir")"
  done
  if [ "${DOC_COUNT:-0}" -eq 0 ]; then
    echo "  (vacío — ejecutar: ./scripts/rag-index.sh)"
  fi
elif [ "$DB_AVAILABLE" = true ]; then
  RAG_IN_DB=$(sqlite3 "$MEMORY_DB" "SELECT COUNT(*) FROM rag_docs;" 2>/dev/null || echo "0")
  echo "  Documentos en SQLite: $RAG_IN_DB indexados"
  if [ "$RAG_IN_DB" -gt 0 ]; then
    sqlite3 "$MEMORY_DB" "SELECT '    • [' || category || '] ' || title FROM rag_docs ORDER BY category LIMIT 10;" 2>/dev/null || true
  fi
else
  echo "  rag/ no encontrado y SQLite no disponible"
fi

echo "└────────────────────────────────────────────┘"
echo ""
echo "  Listo. Empieza con: /spec <descripción> o /sdd <descripción>"
echo ""
