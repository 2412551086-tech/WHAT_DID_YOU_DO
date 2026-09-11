-- CreateEnum
CREATE TYPE "AchievementOwnerType" AS ENUM ('MEMBER', 'FAMILY', 'PAIR');

-- CreateEnum
CREATE TYPE "AchievementTrack" AS ENUM ('JOURNEY', 'MASTERY', 'BOND', 'HIDDEN');

-- CreateEnum
CREATE TYPE "AchievementTier" AS ENUM ('NONE', 'BRONZE', 'SILVER', 'GOLD');

-- CreateEnum
CREATE TYPE "AchievementRuleType" AS ENUM ('FIRST_EVENT', 'ACTIVE_DAYS', 'STREAK', 'COUNT', 'DURATION', 'CATEGORY_COVERAGE', 'ALL_MEMBERS', 'PAIR_COMBINATION', 'ANNIVERSARY');

-- CreateEnum
CREATE TYPE "AchievementWindowType" AS ENUM ('LIFETIME', 'DAY', 'WEEK', 'MONTH', 'ROLLING_DAYS');

-- CreateEnum
CREATE TYPE "AchievementVisibility" AS ENUM ('FAMILY', 'PRIVATE');

-- CreateEnum
CREATE TYPE "AchievementEventSourceType" AS ENUM ('CHORE', 'REACTION', 'MEMBERSHIP', 'FAMILY', 'PLAN');

-- CreateEnum
CREATE TYPE "AchievementEventStatus" AS ENUM ('PENDING', 'PROCESSING', 'SUCCEEDED', 'FAILED');

-- CreateEnum
CREATE TYPE "AchievementProgressStatus" AS ENUM ('ACTIVE', 'COMPLETED', 'DIRTY', 'REBUILDING');

-- CreateEnum
CREATE TYPE "AchievementArchiveStatus" AS ENUM ('ACTIVE', 'HISTORICAL', 'HIDDEN');

-- CreateEnum
CREATE TYPE "AchievementPeriodType" AS ENUM ('WEEK', 'MONTH');

-- CreateEnum
CREATE TYPE "AchievementParticipantDisplayRole" AS ENUM ('ACTIVE', 'FORMER', 'ANONYMIZED');

-- CreateEnum
CREATE TYPE "AchievementRewardType" AS ENUM ('COMMON_CHORE_SLOT', 'CUSTOM_CHORE_SLOT', 'COSMETIC');

-- AlterTable: preserve the business time of existing records before making the field required.
ALTER TABLE "ChoreRecord" ADD COLUMN "occurredAt" TIMESTAMP(3);
UPDATE "ChoreRecord" SET "occurredAt" = "createdAt" WHERE "occurredAt" IS NULL;
ALTER TABLE "ChoreRecord" ALTER COLUMN "occurredAt" SET NOT NULL,
ALTER COLUMN "occurredAt" SET DEFAULT CURRENT_TIMESTAMP;

-- CreateTable
CREATE TABLE "AchievementDefinition" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "nameKey" TEXT NOT NULL,
    "descriptionKey" TEXT NOT NULL,
    "unlockCopyKey" TEXT NOT NULL,
    "ownerType" "AchievementOwnerType" NOT NULL,
    "track" "AchievementTrack" NOT NULL,
    "tier" "AchievementTier" NOT NULL DEFAULT 'NONE',
    "ruleType" "AchievementRuleType" NOT NULL,
    "ruleConfigJson" JSONB NOT NULL,
    "targetValue" INTEGER NOT NULL,
    "windowType" "AchievementWindowType" NOT NULL DEFAULT 'LIFETIME',
    "windowSize" INTEGER,
    "maxDailyContribution" INTEGER,
    "minimumMemberCount" INTEGER,
    "rewardConfigJson" JSONB,
    "defaultVisibility" "AchievementVisibility" NOT NULL DEFAULT 'FAMILY',
    "definitionVersion" INTEGER NOT NULL DEFAULT 1,
    "validFrom" TIMESTAMP(3),
    "validUntil" TIMESTAMP(3),
    "campaignId" TEXT,
    "isHidden" BOOLEAN NOT NULL DEFAULT false,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AchievementDefinition_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AchievementEvent" (
    "id" TEXT NOT NULL,
    "familyId" TEXT NOT NULL,
    "actorUserId" TEXT,
    "eventType" TEXT NOT NULL,
    "sourceType" "AchievementEventSourceType" NOT NULL,
    "sourceId" TEXT NOT NULL,
    "sourceVersion" INTEGER NOT NULL DEFAULT 1,
    "idempotencyKey" TEXT NOT NULL,
    "occurredAt" TIMESTAMP(3) NOT NULL,
    "receivedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "familyTimezoneSnapshot" TEXT NOT NULL,
    "payloadJson" JSONB NOT NULL,
    "processStatus" "AchievementEventStatus" NOT NULL DEFAULT 'PENDING',
    "retryCount" INTEGER NOT NULL DEFAULT 0,
    "nextAttemptAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "processedAt" TIMESTAMP(3),
    "lastErrorCode" TEXT,

    CONSTRAINT "AchievementEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AchievementProgress" (
    "id" TEXT NOT NULL,
    "ownerType" "AchievementOwnerType" NOT NULL,
    "ownerKey" TEXT NOT NULL,
    "familyId" TEXT NOT NULL,
    "definitionId" TEXT NOT NULL,
    "achievementKey" TEXT NOT NULL,
    "tier" "AchievementTier" NOT NULL,
    "definitionVersion" INTEGER NOT NULL,
    "rawCurrentValue" INTEGER NOT NULL DEFAULT 0,
    "displayCurrentValue" INTEGER NOT NULL DEFAULT 0,
    "targetValue" INTEGER NOT NULL,
    "progressStatus" "AchievementProgressStatus" NOT NULL DEFAULT 'ACTIVE',
    "lastEventId" TEXT,
    "lastUpdatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AchievementProgress_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AchievementUnlockBatch" (
    "id" TEXT NOT NULL,
    "familyId" TEXT NOT NULL,
    "triggerEventId" TEXT NOT NULL,
    "primaryUnlockId" TEXT,
    "unlockCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AchievementUnlockBatch_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MemberAchievement" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "familyId" TEXT NOT NULL,
    "definitionId" TEXT NOT NULL,
    "achievementKey" TEXT NOT NULL,
    "tier" "AchievementTier" NOT NULL,
    "definitionVersion" INTEGER NOT NULL,
    "visibility" "AchievementVisibility" NOT NULL DEFAULT 'FAMILY',
    "unlockBatchId" TEXT NOT NULL,
    "triggerEventId" TEXT NOT NULL,
    "unlockedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MemberAchievement_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FamilyAchievement" (
    "id" TEXT NOT NULL,
    "familyId" TEXT NOT NULL,
    "definitionId" TEXT NOT NULL,
    "achievementKey" TEXT NOT NULL,
    "tier" "AchievementTier" NOT NULL,
    "definitionVersion" INTEGER NOT NULL,
    "triggeredByUserId" TEXT,
    "unlockBatchId" TEXT NOT NULL,
    "triggerEventId" TEXT NOT NULL,
    "unlockedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FamilyAchievement_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PairAchievement" (
    "id" TEXT NOT NULL,
    "familyId" TEXT NOT NULL,
    "memberAId" TEXT NOT NULL,
    "memberBId" TEXT NOT NULL,
    "definitionId" TEXT NOT NULL,
    "achievementKey" TEXT NOT NULL,
    "tier" "AchievementTier" NOT NULL,
    "definitionVersion" INTEGER NOT NULL,
    "unlockBatchId" TEXT NOT NULL,
    "triggerEventId" TEXT NOT NULL,
    "unlockedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "archiveStatus" "AchievementArchiveStatus" NOT NULL DEFAULT 'ACTIVE',

    CONSTRAINT "PairAchievement_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FamilyAchievementParticipant" (
    "id" TEXT NOT NULL,
    "familyAchievementId" TEXT NOT NULL,
    "userId" TEXT,
    "displayRole" "AchievementParticipantDisplayRole" NOT NULL DEFAULT 'ACTIVE',
    "contributionSummaryJson" JSONB,

    CONSTRAINT "FamilyAchievementParticipant_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AchievementEligibilitySnapshot" (
    "id" TEXT NOT NULL,
    "familyId" TEXT NOT NULL,
    "periodType" "AchievementPeriodType" NOT NULL,
    "periodStart" TIMESTAMP(3) NOT NULL,
    "periodEnd" TIMESTAMP(3) NOT NULL,
    "timezone" TEXT NOT NULL,
    "eligibleMemberIdsJson" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AchievementEligibilitySnapshot_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FamilyRewardGrant" (
    "id" TEXT NOT NULL,
    "familyId" TEXT NOT NULL,
    "achievementKey" TEXT NOT NULL,
    "rewardType" "AchievementRewardType" NOT NULL,
    "rewardValue" INTEGER NOT NULL,
    "grantedByUserId" TEXT,
    "triggerEventId" TEXT NOT NULL,
    "grantedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FamilyRewardGrant_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AchievementAuditLog" (
    "id" TEXT NOT NULL,
    "familyId" TEXT,
    "actorUserId" TEXT,
    "actionType" TEXT NOT NULL,
    "entityType" TEXT NOT NULL,
    "entityId" TEXT NOT NULL,
    "beforeJson" JSONB,
    "afterJson" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AchievementAuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "AchievementDefinition_track_isActive_idx" ON "AchievementDefinition"("track", "isActive");

-- CreateIndex
CREATE INDEX "AchievementDefinition_ownerType_isActive_idx" ON "AchievementDefinition"("ownerType", "isActive");

-- CreateIndex
CREATE UNIQUE INDEX "AchievementDefinition_key_tier_definitionVersion_key" ON "AchievementDefinition"("key", "tier", "definitionVersion");

-- CreateIndex
CREATE UNIQUE INDEX "AchievementEvent_idempotencyKey_key" ON "AchievementEvent"("idempotencyKey");

-- CreateIndex
CREATE INDEX "AchievementEvent_processStatus_nextAttemptAt_idx" ON "AchievementEvent"("processStatus", "nextAttemptAt");

-- CreateIndex
CREATE INDEX "AchievementEvent_familyId_occurredAt_idx" ON "AchievementEvent"("familyId", "occurredAt");

-- CreateIndex
CREATE INDEX "AchievementEvent_actorUserId_occurredAt_idx" ON "AchievementEvent"("actorUserId", "occurredAt");

-- CreateIndex
CREATE UNIQUE INDEX "AchievementEvent_eventType_sourceType_sourceId_sourceVersio_key" ON "AchievementEvent"("eventType", "sourceType", "sourceId", "sourceVersion");

-- CreateIndex
CREATE INDEX "AchievementProgress_familyId_progressStatus_idx" ON "AchievementProgress"("familyId", "progressStatus");

-- CreateIndex
CREATE INDEX "AchievementProgress_definitionId_idx" ON "AchievementProgress"("definitionId");

-- CreateIndex
CREATE INDEX "AchievementProgress_lastEventId_idx" ON "AchievementProgress"("lastEventId");

-- CreateIndex
CREATE UNIQUE INDEX "AchievementProgress_ownerType_ownerKey_achievementKey_tier__key" ON "AchievementProgress"("ownerType", "ownerKey", "achievementKey", "tier", "definitionVersion");

-- CreateIndex
CREATE UNIQUE INDEX "AchievementUnlockBatch_triggerEventId_key" ON "AchievementUnlockBatch"("triggerEventId");

-- CreateIndex
CREATE INDEX "AchievementUnlockBatch_familyId_createdAt_idx" ON "AchievementUnlockBatch"("familyId", "createdAt");

-- CreateIndex
CREATE INDEX "MemberAchievement_familyId_unlockedAt_idx" ON "MemberAchievement"("familyId", "unlockedAt");

-- CreateIndex
CREATE INDEX "MemberAchievement_definitionId_idx" ON "MemberAchievement"("definitionId");

-- CreateIndex
CREATE INDEX "MemberAchievement_unlockBatchId_idx" ON "MemberAchievement"("unlockBatchId");

-- CreateIndex
CREATE INDEX "MemberAchievement_triggerEventId_idx" ON "MemberAchievement"("triggerEventId");

-- CreateIndex
CREATE UNIQUE INDEX "MemberAchievement_userId_familyId_achievementKey_tier_defin_key" ON "MemberAchievement"("userId", "familyId", "achievementKey", "tier", "definitionVersion");

-- CreateIndex
CREATE INDEX "FamilyAchievement_definitionId_idx" ON "FamilyAchievement"("definitionId");

-- CreateIndex
CREATE INDEX "FamilyAchievement_unlockBatchId_idx" ON "FamilyAchievement"("unlockBatchId");

-- CreateIndex
CREATE INDEX "FamilyAchievement_triggerEventId_idx" ON "FamilyAchievement"("triggerEventId");

-- CreateIndex
CREATE INDEX "FamilyAchievement_triggeredByUserId_idx" ON "FamilyAchievement"("triggeredByUserId");

-- CreateIndex
CREATE UNIQUE INDEX "FamilyAchievement_familyId_achievementKey_tier_definitionVe_key" ON "FamilyAchievement"("familyId", "achievementKey", "tier", "definitionVersion");

-- CreateIndex
CREATE INDEX "PairAchievement_definitionId_idx" ON "PairAchievement"("definitionId");

-- CreateIndex
CREATE INDEX "PairAchievement_unlockBatchId_idx" ON "PairAchievement"("unlockBatchId");

-- CreateIndex
CREATE INDEX "PairAchievement_triggerEventId_idx" ON "PairAchievement"("triggerEventId");

-- CreateIndex
CREATE INDEX "PairAchievement_memberAId_memberBId_idx" ON "PairAchievement"("memberAId", "memberBId");

-- CreateIndex
CREATE UNIQUE INDEX "PairAchievement_familyId_memberAId_memberBId_achievementKey_key" ON "PairAchievement"("familyId", "memberAId", "memberBId", "achievementKey", "tier", "definitionVersion");

-- CreateIndex
CREATE INDEX "FamilyAchievementParticipant_userId_idx" ON "FamilyAchievementParticipant"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "FamilyAchievementParticipant_familyAchievementId_userId_key" ON "FamilyAchievementParticipant"("familyAchievementId", "userId");

-- CreateIndex
CREATE INDEX "AchievementEligibilitySnapshot_familyId_periodEnd_idx" ON "AchievementEligibilitySnapshot"("familyId", "periodEnd");

-- CreateIndex
CREATE UNIQUE INDEX "AchievementEligibilitySnapshot_familyId_periodType_periodSt_key" ON "AchievementEligibilitySnapshot"("familyId", "periodType", "periodStart");

-- CreateIndex
CREATE INDEX "FamilyRewardGrant_triggerEventId_idx" ON "FamilyRewardGrant"("triggerEventId");

-- CreateIndex
CREATE INDEX "FamilyRewardGrant_grantedByUserId_idx" ON "FamilyRewardGrant"("grantedByUserId");

-- CreateIndex
CREATE UNIQUE INDEX "FamilyRewardGrant_familyId_achievementKey_rewardType_key" ON "FamilyRewardGrant"("familyId", "achievementKey", "rewardType");

-- CreateIndex
CREATE INDEX "AchievementAuditLog_familyId_createdAt_idx" ON "AchievementAuditLog"("familyId", "createdAt");

-- CreateIndex
CREATE INDEX "AchievementAuditLog_actorUserId_createdAt_idx" ON "AchievementAuditLog"("actorUserId", "createdAt");

-- CreateIndex
CREATE INDEX "AchievementAuditLog_entityType_entityId_idx" ON "AchievementAuditLog"("entityType", "entityId");

-- CreateIndex
CREATE INDEX "ChoreRecord_familyId_occurredAt_idx" ON "ChoreRecord"("familyId", "occurredAt");

-- CreateIndex
CREATE INDEX "ChoreRecord_familyId_userId_occurredAt_idx" ON "ChoreRecord"("familyId", "userId", "occurredAt");

-- AddForeignKey
ALTER TABLE "AchievementEvent" ADD CONSTRAINT "AchievementEvent_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "Family"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AchievementEvent" ADD CONSTRAINT "AchievementEvent_actorUserId_fkey" FOREIGN KEY ("actorUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AchievementProgress" ADD CONSTRAINT "AchievementProgress_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "Family"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AchievementProgress" ADD CONSTRAINT "AchievementProgress_definitionId_fkey" FOREIGN KEY ("definitionId") REFERENCES "AchievementDefinition"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AchievementProgress" ADD CONSTRAINT "AchievementProgress_lastEventId_fkey" FOREIGN KEY ("lastEventId") REFERENCES "AchievementEvent"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AchievementUnlockBatch" ADD CONSTRAINT "AchievementUnlockBatch_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "Family"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AchievementUnlockBatch" ADD CONSTRAINT "AchievementUnlockBatch_triggerEventId_fkey" FOREIGN KEY ("triggerEventId") REFERENCES "AchievementEvent"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MemberAchievement" ADD CONSTRAINT "MemberAchievement_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MemberAchievement" ADD CONSTRAINT "MemberAchievement_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "Family"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MemberAchievement" ADD CONSTRAINT "MemberAchievement_definitionId_fkey" FOREIGN KEY ("definitionId") REFERENCES "AchievementDefinition"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MemberAchievement" ADD CONSTRAINT "MemberAchievement_unlockBatchId_fkey" FOREIGN KEY ("unlockBatchId") REFERENCES "AchievementUnlockBatch"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MemberAchievement" ADD CONSTRAINT "MemberAchievement_triggerEventId_fkey" FOREIGN KEY ("triggerEventId") REFERENCES "AchievementEvent"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FamilyAchievement" ADD CONSTRAINT "FamilyAchievement_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "Family"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FamilyAchievement" ADD CONSTRAINT "FamilyAchievement_definitionId_fkey" FOREIGN KEY ("definitionId") REFERENCES "AchievementDefinition"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FamilyAchievement" ADD CONSTRAINT "FamilyAchievement_triggeredByUserId_fkey" FOREIGN KEY ("triggeredByUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FamilyAchievement" ADD CONSTRAINT "FamilyAchievement_unlockBatchId_fkey" FOREIGN KEY ("unlockBatchId") REFERENCES "AchievementUnlockBatch"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FamilyAchievement" ADD CONSTRAINT "FamilyAchievement_triggerEventId_fkey" FOREIGN KEY ("triggerEventId") REFERENCES "AchievementEvent"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PairAchievement" ADD CONSTRAINT "PairAchievement_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "Family"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PairAchievement" ADD CONSTRAINT "PairAchievement_memberAId_fkey" FOREIGN KEY ("memberAId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PairAchievement" ADD CONSTRAINT "PairAchievement_memberBId_fkey" FOREIGN KEY ("memberBId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PairAchievement" ADD CONSTRAINT "PairAchievement_definitionId_fkey" FOREIGN KEY ("definitionId") REFERENCES "AchievementDefinition"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PairAchievement" ADD CONSTRAINT "PairAchievement_unlockBatchId_fkey" FOREIGN KEY ("unlockBatchId") REFERENCES "AchievementUnlockBatch"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PairAchievement" ADD CONSTRAINT "PairAchievement_triggerEventId_fkey" FOREIGN KEY ("triggerEventId") REFERENCES "AchievementEvent"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FamilyAchievementParticipant" ADD CONSTRAINT "FamilyAchievementParticipant_familyAchievementId_fkey" FOREIGN KEY ("familyAchievementId") REFERENCES "FamilyAchievement"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FamilyAchievementParticipant" ADD CONSTRAINT "FamilyAchievementParticipant_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AchievementEligibilitySnapshot" ADD CONSTRAINT "AchievementEligibilitySnapshot_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "Family"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FamilyRewardGrant" ADD CONSTRAINT "FamilyRewardGrant_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "Family"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FamilyRewardGrant" ADD CONSTRAINT "FamilyRewardGrant_grantedByUserId_fkey" FOREIGN KEY ("grantedByUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FamilyRewardGrant" ADD CONSTRAINT "FamilyRewardGrant_triggerEventId_fkey" FOREIGN KEY ("triggerEventId") REFERENCES "AchievementEvent"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AchievementAuditLog" ADD CONSTRAINT "AchievementAuditLog_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "Family"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AchievementAuditLog" ADD CONSTRAINT "AchievementAuditLog_actorUserId_fkey" FOREIGN KEY ("actorUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
