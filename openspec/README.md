# OpenSpec

Especificaciones del sistema organizadas bajo SDD (Spec Driven Development).

## Estructura

```
openspec/
  specs/          ← Specs canónicas (fuente de verdad)
  changes/        ← Cambios en progreso (pipeline ATL)
    <nombre>/     ← Un cambio activo
      state.yaml  ← Estado del DAG pipeline
      proposal.md ← Propuesta (requiere aprobación)
      specs/      ← Delta specs de este cambio
      design.md   ← Decisiones de diseño
      tasks.md    ← Plan de tareas
      apply-progress.md ← Progreso de implementación
      verify-report.md  ← Reporte de verificación
    archive/      ← Cambios completados y archivados
```

## Pipeline ATL

```
Explorer → Proposer → [GATE] → SpecWriter → Designer → TaskPlanner → Implementer → Verifier → Archiver
```

Iniciar un nuevo cambio: `/sdd new <nombre>`
