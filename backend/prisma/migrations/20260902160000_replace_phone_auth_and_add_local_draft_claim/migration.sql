-- Preserve pre-release development accounts while retiring the legacy provider.
DELETE FROM "AuthIdentity" AS legacy
USING "AuthIdentity" AS development
WHERE legacy."provider" = 'PHONE'
  AND development."provider" = 'DEV'
  AND legacy."userId" = development."userId";

UPDATE "AuthIdentity"
SET "providerSubject" = 'legacy:' || "id",
    "provider" = 'DEV'
WHERE "provider" = 'PHONE';

ALTER TYPE "AuthProvider" RENAME TO "AuthProvider_legacy";
CREATE TYPE "AuthProvider" AS ENUM ('APPLE', 'WECHAT', 'EMAIL', 'GOOGLE', 'DEV');
ALTER TABLE "AuthIdentity"
  ALTER COLUMN "provider" TYPE "AuthProvider"
  USING ("provider"::text::"AuthProvider");
DROP TYPE "AuthProvider_legacy";

DROP TABLE IF EXISTS "SmsVerificationChallenge";
ALTER TABLE "User" DROP COLUMN IF EXISTS "phoneNumber";

CREATE TABLE "LocalDraftClaim" (
  "draftId" TEXT NOT NULL,
  "payloadDigest" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "familyId" TEXT NOT NULL,
  "claimedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "LocalDraftClaim_pkey" PRIMARY KEY ("draftId")
);

CREATE UNIQUE INDEX "LocalDraftClaim_familyId_key" ON "LocalDraftClaim"("familyId");
CREATE INDEX "LocalDraftClaim_userId_claimedAt_idx" ON "LocalDraftClaim"("userId", "claimedAt");

ALTER TABLE "LocalDraftClaim"
  ADD CONSTRAINT "LocalDraftClaim_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "LocalDraftClaim"
  ADD CONSTRAINT "LocalDraftClaim_familyId_fkey"
  FOREIGN KEY ("familyId") REFERENCES "Family"("id") ON DELETE CASCADE ON UPDATE CASCADE;
