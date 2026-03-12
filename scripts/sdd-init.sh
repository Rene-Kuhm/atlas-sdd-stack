#!/usr/bin/env bash
# sdd-init.sh — Inicializa la estructura openspec/ en un proyecto
# Uso: bash scripts/sdd-init.sh [nombre-del-cambio]
# Sin args: solo crea la estructura base openspec/

set -euo pipefail

export PATH="/c/Program Files/nodejs:/c/Users/insyd/AppData/Local/Microsoft/WinGet/Packages/SQLite.SQLite_Microsoft.Winget.Source_8wekyb3d8bbwe:/c/Users/insyd/AppData/Local/Microsoft/WinGet/Packages/astral-sh.uv_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"

CHANGE_NAME="${1:-}"
PROJECT_DIR="${2:-$(pwd)}"
TODAY=$(date '+%Y-%m-%d')
MEMORY_DB="${USERPROFILE:-$HOME}/.local/enterprise-ai/memory.db"

echo ""
echo "╔══════════════════════════════════╗"
echo "║      SDD Init — OpenSpec         ║"
echo "╚══════════════════════════════════╝"
echo "  Proyecto: $PROJECT_DIR"
echo ""

# ─────────────────────────────────────────────
# 1. Crear estructura base openspec/
# ─────────────────────────────────────────────
mkdir -p "$PROJECT_DIR/openspec/specs"
mkdir -p "$PROJECT_DIR/openspec/changes/archive"

if [ ! -f "$PROJECT_DIR/openspec/README.md" ]; then
  cat > "$PROJECT_DIR/openspec/README.md" << 'EOF'
# OpenSpec

Especificaciones del sistema organizadas bajo SDD (Spec Driven Development).

## Estructura

```
openspec/
  specs/          ← Specs canónicas (fuente de verdad)
  changes/        ← Cambios en progreso (pipeline ATL)
    <nombre>/     ← Un cambio activo
      state.yaml  ← Estado del DAG pipeline
      proposal.md ← Propuesta (requiere aprobación)
      specs/      ← Delta specs de este cambio
      design.md   ← Decisiones de diseño
      tasks.md    ← Plan de tareas
      apply-progress.md ← Progreso de implementación
      verify-report.md  ← Reporte de verificación
    archive/      ← Cambios completados y archivados
```

## Pipeline ATL

```
Explorer → Proposer → [GATE] → SpecWriter → Designer → TaskPlanner → Implementer → Verifier → Archiver
```

Iniciar un nuevo cambio: `/sdd new <nombre>`
EOF
  echo "  ✓ openspec/README.md creado"
fi

echo "  ✓ Estructura base openspec/ lista"

# ─────────────────────────────────────────────
# 2. Si se especificó nombre de cambio, crear carpeta
# ─────────────────────────────────────────────
if [ -n "$CHANGE_NAME" ]; then
  CHANGE_DIR="$PROJECT_DIR/openspec/changes/$CHANGE_NAME"

  if [ -d "$CHANGE_DIR" ]; then
    echo ""
    echo "⚠️  Ya existe: openspec/changes/$CHANGE_NAME"
    echo "   Usa /sdd-new $CHANGE_NAME para continuar desde donde quedó."
    exit 0
  fi

  mkdir -p "$CHANGE_DIR/specs"

  # Crear state.yaml desde template
  TEMPLATE_SRC="/c/Users/insyd/enterprise-ai-stack/templates/openspec-state.yaml"
  if [ -f "$TEMPLATE_SRC" ]; then
    sed \
      -e "s/<change-name>/$CHANGE_NAME/g" \
      -e "s/YYYY-MM-DD/$TODAY/g" \
      "$TEMPLATE_SRC" > "$CHANGE_DIR/state.yaml"
  else
    cat > "$CHANGE_DIR/state.yaml" << EOF
change: "$CHANGE_NAME"
artifact_store: "openspec"
status: "exploring"
phase: "explore"
started: "$TODAY"
last_updated: "$TODAY"
phases_completed: []
phases_pending:
  - explore
  - propose
  - spec
  - design
  - tasks
  - apply
  - verify
  - archive
gates:
  proposal_approved: false
  archive_approved: false
artifacts:
  exploration: ""
  proposal: ""
  specs: []
  design: ""
  tasks: ""
  apply_progress: ""
  verify_report: ""
  archive_report: ""
worktree: "feat/$CHANGE_NAME"
agents_used: []
EOF
  fi

  echo ""
  echo "  ✓ openspec/changes/$CHANGE_NAME/ creado"
  echo "  ✓ state.yaml inicializado (fase: explore)"

  # Registrar en SQLite si disponible
  if command -v sqlite3 &>/dev/null && [ -f "$MEMORY_DB" ]; then
    TASK_ID=$(echo "${CHANGE_NAME}-${TODAY}" | sha256sum | cut -c1-16)
    sqlite3 "$MEMORY_DB" \
      "INSERT OR IGNORE INTO tasks (id, project, title, status, priority, worktree, tags)
       VALUES ('$TASK_ID', '$(basename $PROJECT_DIR)', 'SDD: $CHANGE_NAME', 'todo', 'medium', 'feat/$CHANGE_NAME', 'sdd,atl');" 2>/dev/null
    echo "  ✓ Tarea registrada en SQLite (id: $TASK_ID)"
  fi

  echo ""
  echo "Próximo paso: /sdd-new $CHANGE_NAME"
fi

echo ""
echo "✓ SDD Init completado"
echo ""
