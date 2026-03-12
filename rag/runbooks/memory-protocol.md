# Memory Protocol — Cuándo y Cómo Guardar Memoria

## Regla Fundamental

**La memoria es un contrato de continuidad.** Sin memoria estructurada, cada sesión empieza desde cero.
El agente que no guarda memoria roba tiempo a su próxima versión.

---

## CUÁNDO Guardar (triggers obligatorios)

Guardar una observación SIEMPRE después de:

| Evento | Tipo | Urgencia |
|--------|------|----------|
| Bug resuelto (especialmente si tomó > 15 min) | `bugfix` | Inmediata |
| Decisión de diseño o arquitectura tomada | `decision` | Inmediata |
| Descubrimiento no obvio sobre el codebase | `discovery` | Inmediata |
| Patrón reutilizable identificado | `pattern` | Al cierre |
| Configuración de sistema o entorno resuelta | `config` | Inmediata |
| Regla de negocio confirmada con el usuario | `business_rule` | Inmediata |
| ADR (Architecture Decision Record) creado | `architecture` | Al cierre |

**NO guardar**:
- Acciones rutinarias sin aprendizaje (leer un archivo, hacer un grep)
- Información temporal de la sesión actual
- Datos que ya están en el código o en los archivos del proyecto

---

## CÓMO Guardar — Formato What/Why/Where/Learned

Toda observación debe seguir esta estructura:

```
WHAT: [Qué ocurrió / qué se descubrió en 1 oración]
WHY: [Por qué importa / por qué se tomó esa decisión]
WHERE: [Archivo:línea o componente donde aplica]
LEARNED: [Qué aprender para la próxima vez]
```

### Ejemplo — Bugfix
```
WHAT: El endpoint /auth/refresh fallaba con 401 cuando el token tenía exactamente 0 segundos de vida
WHY: JWT usa <= no < para verificar expiración; un segundo de diferencia entre servers causaba el fallo
WHERE: src/auth/jwt.service.ts:142 — validación de expiración
LEARNED: Siempre añadir clock_skew_tolerance de 30s en validaciones JWT entre servicios
```

### Ejemplo — Decisión de arquitectura
```
WHAT: Decidimos usar BullMQ en lugar de SQS para la cola de jobs de emails
WHY: Latencia < 100ms requerida; SQS tiene latencia mínima de 1s por long polling
WHERE: services/email/ — toda la capa de jobs
LEARNED: Para jobs internos de baja latencia: Redis queue > SQS. Para durabilidad cross-region: SQS.
```

### Ejemplo — Regla de negocio
```
WHAT: Los pedidos en estado PENDIENTE no pueden cancelarse si han pasado más de 2 horas desde creación
WHY: Regla confirmada por el usuario — el proveedor logístico ya habrá iniciado el picking
WHERE: Módulo orders — toda acción de cancelación debe verificar esta regla
LEARNED: Verificar created_at + 2h ANTES de mostrar opción de cancelar en UI
```

---

## topic_key — Identificador de Continuidad

El `topic_key` permite rastrear un tema a lo largo del tiempo sin duplicados.

**Formato**: `<ámbito>/<tema-en-kebab-case>`

```
auth/jwt-expiration-handling
db/postgres-connection-pooling
api/rate-limit-strategy
payment/stripe-webhook-retry
```

**Regla**: Si ya existe una observación con el mismo `topic_key`, actualizar (`revision_count + 1`) en lugar de crear una nueva.

---

## Datos Privados — Stripping Obligatorio

Antes de guardar CUALQUIER observación, verificar que NO contiene:
- Contraseñas, tokens, API keys
- PII (emails reales, IPs de usuarios, nombres)
- Datos de producción

Si necesitas incluirlos para dar contexto, usar marcado privado:
```
WHAT: La API key de Stripe estaba configurada incorrectamente
WHERE: <private>sk_live_abc123xyz...</private> → variable de entorno STRIPE_SECRET_KEY
```

El sistema elimina automáticamente el contenido entre `<private>...</private>` antes de persistir.

---

## Cómo Guardar en SQLite

### Insertar una observación nueva:
```sql
INSERT INTO observations (id, project, type, topic_key, title, what, why, where_ref, learned, tags)
VALUES (
  hex(randomblob(8)),
  'mi-proyecto',
  'bugfix',
  'auth/jwt-expiration',
  'JWT expiration off-by-one en validación',
  'El endpoint /auth/refresh fallaba con 401...',
  'JWT usa <= no < para verificar expiración...',
  'src/auth/jwt.service.ts:142',
  'Siempre añadir clock_skew_tolerance de 30s...',
  '["jwt","auth","bug"]'
);
```

### Actualizar observación existente (mismo topic_key):
```sql
UPDATE observations
SET what = '<nuevo contenido>',
    learned = '<nuevo aprendizaje>',
    revision_count = revision_count + 1,
    updated_at = datetime('now')
WHERE topic_key = 'auth/jwt-expiration'
  AND deleted_at IS NULL;
```

### Buscar en memoria:
```sql
SELECT title, type, what, learned, updated_at
FROM observations
WHERE deleted_at IS NULL
ORDER BY updated_at DESC
LIMIT 10;

-- Búsqueda FTS5:
SELECT title, snippet(observations_fts, 3, '[', ']', '...', 20) AS preview
FROM observations_fts
WHERE observations_fts MATCH 'jwt OR auth OR token'
ORDER BY rank;
```

---

## Progressive Disclosure — Cómo Presentar Resultados

Al buscar en memoria, presentar en 3 niveles (no volcar todo de golpe):

**Nivel 1 — Resumen** (siempre):
```
[bugfix] auth/jwt-expiration — JWT expiration off-by-one (hace 3 días)
```

**Nivel 2 — Contexto** (si el nivel 1 es relevante):
```
WHAT: El endpoint /auth/refresh fallaba con 401...
WHERE: src/auth/jwt.service.ts:142
```

**Nivel 3 — Detalle completo** (solo si se necesita para la tarea actual):
```
WHY + LEARNED completos
```

---

## Session Summary — Formato Estructurado

Al cerrar cada sesión, guardar con este formato:

```
GOAL: [Qué se intentaba conseguir en esta sesión]
INSTRUCTIONS: [Qué pidió el usuario exactamente]
DISCOVERIES: [Hallazgos no obvios encontrados durante la sesión]
ACCOMPLISHED: [Qué se completó efectivamente]
RELEVANT_FILES: [Archivos clave tocados con file:line]
NEXT_STEPS: [Qué queda pendiente para la próxima sesión]
```

---

## Regla de Oro

> **Un bug resuelto sin observación guardada es un bug que se resolverá dos veces.**
> **Una decisión sin topic_key es una decisión que se debatirá de nuevo.**
