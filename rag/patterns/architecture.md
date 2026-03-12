# Architecture Patterns — Guía de Decisiones de Arquitectura

## Cuándo Crear un ADR

Crear un Architecture Decision Record (ADR) SIEMPRE que:
- Se elija una librería o framework sobre alternativas evaluadas
- Se cambie el patrón de comunicación entre servicios
- Se tome una decisión de esquema de datos que afecte múltiples módulos
- Se establezca un límite de responsabilidad entre componentes
- Se acepte una deuda técnica conscientemente

**No crear ADR para**: decisiones de implementación interna sin impacto en interfaces, naming, style preferences.

---

## Patrones de Arquitectura Validados

### 1. Separación de Capas (Obligatorio en todos los módulos)

```
Capa de Presentación  →  Validación de inputs, formatos de respuesta
Capa de Aplicación    →  Orquestación de casos de uso, sin lógica de dominio
Capa de Dominio       →  Lógica de negocio pura, sin dependencias externas
Capa de Infraestructura → DB, HTTP, colas, archivos, terceros
```

**Regla de dependencia**: Las capas internas nunca importan de las externas.
Dominio no conoce a Infraestructura. Nunca.

### 2. Contratos de API Primero

Para cualquier interfaz (HTTP, evento, CLI):
1. Definir el contrato (OpenAPI/schema) ANTES de implementar
2. Generar tipos/interfaces desde el contrato (no al revés)
3. El contrato vive en `openspec/` o `docs/api/`

### 3. Boundaries de Error

Cada servicio/módulo define su error boundary:
- Errores propios: mapeados a error taxonomy interna
- Errores externos: siempre wrapped con contexto (`ExternalSvcError`)
- Nunca propagar excepciones raw de librerías de terceros hacia arriba

### 4. Idempotencia en Operaciones Mutantes

Toda operación que modifique estado debe ser idempotente:
- Mutations HTTP: usar `idempotency_key` en headers
- Jobs/Workers: verificar si el trabajo ya fue procesado antes de ejecutar
- Webhooks: guardar `event_id` y rechazar duplicados

### 5. Config externalizada (12-Factor)

```
✓ Variables de entorno para config por environment
✓ Secretos en vault/secrets manager, nunca en código
✓ Config de desarrollo en .env.local (en .gitignore)
✓ Config de producción en sistema de secretos del cloud
✗ NUNCA: if (env === 'production') { ... } en lógica de dominio
```

---

## Decisiones de Comunicación entre Servicios

| Patrón | Cuándo usar | Cuándo NO usar |
|--------|-------------|----------------|
| HTTP/REST síncrono | Lectura, respuesta inmediata requerida | Operaciones > 5s |
| Colas async (BullMQ/SQS) | Operaciones long-running, retry automático | Latencia < 100ms requerida |
| Events (Kafka/EventBridge) | Fan-out, múltiples consumidores | Orden garantizado crítico |
| gRPC | Microservices internos, tipado estricto | APIs públicas externas |
| WebSockets | Tiempo real bidireccional | Polling unidireccional |

---

## Decisiones de Base de Datos

### PostgreSQL (default para datos transaccionales)
- ACID completo, joins complejos, FTS básico
- Usar para: pedidos, usuarios, pagos, inventario

### Redis
- Cache, sesiones, colas (BullMQ), pub/sub
- TTL siempre definido. Nunca como única fuente de verdad.

### SQLite
- Datos locales de una sola instancia, herramientas CLI, tests
- No usar en servicios multi-instancia

### S3/Blob Storage
- Archivos, assets, exports grandes
- Nunca guardar archivos en la DB (columnas BLOB > 1MB)

---

## Anti-Patterns Prohibidos

```
✗ God Object: una clase/módulo que hace todo
✗ Circular dependencies entre módulos de negocio
✗ Lógica de negocio en controllers/resolvers
✗ DB calls directos desde la capa de presentación
✗ Strings mágicos hardcodeados (usar enums/constants)
✗ Singleton mutable global (causa problemas en tests y concurrencia)
✗ Polling cuando hay alternativa event-driven disponible
```

---

## Template para ADR

```markdown
# ADR-XXX: [Título de la decisión]

**Estado**: proposed | accepted | deprecated | superseded
**Fecha**: YYYY-MM-DD
**Contexto**: [Por qué se necesitó tomar esta decisión]
**Opciones evaluadas**:
  - Opción A: [pros / contras]
  - Opción B: [pros / contras]
**Decisión**: [Qué se eligió y por qué]
**Consecuencias**: [Qué cambia, qué deuda se acumula]
**topic_key**: architecture/<slug>
```
