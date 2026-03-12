# Pattern: Error Handling Estándar

**Categoría**: error-handling
**Aplica a**: Python, TypeScript, cualquier servicio HTTP

## El problema

Errores inconsistentes entre servicios hacen imposible el debugging distribuido.
Sin `trace_id`, no puedes correlacionar logs. Sin tipo estandarizado, el frontend no puede manejar errores genéricamente.

## El patrón

### Python (FastAPI)

```python
from enum import Enum
from dataclasses import dataclass
from datetime import datetime, UTC
import uuid

class ErrorType(str, Enum):
    VALIDATION    = "ValidationError"
    AUTH          = "AuthError"
    FORBIDDEN     = "ForbiddenError"
    NOT_FOUND     = "NotFoundError"
    CONFLICT      = "ConflictError"
    RATE_LIMIT    = "RateLimitError"
    INTERNAL      = "InternalError"
    EXTERNAL_SVC  = "ExternalSvcError"

@dataclass
class AppError(Exception):
    type: ErrorType
    code: str           # SCREAMING_SNAKE_CASE, ej: INVALID_EMAIL
    message: str        # Mensaje para el cliente (sin datos internos)
    http_status: int
    trace_id: str = ""

    def to_response(self) -> dict:
        return {
            "error": {
                "type": self.type,
                "code": self.code,
                "message": self.message,
                "trace_id": self.trace_id or str(uuid.uuid4()),
                "timestamp": datetime.now(UTC).isoformat()
            }
        }

# Uso
raise AppError(
    type=ErrorType.NOT_FOUND,
    code="USER_NOT_FOUND",
    message="El usuario solicitado no existe",
    http_status=404
)
```

### TypeScript (Express / Hono)

```typescript
type ErrorType =
  | 'ValidationError' | 'AuthError' | 'ForbiddenError'
  | 'NotFoundError' | 'ConflictError' | 'RateLimitError'
  | 'InternalError' | 'ExternalSvcError'

interface AppError {
  type: ErrorType
  code: string        // SCREAMING_SNAKE_CASE
  message: string
  httpStatus: number
  traceId?: string
}

function errorResponse(err: AppError) {
  return {
    error: {
      type: err.type,
      code: err.code,
      message: err.message,
      trace_id: err.traceId ?? crypto.randomUUID(),
      timestamp: new Date().toISOString()
    }
  }
}
```

## Retry logic (para clientes)

```typescript
async function withRetry<T>(
  fn: () => Promise<T>,
  maxAttempts = 3,
  baseDelayMs = 1000
): Promise<T> {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn()
    } catch (err: any) {
      const retryable = ['InternalError', 'ExternalSvcError', 'RateLimitError']
      if (!retryable.includes(err?.type) || attempt === maxAttempts) throw err

      const jitter = Math.random() * 500
      const delay = Math.min(baseDelayMs * 2 ** (attempt - 1) + jitter, 30_000)
      await new Promise(r => setTimeout(r, delay))
    }
  }
  throw new Error('unreachable')
}
```

## Cuándo NO usar este patrón

- Errores internos entre módulos del mismo proceso (usa excepciones nativas)
- Este patrón es para el boundary HTTP — la respuesta al cliente
