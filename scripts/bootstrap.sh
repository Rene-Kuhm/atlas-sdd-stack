#!/usr/bin/env bash
# bootstrap.sh — Instala y configura el stack completo
# Uso: ./scripts/bootstrap.sh

set -euo pipefail

echo "╔══════════════════════════════════════════════╗"
echo "║   Enterprise AI Stack — Bootstrap            ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ──────────────────────────────────────────────────
# 1. VERIFICAR REQUISITOS
# ──────────────────────────────────────────────────
echo "▶ Verificando requisitos..."

check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo "  ✗ $1 no encontrado. $2"
    MISSING=true
  else
    echo "  ✓ $1"
  fi
}

MISSING=false
check_command "git"    "Instala git: https://git-scm.com"
check_command "node"   "Instala Node.js: https://nodejs.org"
check_command "npx"    "Viene incluido con Node.js"
check_command "python3" "Instala Python 3.11+: https://python.org"
check_command "uv"     "Instala uv: curl -LsSf https://astral.sh/uv/install.sh | sh"
check_command "docker" "Instala Docker: https://docker.com (opcional para algunos MCPs)"

if [ "$MISSING" = true ]; then
  echo ""
  echo "ERROR: Hay dependencias faltantes. Instálalas y vuelve a correr bootstrap.sh"
  exit 1
fi

echo ""

# ──────────────────────────────────────────────────
# 2. INSTALAR MCP SERVERS (Node)
# ──────────────────────────────────────────────────
echo "▶ Instalando MCP servers (Node)..."

MCP_NODE_SERVERS=(
  "@modelcontextprotocol/server-memory"
  "@modelcontextprotocol/server-filesystem"
  "@modelcontextprotocol/server-github"
  "@modelcontextprotocol/server-sequential-thinking"
  "@upstash/context7-mcp"
)

for server in "${MCP_NODE_SERVERS[@]}"; do
  echo "  → Instalando $server..."
  npx -y "$server" --version &> /dev/null 2>&1 || true
  echo "  ✓ $server"
done

echo ""

# ──────────────────────────────────────────────────
# 3. INSTALAR MCP SERVERS (Python/uvx)
# ──────────────────────────────────────────────────
echo "▶ Instalando MCP servers (Python)..."

MCP_PYTHON_SERVERS=(
  "mcp-server-git"
  "mcp-server-sqlite"
  "mcp-server-fetch"
)

for server in "${MCP_PYTHON_SERVERS[@]}"; do
  echo "  → Instalando $server..."
  uv tool install "$server" --quiet 2>/dev/null || echo "  ⚠ $server: instalación manual puede ser necesaria"
  echo "  ✓ $server"
done

echo ""

# ──────────────────────────────────────────────────
# 4. INICIALIZAR BASE DE DATOS DE MEMORIA
# ──────────────────────────────────────────────────
echo "▶ Inicializando base de datos de memoria..."

MEMORY_DIR="$HOME/.local/enterprise-ai"
mkdir -p "$MEMORY_DIR"

if command -v sqlite3 &> /dev/null; then
  sqlite3 "$MEMORY_DIR/memory.db" < "$(dirname "$0")/../memory/schema.sql"
  echo "  ✓ DB inicializada en $MEMORY_DIR/memory.db"
else
  echo "  ⚠ sqlite3 no disponible. La DB se creará automáticamente al primer uso."
fi

echo ""

# ──────────────────────────────────────────────────
# 5. INSTALAR GIT HOOKS
# ──────────────────────────────────────────────────
echo "▶ Instalando git hooks..."

HOOKS_DIR=".git/hooks"
if [ -d "$HOOKS_DIR" ]; then
  cp hooks/pre-commit "$HOOKS_DIR/pre-commit"
  cp hooks/prepare-commit-msg "$HOOKS_DIR/prepare-commit-msg"
  chmod +x "$HOOKS_DIR/pre-commit" "$HOOKS_DIR/prepare-commit-msg"
  echo "  ✓ Hooks instalados"
else
  echo "  ⚠ No es un repositorio git. Inicializa con 'git init' primero."
fi

echo ""

# ──────────────────────────────────────────────────
# 6. DAR PERMISOS A SCRIPTS
# ──────────────────────────────────────────────────
echo "▶ Configurando permisos de scripts..."
chmod +x scripts/*.sh
chmod +x hooks/*
echo "  ✓ Permisos configurados"

echo ""

# ──────────────────────────────────────────────────
# 7. VERIFICAR VARIABLES DE ENTORNO
# ──────────────────────────────────────────────────
echo "▶ Verificando variables de entorno..."

check_env() {
  if [ -z "${!1:-}" ]; then
    echo "  ⚠ $1 no configurada (necesaria para $2)"
  else
    echo "  ✓ $1"
  fi
}

check_env "ANTHROPIC_API_KEY" "Claude Code / Claude API"
check_env "GITHUB_TOKEN"      "MCP GitHub server"
check_env "OPENAI_API_KEY"    "modelos OpenAI (opcional)"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   Bootstrap completado                       ║"
echo "╠══════════════════════════════════════════════╣"
echo "║   Próximos pasos:                            ║"
echo "║   1. Configura las variables de entorno      ║"
echo "║   2. Ejecuta: claude (en la raíz)            ║"
echo "║   3. Inicia con: /sdd tu primera tarea       ║"
echo "╚══════════════════════════════════════════════╝"
