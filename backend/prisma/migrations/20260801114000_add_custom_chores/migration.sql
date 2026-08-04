-- Family-scoped custom chores use the existing Chore/ChoreRecord pipeline so
-- actual-minute scoring and reports keep one source of truth.
ALTER TABLE "Chore"
ADD COLUMN "catalogKey" TEXT,
ADD COLUMN "familyId" TEXT,
ADD COLUMN "createdById" TEXT,
ADD COLUMN "isCustom" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "customSlot" INTEGER,
ADD COLUMN "archivedAt" TIMESTAMP(3);

DROP INDEX "Chore_name_key";

CREATE UNIQUE INDEX "Chore_catalogKey_key" ON "Chore"("catalogKey");
CREATE INDEX "Chore_familyId_isCustom_archivedAt_idx" ON "Chore"("familyId", "isCustom", "archivedAt");
CREATE INDEX "Chore_createdById_idx" ON "Chore"("createdById");
CREATE UNIQUE INDEX "Chore_familyId_customSlot_key" ON "Chore"("familyId", "customSlot");

ALTER TABLE "Chore"
ADD CONSTRAINT "Chore_familyId_fkey"
FOREIGN KEY ("familyId") REFERENCES "Family"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Chore"
ADD CONSTRAINT "Chore_createdById_fkey"
FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
