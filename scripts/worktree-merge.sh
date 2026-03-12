#!/usr/bin/env bash
# worktree-merge.sh — Crea PR y limpia el worktree al terminar
# Uso: ./scripts/worktree-merge.sh feat-user-pagination

set -euo pipefail

WORKTREE_SLUG="${1:-}"

if [ -z "$WORKTREE_SLUG" ]; then
  echo "ERROR: Especifica el slug del worktree."
  echo "Uso: ./scripts/worktree-merge.sh <slug>"
  echo ""
  echo "Worktrees activos:"
  git worktree list
  exit 1
fi

ROOT_DIR="$(git rev-parse --show-toplevel)"
WORKTREE_PATH="$ROOT_DIR/.worktrees/$WORKTREE_SLUG"
BRANCH_NAME=$(echo "$WORKTREE_SLUG" | sed 's/-/\//1')  # feat-name → feat/name

# Verificar que existe
if [ ! -d "$WORKTREE_PATH" ]; then
  echo "ERROR: No se encontró el worktree en $WORKTREE_PATH"
  echo ""
  echo "Worktrees activos:"
  git worktree list
  exit 1
fi

echo "→ Verificando estado del worktree..."
cd "$WORKTREE_PATH"

# Verificar que no hay cambios sin commitear
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: Hay cambios sin commitear en el worktree."
  echo "Haz commit de tus cambios primero."
  git status --short
  exit 1
fi

# Push del branch
echo "→ Pushing branch $BRANCH_NAME..."
git push -u origin "$BRANCH_NAME"

# Crear PR si gh está disponible
if command -v gh &> /dev/null; then
  echo "→ Creando Pull Request..."

  # Obtener el último mensaje de commit como título del PR
  PR_TITLE=$(git log --oneline -1 | sed 's/^[a-f0-9]* //')

  gh pr create \
    --title "$PR_TITLE" \
    --body "$(cat <<EOF
## Cambios

<!-- Describe los cambios realizados -->

## Tests

- [ ] Tests unitarios pasan
- [ ] Tests de integración pasan (si aplica)
- [ ] Review del GGA completado

## Checklist

- [ ] AGENTS.md del módulo respetado
- [ ] Sin secrets en el código
- [ ] Commit message sigue la convención

🤖 Generado desde worktree: $WORKTREE_SLUG
EOF
)"

  PR_URL=$(gh pr view --json url -q .url)
  echo "✓ PR creado: $PR_URL"
else
  echo "→ gh CLI no disponible. Push realizado. Crea el PR manualmente."
fi

# Volver al root y limpiar el worktree
cd "$ROOT_DIR"
echo "→ Limpiando worktree..."
git worktree remove "$WORKTREE_PATH" --force

echo ""
echo "✓ Worktree '$WORKTREE_SLUG' eliminado"
echo "  Branch '$BRANCH_NAME' está en origin, listo para review."
