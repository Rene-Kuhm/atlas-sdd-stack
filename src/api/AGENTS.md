# AGENTS.md — Módulo API

## Scope
Todo código en `src/api/` sigue estas reglas adicionales al AGENTS.md global.

## Arquitectura REST

- Versiona todos los endpoints: `/api/v1/`, `/api/v2/`
- Respuestas siempre en formato estándar:
```json
{
  "success": true,
  "data": {},
  "error": null,
  "meta": { "timestamp": "", "version": "v1" }
}
```
- Códigos HTTP correctos: 200 OK, 201 Created, 400 Bad Request, 401 Unauth, 403 Forbidden, 404 Not Found, 422 Validation, 429 Rate Limit, 500 Server Error.
- Nunca retornes 200 con error dentro del body.

## Validación

- Valida en el boundary de entrada, no en la lógica de negocio.
- Usa schemas explícitos (Pydantic, Zod, Joi según el lenguaje).
- Devuelve todos los errores de validación juntos, no el primero que encuentres.

## Autenticación / Autorización

- JWT con expiración corta (15min access, 7d refresh).
- Nunca almacenes tokens en localStorage. Usa httpOnly cookies.
- Autorización basada en roles (RBAC). Define los roles en `src/api/auth/roles.py|ts`.

## Performance

- Paginación obligatoria en listas: `?page=1&limit=20`.
- Índices en columnas de búsqueda y foreign keys.
- Cache en endpoints de lectura frecuente (Redis o in-memory).

## Testing API

- Test de contrato para cada endpoint.
- Tests de límites: payloads vacíos, tipos incorrectos, SQL injection strings.
- Load test antes de ir a producción si el endpoint es público.
