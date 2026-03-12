#!/usr/bin/env bash
# obsidian-sync.sh — Exporta SQLite (sesiones, tareas, ADRs) a Obsidian vault
# Uso: ./scripts/obsidian-sync.sh
# Se llama automáticamente desde session-end.sh

set -euo pipefail

export PATH="/c/Program Files/nodejs:/c/Users/insyd/AppData/Local/Microsoft/WinGet/Packages/SQLite.SQLite_Microsoft.Winget.Source_8wekyb3d8bbwe:/c/Users/insyd/AppData/Local/Microsoft/WinGet/Packages/astral-sh.uv_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"

MEMORY_DB="${USERPROFILE:-$HOME}/.local/enterprise-ai/memory.db"
VAULT_DIR="/c/Users/insyd/ObsidianVault/Enterprise AI Stack"
TODAY=$(date '+%Y-%m-%d')

if ! command -v sqlite3 &>/dev/null; then
  echo "ERROR: sqlite3 no disponible"
  exit 1
fi

if [ ! -f "$MEMORY_DB" ]; then
  echo "ERROR: DB no encontrada"
  exit 1
fi

echo ""
echo "╔══════════════════════════════════╗"
echo "║     Obsidian Sync                ║"
echo "╚══════════════════════════════════╝"
echo "  Vault: $VAULT_DIR"
echo ""

# ─────────────────────────────────────────────
# 1. Exportar sesión de hoy a Daily/
# ─────────────────────────────────────────────
LAST_SESSION=$(sqlite3 "$MEMORY_DB" \
  "SELECT project || '|||' || summary || '|||' || COALESCE(next_steps,'') || '|||' || COALESCE(files,'')
   FROM sessions
   ORDER BY created_at DESC LIMIT 1;" 2>/dev/null || echo "")

if [ -n "$LAST_SESSION" ]; then
  IFS='|||' read -r S_PROJECT S_SUMMARY S_NEXT S_FILES <<< "$LAST_SESSION"
  SESSION_FILE="$VAULT_DIR/Sesiones/$TODAY.md"

  cat > "$SESSION_FILE" << MDEOF
---
tipo: sesion
fecha: $TODAY
proyecto: $S_PROJECT
tags: [sesion, daily]
---

# Sesión $TODAY — $S_PROJECT

## Qué se hizo
$S_SUMMARY

## Pendiente
$([ -n "$S_NEXT" ] && echo "$S_NEXT" || echo "_nada pendiente_")

## Archivos modificados
$([ -n "$S_FILES" ] && echo "$S_FILES" | tr ',' '\n' | sed 's/^/- /' || echo "_sin cambios registrados_")

---
*Exportado automáticamente desde SQLite*
MDEOF

  echo "  ✓ Sesión exportada → Sesiones/$TODAY.md"
fi

# ─────────────────────────────────────────────
# 2. Exportar tareas activas a Tareas/
# ─────────────────────────────────────────────
TASK_FILE="$VAULT_DIR/Tareas/activas.md"

{
  echo "---"
  echo "tipo: tareas"
  echo "actualizado: $TODAY"
  echo "tags: [tareas, dashboard]"
  echo "---"
  echo ""
  echo "# Tareas Activas"
  echo ""
  echo "_Actualizado: ${TODAY}_"
  echo ""
  echo "## En Progreso"
  echo ""
  sqlite3 "$MEMORY_DB" \
    "SELECT '- [ ] **' || title || '** (' || priority || ') — worktree: ' || COALESCE(worktree, 'sin asignar')
     FROM tasks WHERE status = 'in_progress'
     ORDER BY CASE priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END;" \
    2>/dev/null || echo "_ninguna_"
  echo ""
  echo "## Bloqueadas"
  echo ""
  sqlite3 "$MEMORY_DB" \
    "SELECT '- ⛔ **' || title || '** — ' || COALESCE(blocked_by, 'sin especificar')
     FROM tasks WHERE status = 'blocked';" \
    2>/dev/null || echo "_ninguna_"
  echo ""
  echo "## Pendientes (siguiente)"
  echo ""
  sqlite3 "$MEMORY_DB" \
    "SELECT '- [ ] ' || title || ' (' || priority || ')'
     FROM tasks WHERE status = 'pending'
     ORDER BY CASE priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END
     LIMIT 10;" \
    2>/dev/null || echo "_ninguna_"
  echo ""
  echo "## Completadas hoy"
  echo ""
  sqlite3 "$MEMORY_DB" \
    "SELECT '- ✅ ' || title
     FROM tasks WHERE status = 'done' AND done_at >= date('now');" \
    2>/dev/null || echo "_ninguna_"
} > "$TASK_FILE"

echo "  ✓ Tareas exportadas → Tareas/activas.md"

# ─────────────────────────────────────────────
# 3. Exportar ADRs a Decisiones/
# ─────────────────────────────────────────────
DECISION_COUNT=$(sqlite3 "$MEMORY_DB" "SELECT COUNT(*) FROM decisions WHERE status='active';" 2>/dev/null || echo "0")

if [ "$DECISION_COUNT" -gt 0 ]; then
  INDEX_FILE="$VAULT_DIR/Decisiones/index.md"
  {
    echo "---"
    echo "tipo: indice"
    echo "actualizado: $TODAY"
    echo "tags: [adr, indice]"
    echo "---"
    echo ""
    echo "# Decisiones Arquitectónicas"
    echo ""
    sqlite3 "$MEMORY_DB" \
      "SELECT '- **' || title || '** (' || substr(created_at,1,10) || ') — ' || substr(reasoning,1,80)
       FROM decisions WHERE status='active'
       ORDER BY created_at DESC;" \
      2>/dev/null
  } > "$INDEX_FILE"
  echo "  ✓ ADRs exportadas → Decisiones/index.md"
fi

# ─────────────────────────────────────────────
# 4. Indexar vault en RAG (bidireccional)
# ─────────────────────────────────────────────
STACK_DIR="/c/Users/insyd/enterprise-ai-stack"
bash "$STACK_DIR/scripts/rag-index.sh" \
  --dir "$VAULT_DIR" \
  --project "obsidian-vault" 2>/dev/null | grep -E "✓|✗|Resultado" || true

echo ""
echo "✓ Sync completado — Abre Obsidian para ver los cambios"
echo ""
