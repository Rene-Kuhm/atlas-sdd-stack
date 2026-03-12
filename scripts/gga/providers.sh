#!/usr/bin/env bash
# gga/providers.sh — Abstracción multi-provider para AI code review
# Providers: claude | gemini | ollama | lmstudio | github-models | opencode
# Cargado por: scripts/gga-review.sh

# ──────────────────────────────────────────────────────────────────
# validate_provider — Verifica que el provider está disponible
# Uso: validate_provider "$PROVIDER" "$MODEL"
# ──────────────────────────────────────────────────────────────────
validate_provider() {
  local provider="${1:-claude}"
  local model="${2:-}"

  case "$provider" in
    claude)
      if ! command -v claude &>/dev/null; then
        echo "ERROR: 'claude' CLI no encontrado. Instalar Claude Code." >&2
        return 1
      fi
      ;;
    gemini)
      if ! command -v gemini &>/dev/null; then
        echo "ERROR: 'gemini' CLI no encontrado." >&2
        return 1
      fi
      ;;
    ollama)
      if ! command -v ollama &>/dev/null; then
        echo "ERROR: 'ollama' no encontrado. Instalar desde https://ollama.ai" >&2
        return 1
      fi
      if [ -z "$model" ]; then
        echo "ERROR: PROVIDER=ollama requiere MODEL=<nombre> en .gga" >&2
        return 1
      fi
      ;;
    lmstudio)
      # LM Studio expone API en localhost:1234
      if ! curl -sf "http://localhost:1234/v1/models" &>/dev/null; then
        echo "ERROR: LM Studio no responde en localhost:1234. ¿Está corriendo?" >&2
        return 1
      fi
      ;;
    github-models)
      if [ -z "${GITHUB_TOKEN:-}" ] && ! command -v gh &>/dev/null; then
        echo "ERROR: PROVIDER=github-models requiere GITHUB_TOKEN env var o gh CLI autenticado." >&2
        return 1
      fi
      ;;
    opencode)
      if ! command -v opencode &>/dev/null; then
        echo "ERROR: 'opencode' CLI no encontrado." >&2
        return 1
      fi
      ;;
    *)
      echo "ERROR: Provider desconocido '$provider'. Opciones: claude|gemini|ollama|lmstudio|github-models|opencode" >&2
      return 1
      ;;
  esac
  return 0
}

# ──────────────────────────────────────────────────────────────────
# execute_provider — Router principal
# Uso: execute_provider "$PROVIDER" "$MODEL" "$PROMPT"
# Retorna: texto de respuesta del AI
# ──────────────────────────────────────────────────────────────────
execute_provider() {
  local provider="${1:-claude}"
  local model="${2:-}"
  local prompt="$3"

  case "$provider" in
    claude)        _execute_claude        "$model" "$prompt" ;;
    gemini)        _execute_gemini        "$model" "$prompt" ;;
    ollama)        _execute_ollama        "$model" "$prompt" ;;
    lmstudio)      _execute_lmstudio      "$model" "$prompt" ;;
    github-models) _execute_github_models "$model" "$prompt" ;;
    opencode)      _execute_opencode      "$model" "$prompt" ;;
    *)
      echo "STATUS: FAILED" >&2
      echo "REASON: Provider desconocido '$provider'" >&2
      return 1
      ;;
  esac
}

# ──────────────────────────────────────────────────────────────────
# execute_provider_with_timeout — Wrapper con timeout protection
# Uso: execute_provider_with_timeout "$TIMEOUT" "$PROVIDER" "$MODEL" "$PROMPT"
# ──────────────────────────────────────────────────────────────────
execute_provider_with_timeout() {
  local timeout_s="${1:-60}"
  local provider="$2"
  local model="$3"
  local prompt="$4"

  if command -v timeout &>/dev/null; then
    timeout "$timeout_s" bash -c "
      source '$(dirname "${BASH_SOURCE[0]}")/providers.sh'
      execute_provider '$provider' '$model' \"\$PROMPT\"
    " PROMPT="$prompt" 2>/dev/null
    local exit_code=$?
    if [ $exit_code -eq 124 ]; then
      echo "STATUS: FAILED"
      echo "REASON: Timeout — el provider '$provider' no respondió en ${timeout_s}s"
      return 1
    fi
    return $exit_code
  else
    # Sin timeout disponible: ejecutar directo (macOS sin coreutils)
    execute_provider "$provider" "$model" "$prompt"
  fi
}

# ──────────────────────────────────────────────────────────────────
# parse_status — Extrae STATUS: PASSED | FAILED de la respuesta
# Uso: parse_status "$RESPONSE"
# Retorna: 0 si PASSED, 1 si FAILED, 2 si respuesta ambigua
# ──────────────────────────────────────────────────────────────────
parse_status() {
  local response="$1"

  if echo "$response" | grep -q "^STATUS: PASSED"; then
    return 0
  elif echo "$response" | grep -q "^STATUS: FAILED"; then
    return 1
  else
    # Strict mode: respuesta ambigua = fallo
    return 2
  fi
}

# ──────────────────────────────────────────────────────────────────
# extract_reason — Extrae el motivo del FAILED
# ──────────────────────────────────────────────────────────────────
extract_reason() {
  local response="$1"
  echo "$response" | grep "^REASON:" | sed 's/^REASON: //'
}

# ──────────────────────────────────────────────────────────────────
# IMPLEMENTACIONES INTERNAS
# ──────────────────────────────────────────────────────────────────

_execute_claude() {
  local model="${1:-}"
  local prompt="$2"
  # Claude CLI: lee desde stdin, -p para prompt directo
  echo "$prompt" | claude -p "$(cat -)" 2>/dev/null
}

_execute_gemini() {
  local model="${1:-}"
  local prompt="$2"
  local model_flag=""
  [ -n "$model" ] && model_flag="--model=$model"
  echo "$prompt" | gemini $model_flag 2>/dev/null
}

_execute_ollama() {
  local model="$1"
  local prompt="$2"
  ollama run "$model" "$prompt" 2>/dev/null
}

_execute_lmstudio() {
  local model="${1:-local-model}"
  local prompt="$2"
  # LM Studio expone API compatible con OpenAI en localhost:1234
  local escaped_prompt
  escaped_prompt=$(echo "$prompt" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null \
    || echo "$prompt" | sed 's/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')

  curl -sf "http://localhost:1234/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"$model\",
      \"messages\": [{\"role\": \"user\", \"content\": $escaped_prompt}],
      \"temperature\": 0.1,
      \"max_tokens\": 500
    }" 2>/dev/null \
    | python3 -c "import sys,json; data=json.load(sys.stdin); print(data['choices'][0]['message']['content'])" 2>/dev/null
}

_execute_github_models() {
  local model="${1:-gpt-4o-mini}"
  local prompt="$2"

  # Obtener credenciales: primero GITHUB_TOKEN, luego gh auth token
  local gh_auth_value="${GITHUB_TOKEN:-}"
  if [ -z "$gh_auth_value" ] && command -v gh &>/dev/null; then
    gh_auth_value=$(gh auth token 2>/dev/null || echo "")
  fi

  if [ -z "$gh_auth_value" ]; then
    echo "STATUS: FAILED"
    echo "REASON: GITHUB_TOKEN no disponible"
    return 1
  fi

  local escaped_prompt
  escaped_prompt=$(echo "$prompt" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null \
    || echo "\"$prompt\"")

  curl -sf "https://models.inference.ai.azure.com/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $gh_auth_value" \
    -d "{
      \"model\": \"$model\",
      \"messages\": [{\"role\": \"user\", \"content\": $escaped_prompt}],
      \"temperature\": 0.1,
      \"max_tokens\": 500
    }" 2>/dev/null \
    | python3 -c "import sys,json; data=json.load(sys.stdin); print(data['choices'][0]['message']['content'])" 2>/dev/null
}

_execute_opencode() {
  local model="${1:-}"
  local prompt="$2"
  local model_flag=""
  [ -n "$model" ] && model_flag="--model=$model"
  echo "$prompt" | opencode $model_flag --no-interactive 2>/dev/null
}
