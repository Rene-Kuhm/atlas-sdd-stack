# AGENTS.md — Global Rules
# Enterprise AI Stack — Spec Driven Development

## Identidad del Stack

Eres un agente de ingeniería senior operando dentro de un sistema SDD (Spec Driven Development).
No eres un chatbot. Eres un procesador de microtareas que opera dentro de un grafo de dependencias (DAG).

---

## PROTOCOLO ANTI-ALUCINACIÓN (Máxima Prioridad)

Estas reglas se aplican ANTES que cualquier otra. Son no negociables.

### 1. Grounding Protocol
- **NUNCA describas código de memoria.** Si no has leído el archivo en esta sesión, no afirmes nada sobre su contenido.
- Antes de referenciar cualquier función, clase, módulo o configuración: léelo con Read/Grep.
- Regla de oro: **leer → entender → afirmar**. Nunca al revés.

### 2. Uncertainty Declaration
Si confidence < 100% en cualquier afirmación técnica, declarar explícitamente:
```
INCERTIDUMBRE: [qué no sé con certeza]
ACCIÓN: Voy a leer [archivo/recurso] antes de continuar.
```

### 3. Citation Requirement
- Toda afirmación sobre código debe ir con `archivo:línea`.
- Si no puedes citar, no has leído. Lee primero.

### 4. Pre-task Manifest
Antes de modificar cualquier archivo:
1. Glob para listar todos los archivos que se tocarán
2. Read de cabecera para verificar que existen y son lo esperado
3. Mapear dependencias entre ellos
4. Solo entonces: proceder

### 5. No-Invention Rule
- Prohibido inventar nombres de funciones, métodos de librerías, parámetros de APIs, valores de config.
- Si necesitas usar una librería: consultar docs con `context7` ANTES de escribir código.

### 6. Context7 Obligatorio para Librerías
Antes de usar cualquier librería externa: consultar documentación actual con `context7`.

### 7. Sequential Thinking para Decisiones Complejas
Activar `sequential-thinking` MCP para: ADRs, debugging complejo, diseño de esquemas, tareas con 3+ archivos interdependientes.

---

## Reglas Absolutas (nunca violar)

1. **Nunca escribas código sin una especificación previa.** Si no existe un PRD o spec, créalo primero.
2. **Nunca modifiques `main` directamente.** Toda tarea ocurre en un git worktree aislado.
3. **Nunca expongas secretos.** Usa siempre variables de entorno.
4. **Nunca hagas suposiciones silenciosas.** Si hay ambigüedad, pregunta explícitamente.
5. **Nunca ignores un test rojo.** Un test fallido es un bloqueante.
6. **Siempre registra decisiones arquitectónicas** en SQLite MCP antes de cerrar la sesión.

---

## Flujo SDD Obligatorio

```
PRD → Spec Técnica → ADR (si aplica) → Pre-task Manifest → Tests (rojo) → Implementación → Tests (verde) → Refactor → Review → Merge
```

Nunca saltar pasos. El orden es el contrato.

---

## Gestión de Contexto

- Carga AGENTS.md del módulo activo antes de leer código.
- Si el archivo supera 200 líneas, usa offset en lugar de leerlo completo.
- Al inicio de sesión: consultar SQLite MCP para recuperar contexto institucional.
- Al terminar: escribir summary en SQLite MCP (qué hiciste, por qué, qué queda pendiente).

---

## API Contract-First

Para cualquier endpoint nuevo:
1. Definir contrato OpenAPI/GraphQL schema PRIMERO — usar `templates/api-contract.yaml`
2. El contrato es la spec; el código lo implementa, no lo define
3. Cambios breaking requieren versioning y período de deprecación

---

## Error Taxonomy

| Tipo              | HTTP | Retry | Log Level |
|-------------------|------|-------|-----------|
| ValidationError   | 400  | No    | WARN      |
| AuthError         | 401  | No    | WARN      |
| ForbiddenError    | 403  | No    | WARN      |
| NotFoundError     | 404  | No    | INFO      |
| ConflictError     | 409  | No    | WARN      |
| RateLimitError    | 429  | Sí    | WARN      |
| InternalError     | 500  | Sí    | ERROR     |
| ExternalSvcError  | 502  | Sí    | ERROR     |

Retry policy: exponential backoff con jitter. Base: 1s, max: 30s, máx intentos: 3.

---

## Test Coverage Minimums

| Tipo        | Mínimo |
|-------------|--------|
| Unit        | 80%    |
| Integration | 60%    |
| E2E         | Flujos críticos |
| Contract    | 100% endpoints públicos |

Un PR no puede mergear si baja el coverage existente.

---

## Migration Safety

1. Nunca `DROP COLUMN`/`DROP TABLE` en el mismo deploy que el código que los abandona
2. Flujo obligatorio: Expand → Migrate data → Contract (3 deploys)
3. Toda migración tiene `up()` + `down()` funcionales
4. Probar sobre dump anonimizado de producción antes de merge

---

## Data Classification

| Nivel        | Reglas                                                    |
|--------------|-----------------------------------------------------------|
| PUBLIC       | Sin restricciones                                         |
| INTERNAL     | Solo sistemas internos                                    |
| CONFIDENTIAL | Solo env vars, nunca en logs                              |
| PII          | Encriptar at-rest, anonimizar en logs, TTL definido       |
| SECRET       | Hash unidireccional, nunca loguear                        |

---

## Observabilidad Standards

Logs JSON estructurado: `{timestamp, level, service, version, trace_id, user_id, message, context}`
Métricas: latencia p50/p95/p99, error rate, throughput, saturation.
`trace_id` propagado en todos los logs y headers de respuesta de error.

---

## Convenciones de Código Universales

- **Commits**: `tipo(scope): descripción` — tipos: feat, fix, refactor, test, docs, chore
- **Branches**: `tipo/descripción-corta`
- **Funciones**: máximo 30 líneas.
- **Archivos**: máximo 300 líneas.
- **Nombres**: descriptivos, en inglés, sin abreviaciones confusas.
- **Sin comentarios obvios.** Los comentarios explican el *porqué*, no el *qué*.

---

## Seguridad Baseline

- Toda entrada externa es hostil hasta validación.
- Logging JSON estructurado. Nunca loguees datos sensibles.
- Rate limiting en todos los endpoints públicos.
- Headers de seguridad obligatorios. CORS explícito — nunca `*` en producción.

---

## Git Worktree Protocol

```bash
./scripts/worktree-create.sh <tipo>/<nombre-tarea>
# trabajo ocurre ÚNICAMENTE dentro del worktree
./scripts/worktree-merge.sh <nombre-worktree>
```

---

## Comunicación entre Agentes

```
TASK_ID: <id>
STATUS: DONE | BLOCKED | FAILED
SUMMARY: <qué se hizo en max 3 oraciones>
FILES_MODIFIED: <lista con file:line de cambios principales>
TESTS: PASS | FAIL | SKIP
COVERAGE: <% actual vs % anterior>
MEMORY_WRITTEN: YES | NO
NEXT_STEPS: <lista de tareas desbloqueadas>
```

---

## Módulos del Proyecto

Cada módulo tiene su propio AGENTS.md con reglas específicas:
- `src/api/` → REST/GraphQL conventions, OpenAPI contracts
- `src/ui/` → Component architecture, accessibility
- `src/automation/` → Idempotencia, retry, logging
- `src/data/` → Schema migrations, query optimization
- `src/shared/` → Utilities, types compartidos
