# AGENTS.md — Módulo Automation

## Scope
Todo código en `src/automation/` sigue estas reglas. Este módulo maneja integraciones,
webhooks, crons, ETLs y automatizaciones de sistemas empresariales.

## Principios Core

### Idempotencia Obligatoria
Toda operación debe poder ejecutarse múltiples veces con el mismo resultado.
Usa IDs de idempotencia en requests externos. Implementa deduplicación.

### Retry con Backoff Exponencial
```python
# Patrón base para toda llamada externa
MAX_RETRIES = 3
INITIAL_DELAY = 1  # segundos
backoff = INITIAL_DELAY * (2 ** attempt) + random.uniform(0, 1)
```

### Dead Letter Queue
Todo mensaje/tarea que falle después de MAX_RETRIES va a DLQ.
La DLQ es inspeccionable y re-procesable manualmente.

## Logging Estructurado (obligatorio)

```json
{
  "timestamp": "ISO8601",
  "level": "INFO|WARN|ERROR",
  "service": "nombre-del-servicio",
  "task_id": "uuid",
  "event": "descripción-del-evento",
  "duration_ms": 123,
  "error": null
}
```

Nunca uses `print()` o `console.log()` en producción. Siempre logger estructurado.

## Webhooks

- Valida firma del webhook antes de procesar (HMAC-SHA256).
- Responde 200 inmediatamente, procesa en background.
- Almacena el payload raw antes de parsear (para replay).

## Crons y Scheduled Jobs

- Cada job tiene un timeout explícito.
- Registra inicio, fin y resultado en la DB.
- Alertas si el job no ejecuta en el intervalo esperado (missed heartbeat).
- Nunca dos instancias del mismo job corriendo simultáneamente (distributed lock).

## Integraciones Externas

- Circuit breaker para cada integración externa.
- Health check activo por integración.
- Documenta en `docs/integrations/<nombre>.md` el contrato de cada integración.
- Variables de entorno para todas las credenciales. Esquema documentado en `.env.example`.

## Testing Automations

- Mockea siempre servicios externos en tests unitarios.
- Tests de integración contra sandboxes reales (no producción).
- Test del flujo de error/retry explícitamente.
