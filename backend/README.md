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
