# Enterprise AI Stack

34 archivos en 10 capas. Todo está en `C:\Users\insyd\enterprise-ai-stack\`.

---

## Resumen de lo construido

```
enterprise-ai-stack/
│
├── AGENTS.md                    ← Reglas globales absolutas
│
├── src/[api|ui|automation|data|shared]/
│   └── AGENTS.md                ← Reglas por módulo (scope rules)
│
├── .claude/
│   ├── settings.json            ← MCP + permissions (allow/deny explícito)
│   ├── skills/                  ← 7 skills lazy-loaded
│   │   python, typescript, sql, automation, tdd, review, security, devops
│   └── commands/                ← 4 slash commands
│       /sdd  /spec  /review  /worktree
│
├── agents/                      ← System prompts de cada agente
│   orchestrator, implementer, verifier, architect
│
├── scripts/                     ← Git worktree automation
│   bootstrap.sh, worktree-create.sh, worktree-merge.sh
│
├── hooks/                       ← Pre-commit GGA con cache de hash
│   pre-commit (detección de secrets + ruff + cache SQLite)
│   prepare-commit-msg (template de commits automático)
│
├── memory/
│   └── schema.sql               ← SQLite con FTS5: decisions, sessions, patterns, cache
│
├── templates/
│   prd.md  adr.md  task.md      ← Documentos de trabajo estandarizados
│
└── docs/
    architecture.md  workflow.md  ← Guías del sistema
```

---

## Para usar en un proyecto real

```bash
# 1. Copia la estructura al proyecto
cp -r ~/enterprise-ai-stack/. mi-proyecto/

# 2. Instala todo
cd mi-proyecto
./scripts/bootstrap.sh

# 3. Arranca Claude Code
claude

# 4. Primera tarea
/spec "describe lo que quieres construir"
```
