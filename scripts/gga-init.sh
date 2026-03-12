#!/usr/bin/env bash
# gga-init.sh — Inicializa GGA en cualquier proyecto
# Genera .gga config + instala/actualiza el pre-commit hook
# Uso: bash /c/Users/insyd/enterprise-ai-stack/scripts/gga-init.sh [--provider claude] [--install-hook]

set -euo pipefail

export PATH="/c/Program Files/nodejs:/c/Users/insyd/AppData/Local/Microsoft/WinGet/Packages/SQLite.SQLite_Microsoft.Winget.Source_8wekyb3d8bbwe:/c/Users/insyd/AppData/Local/Microsoft/WinGet/Packages/astral-sh.uv_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"

PROVIDER="claude"
INSTALL_HOOK=false
PROJECT_DIR="$(pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider) PROVIDER="$2"; shift 2 ;;
    --install-hook) INSTALL_HOOK=true; shift ;;
    --dir) PROJECT_DIR="$2"; shift 2 ;;
    *) echo "Arg desconocido: $1" >&2; exit 1 ;;
  esac
done

echo ""
echo "╔══════════════════════════════════╗"
echo "║         GGA Init                 ║"
echo "╚══════════════════════════════════╝"
echo "  Proyecto: $PROJECT_DIR"
echo "  Provider: $PROVIDER"
echo ""

if ! git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null 2>&1; then
  echo "ERROR: '$PROJECT_DIR' no es un repositorio git."
  exit 1
fi

# ──────────────────────────────────────────────────────────────────
# 1. Generar .gga si no existe
# ──────────────────────────────────────────────────────────────────
GGA_CONFIG="$PROJECT_DIR/.gga"

if [ -f "$GGA_CONFIG" ]; then
  echo "  · .gga ya existe — no se sobreescribirá"
  echo "    Para recrear: rm .gga && bash gga-init.sh"
else
  cat > "$GGA_CONFIG" << EOF
# GGA Config — Code Review con IA
# Generado por gga-init.sh

# Provider de IA: claude | gemini | ollama | lmstudio | github-models | opencode
PROVIDER=$PROVIDER

# Modelo (opcional — requerido para ollama)
# MODEL=llama3.2
# MODEL=gpt-4o-mini
MODEL=

# Timeout en segundos antes de abortar el review
TIMEOUT=60

# Archivos a incluir en el review (vacío = todos)
# INCLUDE=*.py,*.ts,*.tsx,*.js,*.go,*.rs,*.java
INCLUDE=

# Archivos a excluir siempre
EXCLUDE=*.lock,*.min.js,*.min.css,dist/*,build/*,node_modules/*,.git/*,*_generated.*,*.pb.go

# Máximo de archivos por review (evitar exceder contexto del AI)
MAX_FILES=20

# Rama base para PR mode (vacío = autodetect: main/master/develop)
BASE_BRANCH=
EOF
  echo "  ✓ .gga creado"
fi

# ──────────────────────────────────────────────────────────────────
# 2. Verificar/crear AGENTS.md si no existe
# ──────────────────────────────────────────────────────────────────
AGENTS_FILE="$PROJECT_DIR/AGENTS.md"

if [ ! -f "$AGENTS_FILE" ]; then
  cat > "$AGENTS_FILE" << 'EOF'
# AGENTS.md — Reglas del Proyecto para Code Review

## Estándares de Código

- Funciones: máximo 30 líneas. Si supera, extraer en funciones más pequeñas.
- Archivos: máximo 300 líneas. Si supera, modularizar.
- Nombres: descriptivos, en inglés, sin abreviaciones confusas.
- Sin comentarios obvios. Los comentarios explican el *por qué*, no el *qué*.
- Sin código comentado (dead code). Si no se usa, borrar.

## Seguridad

- NUNCA hardcodear credenciales, API keys, passwords o tokens.
- NUNCA usar `eval` con inputs externos.
- Validar TODA entrada del usuario en el boundary del sistema.
- No loguear datos sensibles (passwords, tokens, PII).

## Manejo de Errores

- No silenciar errores con `catch {}` vacío o `except: pass`.
- Toda excepción atrapada debe loguearse o re-lanzarse con contexto.
- Los errores de validación deben dar mensajes útiles al usuario.

## Tests

- Todo nuevo feature debe incluir tests.
- Todo bugfix debe incluir un test que habría fallado antes del fix.
- No mockear la lógica de negocio central — mockear solo dependencias externas.

## Convenciones Git

- Commits en formato: `tipo(scope): descripción` (conventional commits)
- Tipos válidos: feat, fix, refactor, test, docs, chore
EOF
  echo "  ✓ AGENTS.md creado con reglas base"
  echo "    → Edítalo para agregar las reglas específicas de tu proyecto"
else
  echo "  · AGENTS.md ya existe ($(wc -l < "$AGENTS_FILE") líneas)"
fi

# ──────────────────────────────────────────────────────────────────
# 3. Instalar pre-commit hook (si se pidió)
# ──────────────────────────────────────────────────────────────────
GIT_DIR=$(git -C "$PROJECT_DIR" rev-parse --git-dir 2>/dev/null)
HOOK_SRC="/c/Users/insyd/enterprise-ai-stack/hooks/pre-commit"
HOOK_DST="$PROJECT_DIR/$GIT_DIR/hooks/pre-commit"

if [ "$INSTALL_HOOK" = true ]; then
  if [ ! -f "$HOOK_SRC" ]; then
    echo "  ERROR: pre-commit hook no encontrado en $HOOK_SRC"
  else
    mkdir -p "$(dirname "$HOOK_DST")"
    cp "$HOOK_SRC" "$HOOK_DST"
    chmod +x "$HOOK_DST"
    echo "  ✓ pre-commit hook instalado en $HOOK_DST"
  fi
else
  echo ""
  echo "  Para instalar el hook en este proyecto:"
  echo "    bash /c/Users/insyd/enterprise-ai-stack/scripts/gga-init.sh --install-hook"
  echo ""
  echo "  O manualmente:"
  echo "    cp /c/Users/insyd/enterprise-ai-stack/hooks/pre-commit $PROJECT_DIR/.git/hooks/pre-commit"
  echo "    chmod +x $PROJECT_DIR/.git/hooks/pre-commit"
fi

# ──────────────────────────────────────────────────────────────────
# 4. Añadir .gga al .gitignore si no está ya
# ──────────────────────────────────────────────────────────────────
GITIGNORE="$PROJECT_DIR/.gitignore"
if [ -f "$GITIGNORE" ] && grep -q "^\.gga$" "$GITIGNORE" 2>/dev/null; then
  echo "  · .gga ya está en .gitignore"
else
  echo "" >> "$GITIGNORE" 2>/dev/null || true
  echo "# GGA config (puede contener configuración local del desarrollador)" >> "$GITIGNORE" 2>/dev/null || true
  echo ".gga" >> "$GITIGNORE" 2>/dev/null || true
  echo "  ✓ .gga añadido a .gitignore"
fi

echo ""
echo "╔══════════════════════════════════╗"
echo "║   Próximos pasos                 ║"
echo "╚══════════════════════════════════╝"
echo ""
echo "  1. Edita AGENTS.md con las reglas de tu proyecto"
echo "  2. Edita .gga para configurar provider y modelo"
echo "  3. Instala el hook (si no lo hiciste ya):"
echo "     bash /c/Users/insyd/enterprise-ai-stack/scripts/gga-init.sh --install-hook"
echo ""
echo "  Para hacer un review manual:"
echo "     bash /c/Users/insyd/enterprise-ai-stack/scripts/gga-review.sh --staged"
echo "     bash /c/Users/insyd/enterprise-ai-stack/scripts/gga-review.sh --pr --diff-only"
echo "     bash /c/Users/insyd/enterprise-ai-stack/scripts/gga-review.sh --ci"
echo ""
