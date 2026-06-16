-- CreateTable
CREATE TABLE "Chore" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "standardMinutes" INTEGER NOT NULL,
    "difficultyMultiplier" DOUBLE PRECISION NOT NULL,
    "defaultPoints" INTEGER NOT NULL,
    "icon" TEXT NOT NULL,
    "isFreeCore" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Chore_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Chore_name_key" ON "Chore"("name");

-- CreateIndex
CREATE INDEX "Chore_isFreeCore_sortOrder_idx" ON "Chore"("isFreeCore", "sortOrder");
