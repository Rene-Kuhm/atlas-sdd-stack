---
trigger: archivos .ts OR .tsx OR TypeScript OR React OR Next.js OR Node OR Bun
scope: Implementación TypeScript/JavaScript
priority: high
---

# TypeScript Skill

## Configuración Base
- TypeScript strict mode siempre: `"strict": true` en tsconfig.
- Runtime: Bun para scripts/backend. Node si el proyecto ya lo usa.
- Sin `any`. Si necesitas escape, usa `unknown` y narrowing.
- ESLint + Prettier. Configuración en el root del proyecto.

## Tipos

```typescript
// Prefiere interfaces para objetos públicos (son más extensibles)
interface User {
  id: string
  email: string
  role: UserRole
  createdAt: Date
}

// Type aliases para unions, intersections, y tipos complejos
type ApiResponse<T> = {
  success: boolean
  data: T | null
  error: string | null
}

// Enums como const objects (tree-shakeable)
const UserRole = {
  ADMIN: 'admin',
  VIEWER: 'viewer',
} as const
type UserRole = (typeof UserRole)[keyof typeof UserRole]
```

## Async/Await y Manejo de Errores

```typescript
// Patrón Result para errores esperados (sin try/catch en lógica de negocio)
type Result<T, E = Error> = { ok: true; value: T } | { ok: false; error: E }

async function getUser(id: string): Promise<Result<User>> {
  const user = await db.users.findById(id)
  if (!user) return { ok: false, error: new UserNotFoundError(id) }
  return { ok: true, value: user }
}

// try/catch solo en el boundary (handler de request, main function)
```

## React (si aplica)

```typescript
// Props tipadas siempre
interface ButtonProps {
  label: string
  onClick: () => void
  variant?: 'primary' | 'secondary'
  disabled?: boolean
}

// Componentes funcionales con React.FC no — define el tipo directo
export function Button({ label, onClick, variant = 'primary', disabled = false }: ButtonProps) {
  return <button onClick={onClick} disabled={disabled} className={styles[variant]}>{label}</button>
}
```

## Testing

```typescript
// Vitest (Bun) o Jest
// Testing Library para componentes React
import { describe, it, expect, vi } from 'vitest'

describe('getUser', () => {
  it('returns error when user not found', async () => {
    const result = await getUser('nonexistent-id')
    expect(result.ok).toBe(false)
    if (!result.ok) expect(result.error).toBeInstanceOf(UserNotFoundError)
  })
})
```

## Dependencias Preferidas
- Validation: `zod`
- HTTP: `fetch` nativo o `ky`
- ORM: `Prisma` o `Drizzle`
- Tests: `vitest`, `@testing-library/react`
- State (React): `zustand` para global, `useState` para local
