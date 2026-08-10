ALTER TYPE "MemberStatus" ADD VALUE IF NOT EXISTS 'LEFT';

ALTER TABLE "FamilyMember"
ADD COLUMN "leftAt" TIMESTAMP(3);

ALTER TABLE "ChoreRecord"
ADD COLUMN "creatorDisplayNameSnapshot" TEXT,
ADD COLUMN "creatorIdentityLabelSnapshot" TEXT,
ADD COLUMN "creatorCustomIdentitySnapshot" TEXT,
ADD COLUMN "creatorAvatarKeySnapshot" TEXT;

UPDATE "ChoreRecord" AS record
SET
  "creatorDisplayNameSnapshot" = COALESCE(
    (SELECT "displayName" FROM "User" WHERE "id" = record."userId"),
    '家庭成员'
  ),
  "creatorIdentityLabelSnapshot" = COALESCE(
    (
      SELECT "identityLabel"
      FROM "FamilyMember"
      WHERE "userId" = record."userId" AND "familyId" = record."familyId"
      LIMIT 1
    ),
    '家庭成员'
  ),
  "creatorCustomIdentitySnapshot" = (
    SELECT "customIdentity"
    FROM "FamilyMember"
    WHERE "userId" = record."userId" AND "familyId" = record."familyId"
    LIMIT 1
  ),
  "creatorAvatarKeySnapshot" = (
    SELECT "avatarKey"
    FROM "FamilyMember"
    WHERE "userId" = record."userId" AND "familyId" = record."familyId"
    LIMIT 1
  );

ALTER TABLE "ChoreRecord"
ALTER COLUMN "creatorDisplayNameSnapshot" SET NOT NULL,
ALTER COLUMN "creatorIdentityLabelSnapshot" SET NOT NULL;
