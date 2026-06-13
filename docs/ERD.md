# ERD Draft

This document tracks the first-pass data model implied by `docs/PRD.md`. Prisma models are not created yet.

## Candidate Entities

- User
- AuthIdentity
- Family
- FamilyMember
- ChoreCategory
- ChoreItem
- ChoreRecord
- FrequentChore
- CustomChore
- VoiceRecord
- Subscription
- MonthlyReport
- Notification

## Key Relationships

- A user can belong to many families through family memberships.
- A family has many members, chore records, frequent chores, custom chores, and reports.
- A chore record belongs to one family and one submitting user.
- A chore record may reference a preset chore item or a custom chore item.
- A monthly report can be family-scoped or user-scoped.

## Open Modeling Questions

1. Should deleted chore records remain soft-deleted for reporting?
2. Should points be stored as snapshots on records or recalculated from chore rules?
3. Should custom chores be copied into a family catalog when shared?
4. How long should raw voice audio be retained?
5. Should subscription be per user first, or should family billing be designed from day one?
