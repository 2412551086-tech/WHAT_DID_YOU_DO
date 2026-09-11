CREATE TABLE "AchievementCharacter" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "sourceAchievementId" TEXT NOT NULL,
    "claimedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "AchievementCharacter_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "AchievementCharacter_userId_key_key" ON "AchievementCharacter"("userId", "key");
ALTER TABLE "AchievementCharacter" ADD CONSTRAINT "AchievementCharacter_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
