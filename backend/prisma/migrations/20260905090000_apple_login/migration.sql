ALTER TABLE "AuthIdentity" ADD COLUMN "appleRefreshTokenEncrypted" TEXT;
CREATE TABLE "AppleAuthChallenge" (
    "id" TEXT NOT NULL,
    "nonce" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "usedAt" TIMESTAMP(3),
    CONSTRAINT "AppleAuthChallenge_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "AppleAuthChallenge_expiresAt_idx" ON "AppleAuthChallenge"("expiresAt");
