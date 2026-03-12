#!/usr/bin/env bash
# db-migrate.sh — Aplica schema-v2 (Engram-style: observations, topic_key, soft-delete)
# Uso: ./scripts/db-migrate.sh
# Seguro de re-ejecutar: las columnas que ya existen generan error ignorado

set -euo pipefail

export PATH="/c/Program Files/nodejs:/c/Users/insyd/AppData/Local/Microsoft/WinGet/Packages/SQLite.SQLite_Microsoft.Winget.Source_8wekyb3d8bbwe:/c/Users/insyd/AppData/Local/Microsoft/WinGet/Packages/astral-sh.uv_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"

MEMORY_DB="${USERPROFILE:-$HOME}/.local/enterprise-ai/memory.db"
SCHEMA_V2="$(cd "$(dirname "$0")/.." && pwd)/memory/schema-v2.sql"

echo ""
echo "╔══════════════════════════════════╗"
echo "║   Enterprise AI — DB Migrate v2  ║"
echo "╚══════════════════════════════════╝"
echo "  DB:     $MEMORY_DB"
echo "  Schema: $SCHEMA_V2"
echo ""

if ! command -v sqlite3 &>/dev/null; then
  echo "ERROR: sqlite3 no encontrado."
  exit 1
fi

if [ ! -f "$MEMORY_DB" ]; then
  echo "ERROR: DB no encontrada. Ejecutar primero: ./scripts/db-init.sh"
  exit 1
fi

if [ ! -f "$SCHEMA_V2" ]; then
  echo "ERROR: schema-v2.sql no encontrado en $SCHEMA_V2"
  exit 1
fi

# Backup antes de migrar
BACKUP="${MEMORY_DB}.backup-$(date '+%Y%m%d_%H%M%S')"
cp "$MEMORY_DB" "$BACKUP"
echo "  ✓ Backup creado: $BACKUP"
echo ""

# Aplicar schema-v2
# Las instrucciones ALTER TABLE fallan si la columna ya existe — ignorar esos errores
echo "▶ Aplicando schema-v2..."
echo ""

# Ejecutar el schema completo, capturando errores de ALTER TABLE (columna ya existe)
# SQLite devuelve "duplicate column name" cuando la columna ya existe — es seguro ignorarlo
sqlite3 "$MEMORY_DB" << 'EOF_SQLITE'
.bail off
EOF_SQLITE

# Aplicar en dos partes: primero lo que no puede fallar, luego los ALTER (que pueden fallar)
# Parte 1: Nuevas tablas, triggers, vistas (seguro)
sqlite3 "$MEMORY_DB" << 'SQL_SAFE'
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

CREATE TABLE IF NOT EXISTS observations (
    id               TEXT PRIMARY KEY DEFAULT (hex(randomblob(8))),
    project          TEXT NOT NULL DEFAULT 'global',
    type             TEXT NOT NULL DEFAULT 'discovery',
    topic_key        TEXT,
    title            TEXT NOT NULL,
    what             TEXT NOT NULL,
    why              TEXT,
    where_ref        TEXT,
    learned          TEXT,
    tags             TEXT,
    revision_count   INTEGER NOT NULL DEFAULT 0,
    normalized_hash  TEXT,
    deleted_at       TEXT,
    created_at       TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at       TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_observations_topic_key ON observations(topic_key) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_observations_type      ON observations(type) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_observations_project   ON observations(project) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_observations_hash      ON observations(normalized_hash);

CREATE VIRTUAL TABLE IF NOT EXISTS observations_fts USING fts5(
    id UNINDEXED, title, what, why, where_ref, learned, tags,
    content=observations, content_rowid=rowid
);

CREATE TRIGGER IF NOT EXISTS observations_ai AFTER INSERT ON observations BEGIN
    INSERT INTO observations_fts(rowid, id, title, what, why, where_ref, learned, tags)
    VALUES (new.rowid, new.id, new.title, new.what, new.why, new.where_ref, new.learned, new.tags);
END;

CREATE TRIGGER IF NOT EXISTS observations_au AFTER UPDATE ON observations BEGIN
    INSERT INTO observations_fts(observations_fts, rowid, id, title, what, why, where_ref, learned, tags)
    VALUES ('delete', old.rowid, old.id, old.title, old.what, old.why, old.where_ref, old.learned, old.tags);
    INSERT INTO observations_fts(rowid, id, title, what, why, where_ref, learned, tags)
    VALUES (new.rowid, new.id, new.title, new.what, new.why, new.where_ref, new.learned, new.tags);
END;

CREATE TABLE IF NOT EXISTS user_prompts (
    id          TEXT PRIMARY KEY DEFAULT (hex(randomblob(8))),
    project     TEXT NOT NULL DEFAULT 'global',
    session_id  TEXT,
    intent      TEXT NOT NULL,
    context     TEXT,
    outcome     TEXT,
    tags        TEXT,
    deleted_at  TEXT,
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_user_prompts_project ON user_prompts(project) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS sync_mutations (
    seq         INTEGER PRIMARY KEY AUTOINCREMENT,
    table_name  TEXT NOT NULL,
    record_id   TEXT NOT NULL,
    operation   TEXT NOT NULL,
    project     TEXT NOT NULL DEFAULT 'global',
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TRIGGER IF NOT EXISTS observations_audit_insert AFTER INSERT ON observations BEGIN
    INSERT INTO sync_mutations(table_name, record_id, operation, project)
    VALUES ('observations', new.id, 'INSERT', new.project);
END;

CREATE TRIGGER IF NOT EXISTS observations_audit_update AFTER UPDATE ON observations BEGIN
    INSERT INTO sync_mutations(table_name, record_id, operation, project)
    VALUES ('observations', new.id, 'UPDATE', new.project);
END;

DROP VIEW IF EXISTS memory_search;
CREATE VIEW memory_search AS
    SELECT 'observation' AS type, id, title AS content, project, created_at FROM observations WHERE deleted_at IS NULL
    UNION ALL
    SELECT 'decision'    AS type, id, title AS content, project, created_at FROM decisions WHERE deleted_at IS NULL
    UNION ALL
    SELECT 'pattern'     AS type, id, description AS content, project, created_at FROM patterns
    UNION ALL
    SELECT 'integration' AS type, id, name AS content, project, created_at FROM integrations
    UNION ALL
    SELECT 'task'        AS type, id, title AS content, project, created_at FROM tasks
    UNION ALL
    SELECT 'rag_doc'     AS type, id, title AS content, project, indexed_at AS created_at FROM rag_docs
    UNION ALL
    SELECT 'user_prompt' AS type, id, intent AS content, project, created_at FROM user_prompts WHERE deleted_at IS NULL;

DROP VIEW IF EXISTS recent_observations;
CREATE VIEW recent_observations AS
    SELECT id, project, type, topic_key, title, what, learned, revision_count, updated_at
    FROM observations WHERE deleted_at IS NULL ORDER BY updated_at DESC;

DROP VIEW IF EXISTS observation_topics;
CREATE VIEW observation_topics AS
    SELECT topic_key, COUNT(*) AS count, MAX(revision_count) AS max_revision, MAX(updated_at) AS last_updated
    FROM observations WHERE deleted_at IS NULL AND topic_key IS NOT NULL
    GROUP BY topic_key ORDER BY last_updated DESC;
SQL_SAFE

echo "  ✓ Nuevas tablas y vistas creadas"

# Parte 2: ALTER TABLE (puede fallar si columnas ya existen — ignorar errores)
run_alter() {
  sqlite3 "$MEMORY_DB" "$1" 2>/dev/null && echo "  ✓ $2" || echo "  · $2 (ya existe)"
}

echo ""
echo "▶ Migrando columnas existentes..."
run_alter "ALTER TABLE decisions ADD COLUMN topic_key       TEXT;"       "decisions.topic_key"
run_alter "ALTER TABLE decisions ADD COLUMN revision_count  INTEGER NOT NULL DEFAULT 0;" "decisions.revision_count"
run_alter "ALTER TABLE decisions ADD COLUMN deleted_at      TEXT;"       "decisions.deleted_at"
run_alter "ALTER TABLE decisions ADD COLUMN normalized_hash TEXT;"       "decisions.normalized_hash"
run_alter "ALTER TABLE sessions  ADD COLUMN goal            TEXT;"       "sessions.goal"
run_alter "ALTER TABLE sessions  ADD COLUMN instructions    TEXT;"       "sessions.instructions"
run_alter "ALTER TABLE sessions  ADD COLUMN discoveries     TEXT;"       "sessions.discoveries"
run_alter "ALTER TABLE sessions  ADD COLUMN accomplished    TEXT;"       "sessions.accomplished"

# Verificar resultado
echo ""
echo "▶ Estado final de la DB:"
TABLES=$(sqlite3 "$MEMORY_DB" ".tables" 2>/dev/null)
echo "$TABLES" | tr ' ' '\n' | grep -v '^$' | sort | while read -r t; do
  echo "  ✓ $t"
done

# Contar rows por tabla principal
echo ""
echo "▶ Registros existentes:"
sqlite3 "$MEMORY_DB" -column \
  "SELECT 'decisions' AS tabla, COUNT(*) AS n FROM decisions
   UNION ALL SELECT 'sessions', COUNT(*) FROM sessions
   UNION ALL SELECT 'observations', COUNT(*) FROM observations
   UNION ALL SELECT 'rag_docs', COUNT(*) FROM rag_docs
   UNION ALL SELECT 'tasks', COUNT(*) FROM tasks;" 2>/dev/null || true

echo ""
echo "✓ Migración v2 completada"
echo "  Backup guardado en: $BACKUP"
echo ""
