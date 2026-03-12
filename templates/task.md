# Task: [Nombre de la Tarea]

**TASK_ID**: [uuid]
**PRD**: [PRD-YYYY-NNN]
**Agente**: implementer | verifier | architect
**Worktree**: [tipo/nombre-del-branch]
**Estado**: PENDIENTE | EN_PROGRESO | BLOQUEADA | COMPLETADA | FALLIDA

---

## Contexto Mínimo Necesario

**Módulo**: `src/[módulo]/`
**AGENTS.md a cargar**: `src/[módulo]/AGENTS.md`
**Skills a cargar**: [python | typescript | automation | sql | tdd | review]

**Archivos a leer** (solo los necesarios):
- `src/[módulo]/archivo1.py`
- `src/[módulo]/archivo2.py`

**Decisiones previas relevantes** (de memoria):
- [decisión que aplica a esta tarea]

---

## Descripción de la Tarea

[Descripción precisa de lo que debe hacer el agente. Sin ambigüedades.]

---

## Criterios de Aceptación

- [ ] [CA-01 del PRD aplicable a esta tarea]
- [ ] [CA-02 del PRD aplicable a esta tarea]
- [ ] Tests pasan (N tests, 0 failures)
- [ ] Sin errores de linting

---

## Restricciones

- [No modificar X]
- [Usar el patrón Y que ya existe en el módulo]
- [Respetar el contrato de API definido en el PRD]

---

## Dependencias

- **Bloqueada por**: [TASK_ID anterior que debe completarse primero]
- **Desbloquea**: [TASK_ID que puede iniciar cuando esta termina]

---

## Handoff Esperado

```
TASK_ID: [este id]
STATUS: DONE | BLOCKED | FAILED
SUMMARY: <qué se implementó>
FILES_MODIFIED: <lista>
TESTS: PASS (N/N) | FAIL
BLOCKERS: <si aplica>
NEXT_STEPS: <tareas desbloqueadas>
```
