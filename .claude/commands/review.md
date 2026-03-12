# /review — Code Review como GGA

Activa el Verifier Agent para revisar los cambios actuales.

## Instrucciones

### Paso 1: Obtener el diff

```bash
git diff main...HEAD --name-only
git diff main...HEAD
```

### Paso 2: Cargar contexto

Para cada archivo modificado:
- Identifica a qué módulo pertenece.
- Carga el AGENTS.md de ese módulo.
- Carga las skills relevantes (review.md obligatorio + la del lenguaje).

### Paso 3: Activar Verifier

Toma el rol del Verifier Agent (ver `agents/verifier.md`).

Ejecuta el checklist completo de verificación sobre todos los archivos modificados.

### Paso 4: Reporte

Genera el reporte en el formato:
```
## GGA Review

**Veredicto**: APPROVE | REQUEST_CHANGES | ESCALATE

### Blockers
...

### Majors
...

### Summary
...
```

### Paso 5: Si hay REQUEST_CHANGES

Lista exactamente qué debe cambiarse.
Ofrece al usuario generar los cambios automáticamente para los MAJORS y MINORS.
Los BLOCKERS siempre requieren confirmación humana antes de proceder.
