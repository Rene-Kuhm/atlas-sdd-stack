#!/usr/bin/env bash
# gga/pr-mode.sh — PR mode y CI mode para review de Pull Requests y GitHub Actions
# Cargado por: scripts/gga-review.sh

# ──────────────────────────────────────────────────────────────────
# detect_base_branch — Detecta la rama base del repo
# Prioridad: main → master → develop → primera rama disponible
# ──────────────────────────────────────────────────────────────────
detect_base_branch() {
  local candidates=("main" "master" "develop" "dev" "trunk")

  for branch in "${candidates[@]}"; do
    if git show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null; then
      echo "$branch"
      return
    fi
    if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
      echo "$branch"
      return
    fi
  done

  # Fallback: primera rama distinta a la actual
  local current
  current=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  git branch -r 2>/dev/null | grep -v "HEAD" | grep -v "$current" | head -1 | sed 's|origin/||' | tr -d ' '
}

# ──────────────────────────────────────────────────────────────────
# get_pr_range — Rango de commits para comparar con la base
# Retorna: "origin/main...HEAD" o equivalente
# ──────────────────────────────────────────────────────────────────
get_pr_range() {
  local base_branch="${1:-}"

  if [ -z "$base_branch" ]; then
    base_branch=$(detect_base_branch)
  fi

  if [ -z "$base_branch" ]; then
    echo "HEAD~1" # Fallback: solo último commit
    return
  fi

  echo "origin/${base_branch}...HEAD"
}

# ──────────────────────────────────────────────────────────────────
# get_pr_files — Archivos cambiados en la PR (sin deletes)
# Uso: get_pr_files "$range" "$include_pattern" "$exclude_pattern"
# ──────────────────────────────────────────────────────────────────
get_pr_files() {
  local range="$1"
  local include="${2:-}"    # Ej: "*.py,*.ts,*.js"
  local exclude="${3:-}"    # Ej: "*.lock,dist/*"

  local files
  files=$(git diff --name-only --diff-filter=ACM "$range" 2>/dev/null || echo "")

  if [ -z "$files" ]; then
    echo ""
    return
  fi

  # Aplicar filtros de inclusión
  if [ -n "$include" ]; then
    local filtered=""
    IFS=',' read -ra patterns <<< "$include"
    for pattern in "${patterns[@]}"; do
      pattern=$(echo "$pattern" | tr -d ' ')
      local matched
      matched=$(echo "$files" | grep -E "$(echo "$pattern" | sed 's/\*/.*/g; s/\?/./g')" 2>/dev/null || echo "")
      filtered="${filtered}${matched}"$'\n'
    done
    files=$(echo "$filtered" | sort -u | grep -v '^$')
  fi

  # Aplicar filtros de exclusión
  if [ -n "$exclude" ]; then
    IFS=',' read -ra patterns <<< "$exclude"
    for pattern in "${patterns[@]}"; do
      pattern=$(echo "$pattern" | tr -d ' ')
      files=$(echo "$files" | grep -vE "$(echo "$pattern" | sed 's/\*/.*/g; s/\?/./g')" 2>/dev/null || echo "$files")
    done
  fi

  echo "$files" | grep -v '^$'
}

# ──────────────────────────────────────────────────────────────────
# get_pr_diff — Diff unificado de la PR completa
# ──────────────────────────────────────────────────────────────────
get_pr_diff() {
  local range="$1"
  local max_lines="${2:-500}"  # Limitar tamaño para no exceder contexto del AI

  local diff
  diff=$(git diff "$range" 2>/dev/null | head -n "$max_lines")

  if [ -z "$diff" ]; then
    echo ""
    return
  fi

  echo "$diff"
}

# ──────────────────────────────────────────────────────────────────
# get_ci_files — Archivos modificados en el último commit (modo CI)
# Uso en GitHub Actions: gga-review --ci
# ──────────────────────────────────────────────────────────────────
get_ci_files() {
  local include="${1:-}"
  local exclude="${2:-}"

  local files
  files=$(git diff --name-only --diff-filter=ACM HEAD~1..HEAD 2>/dev/null \
    || git diff --name-only --diff-filter=ACM HEAD 2>/dev/null \
    || echo "")

  [ -z "$files" ] && echo "" && return

  # Filtros
  if [ -n "$include" ]; then
    local filtered=""
    IFS=',' read -ra patterns <<< "$include"
    for pattern in "${patterns[@]}"; do
      pattern=$(echo "$pattern" | tr -d ' ')
      local matched
      matched=$(echo "$files" | grep -E "$(echo "$pattern" | sed 's/\*/.*/g; s/\?/./g')" 2>/dev/null || echo "")
      filtered="${filtered}${matched}"$'\n'
    done
    files=$(echo "$filtered" | sort -u | grep -v '^$')
  fi

  if [ -n "$exclude" ]; then
    IFS=',' read -ra patterns <<< "$exclude"
    for pattern in "${patterns[@]}"; do
      pattern=$(echo "$pattern" | tr -d ' ')
      files=$(echo "$files" | grep -vE "$(echo "$pattern" | sed 's/\*/.*/g; s/\?/./g')" 2>/dev/null || echo "$files")
    done
  fi

  echo "$files" | grep -v '^$'
}

# ──────────────────────────────────────────────────────────────────
# build_pr_prompt — Construye el prompt para review de PR (diff-only)
# Más eficiente que enviar archivos completos
# ──────────────────────────────────────────────────────────────────
build_pr_prompt() {
  local rules="$1"
  local diff="$2"
  local context="${3:-}"   # Info adicional: branch, PR title, etc.

  cat << EOF
Eres un code reviewer senior. Debes revisar el siguiente diff de una Pull Request contra estas reglas del proyecto.

<rules>
$rules
</rules>

${context:+Contexto de la PR:
$context

}Revisa el diff y responde ÚNICAMENTE con uno de estos dos formatos:

STATUS: PASSED

o

STATUS: FAILED
REASON: [descripción específica de la violación, indicar archivo:línea si es posible]

No escribas nada más. No expliques si pasa. Solo lista violaciones si falla.

<diff>
$diff
</diff>
EOF
}

# ──────────────────────────────────────────────────────────────────
# build_files_prompt — Construye prompt para review de archivos completos
# ──────────────────────────────────────────────────────────────────
build_files_prompt() {
  local rules="$1"
  shift
  local files=("$@")

  local files_content=""
  for f in "${files[@]}"; do
    [ -f "$f" ] || continue
    files_content+="
--- $f ---
$(cat "$f" 2>/dev/null | head -200)
"
  done

  cat << EOF
Eres un code reviewer senior. Revisa los siguientes archivos contra estas reglas del proyecto.

<rules>
$rules
</rules>

Responde ÚNICAMENTE con uno de estos dos formatos:

STATUS: PASSED

o

STATUS: FAILED
REASON: [violación específica, archivo:línea si es posible]

No escribas nada más. No expliques si pasa. Solo lista violaciones si falla.

<files>
$files_content
</files>
EOF
}
