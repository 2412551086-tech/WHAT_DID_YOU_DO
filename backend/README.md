# Backend

NestJS + TypeScript API service for the app.

## Stack

- NestJS
- TypeScript
- Prisma
- PostgreSQL

## Setup

macOS/Linux:

```sh
corepack enable
pnpm install
cp backend/.env.example backend/.env
pnpm backend:prisma:generate
pnpm backend:prisma:migrate
pnpm --filter @what-did-you-do/backend prisma:seed
pnpm backend:dev
```

Windows PowerShell:

```powershell
corepack enable
pnpm install
Copy-Item backend\.env.example backend\.env
pnpm backend:prisma:generate
pnpm backend:prisma:migrate
pnpm --filter @what-did-you-do/backend prisma:seed
pnpm backend:dev
```

Use pnpm for this workspace. Avoid mixing `npm install` with pnpm-managed `node_modules`.

## Integration Tests

Point `DATABASE_URL` at a dedicated test database, apply migrations, seed it, and
run `pnpm run test:e2e`. Never use a production or personal development database.

The E2E suites run serially because they share database-wide achievement
definitions and an outbox queue. Parallel suite workers can consume each other's
events, invalidating assertions about pending states, retries, and unlocks. The
E2E setup disables automatic achievement polling before app startup; achievement
tests explicitly enable evaluation and call the real worker when needed.
Do not override `maxWorkers` unless each suite has its own database. Concurrent
HTTP requests and worker calls inside individual tests still exercise races.
