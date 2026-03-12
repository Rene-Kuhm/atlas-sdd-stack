# Arquitectura del Stack

## Principios de Diseño

1. **AI-First, no AI-Only**: La IA acelera, el humano decide. Los agentes tienen guardrails explícitos.
2. **Context Isolation**: Cada agente opera con contexto mínimo suficiente. No se comparte el estado global.
3. **Spec Before Code**: Nada se implementa sin una especificación validada.
4. **Fail Fast**: Los errores se detectan lo antes posible (pre-commit > CI > producción).
5. **Boring Technology**: Preferimos tecnología probada sobre la última moda.

---

## Flujo SDD Completo

```
Usuario
  │
  ▼
/sdd [descripción]
  │
  ▼
¿Existe PRD? ──No──▶ Generar template PRD ──▶ PAUSA (usuario completa)
  │ Sí
  ▼
Orchestrator analiza PRD
  │
  ▼
Consulta memoria institucional (SQLite MCP)
  │
  ▼
Construye DAG de tareas
  │
  ▼
Para cada tarea en el DAG:
  ├─▶ worktree-create.sh feat/nombre-tarea
  ├─▶ Asigna a Implementer (carga skill + AGENTS.md mínimo)
  │     ├─▶ Escribe tests (rojo)
  │     ├─▶ Implementa (verde)
  │     └─▶ Refactoriza
  ├─▶ Handoff a Verifier
  │     ├─▶ Verifica vs criterios de aceptación
  │     ├─▶ Security checklist
  │     └─▶ APPROVE | REQUEST_CHANGES
  └─▶ Si APPROVE: worktree-merge.sh → PR
  │
  ▼
Orchestrator consolida
  │
  ▼
Escribe decisiones en memoria
  │
  ▼
Reporte final al usuario
```

---

## Gestión de Contexto (Anti-Amnesia)

```
┌─────────────────────────────────────────────────┐
│                  Sesión LLM                      │
│                                                  │
│  Contexto activo (ventana de tokens):            │
│  ├── AGENTS.md del módulo activo (cargado)       │
│  ├── Skill activa (lazy loaded)                  │
│  ├── 3-5 archivos relevantes (no el repo entero) │
│  └── Task actual (no el DAG completo)            │
│                                                  │
│  Contexto persistente (MCP SQLite):              │
│  ├── Decisiones arquitectónicas históricas       │
│  ├── Patrones establecidos                       │
│  ├── Integraciones configuradas                  │
│  └── Summary de sesiones anteriores             │
└─────────────────────────────────────────────────┘
```

---

## Worktree Flow

```
main (solo lectura para agentes)
├── .worktrees/
│   ├── feat-user-auth/       ← Implementer Agent #1
│   ├── feat-payments/        ← Implementer Agent #2 (paralelo)
│   └── fix-api-timeout/      ← Implementer Agent #3 (paralelo)
```

Los worktrees corren en paralelo cuando no hay dependencias entre tareas.
El DAG del Orchestrator gestiona cuándo puede iniciar cada worktree.

---

## MCP Stack

| Servidor | Función | Cuándo se usa |
|----------|---------|---------------|
| `memory` | Knowledge graph en RAM | Hechos cortos, relaciones |
| `sqlite` | Memoria persistente FTS | Decisiones, sesiones, cache |
| `filesystem` | Acceso al repo | Lectura/escritura de archivos |
| `git` | Operaciones git | Commits, diffs, historial |
| `github` | GitHub API | PRs, issues, releases |
| `context7` | Docs de librerías | Cuando el agente necesita API docs |
| `sequential-thinking` | Razonamiento estructurado | Tareas complejas multipasos |
| `fetch` | HTTP externo | Webhooks, APIs externas |

---

## Estructura de Directorio Estándar de Proyecto

```
mi-proyecto/
├── AGENTS.md                  ← Reglas globales
├── .claude/
│   ├── settings.json          ← MCP + permissions
│   ├── skills/                ← Skills lazy-loaded
│   └── commands/              ← Slash commands custom
├── .worktrees/                ← Worktrees activos (gitignored)
├── agents/                    ← System prompts de agentes
├── docs/
│   ├── prds/                  ← Product Requirements
│   ├── specs/                 ← Technical Specs
│   ├── adrs/                  ← Architecture Decision Records
│   └── integrations/          ← Docs de cada integración externa
├── src/
│   ├── api/
│   │   └── AGENTS.md
│   ├── ui/
│   │   └── AGENTS.md
│   ├── automation/
│   │   └── AGENTS.md
│   ├── data/
│   │   └── AGENTS.md
│   └── shared/
│       └── AGENTS.md
├── scripts/
│   ├── bootstrap.sh
│   ├── worktree-create.sh
│   └── worktree-merge.sh
├── hooks/
│   ├── pre-commit
│   └── prepare-commit-msg
├── templates/
│   ├── prd.md
│   ├── adr.md
│   └── task.md
└── memory/
    └── schema.sql
```
