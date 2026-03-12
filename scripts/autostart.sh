#!/usr/bin/env bash
# autostart.sh — Se llama desde .bashrc al abrir terminal
# Muestra el dashboard solo UNA VEZ por día por terminal (flag en /tmp)
# Seguro de ejecutar múltiples veces: el check de flag lo controla

FLAG_FILE="/tmp/ai-session-$(date +%Y%m%d)-$USER"

# Salir si ya se mostró hoy en esta máquina
[ -f "$FLAG_FILE" ] && exit 0
touch "$FLAG_FILE"

STACK_DIR="/c/Users/insyd/enterprise-ai-stack"

# PATH necesario para que sqlite3 funcione
export PATH="/c/Program Files/nodejs:/c/Users/insyd/AppData/Local/Microsoft/WinGet/Packages/SQLite.SQLite_Microsoft.Winget.Source_8wekyb3d8bbwe:/c/Users/insyd/AppData/Local/Microsoft/WinGet/Packages/astral-sh.uv_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"

bash "$STACK_DIR/scripts/session-start.sh" 2>/dev/null || true

# Background: indexar RAG + skill registry (no bloquea la terminal)
{
  bash "$STACK_DIR/scripts/rag-index.sh" \
    --dir "$STACK_DIR/rag" \
    --project "stack" 2>/dev/null | grep -E "Resultado:|✗"

  bash "$STACK_DIR/scripts/rag-index.sh" \
    --dir "$STACK_DIR/agents" \
    --project "stack" 2>/dev/null | grep -E "Resultado:|✗"

  bash "$STACK_DIR/scripts/rag-index.sh" \
    --dir "/c/Users/insyd/ObsidianVault/Enterprise AI Stack" \
    --project "obsidian" 2>/dev/null | grep -E "Resultado:|✗"

  bash "$STACK_DIR/scripts/skill-registry.sh" "$STACK_DIR" 2>/dev/null | grep -E "✓ Skill|✓ Indexado"

  # Mantener git template sincronizado con la versión actual del hook
  cp "$STACK_DIR/hooks/pre-commit" "$HOME/.git-templates/hooks/pre-commit" 2>/dev/null && \
  chmod +x "$HOME/.git-templates/hooks/pre-commit" 2>/dev/null || true
} &
