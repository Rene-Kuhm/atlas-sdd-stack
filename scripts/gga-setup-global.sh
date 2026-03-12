#!/usr/bin/env bash
# gga-setup-global.sh — Configura GGA para que se instale automáticamente en TODO futuro repo
# Mecanismos:
#   1. Git global template → git init / git clone reciben el hook automáticamente
#   2. Imprime las líneas para añadir a .bashrc (PROMPT_COMMAND para repos existentes)
#   3. Ejecuta gga-install-all.sh para repos ya existentes
#
# Uso: bash scripts/gga-setup-global.sh

set -euo pipefail

HOOK_SRC="/c/Users/insyd/enterprise-ai-stack/hooks/pre-commit"
TEMPLATE_DIR="$HOME/.git-templates"
STACK_SCRIPTS="/c/Users/insyd/enterprise-ai-stack/scripts"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   GGA — Setup Global Automático          ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ──────────────────────────────────────────────────────────────────
# 1. Git global template directory
# Cualquier git init o git clone usará este template
# ──────────────────────────────────────────────────────────────────
echo "▶ Configurando git template global..."

mkdir -p "$TEMPLATE_DIR/hooks"
cp "$HOOK_SRC" "$TEMPLATE_DIR/hooks/pre-commit"
chmod +x "$TEMPLATE_DIR/hooks/pre-commit"

git config --global init.templateDir "$TEMPLATE_DIR"

echo "  ✓ Template: $TEMPLATE_DIR"
echo "  ✓ git config global init.templateDir configurado"
echo "  → Cualquier git init / git clone incluirá el hook automáticamente"
echo ""

# ──────────────────────────────────────────────────────────────────
# 2. Añadir PROMPT_COMMAND a .bashrc (si no está ya)
# Auto-instala el hook al hacer cd a un repo sin hook
# ──────────────────────────────────────────────────────────────────
echo "▶ Configurando auto-install en cd (PROMPT_COMMAND)..."

BASHRC="$HOME/.bashrc"
GGA_PROMPT_MARKER="# GGA_AUTO_HOOK"

if grep -q "$GGA_PROMPT_MARKER" "$BASHRC" 2>/dev/null; then
  echo "  · PROMPT_COMMAND ya configurado en .bashrc"
else
  cat >> "$BASHRC" << 'BASHRC_BLOCK'

# GGA_AUTO_HOOK — Auto-instala pre-commit hook al entrar en repos git sin hook
_gga_auto_hook() {
  local git_dir hook_dst hook_src gga_marker
  hook_src="/c/Users/insyd/enterprise-ai-stack/hooks/pre-commit"
  gga_marker="GGA Pre-commit Review v2"

  [ -f "$hook_src" ] || return 0

  git_dir=$(git rev-parse --git-dir 2>/dev/null || echo "")
  [ -z "$git_dir" ] && return 0

  hook_dst="$git_dir/hooks/pre-commit"

  # Solo instalar si: no existe ningún hook
  if [ ! -f "$hook_dst" ]; then
    mkdir -p "$git_dir/hooks"
    cp "$hook_src" "$hook_dst"
    chmod +x "$hook_dst"
    echo "  ✓ GGA hook auto-instalado en $(basename "$(pwd)")"
  fi
}

# Ejecutar antes de cada prompt (después de cd, ls, cualquier comando)
PROMPT_COMMAND="${PROMPT_COMMAND:+${PROMPT_COMMAND}; }_gga_auto_hook"
BASHRC_BLOCK

  echo "  ✓ PROMPT_COMMAND añadido a .bashrc"
  echo "  → Al hacer cd a cualquier repo sin hook, se instala automáticamente"
fi

echo ""

# ──────────────────────────────────────────────────────────────────
# 3. Instalar en repos existentes ahora
# ──────────────────────────────────────────────────────────────────
echo "▶ Instalando en repos existentes..."
echo ""
bash "$STACK_SCRIPTS/gga-install-all.sh"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Setup completo. Ahora es automático:   ║"
echo "║                                          ║"
echo "║  git clone → hook incluido               ║"
echo "║  git init  → hook incluido               ║"
echo "║  cd repo   → hook instalado si falta     ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  Para aplicar PROMPT_COMMAND en esta terminal:"
echo "    source ~/.bashrc"
echo ""
