CREATE TYPE "MemberRole" AS ENUM ('OWNER', 'MEMBER');
CREATE TYPE "MemberStatus" AS ENUM ('PENDING', 'ACTIVE', 'REJECTED');

ALTER TABLE "FamilyMember"
ADD COLUMN "identityLabel" TEXT NOT NULL DEFAULT '家庭成员',
ADD COLUMN "customIdentity" TEXT,
ADD COLUMN "avatarKey" TEXT,
ADD COLUMN "memberRole" "MemberRole" NOT NULL DEFAULT 'MEMBER',
ADD COLUMN "status" "MemberStatus" NOT NULL DEFAULT 'ACTIVE',
ADD COLUMN "approvedAt" TIMESTAMP(3),
ADD COLUMN "approvedById" TEXT;

UPDATE "FamilyMember"
SET "memberRole" = CASE
    WHEN LOWER("role") = 'owner' THEN 'OWNER'::"MemberRole"
    ELSE 'MEMBER'::"MemberRole"
END,
"status" = 'ACTIVE'::"MemberStatus",
"approvedAt" = "createdAt";

ALTER TABLE "FamilyMember" DROP COLUMN "role";

DROP INDEX "FamilyMember_familyId_idx";
CREATE INDEX "FamilyMember_familyId_status_idx" ON "FamilyMember"("familyId", "status");
CREATE INDEX "FamilyMember_approvedById_idx" ON "FamilyMember"("approvedById");

ALTER TABLE "FamilyMember"
ADD CONSTRAINT "FamilyMember_approvedById_fkey"
FOREIGN KEY ("approvedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "ChoreRecord"
ADD COLUMN "deletedAt" TIMESTAMP(3),
ADD COLUMN "deletedById" TEXT;

CREATE INDEX "ChoreRecord_deletedById_idx" ON "ChoreRecord"("deletedById");

ALTER TABLE "ChoreRecord"
ADD CONSTRAINT "ChoreRecord_deletedById_fkey"
FOREIGN KEY ("deletedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "ChoreRecordLike" (
    "id" TEXT NOT NULL,
    "recordId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ChoreRecordLike_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "ChoreRecordLike_recordId_userId_key"
ON "ChoreRecordLike"("recordId", "userId");

CREATE INDEX "ChoreRecordLike_userId_idx" ON "ChoreRecordLike"("userId");

ALTER TABLE "ChoreRecordLike"
ADD CONSTRAINT "ChoreRecordLike_recordId_fkey"
FOREIGN KEY ("recordId") REFERENCES "ChoreRecord"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ChoreRecordLike"
ADD CONSTRAINT "ChoreRecordLike_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
