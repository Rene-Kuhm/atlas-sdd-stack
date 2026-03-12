#!/usr/bin/env bash
# skill-registry.sh — Auto-descubre skills, frameworks y convenciones del proyecto
# y los indexa en SQLite para que los sub-agentes los consulten
# Uso: ./scripts/skill-registry.sh [--project-dir /ruta]

set -euo pipefail

export PATH="/c/Program Files/nodejs:/c/Users/insyd/AppData/Local/Microsoft/WinGet/Packages/SQLite.SQLite_Microsoft.Winget.Source_8wekyb3d8bbwe:/c/Users/insyd/AppData/Local/Microsoft/WinGet/Packages/astral-sh.uv_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"

MEMORY_DB="${USERPROFILE:-$HOME}/.local/enterprise-ai/memory.db"
PROJECT_DIR="${1:-$(pwd)}"
REGISTRY_FILE="$PROJECT_DIR/.atl/skill-registry.md"
TODAY=$(date '+%Y-%m-%d')

echo ""
echo "╔══════════════════════════════════╗"
echo "║     Skill Registry Scanner       ║"
echo "╚══════════════════════════════════╝"
echo "  Proyecto: $PROJECT_DIR"
echo ""

mkdir -p "$PROJECT_DIR/.atl"

# ─────────────────────────────────────────────
# 1. Skills globales (~/.claude/commands/)
# ─────────────────────────────────────────────
echo "▶ Escaneando skills globales..."
GLOBAL_SKILLS=()
COMMANDS_DIR="/c/Users/insyd/.claude/commands"
if [ -d "$COMMANDS_DIR" ]; then
  while IFS= read -r f; do
    name=$(basename "$f" .md)
    desc=$(head -3 "$f" 2>/dev/null | grep -v '^#' | head -1 | sed 's/^[[:space:]]*//' || echo "")
    GLOBAL_SKILLS+=("/$name — $desc")
    echo "  ✓ /$name"
  done < <(find "$COMMANDS_DIR" -name "*.md" | sort)
fi

# ─────────────────────────────────────────────
# 2. Skills del proyecto (.claude/skills/ o skills/)
# ─────────────────────────────────────────────
echo ""
echo "▶ Escaneando skills del proyecto..."
PROJECT_SKILLS=()
for skills_dir in "$PROJECT_DIR/.claude/skills" "$PROJECT_DIR/skills" "$PROJECT_DIR/.atl/skills"; do
  if [ -d "$skills_dir" ]; then
    while IFS= read -r f; do
      name=$(basename "$f" .md)
      PROJECT_SKILLS+=("$name — $(head -1 "$f" 2>/dev/null | sed 's/^#[[:space:]]*//')")
      echo "  ✓ $name ($(basename "$skills_dir"))"
    done < <(find "$skills_dir" -name "*.md" | sort)
  fi
done

# ─────────────────────────────────────────────
# 3. Auto-detección de frameworks y herramientas
# ─────────────────────────────────────────────
echo ""
echo "▶ Detectando stack técnico..."
DETECTED_STACK=()

# Package managers / languages
[ -f "$PROJECT_DIR/package.json" ] && DETECTED_STACK+=("nodejs — $(node -e "try{let p=require('$PROJECT_DIR/package.json');console.log(p.name+'@'+p.version)}catch(e){console.log('nodejs')}" 2>/dev/null || echo 'nodejs')")
[ -f "$PROJECT_DIR/requirements.txt" ] || [ -f "$PROJECT_DIR/pyproject.toml" ] && DETECTED_STACK+=("python")
[ -f "$PROJECT_DIR/go.mod" ] && DETECTED_STACK+=("go — $(head -1 "$PROJECT_DIR/go.mod" | awk '{print $2}')")
[ -f "$PROJECT_DIR/Cargo.toml" ] && DETECTED_STACK+=("rust")
[ -f "$PROJECT_DIR/composer.json" ] && DETECTED_STACK+=("php")

# Frameworks
[ -f "$PROJECT_DIR/package.json" ] && grep -q '"next"' "$PROJECT_DIR/package.json" 2>/dev/null && DETECTED_STACK+=("framework: Next.js")
[ -f "$PROJECT_DIR/package.json" ] && grep -q '"react"' "$PROJECT_DIR/package.json" 2>/dev/null && DETECTED_STACK+=("framework: React")
[ -f "$PROJECT_DIR/package.json" ] && grep -q '"vue"' "$PROJECT_DIR/package.json" 2>/dev/null && DETECTED_STACK+=("framework: Vue")
[ -f "$PROJECT_DIR/pyproject.toml" ] && grep -q 'fastapi' "$PROJECT_DIR/pyproject.toml" 2>/dev/null && DETECTED_STACK+=("framework: FastAPI")
[ -f "$PROJECT_DIR/pyproject.toml" ] && grep -q 'django' "$PROJECT_DIR/pyproject.toml" 2>/dev/null && DETECTED_STACK+=("framework: Django")

# Test runners
[ -f "$PROJECT_DIR/jest.config"* ] 2>/dev/null || ([ -f "$PROJECT_DIR/package.json" ] && grep -q '"jest"' "$PROJECT_DIR/package.json" 2>/dev/null) && DETECTED_STACK+=("test-runner: jest")
[ -f "$PROJECT_DIR/vitest.config"* ] 2>/dev/null || ([ -f "$PROJECT_DIR/package.json" ] && grep -q '"vitest"' "$PROJECT_DIR/package.json" 2>/dev/null) && DETECTED_STACK+=("test-runner: vitest")
[ -f "$PROJECT_DIR/pytest.ini" ] || [ -f "$PROJECT_DIR/pyproject.toml" ] && grep -q 'pytest' "$PROJECT_DIR/pyproject.toml" 2>/dev/null && DETECTED_STACK+=("test-runner: pytest")

# DB
[ -f "$PROJECT_DIR/prisma/schema.prisma" ] && DETECTED_STACK+=("db: prisma")
[ -f "$PROJECT_DIR/drizzle.config"* ] 2>/dev/null && DETECTED_STACK+=("db: drizzle")

# Docker
[ -f "$PROJECT_DIR/docker-compose.yml" ] || [ -f "$PROJECT_DIR/docker-compose.yaml" ] && DETECTED_STACK+=("docker-compose")
[ -f "$PROJECT_DIR/Dockerfile" ] && DETECTED_STACK+=("dockerfile")

for item in "${DETECTED_STACK[@]}"; do
  echo "  ✓ $item"
done

# ─────────────────────────────────────────────
# 4. Convenciones del proyecto (AGENTS.md, CLAUDE.md)
# ─────────────────────────────────────────────
echo ""
echo "▶ Cargando convenciones del proyecto..."
CONVENTIONS=()
for conv_file in "$PROJECT_DIR/AGENTS.md" "$PROJECT_DIR/.claude/CLAUDE.md" "$PROJECT_DIR/CLAUDE.md"; do
  if [ -f "$conv_file" ]; then
    CONVENTIONS+=("$(basename "$conv_file") — $(wc -l < "$conv_file") líneas")
    echo "  ✓ $(basename "$conv_file")"
  fi
done

# ─────────────────────────────────────────────
# 5. Escribir skill-registry.md
# ─────────────────────────────────────────────
{
  echo "# Skill Registry"
  echo ""
  echo "**Generado**: $TODAY | **Proyecto**: $PROJECT_DIR"
  echo ""
  echo "## Comandos Globales (/commands)"
  echo ""
  for s in "${GLOBAL_SKILLS[@]:-}"; do
    [ -n "$s" ] && echo "- $s"
  done
  echo ""
  echo "## Skills del Proyecto"
  echo ""
  if [ ${#PROJECT_SKILLS[@]} -eq 0 ]; then
    echo "_ninguna skill de proyecto encontrada_"
  else
    for s in "${PROJECT_SKILLS[@]}"; do
      echo "- $s"
    done
  fi
  echo ""
  echo "## Stack Técnico Detectado"
  echo ""
  if [ ${#DETECTED_STACK[@]} -eq 0 ]; then
    echo "_no detectado — especificar en AGENTS.md_"
  else
    for s in "${DETECTED_STACK[@]}"; do
      echo "- $s"
    done
  fi
  echo ""
  echo "## Convenciones del Proyecto"
  echo ""
  for c in "${CONVENTIONS[@]:-}"; do
    [ -n "$c" ] && echo "- $c"
  done
  echo ""
  echo "## Cómo Usar este Registry"
  echo ""
  echo "Sub-agentes: al inicio de cada tarea, consultar SQLite:"
  echo '```sql'
  echo "SELECT title, category, source_path FROM rag_docs"
  echo "WHERE category IN ('skill', 'pattern', 'runbook')"
  echo "ORDER BY category;"
  echo '```'
} > "$REGISTRY_FILE"

echo ""
echo "  ✓ Registry escrito en: $REGISTRY_FILE"

# ─────────────────────────────────────────────
# 6. Indexar en SQLite
# ─────────────────────────────────────────────
if command -v sqlite3 &>/dev/null && [ -f "$MEMORY_DB" ]; then
  CONTENT=$(cat "$REGISTRY_FILE")
  CONTENT_ESC=$(echo "$CONTENT" | sed "s/'/''/g")
  FILE_ID=$(sha256sum "$REGISTRY_FILE" | cut -d' ' -f1)
  FILE_ESC=$(echo "$REGISTRY_FILE" | sed "s/'/''/g")

  sqlite3 "$MEMORY_DB" \
    "DELETE FROM rag_docs WHERE source_path='$FILE_ESC';
     INSERT INTO rag_docs (id, title, content, category, project, source_path)
     VALUES ('$FILE_ID', 'Skill Registry — $TODAY', '$CONTENT_ESC', 'skill', 'global', '$FILE_ESC');
     INSERT INTO rag_docs_fts(rag_docs_fts) VALUES('rebuild');" 2>/dev/null

  echo "  ✓ Indexado en SQLite"
fi

echo ""
echo "✓ Skill registry actualizado — $(( ${#GLOBAL_SKILLS[@]} + ${#PROJECT_SKILLS[@]} )) skills, ${#DETECTED_STACK[@]} herramientas detectadas"
echo ""
