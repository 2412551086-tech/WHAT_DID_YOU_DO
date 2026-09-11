CREATE TABLE "SmsVerificationChallenge" (
    "id" TEXT NOT NULL,
    "phoneNumber" TEXT NOT NULL,
    "purpose" TEXT NOT NULL DEFAULT 'LOGIN',
    "codeHash" TEXT NOT NULL,
    "ipHash" TEXT,
    "deliveryStatus" TEXT NOT NULL DEFAULT 'PENDING',
    "providerMessageId" TEXT,
    "failedAttempts" INTEGER NOT NULL DEFAULT 0,
    "maxAttempts" INTEGER NOT NULL DEFAULT 5,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "resendAvailableAt" TIMESTAMP(3) NOT NULL,
    "consumedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SmsVerificationChallenge_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "SmsVerificationChallenge_phoneNumber_createdAt_idx"
ON "SmsVerificationChallenge"("phoneNumber", "createdAt");

CREATE INDEX "SmsVerificationChallenge_ipHash_createdAt_idx"
ON "SmsVerificationChallenge"("ipHash", "createdAt");

CREATE INDEX "SmsVerificationChallenge_expiresAt_idx"
ON "SmsVerificationChallenge"("expiresAt");
