# Migration Safety Checklist

**Fecha**: YYYY-MM-DD
**Migration ID**: `YYYYMMDD_HHMMSS_descripcion`
**Tipo**: ADDITIVE | DESTRUCTIVE | DATA_TRANSFORM
**Tablas afectadas**: [lista]
**Estimado de filas afectadas**: ___________
**Entorno objetivo**: DEV | STAGING | PRODUCTION

---

## ADVERTENCIA: Migraciones Destructivas

Si esta migración incluye `DROP COLUMN`, `DROP TABLE`, `ALTER COLUMN` (cambio de tipo),
o cualquier operación que pueda causar pérdida de datos — revisar el flujo Expand→Migrate→Contract:

```
Deploy 1 — EXPAND:   añadir columna nueva, código soporta ambas columnas
Deploy 2 — MIGRATE:  backfill de datos, verificar consistencia
Deploy 3 — CONTRACT: eliminar columna vieja, código ya no la referencia
```

**¿Esta migración sigue el flujo expand→migrate→contract?** SÍ | NO — Justificación: ___

---

## Pre-Migration Checklist

### Código
- [ ] La migración tiene función `up()` implementada y probada
- [ ] La migración tiene función `down()` implementada y probada (rollback funcional)
- [ ] Los tests pasan contra schema post-migración
- [ ] No hay código en la app que dependa del schema viejo (si es destructiva)

### Datos
- [ ] Probada contra dump anonimizado de producción: FECHA: ___________
- [ ] Tiempo de ejecución estimado en producción: ___________ (basado en prueba)
- [ ] Si > 30 segundos: ¿se ejecutará en ventana de mantenimiento? SÍ | NO
- [ ] Si requiere LOCK en tabla con > 1M filas: ¿estrategia definida? ___________

### Backup
- [ ] Backup verificado de producción: FECHA: ___________
- [ ] Backup restaurable (probado): SÍ | PENDIENTE
- [ ] RTO (tiempo de restauración): ___________ minutos

### Rollback
- [ ] Procedimiento de rollback documentado abajo
- [ ] `down()` probada en entorno de staging
- [ ] Tiempo estimado de rollback: ___________ minutos

---

## Plan de Ejecución

```sql
-- 1. Verificar estado pre-migración
SELECT COUNT(*) FROM [tabla];
-- Resultado esperado: ___________

-- 2. Ejecutar migración
[comando de migración]

-- 3. Verificar post-migración
SELECT COUNT(*) FROM [tabla];
-- Resultado esperado: ___________

-- 4. Smoke test
[query de verificación]
```

---

## Procedimiento de Rollback

Si algo falla durante o después de la migración:

```bash
# Paso 1: Ejecutar down()
[comando rollback]

# Paso 2: Verificar estado
[query verificación]

# Paso 3: Si down() falla, restaurar backup
[comando restore]
```

**Criterios para activar rollback automáticamente**:
- [ ] Error rate > X% en los 5 min post-deploy
- [ ] Latencia p95 > Y ms
- [ ] Errores en logs de tipo: ___________

---

## Post-Migration Checklist

- [ ] Smoke tests pasando en producción
- [ ] Métricas de la tabla normales (no locks, query time normal)
- [ ] Logs sin errores relacionados a la migración
- [ ] Migration marcada como completada en el registro

---

## Historial

| Entorno | Fecha | Resultado | Notas |
|---------|-------|-----------|-------|
| DEV     |       | OK / FAIL |       |
| STAGING |       | OK / FAIL |       |
| PROD    |       | OK / FAIL |       |
