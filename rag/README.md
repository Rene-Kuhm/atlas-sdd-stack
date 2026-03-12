# RAG — Knowledge Base

Documentación interna indexada en SQLite FTS5 para búsqueda instantánea.
Claude consulta esta base antes de tomar decisiones técnicas.

## Estructura

```
rag/
├── docs/        # Documentación general del proyecto / empresa
├── patterns/    # Patrones de código aprobados y convenciones internas
├── runbooks/    # Procedimientos operacionales paso a paso
├── adrs/        # Decisiones arquitectónicas exportadas (ADRs históricos)
└── apis/        # Contratos de APIs internas (OpenAPI, GraphQL schemas)
```

## Cómo agregar documentos

1. Colocar el archivo `.md`, `.yaml` o `.txt` en la carpeta correspondiente
2. Ejecutar el indexador:
   ```bash
   ./scripts/rag-index.sh
   ```
3. El documento ya es consultable por Claude via SQLite FTS5

## Cómo consultar (Claude lo hace automáticamente)

```sql
-- Búsqueda por término
SELECT title, category, source_path
FROM rag_docs_fts
WHERE rag_docs_fts MATCH 'autenticación jwt';

-- Ver todos los documentos
SELECT category, title, source_path FROM rag_docs ORDER BY category;
```

## Qué poner aquí

| Carpeta   | Ejemplos de contenido                                      |
|-----------|------------------------------------------------------------|
| docs/     | Arquitectura del sistema, onboarding, decisiones de equipo |
| patterns/ | Cómo hacer auth, cómo estructurar errores, convenciones     |
| runbooks/ | Cómo hacer deploy, cómo hacer rollback, cómo debuggear     |
| adrs/     | Exportaciones de decisiones arquitectónicas pasadas        |
| apis/     | OpenAPI specs de servicios internos, contratos de eventos  |

## Regla importante

**No pongas secretos aquí.** Esta carpeta va a git.
Las credenciales van en variables de entorno, nunca en documentos RAG.
