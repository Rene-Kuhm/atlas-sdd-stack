#!/usr/bin/env bash
# gga-install-all.sh — Instala el pre-commit hook GGA en todos los repos git encontrados
# Uso: bash scripts/gga-install-all.sh [directorio-raiz]
# Default: busca en ~/Documents, ~/projects, ~/dev, ~/code, ~/repos, ~/work, ~/src

set -euo pipefail

export PATH="/c/Program Files/nodejs:/c/Users/insyd/AppData/Local/Microsoft/WinGet/Packages/SQLite.SQLite_Microsoft.Winget.Source_8wekyb3d8bbwe:/c/Users/insyd/AppData/Local/Microsoft/WinGet/Packages/astral-sh.uv_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"

HOOK_SRC="/c/Users/insyd/enterprise-ai-stack/hooks/pre-commit"
GGA_MARKER="GGA Pre-commit Review v2"

SEARCH_DIRS=()
if [ $# -gt 0 ]; then
  SEARCH_DIRS=("$@")
else
  # Directorios comunes donde viven proyectos
  for d in \
    "/c/Users/insyd/Documents" \
    "/c/Users/insyd/projects" \
    "/c/Users/insyd/dev" \
    "/c/Users/insyd/code" \
    "/c/Users/insyd/repos" \
    "/c/Users/insyd/work" \
    "/c/Users/insyd/src" \
    "/c/Users/insyd/Desktop"; do
    [ -d "$d" ] && SEARCH_DIRS+=("$d")
  done
fi

if [ ${#SEARCH_DIRS[@]} -eq 0 ]; then
  echo "No se encontraron directorios de búsqueda."
  echo "Uso: $0 /ruta/a/tus/proyectos"
  exit 0
fi

if [ ! -f "$HOOK_SRC" ]; then
  echo "ERROR: Hook no encontrado en $HOOK_SRC"
  exit 1
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   GGA — Instalación Masiva de Hooks      ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Buscando repos en:"
for d in "${SEARCH_DIRS[@]}"; do
  echo "  • $d"
done
echo ""

INSTALLED=0
SKIPPED_EXISTING=0
SKIPPED_OTHER_HOOK=0
ERRORS=0

while IFS= read -r git_dir; do
  repo_dir=$(dirname "$git_dir")
  hook_dst="$git_dir/hooks/pre-commit"

  # Saltar el propio enterprise-ai-stack (tiene su propio ciclo de vida)
  [[ "$repo_dir" == *"enterprise-ai-stack"* ]] && continue

  # Si ya existe un hook GGA → skip silencioso
  if [ -f "$hook_dst" ] && grep -q "$GGA_MARKER" "$hook_dst" 2>/dev/null; then
    SKIPPED_EXISTING=$((SKIPPED_EXISTING + 1))
    continue
  fi

  # Si existe un hook de OTRO tool → NO sobreescribir, avisar
  if [ -f "$hook_dst" ]; then
    echo "  ⚠ Hook existente (no GGA) en: $repo_dir"
    echo "    → No se sobreescribe. Revisar manualmente."
    SKIPPED_OTHER_HOOK=$((SKIPPED_OTHER_HOOK + 1))
    continue
  fi

  # Instalar hook
  mkdir -p "$git_dir/hooks"
  if cp "$HOOK_SRC" "$hook_dst" && chmod +x "$hook_dst"; then
    echo "  ✓ $(basename "$repo_dir") ($repo_dir)"
    INSTALLED=$((INSTALLED + 1))
  else
    echo "  ✗ Error en: $repo_dir"
    ERRORS=$((ERRORS + 1))
  fi

done < <(find "${SEARCH_DIRS[@]}" -maxdepth 5 -name ".git" -type d 2>/dev/null | sort)

echo ""
echo "╔══════════════════════════════════════════╗"
echo "  Resultado:"
echo "  ✓ Instalados:        $INSTALLED repos"
echo "  · Ya tenían GGA:     $SKIPPED_EXISTING repos"
echo "  ⚠ Hook ajeno (skip): $SKIPPED_OTHER_HOOK repos"
[ $ERRORS -gt 0 ] && echo "  ✗ Errores:           $ERRORS repos"
echo "╚══════════════════════════════════════════╝"
echo ""
