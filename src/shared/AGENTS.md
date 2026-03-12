# AGENTS.md — Módulo Shared

## Scope
`src/shared/`: utilities, types, constantes, helpers reutilizables entre módulos.

## Regla de Oro
Si algo vive en shared, es porque lo usan AL MENOS 3 módulos distintos.
Si solo lo usan 2, vive en el módulo que más lo use.

## Lo que NO va en shared
- Lógica de negocio específica de un dominio.
- Componentes UI con estado de negocio.
- Acceso a DB.

## Lo que SÍ va en shared
- Types e interfaces base.
- Funciones puras de utilidad (formateo, validación genérica, fechas).
- Constantes del sistema (HTTP codes, regex comunes, enums globales).
- Configuración de logger.
- Error classes base.

## Estructura
```
shared/
├── types/          # TypeScript types / Python dataclasses
├── utils/          # Funciones puras
├── constants/      # Constantes y enums
├── errors/         # Clases de error base
└── config/         # Configuración del entorno
```

## Testing
Todo lo que está en shared tiene cobertura de tests al 100%.
Es código del que depende todo. No puede fallar silenciosamente.
