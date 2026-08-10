ALTER TABLE "Family"
ADD COLUMN "choreOrder" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
ADD COLUMN "pinnedChoreIds" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
ADD COLUMN "choreSetupCompleted" BOOLEAN NOT NULL DEFAULT false;

UPDATE "Chore"
SET "isFreeCore" = true
WHERE "familyId" IS NULL AND "isCustom" = false;
