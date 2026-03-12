---
trigger: automatización OR webhook OR cron OR integración OR ETL OR pipeline OR scheduler OR worker OR queue
scope: Automatizaciones y sistemas empresariales
priority: high
---

# Automation Skill

## Principios Fundamentales

### Todo job es idempotente
Antes de ejecutar cualquier operación, implementa una de estas estrategias:
- **Check-then-act**: Consulta si ya existe el resultado antes de crearlo.
- **Upsert**: Inserta o actualiza, nunca duplica.
- **ID de idempotencia**: Genera un ID determinista para cada operación (hash de los inputs).

### Flujo base de cualquier job
```
1. Acquire lock (distributed si hay múltiples instancias)
2. Log inicio con job_id
3. Ejecutar tarea
4. Log resultado
5. Release lock
6. Alertar si falla o excede SLA
```

## Retry Pattern

```python
import asyncio
import random
from functools import wraps

def with_retry(max_retries: int = 3, base_delay: float = 1.0):
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            for attempt in range(max_retries):
                try:
                    return await func(*args, **kwargs)
                except Exception as e:
                    if attempt == max_retries - 1:
                        raise
                    delay = base_delay * (2 ** attempt) + random.uniform(0, 0.5)
                    logger.warning(f"Retry {attempt + 1}/{max_retries} after {delay:.2f}s: {e}")
                    await asyncio.sleep(delay)
        return wrapper
    return decorator
```

## Webhook Pattern

```python
@router.post("/webhooks/{provider}")
async def handle_webhook(
    provider: str,
    request: Request,
    background_tasks: BackgroundTasks,
):
    # 1. Leer raw payload ANTES de parsear
    raw_body = await request.body()

    # 2. Verificar firma ANTES de procesar
    signature = request.headers.get("X-Signature")
    if not verify_signature(raw_body, signature, settings.WEBHOOK_SECRET):
        raise HTTPException(status_code=401, detail="Invalid signature")

    # 3. Responder 200 INMEDIATAMENTE
    # 4. Procesar en background
    event_id = str(uuid4())
    await store_raw_event(event_id, provider, raw_body)
    background_tasks.add_task(process_webhook_event, event_id, provider, raw_body)

    return {"received": True, "event_id": event_id}
```

## Dead Letter Queue

```python
async def process_with_dlq(task: Task) -> None:
    try:
        await execute_task(task)
    except Exception as e:
        task.attempts += 1
        if task.attempts >= MAX_RETRIES:
            await move_to_dlq(task, error=str(e))
            await notify_team(f"Task {task.id} moved to DLQ: {e}")
        else:
            await reschedule_task(task)
```

## Logging Estructurado

```python
import structlog

logger = structlog.get_logger()

# En cada job
logger.info(
    "job.started",
    job_id=job_id,
    job_type="sync_users",
    source="crm",
    target="database",
)

logger.info(
    "job.completed",
    job_id=job_id,
    records_processed=150,
    duration_ms=234,
    errors=0,
)
```

## Circuit Breaker

```python
from circuitbreaker import circuit

@circuit(failure_threshold=5, recovery_timeout=60, expected_exception=Exception)
async def call_external_api(endpoint: str, payload: dict) -> dict:
    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.post(endpoint, json=payload)
        response.raise_for_status()
        return response.json()
```

## Herramientas por Caso de Uso

| Caso | Herramienta |
|------|-------------|
| Job queue | Celery + Redis / ARQ / Dramatiq |
| Cron scheduling | APScheduler / Celery Beat |
| Workflow complejo | Prefect / Temporal |
| Event streaming | Kafka / RabbitMQ |
| File ETL | Pandas / Polars |
| Distributed lock | Redis SETNX / Redlock |
