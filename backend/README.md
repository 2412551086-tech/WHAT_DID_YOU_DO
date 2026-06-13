# Backend

NestJS + TypeScript API service for the app.

## Stack

- NestJS
- TypeScript
- Prisma
- PostgreSQL

## Setup

```powershell
pnpm install
Copy-Item backend\.env.example backend\.env
pnpm backend:prisma:generate
pnpm backend:dev
```

No business modules are implemented yet. The current files only establish the service skeleton and database tooling.
