-- Enterprise AI Stack — Memory Database Schema
-- SQLite con FTS5 para búsqueda full-text instantánea

PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

-- ──────────────────────────────────────────────────
-- Decisiones Arquitectónicas (ADRs en DB)
-- ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS decisions (
    id          TEXT PRIMARY KEY,               -- uuid
    project     TEXT NOT NULL DEFAULT 'global',
    title       TEXT NOT NULL,
    context     TEXT NOT NULL,
    decision    TEXT NOT NULL,
    reasoning   TEXT NOT NULL,
    consequences TEXT,
    status      TEXT NOT NULL DEFAULT 'active', -- active | deprecated | superseded
    superseded_by TEXT,
    tags        TEXT,                           -- JSON array ["auth", "db"]
    created_at  TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

-- FTS5 para búsqueda semántica rápida en decisiones
CREATE VIRTUAL TABLE IF NOT EXISTS decisions_fts USING fts5(
    id UNINDEXED,
    title,
    context,
    decision,
    reasoning,
    tags,
    content=decisions,
    content_rowid=rowid
);

CREATE TRIGGER IF NOT EXISTS decisions_ai AFTER INSERT ON decisions BEGIN
    INSERT INTO decisions_fts(rowid, id, title, context, decision, reasoning, tags)
    VALUES (new.rowid, new.id, new.title, new.context, new.decision, new.reasoning, new.tags);
END;

CREATE TRIGGER IF NOT EXISTS decisions_au AFTER UPDATE ON decisions BEGIN
    INSERT INTO decisions_fts(decisions_fts, rowid, id, title, context, decision, reasoning, tags)
    VALUES ('delete', old.rowid, old.id, old.title, old.context, old.decision, old.reasoning, old.tags);
    INSERT INTO decisions_fts(rowid, id, title, context, decision, reasoning, tags)
    VALUES (new.rowid, new.id, new.title, new.context, new.decision, new.reasoning, new.tags);
END;

-- ──────────────────────────────────────────────────
-- Sesiones de trabajo
-- ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sessions (
    id          TEXT PRIMARY KEY,
    project     TEXT NOT NULL,
    summary     TEXT NOT NULL,    -- Qué se hizo
    decisions   TEXT,             -- JSON array de decision IDs relacionados
    files       TEXT,             -- JSON array de archivos modificados
    next_steps  TEXT,             -- Qué queda pendiente
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ──────────────────────────────────────────────────
-- Cache de archivos para GGA (pre-commit hook)
-- ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS file_cache (
    path        TEXT PRIMARY KEY,
    hash        TEXT NOT NULL,
    last_review TEXT,             -- Resultado del último review
    reviewed_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ──────────────────────────────────────────────────
-- Patrones del proyecto (aprendizaje incremental)
-- ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS patterns (
    id          TEXT PRIMARY KEY,
    category    TEXT NOT NULL,    -- 'naming', 'structure', 'error-handling', etc.
    description TEXT NOT NULL,
    example     TEXT,
    source      TEXT,             -- De dónde viene este patrón
    project     TEXT NOT NULL DEFAULT 'global',
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE VIRTUAL TABLE IF NOT EXISTS patterns_fts USING fts5(
    id UNINDEXED,
    category,
    description,
    example,
    content=patterns,
    content_rowid=rowid
);

-- ──────────────────────────────────────────────────
-- Integrations registry
-- ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS integrations (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    provider    TEXT NOT NULL,    -- 'stripe', 'sendgrid', etc.
    endpoint    TEXT,
    auth_type   TEXT,             -- 'api_key', 'oauth', 'basic'
    env_var     TEXT,             -- Nombre de la variable de entorno del secret
    status      TEXT DEFAULT 'active',
    notes       TEXT,
    project     TEXT NOT NULL,
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ──────────────────────────────────────────────────
-- Tareas (Task Tracking para trabajo masivo diario)
-- ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tasks (
    id          TEXT PRIMARY KEY,                    -- uuid
    project     TEXT NOT NULL,
    title       TEXT NOT NULL,
    description TEXT,
    status      TEXT NOT NULL DEFAULT 'pending',     -- pending | in_progress | blocked | done | cancelled
    priority    TEXT NOT NULL DEFAULT 'medium',      -- critical | high | medium | low
    worktree    TEXT,                                -- branch/worktree asignado
    blocked_by  TEXT,                               -- JSON array de task IDs bloqueantes
    tags        TEXT,                               -- JSON array
    created_at  TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at  TEXT NOT NULL DEFAULT (datetime('now')),
    done_at     TEXT
);

CREATE VIRTUAL TABLE IF NOT EXISTS tasks_fts USING fts5(
    id UNINDEXED,
    title,
    description,
    tags,
    content=tasks,
    content_rowid=rowid
);

CREATE TRIGGER IF NOT EXISTS tasks_ai AFTER INSERT ON tasks BEGIN
    INSERT INTO tasks_fts(rowid, id, title, description, tags)
    VALUES (new.rowid, new.id, new.title, new.description, new.tags);
END;

CREATE TRIGGER IF NOT EXISTS tasks_au AFTER UPDATE ON tasks BEGIN
    INSERT INTO tasks_fts(tasks_fts, rowid, id, title, description, tags)
    VALUES ('delete', old.rowid, old.id, old.title, old.description, old.tags);
    INSERT INTO tasks_fts(rowid, id, title, description, tags)
    VALUES (new.rowid, new.id, new.title, new.description, new.tags);
END;

-- ──────────────────────────────────────────────────
-- RAG Documents (índice full-text de documentación interna)
-- ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS rag_docs (
    id          TEXT PRIMARY KEY,       -- path relativo del archivo
    title       TEXT NOT NULL,
    content     TEXT NOT NULL,
    category    TEXT NOT NULL,          -- 'runbook' | 'pattern' | 'api' | 'adr' | 'doc'
    project     TEXT NOT NULL DEFAULT 'global',
    source_path TEXT NOT NULL,
    indexed_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE VIRTUAL TABLE IF NOT EXISTS rag_docs_fts USING fts5(
    id UNINDEXED,
    title,
    content,
    category,
    content=rag_docs,
    content_rowid=rowid
);

CREATE TRIGGER IF NOT EXISTS rag_docs_ai AFTER INSERT ON rag_docs BEGIN
    INSERT INTO rag_docs_fts(rowid, id, title, content, category)
    VALUES (new.rowid, new.id, new.title, new.content, new.category);
END;

CREATE TRIGGER IF NOT EXISTS rag_docs_au AFTER UPDATE ON rag_docs BEGIN
    INSERT INTO rag_docs_fts(rag_docs_fts, rowid, id, title, content, category)
    VALUES ('delete', old.rowid, old.id, old.title, old.content, old.category);
    INSERT INTO rag_docs_fts(rowid, id, title, content, category)
    VALUES (new.rowid, new.id, new.title, new.content, new.category);
END;

-- ──────────────────────────────────────────────────
-- Vista: búsqueda unificada
-- ──────────────────────────────────────────────────
CREATE VIEW IF NOT EXISTS memory_search AS
    SELECT 'decision' AS type, id, title AS content, created_at FROM decisions
    UNION ALL
    SELECT 'pattern' AS type, id, description AS content, created_at FROM patterns
    UNION ALL
    SELECT 'integration' AS type, id, name AS content, created_at FROM integrations
    UNION ALL
    SELECT 'task' AS type, id, title AS content, created_at FROM tasks
    UNION ALL
    SELECT 'rag_doc' AS type, id, title AS content, indexed_at AS created_at FROM rag_docs;

-- ──────────────────────────────────────────────────
-- Vistas operacionales para trabajo diario
-- ──────────────────────────────────────────────────
CREATE VIEW IF NOT EXISTS daily_dashboard AS
    SELECT
        (SELECT COUNT(*) FROM tasks WHERE status = 'in_progress') AS en_progreso,
        (SELECT COUNT(*) FROM tasks WHERE status = 'blocked')     AS bloqueadas,
        (SELECT COUNT(*) FROM tasks WHERE status = 'pending')     AS pendientes,
        (SELECT COUNT(*) FROM tasks WHERE status = 'done'
         AND done_at >= date('now'))                              AS completadas_hoy;

CREATE VIEW IF NOT EXISTS active_tasks AS
    SELECT id, project, title, priority, status, worktree, created_at
    FROM tasks
    WHERE status IN ('in_progress', 'blocked')
    ORDER BY
        CASE priority
            WHEN 'critical' THEN 1
            WHEN 'high'     THEN 2
            WHEN 'medium'   THEN 3
            WHEN 'low'      THEN 4
        END,
        created_at ASC;
