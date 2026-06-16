# API Draft

This document tracks API design derived from `docs/PRD.md`.

## Base Path

Local development currently uses:

`http://127.0.0.1:3000`

## Candidate Modules

- Auth: WeChat login, Apple login, phone login.
- Families: create family, join family, update family settings.
- Chore Catalog: categories, preset chores, premium lock metadata.
- Chore Records: create, feed, delete, dispute.
- Frequent Chores: saved repeatable shortcuts and one-tap record.
- Custom Chores: premium custom chore items and sharing.
- Voice: recognize audio, parse text, confirm parsed chores.
- Subscription: status, create order, restore purchase.
- Reports: monthly report retrieval and share image generation.

## Cross-Cutting Requirements

- All family data must be scoped by membership.
- Premium-only actions must return a stable error code when locked.
- Photo proof validation depends on family settings.
- Voice recognition results must be confirmed by the user before records are created.
- Chore record creation must support actual duration. The client must not create a record immediately after a chore is tapped; it must first ask the user to confirm `actualMinutes`.

## MVP Chore Recording Flow

When the user taps a chore item:

1. The client opens an actual-duration picker instead of creating a record immediately.
2. The picker defaults to the chore's system standard duration.
3. The user can select an actual duration from 1 to 180 minutes.
4. The step is 1 minute.
5. The client previews points using:

```text
points = round(chore.defaultPoints * actualMinutes / chore.defaultMinutes)
```

6. The record is created only after the user confirms.

The saved record must include:

| Field | Required | Notes |
| ---- | ---- | ---- |
| `choreId` | Yes | Selected chore ID |
| `familyId` | Yes | Family ID |
| `actualMinutes` | Yes | User-selected duration |
| `points` | Yes | Calculated points |
| `note` | No | User note |
| `createdAt` | Yes | Creation timestamp |

The iOS Mock flow and later API-backed flow must both support `actualMinutes`.

## Implemented MVP Endpoints

### Mock Login

`POST /auth/mock-login`

Request:

```json
{
  "displayName": "iOS联调用户"
}
```

Response includes `user` and `accessToken`.

### Create Chore Record

`POST /chore-records`

Current minimum request:

```json
{
  "familyId": "family-id",
  "choreId": "chore-id",
  "note": "从 iOS 创建"
}
```

Required next contract before iOS API mode:

```json
{
  "familyId": "family-id",
  "choreId": "chore-id",
  "actualMinutes": 20,
  "note": "从 iOS 创建",
  "imageUrls": []
}
```

Backend `POST /chore-records` must accept `actualMinutes`, calculate `points`, persist both fields, and return them in the created record response.

## Next API Tasks

1. Add `actualMinutes` support to `POST /chore-records`.
2. Ensure `activity`, `leaderboard`, and `monthly-report` use calculated points from the saved record.
3. Confirm error code naming and HTTP status mapping.
4. Add OpenAPI generation after backend modules stabilize.
