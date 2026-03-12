-- schema-v2.sql — Migración Engram-style: observations, user_prompts, soft-delete, topic_key
-- Aplicar con: sqlite3 ~/.local/enterprise-ai/memory.db < memory/schema-v2.sql
-- Seguro de re-ejecutar (usa IF NOT EXISTS y columnas ignoradas si ya existen)

PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

-- ──────────────────────────────────────────────────────────────────
-- TABLA: observations — Unidad fundamental de memoria (estilo Engram)
-- Reemplaza el uso ad-hoc de decisions + patterns para conocimiento
-- tipo: bugfix | decision | architecture | discovery | pattern | config | business_rule
-- ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS observations (
    id               TEXT PRIMARY KEY DEFAULT (hex(randomblob(8))),
    project          TEXT NOT NULL DEFAULT 'global',
    type             TEXT NOT NULL DEFAULT 'discovery',
                     -- bugfix | decision | architecture | discovery | pattern | config | business_rule
    topic_key        TEXT,                 -- Ej: "auth/jwt-expiration" — clave estable por tema
    title            TEXT NOT NULL,
    -- Campos What/Why/Where/Learned (Engram pattern)
    what             TEXT NOT NULL,        -- Qué ocurrió/se descubrió en 1 oración
    why              TEXT,                 -- Por qué importa / por qué se decidió
    where_ref        TEXT,                 -- Archivo:línea o componente
    learned          TEXT,                 -- Qué aprender para la próxima vez
    -- Metadatos
    tags             TEXT,                 -- JSON array ["auth", "jwt", "bug"]
    revision_count   INTEGER NOT NULL DEFAULT 0,   -- Incrementar al actualizar mismo topic_key
    normalized_hash  TEXT,                 -- SHA256 del contenido para deduplicación
    deleted_at       TEXT,                 -- Soft-delete — NULL = activo
    created_at       TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at       TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_observations_topic_key ON observations(topic_key) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_observations_type      ON observations(type) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_observations_project   ON observations(project) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_observations_hash      ON observations(normalized_hash);

-- FTS5 para búsqueda semántica en observaciones
CREATE VIRTUAL TABLE IF NOT EXISTS observations_fts USING fts5(
    id      UNINDEXED,
    title,
    what,
    why,
    where_ref,
    learned,
    tags,
    content=observations,
    content_rowid=rowid
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

-- ──────────────────────────────────────────────────────────────────
-- TABLA: user_prompts — Track de intención del usuario (mem_save_prompt)
-- Permite reconstruir "qué quería el usuario" independiente de qué hizo el agente
-- ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_prompts (
    id          TEXT PRIMARY KEY DEFAULT (hex(randomblob(8))),
    project     TEXT NOT NULL DEFAULT 'global',
    session_id  TEXT,                      -- FK opcional a sessions
    intent      TEXT NOT NULL,             -- Qué pidió el usuario (parafrasear, no copiar)
    context     TEXT,                      -- Contexto relevante en ese momento
    outcome     TEXT,                      -- Qué resultó de esa intención
    tags        TEXT,                      -- JSON array
    deleted_at  TEXT,
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_user_prompts_project ON user_prompts(project) WHERE deleted_at IS NULL;

-- ──────────────────────────────────────────────────────────────────
-- TABLA: sync_mutations — Journal de cambios para audit trail y sync
-- Append-only: nunca modificar registros existentes
-- ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sync_mutations (
    seq         INTEGER PRIMARY KEY AUTOINCREMENT,
    table_name  TEXT NOT NULL,             -- 'observations' | 'decisions' | 'sessions'
    record_id   TEXT NOT NULL,
    operation   TEXT NOT NULL,             -- 'INSERT' | 'UPDATE' | 'DELETE'
    project     TEXT NOT NULL DEFAULT 'global',
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Trigger de audit trail para observations
CREATE TRIGGER IF NOT EXISTS observations_audit_insert AFTER INSERT ON observations BEGIN
    INSERT INTO sync_mutations(table_name, record_id, operation, project)
    VALUES ('observations', new.id, 'INSERT', new.project);
END;

CREATE TRIGGER IF NOT EXISTS observations_audit_update AFTER UPDATE ON observations BEGIN
    INSERT INTO sync_mutations(table_name, record_id, operation, project)
    VALUES ('observations', new.id, 'UPDATE', new.project);
END;

-- ──────────────────────────────────────────────────────────────────
-- MIGRACIÓN: Añadir columnas Engram a tablas existentes
-- SQLite no tiene ALTER TABLE ADD COLUMN IF NOT EXISTS
-- Estas instrucciones fallan silenciosamente si la columna ya existe
-- ──────────────────────────────────────────────────────────────────

-- decisions: añadir topic_key, revision_count, deleted_at, normalized_hash
ALTER TABLE decisions ADD COLUMN topic_key       TEXT;
ALTER TABLE decisions ADD COLUMN revision_count  INTEGER NOT NULL DEFAULT 0;
ALTER TABLE decisions ADD COLUMN deleted_at      TEXT;
ALTER TABLE decisions ADD COLUMN normalized_hash TEXT;

-- sessions: añadir campos de session summary estructurado
ALTER TABLE sessions ADD COLUMN goal         TEXT;   -- Qué se intentaba conseguir
ALTER TABLE sessions ADD COLUMN instructions TEXT;   -- Qué pidió el usuario
ALTER TABLE sessions ADD COLUMN discoveries  TEXT;   -- Hallazgos no obvios
ALTER TABLE sessions ADD COLUMN accomplished TEXT;   -- Qué se completó

-- ──────────────────────────────────────────────────────────────────
-- VISTAS: actualizar memory_search para incluir observations y user_prompts
-- ──────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS memory_search;
CREATE VIEW memory_search AS
    SELECT 'observation'  AS type, id, title AS content, project, created_at FROM observations WHERE deleted_at IS NULL
    UNION ALL
    SELECT 'decision'     AS type, id, title AS content, project, created_at FROM decisions WHERE deleted_at IS NULL
    UNION ALL
    SELECT 'pattern'      AS type, id, description AS content, project, created_at FROM patterns
    UNION ALL
    SELECT 'integration'  AS type, id, name AS content, project, created_at FROM integrations
    UNION ALL
    SELECT 'task'         AS type, id, title AS content, project, created_at FROM tasks
    UNION ALL
    SELECT 'rag_doc'      AS type, id, title AS content, project, indexed_at AS created_at FROM rag_docs
    UNION ALL
    SELECT 'user_prompt'  AS type, id, intent AS content, project, created_at FROM user_prompts WHERE deleted_at IS NULL;

-- Vista: observaciones activas ordenadas por recientes
DROP VIEW IF EXISTS recent_observations;
CREATE VIEW recent_observations AS
    SELECT id, project, type, topic_key, title, what, learned, revision_count, updated_at
    FROM observations
    WHERE deleted_at IS NULL
    ORDER BY updated_at DESC;

-- Vista: búsqueda de deduplicación (identifica posibles duplicados por topic_key)
DROP VIEW IF EXISTS observation_topics;
CREATE VIEW observation_topics AS
    SELECT topic_key, COUNT(*) AS count, MAX(revision_count) AS max_revision, MAX(updated_at) AS last_updated
    FROM observations
    WHERE deleted_at IS NULL AND topic_key IS NOT NULL
    GROUP BY topic_key
    ORDER BY last_updated DESC;
