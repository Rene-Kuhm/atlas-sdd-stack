---
trigger: archivos .py OR "import " OR "def " OR "class " OR python OR FastAPI OR Django OR Flask
scope: Implementación Python
priority: high
---

# Python Skill

## Estilo y Formato
- Python 3.11+. Type hints en todo: funciones, variables de clase, retornos.
- Docstrings en Google format para funciones públicas.
- Black + isort + ruff. Sin configuración manual de formato.
- Máximo 88 caracteres por línea (Black default).

## Patrones Obligatorios

### Async por defecto para I/O
```python
async def fetch_user(user_id: str) -> User | None:
    async with httpx.AsyncClient() as client:
        response = await client.get(f"/users/{user_id}")
        return User(**response.json()) if response.is_success else None
```

### Dataclasses / Pydantic para modelos
```python
from pydantic import BaseModel, Field

class CreateUserRequest(BaseModel):
    email: EmailStr
    name: str = Field(min_length=2, max_length=100)
    role: UserRole = UserRole.VIEWER
```

### Context managers para recursos
```python
# Bien
async with get_db_session() as session:
    result = await session.execute(query)

# Mal — no uses try/finally manualmente para recursos
```

### Errores explícitos
```python
class UserNotFoundError(ValueError):
    def __init__(self, user_id: str) -> None:
        super().__init__(f"User {user_id} not found")
        self.user_id = user_id
```

## Testing con Pytest
```python
# Fixtures en conftest.py
# Usa pytest-asyncio para tests async
# Mockea con pytest-mock, no con unittest.mock directamente

@pytest.mark.asyncio
async def test_create_user_returns_201(client: AsyncClient, db: AsyncSession):
    response = await client.post("/users", json={"email": "a@b.com", "name": "Test"})
    assert response.status_code == 201
    assert response.json()["data"]["email"] == "a@b.com"
```

## FastAPI Específico
- Router por feature en `routers/`.
- Dependency injection para DB sessions, auth, servicios.
- `HTTPException` solo en la capa de router, nunca en servicios.
- OpenAPI docs siempre actualizadas (automático con FastAPI).

## Dependencias Preferidas
- HTTP client: `httpx` (async)
- Validación: `pydantic v2`
- ORM: `SQLAlchemy 2.x` async
- Tests: `pytest`, `pytest-asyncio`, `pytest-mock`, `httpx`
- Linting: `ruff`, `mypy`
