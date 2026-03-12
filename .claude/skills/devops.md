---
trigger: Docker OR CI/CD OR GitHub Actions OR deploy OR Dockerfile OR pipeline OR infra OR nginx OR kubernetes OR k8s
scope: DevOps, infraestructura y despliegue
priority: medium
---

# DevOps Skill

## Docker

```dockerfile
# Multi-stage build — imagen mínima en producción
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.12-slim AS runtime
WORKDIR /app
# Usuario no-root siempre
RUN useradd -m -u 1000 appuser
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --chown=appuser:appuser . .
USER appuser
# Sin secrets en ENV. Se inyectan en runtime.
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

```yaml
# docker-compose.yml para desarrollo local
services:
  api:
    build: .
    ports: ["8000:8000"]
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/app
    depends_on:
      db:
        condition: service_healthy
    volumes:
      - .:/app  # Hot reload en dev

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: app
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d app"]
      interval: 5s
      timeout: 5s
      retries: 5
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

## GitHub Actions — Pipeline Estándar

```yaml
# .github/workflows/ci.yml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: test_db
          POSTGRES_USER: user
          POSTGRES_PASSWORD: pass
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.12" }

      - name: Cache dependencies
        uses: actions/cache@v4
        with:
          path: ~/.cache/pip
          key: pip-${{ hashFiles('requirements*.txt') }}

      - run: pip install -r requirements-dev.txt
      - run: ruff check .
      - run: mypy src/
      - run: pytest tests/ --cov=src --cov-report=xml -x
        env:
          DATABASE_URL: postgresql://user:pass@localhost:5432/test_db

      - name: Upload coverage
        uses: codecov/codecov-action@v4

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Dependency audit
        run: pip install pip-audit && pip-audit
      - name: SAST scan
        uses: github/codeql-action/analyze@v3
```

## Environments y Secrets

```
Nunca:  secrets en el código, en .env commiteado, en logs
Siempre: GitHub Secrets para CI, Vault/Doppler para producción

Naming de secrets:
  DEV_DATABASE_URL
  STAGING_DATABASE_URL
  PROD_DATABASE_URL
  <ENV>_<SERVICE>_<KEY>
```

## Monitoreo Mínimo

- **Health endpoint**: `GET /health` → `{"status": "ok", "version": "1.2.3"}`
- **Métricas**: Prometheus + Grafana (o Datadog)
- **Logs**: Loki + Grafana (o CloudWatch)
- **Alertas**: Uptime check + error rate > 1% + p95 latency > SLA
- **On-call**: Runbook por tipo de alerta en `docs/runbooks/`
