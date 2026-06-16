ALTER TABLE "ChoreRecord" ADD COLUMN "actualMinutes" INTEGER;

UPDATE "ChoreRecord"
SET "actualMinutes" = "minutes"
WHERE "actualMinutes" IS NULL;

ALTER TABLE "ChoreRecord" ALTER COLUMN "actualMinutes" SET NOT NULL;
