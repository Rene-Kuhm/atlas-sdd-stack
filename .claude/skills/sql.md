---
trigger: SQL OR PostgreSQL OR MySQL OR SQLite OR query OR migration OR schema OR ORM
scope: Base de datos y queries
priority: medium
---

# SQL Skill

## Diseño de Schema

```sql
-- Tabla base estándar
CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email       VARCHAR(255) NOT NULL UNIQUE,
    name        VARCHAR(100) NOT NULL,
    role        VARCHAR(50) NOT NULL DEFAULT 'viewer',
    metadata    JSONB DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at  TIMESTAMPTZ  -- soft delete
);

-- Índices siempre en foreign keys y columnas de búsqueda frecuente
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_deleted_at ON users(deleted_at) WHERE deleted_at IS NULL;

-- Trigger para updated_at automático
CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();
```

## Queries: Reglas

- **NUNCA** `SELECT *` en código de producción.
- Usa CTEs para queries complejas (legibilidad).
- Paginación con cursor en datasets > 10k rows:

```sql
-- Paginación con cursor (eficiente)
SELECT id, name, created_at
FROM users
WHERE deleted_at IS NULL
  AND created_at < :cursor_timestamp
  AND id < :cursor_id
ORDER BY created_at DESC, id DESC
LIMIT 20;

-- Paginación OFFSET (solo para datasets pequeños < 10k rows)
SELECT id, name FROM users LIMIT 20 OFFSET 100;
```

## EXPLAIN antes de mergear

Para queries sobre tablas > 1k rows, incluye el plan:
```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT ...;
```
Señales de alerta: `Seq Scan` en tablas grandes, `Hash Join` sin índice, loops N+1.

## Migraciones

```sql
-- Formato: YYYYMMDD_HHMMSS_descripcion.sql
-- 20240115_143022_add_user_metadata.sql

-- UP
ALTER TABLE users ADD COLUMN metadata JSONB DEFAULT '{}';
CREATE INDEX CONCURRENTLY idx_users_metadata ON users USING GIN(metadata);

-- DOWN
DROP INDEX IF EXISTS idx_users_metadata;
ALTER TABLE users DROP COLUMN IF EXISTS metadata;
```

Reglas de migraciones:
- `CONCURRENTLY` en índices de tablas con datos (no bloquea).
- `IF EXISTS` / `IF NOT EXISTS` para idempotencia.
- Nunca modifiques el tipo de una columna sin migración de datos.
- Prueba el DOWN antes de mergear.

## Anti-patrones a Evitar

```sql
-- MAL: N+1 queries
-- Nunca hagas queries dentro de loops. Usa JOIN o IN.

-- MAL: Columnas calculadas sin índice funcional
WHERE LOWER(email) = 'test@test.com'  -- usar índice funcional o columna generada

-- BIEN: Índice funcional
CREATE INDEX idx_users_email_lower ON users(LOWER(email));
```
