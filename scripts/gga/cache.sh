#!/usr/bin/env bash
# gga/cache.sh — Cache inteligente de resultados de code review
# Solo cachea resultados PASSED. FAILED siempre re-revisa.
# Invalidación: cualquier cambio en el archivo, AGENTS.md, o .gga config
# Cargado por: scripts/gga-review.sh

MEMORY_DB="${USERPROFILE:-$HOME}/.local/enterprise-ai/memory.db"

# ──────────────────────────────────────────────────────────────────
# get_meta_hash — Hash combinado de config + reglas
# Si AGENTS.md o .gga cambian → toda la cache se invalida
# ──────────────────────────────────────────────────────────────────
get_meta_hash() {
  local agents_hash=""
  local config_hash=""

  [ -f "AGENTS.md" ]  && agents_hash=$(sha256sum "AGENTS.md" | cut -d' ' -f1)
  [ -f ".gga" ]       && config_hash=$(sha256sum ".gga"      | cut -d' ' -f1)

  echo "${agents_hash}:${config_hash}"
}

# ──────────────────────────────────────────────────────────────────
# get_file_cache_key — Hash único por archivo + meta
# ──────────────────────────────────────────────────────────────────
get_file_cache_key() {
  local file="$1"
  local meta_hash="$2"

  if [ ! -f "$file" ]; then
    echo ""
    return
  fi

  local file_hash
  file_hash=$(sha256sum "$file" | cut -d' ' -f1)
  echo "${file_hash}:${meta_hash}"
}

# ──────────────────────────────────────────────────────────────────
# is_cached_passing — Retorna 0 si el archivo ya pasó review con el mismo hash
# Uso: is_cached_passing "$file" "$meta_hash"
# ──────────────────────────────────────────────────────────────────
is_cached_passing() {
  local file="$1"
  local meta_hash="$2"

  if ! command -v sqlite3 &>/dev/null || [ ! -f "$MEMORY_DB" ]; then
    return 1  # Sin SQLite: siempre revisar
  fi

  local cache_key
  cache_key=$(get_file_cache_key "$file" "$meta_hash")

  if [ -z "$cache_key" ]; then
    return 1
  fi

  local cached
  cached=$(sqlite3 "$MEMORY_DB" \
    "SELECT hash FROM file_cache
     WHERE path='$(echo "$file" | sed "s/'/''/g")'
       AND hash='$cache_key'
       AND last_review='PASSED';" 2>/dev/null || echo "")

  [ -n "$cached" ]
}

# ──────────────────────────────────────────────────────────────────
# filter_uncached — Filtra lista de archivos, retorna solo los que necesitan review
# Uso: filter_uncached "$meta_hash" file1 file2 file3 ...
# Output: lista de archivos que necesitan review (uno por línea)
# ──────────────────────────────────────────────────────────────────
filter_uncached() {
  local meta_hash="$1"
  shift
  local files=("$@")
  local needs_review=()
  local cached_count=0

  for file in "${files[@]}"; do
    [ -f "$file" ] || continue
    if is_cached_passing "$file" "$meta_hash"; then
      cached_count=$((cached_count + 1))
    else
      needs_review+=("$file")
    fi
  done

  if [ $cached_count -gt 0 ]; then
    echo "  ✓ $cached_count archivo(s) con cache hit (sin costo de tokens)" >&2
  fi

  printf '%s\n' "${needs_review[@]}"
}

# ──────────────────────────────────────────────────────────────────
# save_cache_pass — Guarda en cache que el archivo pasó
# Solo llamar cuando STATUS: PASSED
# ──────────────────────────────────────────────────────────────────
save_cache_pass() {
  local file="$1"
  local meta_hash="$2"

  if ! command -v sqlite3 &>/dev/null || [ ! -f "$MEMORY_DB" ]; then
    return 0
  fi

  local cache_key
  cache_key=$(get_file_cache_key "$file" "$meta_hash")
  [ -z "$cache_key" ] && return 0

  sqlite3 "$MEMORY_DB" \
    "INSERT OR REPLACE INTO file_cache (path, hash, last_review, reviewed_at)
     VALUES (
       '$(echo "$file" | sed "s/'/''/g")',
       '$cache_key',
       'PASSED',
       datetime('now')
     );" 2>/dev/null || true
}

# ──────────────────────────────────────────────────────────────────
# save_cache_fail — Marca el archivo como FAILED (no se cachea, pero se registra)
# Los FAILs nunca se usan para skip — siempre se re-revisan
# ──────────────────────────────────────────────────────────────────
save_cache_fail() {
  local file="$1"
  local meta_hash="$2"

  if ! command -v sqlite3 &>/dev/null || [ ! -f "$MEMORY_DB" ]; then
    return 0
  fi

  local cache_key
  cache_key=$(get_file_cache_key "$file" "$meta_hash")
  [ -z "$cache_key" ] && return 0

  # Guardar con last_review=FAILED — no se usará para skip
  sqlite3 "$MEMORY_DB" \
    "INSERT OR REPLACE INTO file_cache (path, hash, last_review, reviewed_at)
     VALUES (
       '$(echo "$file" | sed "s/'/''/g")',
       '$cache_key',
       'FAILED',
       datetime('now')
     );" 2>/dev/null || true
}

# ──────────────────────────────────────────────────────────────────
# cache_status — Muestra estado actual del cache
# ──────────────────────────────────────────────────────────────────
cache_status() {
  if ! command -v sqlite3 &>/dev/null || [ ! -f "$MEMORY_DB" ]; then
    echo "  Cache: SQLite no disponible"
    return
  fi

  local total passed failed
  total=$(sqlite3 "$MEMORY_DB" "SELECT COUNT(*) FROM file_cache;" 2>/dev/null || echo "0")
  passed=$(sqlite3 "$MEMORY_DB" "SELECT COUNT(*) FROM file_cache WHERE last_review='PASSED';" 2>/dev/null || echo "0")
  failed=$(sqlite3 "$MEMORY_DB" "SELECT COUNT(*) FROM file_cache WHERE last_review='FAILED';" 2>/dev/null || echo "0")

  echo "  Cache: $total archivos ($passed PASSED, $failed FAILED)"
}

# ──────────────────────────────────────────────────────────────────
# cache_clear — Limpia cache de un proyecto o todo
# Uso: cache_clear [directorio-proyecto]
# ──────────────────────────────────────────────────────────────────
cache_clear() {
  local project_dir="${1:-}"

  if ! command -v sqlite3 &>/dev/null || [ ! -f "$MEMORY_DB" ]; then
    return 0
  fi

  if [ -n "$project_dir" ]; then
    local count
    count=$(sqlite3 "$MEMORY_DB" \
      "SELECT COUNT(*) FROM file_cache WHERE path LIKE '$(echo "$project_dir" | sed "s/'/''/g")%';" 2>/dev/null || echo "0")
    sqlite3 "$MEMORY_DB" \
      "DELETE FROM file_cache WHERE path LIKE '$(echo "$project_dir" | sed "s/'/''/g")%';" 2>/dev/null || true
    echo "  ✓ Cache limpiado: $count archivos eliminados"
  else
    local count
    count=$(sqlite3 "$MEMORY_DB" "SELECT COUNT(*) FROM file_cache;" 2>/dev/null || echo "0")
    sqlite3 "$MEMORY_DB" "DELETE FROM file_cache;" 2>/dev/null || true
    echo "  ✓ Cache completo limpiado: $count archivos eliminados"
  fi
}
