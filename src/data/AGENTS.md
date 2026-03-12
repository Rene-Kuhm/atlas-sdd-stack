# AGENTS.md — Módulo Data

## Scope
Todo código en `src/data/`: modelos, migraciones, queries, seeds, repositories.

## Migraciones

- NUNCA modifiques una migración ya aplicada en producción. Crea una nueva.
- Toda migración tiene su `down()` (rollback) implementado.
- Nombre de migración: `YYYYMMDD_HHMMSS_descripcion_corta`.
- Prueba el rollback antes de mergear.

## Schema Design

- Primary keys: UUID v4 por defecto (no auto-increment secuencial en sistemas distribuidos).
- Timestamps: `created_at`, `updated_at` en toda tabla. Soft deletes con `deleted_at`.
- Foreign keys con índice siempre.
- Nombres de tablas: plural, snake_case. Nombres de columnas: snake_case.

## Queries

- ORM para CRUD estándar. SQL raw solo para queries complejas o de performance crítica.
- Nunca `SELECT *` en producción. Lista columnas explícitamente.
- Explain/analyze antes de mergear queries sobre tablas grandes.
- Paginación con cursor (no offset) para datasets grandes.

## Repository Pattern

Toda lógica de acceso a datos vive en un Repository.
La lógica de negocio no importa ORMs ni conexiones de DB directamente.

```
business_logic.py → UserRepository → DB
```

## Seguridad de Datos

- Nunca loguees datos personales (PII).
- Encripta datos sensibles en reposo (no solo la DB completa).
- Backups: política de retención documentada, restore testeado mensualmente.
- Acceso a producción: solo con necesidad justificada y auditoría.
