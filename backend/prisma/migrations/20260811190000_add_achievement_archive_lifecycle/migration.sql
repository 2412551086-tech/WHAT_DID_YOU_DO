ALTER TABLE "User" ADD COLUMN "anonymizedAt" TIMESTAMP(3);
ALTER TABLE "Family" ADD COLUMN "archivedAt" TIMESTAMP(3);

CREATE INDEX "Family_archivedAt_idx" ON "Family"("archivedAt");
