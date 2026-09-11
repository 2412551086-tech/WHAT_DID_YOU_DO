ALTER TABLE "ChoreRecord" ADD COLUMN "clientRequestId" TEXT;

CREATE UNIQUE INDEX "ChoreRecord_familyId_userId_clientRequestId_key"
ON "ChoreRecord"("familyId", "userId", "clientRequestId");
