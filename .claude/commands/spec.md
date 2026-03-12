# /spec — Generar Especificación Técnica

A partir de una descripción en lenguaje natural, genera una spec técnica completa.

## Instrucciones

El usuario invoca: `/spec [descripción del feature o tarea]`

### Paso 1: Clarificación (si aplica)

Si la descripción es vaga (menos de 2 oraciones o sin criterios de éxito claros),
haz MÁXIMO 3 preguntas específicas antes de continuar. No más.

### Paso 2: Generar PRD

Usa `templates/prd.md` como base. Completa todas las secciones con la información disponible.
Marca con `[PENDIENTE]` lo que el usuario debe completar.

Guarda en: `docs/prds/<nombre-en-kebab-case>.md`

### Paso 3: Generar Spec Técnica

Basándote en el PRD, genera la spec técnica en `docs/specs/<nombre>.md`:

```markdown
# Spec Técnica: <nombre>

## Contexto
<Por qué existe esta tarea>

## Módulos Afectados
- src/api/... → <qué cambia>
- src/data/... → <qué cambia>

## Contrato de API (si aplica)

### POST /api/v1/recurso
Request:
```json
{ "campo": "tipo" }
```
Response 201:
```json
{ "success": true, "data": { "id": "uuid" } }
```

## Schema de DB (si aplica)

## Diagrama de Flujo
<Texto o ASCII art del flujo principal>

## Casos de Error
| Condición | Código | Respuesta |
|-----------|--------|-----------|

## Criterios de Aceptación
- [ ] criterio 1
- [ ] criterio 2

## Tasks de Implementación (DAG)
1. [ ] Tarea A (no dependencias)
2. [ ] Tarea B (depende de A)
3. [ ] Tarea C (depende de A)
4. [ ] Tarea D (depende de B y C)
```

### Paso 4: Confirmar con el usuario

Muestra el PRD y la spec. Pregunta:
- ¿Algo está incorrecto o falta?
- ¿Quieres iniciar la implementación ahora con `/sdd`?
