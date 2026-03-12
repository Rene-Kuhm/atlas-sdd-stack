# AGENTS.md — Módulo UI

## Scope
Todo código en `src/ui/` sigue estas reglas adicionales al AGENTS.md global.

## Arquitectura de Componentes

- Estructura por feature, no por tipo: `/features/auth/`, `/features/dashboard/`
- Componentes: Átomos → Moléculas → Organismos (Atomic Design)
- Un componente = un archivo. Máximo 150 líneas por componente.
- Props siempre tipadas. Sin `any`.

## Estado

- Estado local (useState) para UI efímera (toggles, modales).
- Estado global solo para: auth, theme, datos compartidos entre múltiples rutas.
- No abuses del estado global. Si solo lo usa un componente, es estado local.

## Accesibilidad (A11y) — No negociable

- Todos los elementos interactivos tienen `aria-label` o texto visible.
- Navegación completa por teclado.
- Contraste mínimo AA (WCAG 2.1).
- `alt` descriptivo en todas las imágenes.

## Performance

- Lazy loading para rutas y componentes pesados.
- Imágenes optimizadas (WebP, tamaño correcto).
- Sin re-renders innecesarios: usa memo/useMemo/useCallback con criterio.
- Core Web Vitals: LCP < 2.5s, FID < 100ms, CLS < 0.1.

## Testing UI

- Testea comportamiento, no implementación.
- Usa queries semánticas: `getByRole`, `getByLabelText`, no `getByTestId`.
- Un test de smoke por página principal.
- Tests E2E para flujos críticos (login, checkout, formularios principales).
