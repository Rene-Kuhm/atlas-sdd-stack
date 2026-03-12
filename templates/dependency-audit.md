# Dependency Audit — Checklist

**Fecha**: YYYY-MM-DD
**Dependencia**: `nombre-paquete@version`
**Ecosistema**: npm | pip | cargo | go
**Solicitado por**: [tarea o PRD que requiere esta dep]

---

## 1. Actividad del Proyecto

- [ ] Último commit: `< 6 meses atrás` — Fecha real: ___________
- [ ] Issues abiertos: ___________ (¿hay bugs críticos sin resolver?)
- [ ] Mantenedores activos: ___________
- [ ] Stars / descargas semanales: ___________ (señal de adopción)

**Veredicto actividad**: ACTIVO | MANTENIMIENTO MÍNIMO | ABANDONADO

---

## 2. Seguridad

```bash
# Para npm:
npm audit --audit-level=high

# Para pip:
pip-audit -r requirements.txt

# Para cargo:
cargo audit
```

- [ ] CVEs críticos: NINGUNO | [listar si los hay]
- [ ] CVEs altos sin parchear: NINGUNO | [listar si los hay]
- [ ] Fecha de último security advisory: ___________

**Veredicto seguridad**: LIMPIO | REQUIERE EVALUACIÓN | BLOQUEADO

---

## 3. Licencia

- [ ] Licencia: MIT | Apache-2.0 | BSD-2/3 | GPL | LGPL | Propietaria | Otra: ___
- [ ] Compatible con el proyecto: SÍ | REQUIERE APROBACIÓN LEGAL | NO

**Nota**: GPL requiere aprobación explícita del tech lead. Licencias propietarias requieren revisión legal.

---

## 4. Análisis de Necesidad

- [ ] ¿Existe ya una dependencia en el proyecto que cubra este caso?
  - Dependencia existente evaluada: ___________ — Razón de descarte: ___________
- [ ] ¿Podría implementarse sin dependencia externa (< 50 líneas)?
  - Evaluación: SÍ (no añadir dep) | NO (dep justificada)

---

## 5. Impacto en Bundle / Entorno

- [ ] Tamaño añadido: ___________ KB
- [ ] Número de sub-dependencias que trae: ___________
- [ ] Requiere ADR: SÍ (> 50KB o > 10 sub-deps) | NO

---

## 6. Decisión Final

- [ ] **APROBADO** — Añadir a dependencias de producción
- [ ] **APROBADO DEV** — Solo para desarrollo/testing
- [ ] **RECHAZADO** — Razón: ___________
- [ ] **ESCALADO** — Requiere aprobación de: ___________

**Añadir al lock file**: SÍ (siempre)
**Versión fijada**: `nombre-paquete==X.Y.Z` (sin rangos en producción)

---

## 7. Alternativas Evaluadas

| Alternativa | Descartada porque |
|-------------|-------------------|
| [nombre]    | [razón]           |

---

## Referencias

- npm/PyPI page: [URL]
- GitHub repo: [URL]
- Changelog: [URL]
