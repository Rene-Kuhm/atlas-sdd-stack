#!/usr/bin/env bash
# worktree-create.sh — Crea un worktree aislado para una tarea
# Uso: ./scripts/worktree-create.sh feat/user-pagination

set -euo pipefail

BRANCH_NAME="${1:-}"

if [ -z "$BRANCH_NAME" ]; then
  echo "ERROR: Debes especificar el nombre del branch."
  echo "Uso: ./scripts/worktree-create.sh <tipo>/<nombre>"
  echo "Ejemplos:"
  echo "  ./scripts/worktree-create.sh feat/user-pagination"
  echo "  ./scripts/worktree-create.sh fix/api-timeout"
  exit 1
fi

# Validar formato del branch
if ! echo "$BRANCH_NAME" | grep -qE '^(feat|fix|refactor|test|docs|chore)/[a-z0-9-]+$'; then
  echo "ERROR: El nombre del branch debe seguir el formato <tipo>/<descripcion-en-kebab>"
  echo "Tipos válidos: feat, fix, refactor, test, docs, chore"
  exit 1
fi

WORKTREE_DIR=".worktrees/$(echo "$BRANCH_NAME" | tr '/' '-')"
ROOT_DIR="$(git rev-parse --show-toplevel)"
WORKTREE_PATH="$ROOT_DIR/$WORKTREE_DIR"

# Verificar que no existe ya
if [ -d "$WORKTREE_PATH" ]; then
  echo "ERROR: El worktree '$WORKTREE_DIR' ya existe en $WORKTREE_PATH"
  exit 1
fi

# Crear directorio base si no existe
mkdir -p "$ROOT_DIR/.worktrees"

# Asegurarse de estar en main actualizado
echo "→ Actualizando main..."
git fetch origin main --quiet

# Crear el worktree y el branch
echo "→ Creando worktree: $WORKTREE_DIR"
git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH" origin/main

# Copiar .env.local si existe (no se versiona pero el worktree lo necesita)
if [ -f "$ROOT_DIR/.env.local" ]; then
  cp "$ROOT_DIR/.env.local" "$WORKTREE_PATH/.env.local"
  echo "→ .env.local copiado"
fi

echo ""
echo "✓ Worktree creado exitosamente"
echo ""
echo "  Branch:  $BRANCH_NAME"
echo "  Ruta:    $WORKTREE_PATH"
echo ""
echo "  Para trabajar en él (nueva terminal):"
echo "  cd $WORKTREE_PATH"
echo ""
echo "  Cuando termines:"
echo "  ./scripts/worktree-merge.sh $(echo "$BRANCH_NAME" | tr '/' '-')"
