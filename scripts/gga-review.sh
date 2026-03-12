#!/usr/bin/env bash
# gga-review.sh — CLI de code review con IA multi-provider (estilo GGA)
#
# Modos:
#   --staged         Review de archivos en staging (para pre-commit hook) [default]
#   --ci             Review de archivos del último commit (GitHub Actions)
#   --pr             Review de todos los archivos cambiados en la PR vs base
#   --pr --diff-only Review solo el diff de la PR (más rápido, menos tokens)
#   --file <path>    Review de un archivo específico
#   --cache          Muestra estado del cache
#   --cache-clear    Limpia el cache
#
# Config: lee .gga del directorio actual si existe

set -euo pipefail

export PATH="/c/Program Files/nodejs:/c/Users/insyd/AppData/Local/Microsoft/WinGet/Packages/SQLite.SQLite_Microsoft.Winget.Source_8wekyb3d8bbwe:/c/Users/insyd/AppData/Local/Microsoft/WinGet/Packages/astral-sh.uv_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"

# Cargar librerías GGA
GGA_LIB="$(cd "$(dirname "$0")/gga" && pwd)"
# shellcheck source=gga/providers.sh
source "$GGA_LIB/providers.sh"
# shellcheck source=gga/cache.sh
source "$GGA_LIB/cache.sh"
# shellcheck source=gga/pr-mode.sh
source "$GGA_LIB/pr-mode.sh"

# ──────────────────────────────────────────────────────────────────
# Defaults de configuración
# ──────────────────────────────────────────────────────────────────
PROVIDER="claude"
MODEL=""
TIMEOUT=60
INCLUDE=""
EXCLUDE="*.lock,*.min.js,*.min.css,dist/*,build/*,node_modules/*,.git/*,*.pb.go,*_generated.*"
MAX_FILES=20
BASE_BRANCH=""

# ──────────────────────────────────────────────────────────────────
# Cargar .gga config del proyecto (si existe)
# ──────────────────────────────────────────────────────────────────
load_config() {
  local config_file="${1:-.gga}"
  if [ -f "$config_file" ]; then
    while IFS='=' read -r key value; do
      # Ignorar comentarios y líneas vacías
      [[ "$key" =~ ^#.*$ ]] && continue
      [[ -z "$key" ]] && continue
      key=$(echo "$key" | tr -d ' ')
      value=$(echo "$value" | tr -d '"' | sed 's/^[[:space:]]*//')
      case "$key" in
        PROVIDER)     PROVIDER="$value"     ;;
        MODEL)        MODEL="$value"        ;;
        TIMEOUT)      TIMEOUT="$value"      ;;
        INCLUDE)      INCLUDE="$value"      ;;
        EXCLUDE)      EXCLUDE="$value"      ;;
        MAX_FILES)    MAX_FILES="$value"    ;;
        BASE_BRANCH)  BASE_BRANCH="$value"  ;;
      esac
    done < "$config_file"
  fi
}

load_config

# ──────────────────────────────────────────────────────────────────
# Parsear argumentos CLI
# ──────────────────────────────────────────────────────────────────
MODE="staged"
DIFF_ONLY=false
SINGLE_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --staged)       MODE="staged";   shift ;;
    --ci)           MODE="ci";       shift ;;
    --pr)           MODE="pr";       shift ;;
    --diff-only)    DIFF_ONLY=true;  shift ;;
    --file)         MODE="file"; SINGLE_FILE="$2"; shift 2 ;;
    --provider)     PROVIDER="$2";   shift 2 ;;
    --model)        MODEL="$2";      shift 2 ;;
    --timeout)      TIMEOUT="$2";    shift 2 ;;
    --base)         BASE_BRANCH="$2";shift 2 ;;
    --cache)        cache_status; exit 0 ;;
    --cache-clear)  cache_clear "$(pwd)"; exit 0 ;;
    --cache-clear-all) cache_clear; exit 0 ;;
    --help|-h)
      echo "Uso: gga-review.sh [modo] [opciones]"
      echo ""
      echo "Modos:"
      echo "  --staged          Review de archivos en staging [default]"
      echo "  --ci              Review del último commit (GitHub Actions)"
      echo "  --pr              Review de toda la PR vs rama base"
      echo "  --pr --diff-only  Review solo el diff (menos tokens)"
      echo "  --file <ruta>     Review de un archivo específico"
      echo ""
      echo "Opciones:"
      echo "  --provider <p>    claude|gemini|ollama|lmstudio|github-models|opencode"
      echo "  --model <m>       Modelo específico (requerido para ollama)"
      echo "  --timeout <s>     Timeout en segundos [default: 60]"
      echo "  --base <branch>   Rama base para PR mode [default: autodetect]"
      echo "  --cache           Mostrar estado del cache"
      echo "  --cache-clear     Limpiar cache del proyecto"
      exit 0
      ;;
    *) echo "Argumento desconocido: $1" >&2; exit 1 ;;
  esac
done

# ──────────────────────────────────────────────────────────────────
# Header
# ──────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   GGA Code Review — $PROVIDER$(printf '%*s' $((26 - ${#PROVIDER})) '')║"
echo "╚══════════════════════════════════════════╝"
echo "  Modo: $MODE${DIFF_ONLY:+ (diff-only)} | Timeout: ${TIMEOUT}s"
echo ""

# ──────────────────────────────────────────────────────────────────
# Validar que estamos en un repo git
# ──────────────────────────────────────────────────────────────────
if ! git rev-parse --git-dir &>/dev/null 2>&1; then
  echo "ERROR: No es un repositorio git."
  exit 1
fi

# ──────────────────────────────────────────────────────────────────
# Cargar reglas (AGENTS.md)
# ──────────────────────────────────────────────────────────────────
RULES=""
if [ -f "AGENTS.md" ]; then
  # Limitar a 300 líneas para no saturar el contexto
  RULES=$(head -300 "AGENTS.md")
else
  RULES="Revisar: código limpio, sin secretos hardcodeados, funciones < 30 líneas, archivos < 300 líneas, nombres descriptivos en inglés."
fi

# ──────────────────────────────────────────────────────────────────
# Obtener archivos a revisar según el modo
# ──────────────────────────────────────────────────────────────────
FILES_TO_REVIEW=()

case "$MODE" in
  staged)
    echo "▶ Obteniendo archivos en staging..."
    while IFS= read -r f; do
      [ -n "$f" ] && FILES_TO_REVIEW+=("$f")
    done < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)
    ;;

  ci)
    echo "▶ Obteniendo archivos del último commit (CI mode)..."
    while IFS= read -r f; do
      [ -n "$f" ] && FILES_TO_REVIEW+=("$f")
    done < <(get_ci_files "$INCLUDE" "$EXCLUDE")
    ;;

  pr)
    echo "▶ Detectando rama base para PR review..."
    PR_RANGE=$(get_pr_range "$BASE_BRANCH")
    echo "  Rango: $PR_RANGE"

    if [ "$DIFF_ONLY" = true ]; then
      echo "  Modo: diff-only (más eficiente)"
      # En diff-only, no necesitamos lista de archivos individuales
      FILES_TO_REVIEW=("__DIFF__")
    else
      while IFS= read -r f; do
        [ -n "$f" ] && FILES_TO_REVIEW+=("$f")
      done < <(get_pr_files "$PR_RANGE" "$INCLUDE" "$EXCLUDE")
    fi
    ;;

  file)
    if [ -z "$SINGLE_FILE" ] || [ ! -f "$SINGLE_FILE" ]; then
      echo "ERROR: Archivo no encontrado: $SINGLE_FILE" >&2
      exit 1
    fi
    FILES_TO_REVIEW=("$SINGLE_FILE")
    ;;
esac

# Aplicar MAX_FILES para no exceder contexto
if [ "${#FILES_TO_REVIEW[@]}" -gt "$MAX_FILES" ]; then
  echo "  ⚠ ${#FILES_TO_REVIEW[@]} archivos encontrados — limitando a $MAX_FILES (configura MAX_FILES en .gga)"
  FILES_TO_REVIEW=("${FILES_TO_REVIEW[@]:0:$MAX_FILES}")
fi

if [ "${#FILES_TO_REVIEW[@]}" -eq 0 ]; then
  echo "  (sin archivos para revisar)"
  echo ""
  exit 0
fi

echo "  ${#FILES_TO_REVIEW[@]} archivo(s) a revisar"
echo ""

# ──────────────────────────────────────────────────────────────────
# Validar provider ANTES de procesar archivos
# ──────────────────────────────────────────────────────────────────
echo "▶ Validando provider '$PROVIDER'..."
if ! validate_provider "$PROVIDER" "$MODEL"; then
  echo ""
  echo "  Puedes cambiar el provider en .gga o con --provider"
  exit 1
fi
echo "  ✓ Provider OK"
echo ""

# ──────────────────────────────────────────────────────────────────
# PR diff-only: un solo call de AI con el diff completo
# ──────────────────────────────────────────────────────────────────
if [ "$MODE" = "pr" ] && [ "$DIFF_ONLY" = true ]; then
  echo "▶ Obteniendo diff de la PR..."
  PR_DIFF=$(get_pr_diff "$PR_RANGE")

  if [ -z "$PR_DIFF" ]; then
    echo "  (sin cambios en el diff)"
    exit 0
  fi

  LINES=$(echo "$PR_DIFF" | wc -l)
  echo "  $LINES líneas en el diff"

  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  PROMPT=$(build_pr_prompt "$RULES" "$PR_DIFF" "Branch: $CURRENT_BRANCH")

  echo ""
  echo "▶ Enviando diff al AI ($PROVIDER)..."
  RESPONSE=$(execute_provider_with_timeout "$TIMEOUT" "$PROVIDER" "$MODEL" "$PROMPT" 2>/dev/null || echo "STATUS: FAILED
REASON: Error al llamar al provider")

  echo ""
  if parse_status "$RESPONSE"; then
    echo "✅ STATUS: PASSED — PR diff aprobado"
    exit 0
  else
    REASON=$(extract_reason "$RESPONSE")
    echo "❌ STATUS: FAILED"
    [ -n "$REASON" ] && echo "   REASON: $REASON"
    exit 1
  fi
fi

# ──────────────────────────────────────────────────────────────────
# Mode normal: revisar archivos (con cache)
# ──────────────────────────────────────────────────────────────────
META_HASH=$(get_meta_hash)

echo "▶ Verificando cache..."
UNCACHED=()
while IFS= read -r f; do
  [ -n "$f" ] && UNCACHED+=("$f")
done < <(filter_uncached "$META_HASH" "${FILES_TO_REVIEW[@]}")

CACHED_COUNT=$(( ${#FILES_TO_REVIEW[@]} - ${#UNCACHED[@]} ))
[ $CACHED_COUNT -gt 0 ] && echo "  ✓ $CACHED_COUNT archivo(s) en cache (sin costo)"

if [ "${#UNCACHED[@]}" -eq 0 ]; then
  echo ""
  echo "✅ Todos los archivos en cache — sin cambios relevantes"
  echo ""
  exit 0
fi

echo "  ${#UNCACHED[@]} archivo(s) para revisar con AI"
echo ""

# ──────────────────────────────────────────────────────────────────
# Revisar archivos: un call por lote (más eficiente que uno por archivo)
# ──────────────────────────────────────────────────────────────────
echo "▶ Revisando con AI ($PROVIDER)..."
for f in "${UNCACHED[@]}"; do
  echo "  → $f"
done

PROMPT=$(build_files_prompt "$RULES" "${UNCACHED[@]}")
RESPONSE=$(execute_provider_with_timeout "$TIMEOUT" "$PROVIDER" "$MODEL" "$PROMPT" 2>/dev/null || echo "STATUS: FAILED
REASON: Error al llamar al provider '$PROVIDER'")

echo ""

if parse_status "$RESPONSE"; then
  echo "✅ STATUS: PASSED"
  # Guardar en cache solo los PASSED
  for f in "${UNCACHED[@]}"; do
    save_cache_pass "$f" "$META_HASH"
  done
elif echo "$RESPONSE" | grep -q "^STATUS: FAILED"; then
  REASON=$(extract_reason "$RESPONSE")
  echo "❌ STATUS: FAILED"
  [ -n "$REASON" ] && echo "   REASON: $REASON"
  # Registrar FAILs en cache (para estadísticas, no para skip)
  for f in "${UNCACHED[@]}"; do
    save_cache_fail "$f" "$META_HASH"
  done
  echo ""
  exit 1
else
  # Respuesta ambigua — strict mode: bloquear
  echo "⚠ RESPUESTA AMBIGUA — Bloqueando por precaución (strict mode)"
  echo "  Respuesta recibida:"
  echo "$RESPONSE" | head -5 | sed 's/^/  /'
  echo ""
  exit 1
fi

echo ""
