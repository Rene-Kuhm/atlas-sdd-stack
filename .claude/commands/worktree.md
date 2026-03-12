# /worktree — Gestión de Git Worktrees

Gestiona worktrees para desarrollo paralelo aislado.

## Uso

- `/worktree new <tipo>/<nombre>` — Crear worktree nuevo
- `/worktree list` — Ver worktrees activos
- `/worktree merge <nombre>` — Mergear y limpiar worktree
- `/worktree clean` — Limpiar worktrees huérfanos

## Instrucciones

### /worktree new <tipo>/<nombre>

Ejecuta:
```bash
./scripts/worktree-create.sh <tipo>/<nombre>
```

Luego confirma al usuario:
- Ruta del worktree creado.
- Branch creado.
- Comando para activarlo en una nueva terminal.

### /worktree list

Ejecuta:
```bash
git worktree list
```

Muestra la lista formateada con: nombre, branch, última modificación, estado.

### /worktree merge <nombre>

Antes de ejecutar, verifica:
1. ¿Los tests pasan en el worktree?
2. ¿El verifier aprobó el PR?

Si ambos son SÍ:
```bash
./scripts/worktree-merge.sh <nombre>
```

Si alguno es NO, informa al usuario y no procede.

### /worktree clean

Lista worktrees sin actividad en los últimos 7 días.
Pregunta confirmación antes de eliminar cada uno.
