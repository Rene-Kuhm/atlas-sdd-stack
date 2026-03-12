# PRD: [Nombre del Feature]

**ID**: PRD-YYYY-NNN
**Fecha**: YYYY-MM-DD
**Autor**: [nombre]
**Estado**: BORRADOR | EN REVISIÓN | APROBADO | IMPLEMENTADO
**Prioridad**: CRÍTICA | ALTA | MEDIA | BAJA

---

## 1. Contexto y Problema

> ¿Por qué existe esta tarea? ¿Qué problema del negocio resuelve?

[Describe la situación actual y el pain point]

---

## 2. Objetivo

> Una frase que describe el resultado deseado.

**Queremos** [acción]
**Para** [beneficiario]
**De modo que** [resultado medible]

---

## 3. Usuarios Afectados

| Rol | Descripción | Impacto |
|-----|-------------|---------|
| [rol] | [descripción] | [cómo les afecta] |

---

## 4. Alcance (Scope)

### Incluido ✅
- [qué está dentro de este PRD]

### Excluido ❌ (fuera de scope)
- [qué NO está en este PRD, para evitar scope creep]

---

## 5. Criterios de Aceptación

> Estos son los tests de negocio. El agente los usará para verificar que la implementación es correcta.

- [ ] **CA-01**: Dado [contexto], cuando [acción], entonces [resultado esperado]
- [ ] **CA-02**: Dado [contexto], cuando [acción], entonces [resultado esperado]
- [ ] **CA-03** (edge case): Si [condición de error], el sistema debe [respuesta esperada]

---

## 6. Casos de Uso Principales

### Flujo Feliz (Happy Path)
1. El usuario hace X
2. El sistema responde con Y
3. El usuario ve Z

### Flujos de Error
- **Error A**: Si [condición], mostrar [mensaje] y [acción del sistema]
- **Error B**: Si [condición], [comportamiento del sistema]

---

## 7. Requisitos No Funcionales

| Categoría | Requisito |
|-----------|-----------|
| Performance | Respuesta < 500ms en p95 |
| Seguridad | [requisito específico] |
| Disponibilidad | [SLA] |
| Escalabilidad | [requisito] |

---

## 8. Dependencias

- **Sistemas externos**: [APIs, servicios de terceros]
- **PRDs relacionados**: [PRD-YYYY-NNN]
- **Tareas bloqueantes**: [qué debe existir antes]

---

## 9. Métricas de Éxito

> ¿Cómo sabremos que esto funcionó? Medibles, con baseline y target.

| Métrica | Baseline actual | Target | Cómo medir |
|---------|-----------------|--------|------------|
| [métrica] | [valor actual] | [valor objetivo] | [herramienta] |

---

## 10. Notas de Implementación

> Hints para el equipo técnico. No son especificaciones, son sugerencias.

[Consideraciones técnicas, librerías sugeridas, patrones a considerar]

---

## 11. Historial de Cambios

| Fecha | Autor | Cambio |
|-------|-------|--------|
| YYYY-MM-DD | [nombre] | Creación del documento |
