# Skill Registry

**Generado**: 2026-03-11 | **Proyecto**: /c/Users/insyd/enterprise-ai-stack

## Comandos Globales (/commands)

- /review — 
- /sdd-archive — Eres el Orchestrator SDD. El usuario quiere archivar un cambio completado.
- /sdd-new — Eres el Orchestrator SDD. El usuario quiere iniciar un nuevo cambio completo.
- /sdd-verify — Eres el Orchestrator SDD. El usuario quiere verificar una implementación.
- /sdd — 
- /skill-registry — Ejecuta el skill registry scan para descubrir y actualizar todas las skills disponibles.
- /spec — 
- /worktree — 

## Skills del Proyecto

- automation — ---
- devops — ---
- python — ---
- review — ---
- security — ---
- sql — ---
- tdd — ---
- typescript — ---

## Stack Técnico Detectado

_no detectado — especificar en AGENTS.md_

## Convenciones del Proyecto

- AGENTS.md — 200 líneas

## Cómo Usar este Registry

Sub-agentes: al inicio de cada tarea, consultar SQLite:
```sql
SELECT title, category, source_path FROM rag_docs
WHERE category IN ('skill', 'pattern', 'runbook')
ORDER BY category;
```
