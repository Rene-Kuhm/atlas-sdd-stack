# Guía de Workflow SDD

## Para una nueva funcionalidad

```bash
# 1. Generar spec
/spec "necesito un endpoint que permita a los usuarios actualizar su perfil"

# 2. Revisar y aprobar el PRD generado en docs/prds/
# 3. Iniciar implementación SDD
/sdd docs/prds/actualizar-perfil-usuario.md

# El Orchestrator toma el control desde aquí
```

## Para un bugfix

```bash
# 1. Crear worktree aislado
./scripts/worktree-create.sh fix/nombre-del-bug

# 2. Ir al worktree
cd .worktrees/fix-nombre-del-bug

# 3. Describir el bug al agente
"El endpoint POST /users falla con 500 cuando el email ya existe.
Lee src/api/users/routes.py y src/api/users/service.py"

# 4. El agente implementa y testea
# 5. Review
/review

# 6. Si todo OK, mergear
cd ../..
./scripts/worktree-merge.sh fix-nombre-del-bug
```

## Para una revisión de PR

```bash
# En la rama a revisar
git checkout feat/mi-feature
/review

# El GGA genera el reporte con APPROVE / REQUEST_CHANGES
```

## Para consultar decisiones históricas

```bash
# El agente puede buscar en la memoria automáticamente
"¿Por qué usamos UUID v4 en lugar de auto-increment?"
# → El MCP sqlite busca en decisions_fts y recupera el ADR
```

## Comandos de Referencia Rápida

| Comando | Descripción |
|---------|-------------|
| `/sdd <descripción>` | Iniciar flujo SDD completo |
| `/spec <descripción>` | Generar PRD + spec técnica |
| `/review` | Code review como GGA |
| `/worktree new <tipo>/<nombre>` | Crear worktree |
| `/worktree list` | Ver worktrees activos |
| `/worktree merge <nombre>` | Mergear y limpiar |

## Señales de Alerta (cuándo escalar al humano)

- El agente reporta `STATUS: BLOCKED` — Siempre requiere decisión humana.
- Dos ADRs en conflicto sobre el mismo tema — Requiere tiebreaker humano.
- Un test E2E falla en CI pero no en local — No dejes que el agente "arregle" esto sin entender la causa raíz.
- El Verifier marca un BLOCKER de seguridad — Nunca autoapruebar blockers de seguridad.
