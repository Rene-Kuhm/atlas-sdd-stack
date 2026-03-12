---
trigger: seguridad OR security OR auth OR JWT OR OWASP OR vulnerability OR CVE OR XSS OR injection OR RBAC OR permissions
scope: Revisión y implementación de seguridad
priority: critical
---

# Security Skill

## OWASP Top 10 — Checklist por PR

Antes de mergear cualquier cambio, verifica:

- [ ] **A01 Broken Access Control**: ¿Cada endpoint verifica permisos explícitamente?
- [ ] **A02 Cryptographic Failures**: ¿Los datos sensibles están encriptados en reposo y tránsito?
- [ ] **A03 Injection**: ¿Todas las queries usan parámetros? ¿Sin interpolación de strings?
- [ ] **A04 Insecure Design**: ¿El flujo de negocio tiene controles que no se pueden bypass?
- [ ] **A05 Security Misconfiguration**: ¿Headers de seguridad presentes? ¿Errores detallados solo en dev?
- [ ] **A06 Vulnerable Components**: ¿Se auditaron las dependencias nuevas?
- [ ] **A07 Auth Failures**: ¿Límite de intentos? ¿Tokens con expiración corta?
- [ ] **A09 Logging Failures**: ¿Se loguean los eventos de seguridad? ¿Sin datos sensibles en logs?

## Validación de Input

```python
# NUNCA: interpolación directa
query = f"SELECT * FROM users WHERE email = '{email}'"  # SQL Injection

# SIEMPRE: parámetros
result = await db.execute(
    text("SELECT * FROM users WHERE email = :email"),
    {"email": email}
)
```

```typescript
// NUNCA: innerHTML con datos del usuario
element.innerHTML = userInput  // XSS

// SIEMPRE: textContent o sanitización
element.textContent = userInput
// O si necesitas HTML:
import DOMPurify from 'dompurify'
element.innerHTML = DOMPurify.sanitize(userInput)
```

## Autenticación JWT

```python
# Access token: 15 minutos
# Refresh token: 7 días, rotación en cada uso
# Algoritmo: RS256 (asimétrico) para producción, HS256 solo en desarrollo

ALGORITHM = "RS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 15
REFRESH_TOKEN_EXPIRE_DAYS = 7

def create_access_token(user_id: str, role: str) -> str:
    payload = {
        "sub": user_id,
        "role": role,
        "type": "access",
        "exp": datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES),
        "iat": datetime.utcnow(),
        "jti": str(uuid4()),  # ID único para revocación
    }
    return jwt.encode(payload, PRIVATE_KEY, algorithm=ALGORITHM)
```

## Headers de Seguridad HTTP

```python
# FastAPI middleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware

app.add_middleware(
    SecurityHeadersMiddleware,
    headers={
        "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
        "X-Content-Type-Options": "nosniff",
        "X-Frame-Options": "DENY",
        "Content-Security-Policy": "default-src 'self'",
        "Referrer-Policy": "strict-origin-when-cross-origin",
        "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
    }
)
```

## Secrets Management

```bash
# NUNCA en el código:
API_KEY = "<secret>"

# SIEMPRE en variables de entorno:
API_KEY = os.getenv("API_KEY")  # Con validación en startup

# Para producción: HashiCorp Vault, AWS Secrets Manager, o Doppler
```

## Rate Limiting

```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@router.post("/auth/login")
@limiter.limit("5/minute")  # Estricto en endpoints de auth
async def login(request: Request, credentials: LoginRequest):
    ...
```

## Auditoría

Loguea siempre estos eventos:
- Login exitoso / fallido
- Cambio de password o email
- Acceso a datos sensibles
- Cambio de roles o permisos
- Operaciones de admin
- Rate limit alcanzado

```python
logger.info("auth.login.success", user_id=user.id, ip=request.client.host)
logger.warning("auth.login.failed", email=credentials.email, ip=request.client.host)
```
