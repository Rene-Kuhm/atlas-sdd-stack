# Runbook: Git Worktree Workflow Diario

**Categoría**: runbook
**Audiencia**: Desarrolladores usando el Enterprise AI Stack

## Flujo estándar de una tarea

### 1. Inicio del día
```bash
./scripts/session-start.sh <nombre-proyecto>
```
Muestra: tareas activas, última sesión, worktrees abiertos.

### 2. Crear worktree para la tarea
```bash
./scripts/worktree-create.sh feat/nombre-de-la-tarea
# o
./scripts/worktree-create.sh fix/descripcion-del-bug
```
Formatos válidos: `feat/`, `fix/`, `refactor/`, `test/`, `docs/`, `chore/`

### 3. Trabajar en el worktree
```bash
cd .worktrees/feat-nombre-de-la-tarea
# todo el trabajo ocurre aquí
```

### 4. Commit con convención
```
feat(scope): descripción en presente
fix(auth): corregir validación de token expirado
refactor(api): extraer lógica de paginación
```

### 5. Merge al terminar
```bash
# desde la raíz del repo principal
./scripts/worktree-merge.sh feat-nombre-de-la-tarea
```

### 6. Cierre del día
```bash
./scripts/session-end.sh <proyecto> "qué hiciste hoy" "qué queda pendiente"
```

---

## Múltiples worktrees en paralelo

```bash
# Terminal 1
cd .worktrees/feat-auth-jwt

# Terminal 2
cd .worktrees/fix-api-timeout

# Terminal 3 (raíz — para scripts globales)
cd /ruta/al/repo
```

Cada worktree tiene su propio estado de archivos pero comparten el mismo `.git`.

---

## Troubleshooting

**Error: worktree ya existe**
```bash
git worktree list          # ver todos
git worktree remove <ruta> # eliminar si está limpio
```

**Error: branch ya existe en remoto**
```bash
git worktree add -b feat/nueva-tarea-v2 .worktrees/feat-nueva-tarea-v2 origin/main
```

**Worktrees huérfanos (branch mergeado pero carpeta existe)**
```bash
git worktree prune         # limpia referencias inválidas
```
