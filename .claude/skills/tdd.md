---
trigger: test OR TDD OR pytest OR vitest OR jest OR testing OR spec OR coverage OR assert
scope: Test Driven Development
priority: high
---

# TDD Skill — Red → Green → Refactor

## El Ciclo Obligatorio

```
1. RED:    Escribe el test que describe el comportamiento deseado. Debe fallar.
2. GREEN:  Escribe el MÍNIMO código para que el test pase. No más.
3. REFACTOR: Limpia sin cambiar el comportamiento. El test sigue verde.
```

Nunca escribas implementación antes de tener al menos un test rojo.

## Anatomía de un Buen Test

```python
# Patrón AAA: Arrange → Act → Assert
def test_create_user_hashes_password():
    # Arrange
    repo = InMemoryUserRepository()
    service = UserService(repo)
    raw_password = "<pwd>"

    # Act
    user = service.create_user(email="a@b.com", password=raw_password)

    # Assert
    assert user.password_hash != raw_password
    assert verify_password(raw_password, user.password_hash) is True
```

Reglas del test:
- Un test = un comportamiento. No tests que verifican 5 cosas.
- Nombre describe el comportamiento: `test_<qué>_<bajo qué condición>_<resultado esperado>`.
- Sin lógica condicional dentro del test (`if`, `for`).
- Sin dependencias entre tests. Orden de ejecución no debe importar.

## Tests por Capa

### Unit Tests (la mayoría)
```python
# Testea una función/clase en completo aislamiento
# Mockea TODO lo externo: DB, HTTP, filesystem, tiempo
from unittest.mock import AsyncMock, patch

async def test_get_user_returns_none_when_not_found():
    repo = AsyncMock()
    repo.find_by_id.return_value = None
    service = UserService(repo)

    result = await service.get_user("nonexistent-id")

    assert result is None
    repo.find_by_id.assert_called_once_with("nonexistent-id")
```

### Integration Tests (pocos, críticos)
```python
# Testea múltiples capas juntas, con DB real (en memoria o test container)
# Marca con @pytest.mark.integration

@pytest.mark.integration
async def test_create_user_persists_in_db(db: AsyncSession):
    service = UserService(PostgresUserRepository(db))
    user = await service.create_user(email="a@b.com", password="<pwd>")

    found = await db.get(UserModel, user.id)
    assert found is not None
    assert found.email == "a@b.com"
```

### E2E Tests (mínimos, flujos críticos)
```python
# Testea el sistema completo desde el HTTP endpoint
# Solo para happy paths de flujos de negocio críticos

@pytest.mark.e2e
async def test_login_flow(client: AsyncClient):
    # Crear usuario
    await client.post("/users", json={"email": "a@b.com", "password": "<pwd>"})

    # Login
    response = await client.post("/auth/login", json={"email": "a@b.com", "password": "<pwd>"})

    assert response.status_code == 200
    assert "access_token" in response.json()["data"]
```

## Cobertura

- Objetivo: >80% en código de negocio. No perseguir 100% (cobertura != calidad).
- Prioriza cobertura en: servicios, repositorios, validadores, edge cases de errores.
- No desperdicies tiempo cubriendo: configuración, migrations, tipos/interfaces.

## Fixtures y Factories

```python
# conftest.py — fixtures compartidas
@pytest.fixture
def user_factory():
    def make_user(**kwargs) -> User:
        defaults = {
            "id": str(uuid4()),
            "email": f"user-{uuid4()}@example.com",
            "name": "Test User",
            "role": UserRole.VIEWER,
        }
        return User(**{**defaults, **kwargs})
    return make_user

# Uso en tests
def test_admin_can_delete_user(user_factory):
    admin = user_factory(role=UserRole.ADMIN)
    target = user_factory()
    # ...
```

## Comandos Rápidos

```bash
# Python
pytest tests/ -v                          # Todos los tests
pytest tests/unit/ -v                     # Solo unit tests
pytest -k "test_create_user" -v           # Por nombre
pytest --cov=src --cov-report=html        # Con cobertura
pytest -x                                 # Para en el primer fallo

# TypeScript
bun test                                  # Todos
bun test --watch                          # Watch mode
bun test --coverage                       # Con cobertura
```
