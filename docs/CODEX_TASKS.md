# Codex Tasks

Use this file as the working task queue for implementation.

## Current Milestone: Project Skeleton

- [x] Create monorepo directories.
- [x] Add backend NestJS + TypeScript + Prisma + PostgreSQL skeleton.
- [x] Add iOS SwiftUI placeholder directory without Xcode project files.
- [x] Add planning docs for API, ERD, release, and Codex tasks.

## Next Milestone: Backend Foundation

- [ ] Confirm ERD and Prisma model boundaries.
- [ ] Add database migrations after ERD approval.
- [ ] Add config module and environment validation.
- [ ] Add authentication module contracts without provider-specific implementation.
- [ ] Add API documentation generation.

## Next Milestone: iOS Foundation

- [ ] Confirm app bundle name and deployment target.
- [ ] Generate SwiftUI Xcode project.
- [ ] Define app navigation shell.
- [ ] Add design tokens and placeholder screens.

## Guardrails

- Do not implement business behavior before the relevant schema and API contracts are reviewed.
- Keep generated files out of version control unless they are required source artifacts.
- Do not commit secrets or local environment files.
