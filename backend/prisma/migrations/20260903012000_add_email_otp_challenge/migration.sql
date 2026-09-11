CREATE TABLE "EmailOtpChallenge" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "codeDigest" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "consumedAt" TIMESTAMP(3),
    "attemptCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "EmailOtpChallenge_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "EmailOtpChallenge_email_createdAt_idx"
ON "EmailOtpChallenge"("email", "createdAt");

CREATE INDEX "EmailOtpChallenge_expiresAt_idx"
ON "EmailOtpChallenge"("expiresAt");

CREATE INDEX "EmailOtpChallenge_consumedAt_idx"
ON "EmailOtpChallenge"("consumedAt");
