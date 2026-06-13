# API Draft

This document tracks API design derived from `docs/PRD.md`. It is a planning document only; endpoints are not implemented yet.

## Base Path

`/api/v1`

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

## Next API Tasks

1. Define request and response DTOs.
2. Define authentication token shape.
3. Confirm error code naming and HTTP status mapping.
4. Add OpenAPI generation after backend modules exist.
