# /sdd — Iniciar flujo Spec Driven Development

Activa el modo SDD completo para una nueva funcionalidad o tarea.

## Instrucciones

El usuario invoca: `/sdd [descripción de la tarea]`

Sigue estos pasos en orden estricto:

### PASO 1: Verificar si existe spec

Busca en `docs/specs/` o `docs/prds/` un documento relacionado con la tarea descrita.

Si NO existe:
- Genera el template de PRD en `docs/prds/<nombre-tarea>.md` usando el template de `templates/prd.md`.
- Dile al usuario que lo complete y vuelva a invocar `/sdd`.
- DETENTE aquí.

Si SÍ existe:
- Cárgalo y continúa.

### PASO 2: Análisis del PRD

Lee el PRD y extrae:
1. **Criterios de aceptación** (los que usarás para verificar el resultado).
2. **Módulos afectados** (para cargar los AGENTS.md correctos).
3. **Dependencias** (¿hay tareas que deben completarse primero?).
4. **Riesgos** (¿qué puede salir mal?).

### PASO 3: Consultar memoria institucional

Usa el MCP de memoria para buscar:
- Decisiones previas relacionadas.
- Patrones establecidos en el proyecto.
- Problemas conocidos en los módulos afectados.

### PASO 4: Diseñar el DAG de ejecución

Genera el grafo de tareas:

```
[Tarea] → Dependencias → Agente → Worktree
──────────────────────────────────────────
Crear tests   → ninguna       → implementer → feat/nombre-tests
Implementar   → tests creados → implementer → feat/nombre
Verificar     → implementar   → verifier    → feat/nombre
Mergear       → verificar     → orchestrator → main
```

Muéstrale el DAG al usuario y pide confirmación antes de continuar.

### PASO 5: Ejecutar (tras confirmación)

Ejecuta el DAG tarea por tarea.
Reporta el estado al usuario al completar cada tarea.

### PASO 6: Cierre

Al terminar:
1. Escribe en memoria: qué se hizo, decisiones tomadas, próximos pasos.
2. Genera el resumen final para el usuario.
