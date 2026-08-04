ALTER TABLE "Chore"
ADD COLUMN "themeKey" TEXT NOT NULL DEFAULT 'daily';

CREATE INDEX "Chore_themeKey_sortOrder_idx" ON "Chore"("themeKey", "sortOrder");
