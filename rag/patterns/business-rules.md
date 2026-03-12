# Business Rules — Guía para Capturar y Aplicar Reglas de Negocio

## Por Qué Importa

Las reglas de negocio son el contrato entre el software y la realidad del cliente.
Un bug en lógica de negocio es siempre más costoso que un bug técnico: afecta dinero, confianza, o cumplimiento legal.

**Regla de oro**: Si el usuario o un stakeholder te dijo "X debe pasar cuando Y", eso es una regla de negocio.
Guardarla en memoria con `type: business_rule` y `topic_key: domain/<tema>`.

---

## Dónde Vive la Lógica de Negocio

```
✓ En la capa de Dominio (domain/ o core/)
✓ En clases/funciones con nombres que reflejen el lenguaje del negocio
✓ Documentada en la spec técnica (openspec/specs/)
✗ NUNCA en controllers, resolvers, o handlers HTTP
✗ NUNCA en queries SQL directas sin validación previa
✗ NUNCA en el frontend como única fuente de validación
```

---

## Cómo Capturar una Regla de Negocio

Cuando el usuario confirme una regla, guardar inmediatamente:

```sql
INSERT INTO observations (
  id, project, type, topic_key, title, what, why, where_ref, learned, tags
) VALUES (
  hex(randomblob(8)),
  'mi-proyecto',
  'business_rule',
  'orders/cancellation-window',
  'Pedidos: ventana de cancelación de 2 horas',
  'Un pedido PENDIENTE no puede cancelarse si han pasado más de 2 horas desde su creación',
  'El proveedor logístico inicia el picking automaticamente a la hora siguiente al pedido',
  'domain/orders/cancellation.service.ts',
  'Verificar created_at + 2h ANTES de mostrar opción de cancelar en cualquier interfaz',
  '["orders","cancellation","sla"]'
);
```

---

## Patrones de Implementación de Reglas de Negocio

### 1. Policy Objects (para reglas complejas)

```typescript
// ✓ La regla está encapsulada, testeable, reutilizable
class OrderCancellationPolicy {
  static canCancel(order: Order, now: Date = new Date()): boolean {
    if (order.status !== 'PENDING') return false;
    const hoursSinceCreation = (now.getTime() - order.createdAt.getTime()) / 3600000;
    return hoursSinceCreation <= 2;
  }

  static rejectionReason(order: Order): string {
    if (order.status !== 'PENDING') return 'Solo se pueden cancelar pedidos en estado PENDIENTE';
    return 'Han pasado más de 2 horas desde la creación del pedido';
  }
}
```

### 2. Guard Clauses (para validaciones de entrada)

```typescript
// ✓ Falla rápido, mensajes explícitos que hablan el lenguaje del negocio
function processRefund(payment: Payment, amount: number): void {
  if (payment.status !== 'COMPLETED') {
    throw new BusinessRuleError('Solo se pueden reembolsar pagos completados', 'payment/refund-status');
  }
  if (amount > payment.amount) {
    throw new BusinessRuleError('El reembolso no puede superar el monto original', 'payment/refund-amount');
  }
  if (daysSince(payment.createdAt) > 90) {
    throw new BusinessRuleError('El período de reembolso de 90 días ha expirado', 'payment/refund-window');
  }
  // ... lógica de reembolso
}
```

### 3. Specification Pattern (para reglas combinables)

```typescript
// ✓ Las reglas se combinan sin if-else complejos
const eligibleForDiscount =
  new IsLoyalCustomer()
  .and(new HasMinimumOrderValue(50))
  .and(new NotAlreadyDiscounted());

if (eligibleForDiscount.isSatisfiedBy(order)) {
  applyDiscount(order, 0.10);
}
```

---

## Documentación de Reglas en Specs

Cada regla de negocio debe aparecer en la spec técnica con formato Given/When/Then:

```gherkin
# Regla: Ventana de cancelación
Given un pedido en estado PENDIENTE
And el pedido fue creado hace menos de 2 horas
When el usuario solicita la cancelación
Then el sistema cancela el pedido
And notifica al usuario por email

Given un pedido en estado PENDIENTE
And el pedido fue creado hace más de 2 horas
When el usuario solicita la cancelación
Then el sistema rechaza la cancelación con código CANCELLATION_WINDOW_EXPIRED
And muestra mensaje explicativo al usuario
```

---

## Reglas de Negocio vs. Reglas Técnicas

| Tipo | Ejemplo | Dónde guardar |
|------|---------|---------------|
| Regla de negocio | "Descuento del 10% para clientes VIP" | `observations` con `type: business_rule` |
| Restricción técnica | "Máximo 100 items por request para evitar timeout" | `observations` con `type: config` |
| Invariante de dominio | "Un pedido siempre tiene al menos 1 ítem" | En el constructor/factory del modelo |
| Política de SLA | "Responder emails en < 4h en horario laboral" | `observations` con `type: decision` |

---

## Red Flags — Reglas de Negocio Mal Implementadas

```
✗ Números mágicos sin constante: if (days > 90) { ... }
✗ Strings de estado duplicados: "PENDING" en 5 archivos distintos
✗ Lógica de negocio en el cliente (JS) sin validación en servidor
✗ Reglas implementadas pero no documentadas en specs
✗ Cambios de reglas sin actualizar tests ni specs
✗ "Esto siempre fue así" sin poder mostrar dónde está documentado
```

---

## Búsqueda de Reglas Existentes Antes de Implementar

Antes de implementar cualquier validación de negocio:

```sql
-- Buscar reglas relacionadas con el dominio
SELECT title, what, where_ref, learned
FROM observations
WHERE type = 'business_rule'
  AND deleted_at IS NULL
ORDER BY updated_at DESC;

-- FTS5 por dominio
SELECT title, snippet(observations_fts, 3, '[', ']', '...', 20)
FROM observations_fts
WHERE observations_fts MATCH 'orders OR payment OR refund'
ORDER BY rank;
```
