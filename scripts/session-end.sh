#!/usr/bin/env bash
# session-end.sh — Guarda resumen estructurado de sesión en SQLite al cerrar
# Uso: ./scripts/session-end.sh <proyecto> "<summary>" "<next_steps>" [goal] [discoveries]
# Formato auto (desde .bashrc trap): ./scripts/session-end.sh "auto" "Sesión cerrada" ""

set -euo pipefail

export PATH="/c/Program Files/nodejs:/c/Users/insyd/AppData/Local/Microsoft/WinGet/Packages/SQLite.SQLite_Microsoft.Winget.Source_8wekyb3d8bbwe:/c/Users/insyd/AppData/Local/Microsoft/WinGet/Packages/astral-sh.uv_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"

PROJECT="${1:-}"
SUMMARY="${2:-}"
NEXT_STEPS="${3:-}"
GOAL="${4:-}"
DISCOVERIES="${5:-}"

MEMORY_DB="${USERPROFILE:-$HOME}/.local/enterprise-ai/memory.db"

if [ -z "$PROJECT" ] || [ -z "$SUMMARY" ]; then
  echo "Uso: ./scripts/session-end.sh <proyecto> '<summary>' '[next_steps]' '[goal]' '[discoveries]'"
  echo ""
  echo "Ejemplo:"
  echo "  ./scripts/session-end.sh mi-api 'Implementado endpoint POST /users' 'Falta tests de integración' 'Añadir autenticación JWT' 'El middleware de auth no soporta refresh tokens'"
  exit 1
fi

if ! command -v sqlite3 &>/dev/null; then
  exit 0  # Silencioso — no bloquear cierre de terminal
fi

if [ ! -f "$MEMORY_DB" ]; then
  exit 0  # Silencioso — no bloquear cierre de terminal
fi

# ──────────────────────────────────────────────────────────────────
# Stripping de datos privados — eliminar contenido entre <private>...</private>
# Aplica a todos los campos antes de persistir
# ──────────────────────────────────────────────────────────────────
strip_private() {
  echo "$1" | sed 's/<private>[^<]*<\/private>/[REDACTED]/g'
}

PROJECT=$(strip_private "$PROJECT")
SUMMARY=$(strip_private "$SUMMARY")
NEXT_STEPS=$(strip_private "$NEXT_STEPS")
GOAL=$(strip_private "$GOAL")
DISCOVERIES=$(strip_private "$DISCOVERIES")

# ──────────────────────────────────────────────────────────────────
# Recopilar archivos modificados en git (si aplica)
# ──────────────────────────────────────────────────────────────────
FILES_MODIFIED=""
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -n "$GIT_ROOT" ]; then
  FILES_MODIFIED=$(git diff --name-only HEAD 2>/dev/null | head -20 | tr '\n' ',' | sed 's/,$//' || echo "")
fi

# ──────────────────────────────────────────────────────────────────
# Escapar comillas simples para SQLite
# ──────────────────────────────────────────────────────────────────
esc() { echo "$1" | sed "s/'/''/g"; }

SESSION_ID=$(date '+%Y%m%d_%H%M%S')_$$

# ──────────────────────────────────────────────────────────────────
# Guardar sesión con campos estructurados
# Los campos nuevos (goal, instructions, discoveries, accomplished) usan
# los parámetros opcionales + detectan contexto automáticamente
# ──────────────────────────────────────────────────────────────────
sqlite3 "$MEMORY_DB" \
  "INSERT INTO sessions (id, project, summary, files, next_steps, goal, discoveries, accomplished)
   VALUES (
     '$(esc "$SESSION_ID")',
     '$(esc "$PROJECT")',
     '$(esc "$SUMMARY")',
     '$(esc "$FILES_MODIFIED")',
     '$(esc "$NEXT_STEPS")',
     '$(esc "$GOAL")',
     '$(esc "$DISCOVERIES")',
     '$(esc "$SUMMARY")'
   );" 2>/dev/null || true

# ──────────────────────────────────────────────────────────────────
# Guardar como observación si hay descubrimientos reales (no cierre auto)
# ──────────────────────────────────────────────────────────────────
if [ "$PROJECT" != "auto" ] && [ -n "$DISCOVERIES" ]; then
  TOPIC_KEY="${PROJECT}/session-$(date '+%Y-%m-%d')"
  NORM_HASH=$(echo "${SUMMARY}${DISCOVERIES}" | sha256sum 2>/dev/null | cut -d' ' -f1 || echo "")

  # Verificar si ya existe una observación idéntica (deduplicación por hash)
  EXISTING=$(sqlite3 "$MEMORY_DB" \
    "SELECT COUNT(*) FROM observations WHERE normalized_hash='$(esc "$NORM_HASH")' AND created_at >= datetime('now','-15 minutes');" \
    2>/dev/null || echo "0")

  if [ "$EXISTING" = "0" ]; then
    sqlite3 "$MEMORY_DB" \
      "INSERT INTO observations (project, type, topic_key, title, what, why, where_ref, learned, tags, normalized_hash)
       VALUES (
         '$(esc "$PROJECT")',
         'discovery',
         '$(esc "$TOPIC_KEY")',
         '$(esc "Sesión $(date +%Y-%m-%d): $PROJECT")',
         '$(esc "$SUMMARY")',
         '$(esc "$GOAL")',
         '$(esc "$FILES_MODIFIED")',
         '$(esc "$DISCOVERIES")',
         '[\"session\",\"$(esc "$PROJECT")\"]',
         '$(esc "$NORM_HASH")'
       );" 2>/dev/null || true
  fi
fi

echo ""
echo "✓ Sesión guardada"
echo "  ID:        $SESSION_ID"
echo "  Proyecto:  $PROJECT"
[ -n "$GOAL" ]        && echo "  Goal:      $GOAL"
echo "  Summary:   $SUMMARY"
[ -n "$DISCOVERIES" ] && echo "  Hallazgos: $DISCOVERIES"
[ -n "$NEXT_STEPS" ]  && echo "  Pendiente: $NEXT_STEPS"
[ -n "$FILES_MODIFIED" ] && echo "  Archivos:  $FILES_MODIFIED"
echo ""

# Mostrar dashboard final
sqlite3 "$MEMORY_DB" -column -header \
  "SELECT en_progreso, bloqueadas, pendientes, completadas_hoy FROM daily_dashboard;" \
  2>/dev/null || true

# Sincronizar con Obsidian
echo ""
echo "→ Sincronizando con Obsidian..."
bash "$(dirname "$0")/obsidian-sync.sh" 2>/dev/null || echo "  (sync omitido)"
echo ""
