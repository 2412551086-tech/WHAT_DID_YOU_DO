# Agent Handoff Notes

## Project Summary

`What Did You Do Today` / `你今天干啥啦` is a family chore tracking app.

Core idea: make invisible household labor visible through chore records, estimated effort, points, family activity, leaderboards, and monthly reports. The product tone should stay light, humorous, and non-accusatory.

Primary MVP target: iOS first, backed by a local NestJS API and PostgreSQL.

## Repository Layout

- `apps/ios`: SwiftUI iOS app.
- `backend`: NestJS + TypeScript API service.
- `backend/prisma`: Prisma schema, migrations, seed, and Prisma client helper.
- `docs`: PRD, API notes, migration notes, and release/task docs.
- `design`: design notes.
- `infra`: infrastructure notes.

## Current iOS State

The iOS app is a SwiftUI + MVVM MVP.

Important files:

- `apps/ios/WhatDidYouDo.xcodeproj`
- `apps/ios/Sources/App/WhatDidYouDoApp.swift`
- `apps/ios/Sources/App/AppRootView.swift`
- `apps/ios/Sources/App/MainTabView.swift`
- `apps/ios/Sources/ViewModels/AppViewModel.swift`
- `apps/ios/Sources/Models/Models.swift`
- `apps/ios/Sources/Mock/MockData.swift`
- `apps/ios/Sources/DesignSystem/*`
- `apps/ios/Sources/Features/Auth/LoginView.swift`
- `apps/ios/Sources/Features/Family/CreateFamilyView.swift`
- `apps/ios/Sources/Features/Home/HomeView.swift`
- `apps/ios/Sources/Features/Home/FamilyDashboardView.swift`
- `apps/ios/Sources/Features/Home/ProfileView.swift`
- `apps/ios/Sources/Features/Chores/ChoreSelectionView.swift`
- `apps/ios/Sources/Features/Chores/ChoreDurationPickerSheet.swift`

Main user flow:

1. Mock login.
2. Create family.
3. Enter bottom tab app.
4. View `今日战况`.
5. Tap `记一下`.
6. Tap a chore.
7. Pick actual duration in `ChoreDurationPickerSheet`.
8. Confirm record.
9. Return to `今日战况`; points, records, activity, and ranking update.

Bottom tabs:

- `今日战况`: `HomeView`
- `记一下`: `ChoreSelectionView`
- `家庭战况`: `FamilyDashboardView`
- `我的`: `ProfileView`

Design style:

- Card-based layout.
- Neo-brutalist thick borders.
- Soft neumorphic shadows.
- Humorous Chinese copy.
- Reuse `DSCard`, `DSButton`, `DSTextField`, `DSColor`, and app font helpers.

Important UX contract:

- Tapping a chore must not immediately create a record.
- It must first show `ChoreDurationPickerSheet`.
- Duration defaults to the chore standard duration.
- Duration range is 1 to 180 minutes, step 1 minute.
- Points preview:

```text
points = round(chore.defaultPoints * actualMinutes / chore.defaultMinutes)
```

Avoid divide-by-zero; fall back to default points if standard minutes is 0.

## Current Backend State

Backend stack:

- NestJS
- TypeScript
- Prisma 7
- PostgreSQL 16 via Docker
- pnpm workspace

Do not mix npm and pnpm. Use pnpm for this project.

Important backend modules:

- `AuthModule`
- `FamiliesModule`
- `ChoresModule`
- `ChoreRecordsModule`
- `ReportsModule`
- `PrismaModule`

Important backend files:

- `backend/src/app.module.ts`
- `backend/src/main.ts`
- `backend/src/prisma/prisma.service.ts`
- `backend/src/auth/*`
- `backend/src/families/*`
- `backend/src/chores/*`
- `backend/src/chore-records/*`
- `backend/src/reports/*`
- `backend/prisma/schema.prisma`
- `backend/prisma/seed.ts`
- `backend/prisma/client.ts`

Implemented local MVP endpoints:

- `POST /auth/mock-login`
- `POST /families`
- `GET /families/me`
- `GET /chores`
- `POST /chore-records`
- `GET /families/:familyId/activity`
- `GET /families/:familyId/leaderboard?range=day|month`
- `GET /families/:familyId/monthly-report?month=YYYY-MM`

Auth is development-only:

- `POST /auth/mock-login` returns a simple signed token.
- Protected endpoints expect `Authorization: Bearer <token>`.
- Secret fallback is `dev-only-secret`; use `JWT_SECRET` for real environments.

Prisma seed:

- `backend/prisma/seed.ts` seeds the free core 10 chores.
- `backend/prisma.config.ts` configures seed:

```ts
seed: "ts-node --transpile-only prisma/seed.ts"
```

## Local Commands

From repo root:

```sh
corepack enable
pnpm install
```

Start PostgreSQL if no compose file exists:

```sh
docker run --name ni-gan-sha-la-postgres \
  -e POSTGRES_USER=app \
  -e POSTGRES_PASSWORD=app123456 \
  -e POSTGRES_DB=ni_gan_sha_la \
  -p 5432:5432 \
  -d postgres:16
```

Backend setup:

```sh
cd /Users/aoxideni/Documents/what_did_you_do/backend
pnpm exec prisma generate
pnpm exec prisma migrate dev
pnpm exec prisma db seed
pnpm run start:dev
```

Backend verification:

```sh
pnpm run build
pnpm test --runInBand
pnpm run test:e2e
```

iOS verification:

```sh
xcrun --sdk iphonesimulator swiftc -target x86_64-apple-ios17.0-simulator -swift-version 6 -typecheck $(find apps/ios/Sources -name '*.swift' | sort)
```

```sh
xcodebuild -quiet -project apps/ios/WhatDidYouDo.xcodeproj -scheme WhatDidYouDo -configuration Debug -destination 'platform=iOS Simulator,id=7FE3BDCB-B1E2-4121-8649-12079CD15672' CODE_SIGNING_ALLOWED=NO build
```

The simulator id above is local-machine specific. Use `xcrun simctl list devices available` to find a valid simulator.

## API Smoke Test

Use a new terminal while backend is running:

```sh
BASE=http://127.0.0.1:3000

TOKEN=$(curl -s -X POST "$BASE/auth/mock-login" \
  -H "Content-Type: application/json" \
  -d '{"displayName":"iOS联调用户"}' | node -pe "JSON.parse(require('fs').readFileSync(0,'utf8')).accessToken")

FAMILY_ID=$(curl -s -X POST "$BASE/families" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"联调家庭","requirePhotoProof":false}' | node -pe "JSON.parse(require('fs').readFileSync(0,'utf8')).id")

CHORE_ID=$(curl -s "$BASE/chores" | node -pe "JSON.parse(require('fs').readFileSync(0,'utf8')).find(c => !c.isLocked).id")

curl -i -X POST "$BASE/chore-records" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"familyId\":\"$FAMILY_ID\",\"choreId\":\"$CHORE_ID\",\"note\":\"从 curl 创建\"}"

curl -i "$BASE/families/me" -H "Authorization: Bearer $TOKEN"
curl -i "$BASE/families/$FAMILY_ID/activity" -H "Authorization: Bearer $TOKEN"
curl -i "$BASE/families/$FAMILY_ID/leaderboard?range=month" -H "Authorization: Bearer $TOKEN"
curl -i "$BASE/families/$FAMILY_ID/monthly-report?month=2026-06" -H "Authorization: Bearer $TOKEN"
```

## Known Contract Gap

iOS Mock flow already supports `actualMinutes`.

Backend `POST /chore-records` currently has a documented next-step requirement to accept `actualMinutes`, calculate points, persist it, and return it. Before switching iOS from Mock mode to API mode, update:

- Prisma `ChoreRecord` model.
- `CreateChoreRecordDto`.
- `ChoreRecordsService.createRecord`.
- activity, leaderboard, and monthly report response mapping if needed.

Required API request shape:

```json
{
  "familyId": "family-id",
  "choreId": "chore-id",
  "actualMinutes": 20,
  "note": "从 iOS 创建",
  "imageUrls": []
}
```

## Engineering Constraints

- Do not rewrite the project structure.
- Do not mix npm and pnpm.
- Do not remove existing migrations or seed data.
- Do not discard uncommitted user changes.
- Keep iOS UI consistent with the current design system.
- Keep backend endpoints small and MVP-focused.
- Prefer adding DTO validation for all request inputs.
- Keep local development auth simple until real auth is planned.

## Next Recommended Steps

1. Add backend `actualMinutes` support to `POST /chore-records`.
2. Update iOS from Mock mode to API mode behind a small service layer.
3. Add API response models on iOS.
4. Add backend e2e tests for the complete MVP flow.
5. Add docs for environment variables and local reset commands.
