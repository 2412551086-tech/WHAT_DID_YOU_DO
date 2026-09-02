CREATE TYPE "AuthProvider" AS ENUM ('PHONE', 'APPLE', 'WECHAT', 'DEV');

CREATE TABLE "AuthIdentity" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "provider" "AuthProvider" NOT NULL,
    "providerSubject" TEXT NOT NULL,
    "verifiedAt" TIMESTAMP(3),
    "lastUsedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AuthIdentity_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "AuthIdentity_provider_providerSubject_key"
ON "AuthIdentity"("provider", "providerSubject");

CREATE UNIQUE INDEX "AuthIdentity_userId_provider_key"
ON "AuthIdentity"("userId", "provider");

CREATE INDEX "AuthIdentity_userId_idx" ON "AuthIdentity"("userId");

ALTER TABLE "AuthIdentity"
ADD CONSTRAINT "AuthIdentity_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

DO $$
BEGIN
  IF EXISTS (
    WITH normalized AS (
      SELECT
        CASE
          WHEN trim("phoneNumber") ~ '^[+0-9 ()-]+$'
            AND regexp_replace("phoneNumber", '[^0-9]', '', 'g') ~ '^1[3-9][0-9]{9}$'
            THEN '+86' || regexp_replace("phoneNumber", '[^0-9]', '', 'g')
          WHEN trim("phoneNumber") ~ '^[+0-9 ()-]+$'
            AND regexp_replace("phoneNumber", '[^0-9]', '', 'g') ~ '^861[3-9][0-9]{9}$'
            THEN '+' || regexp_replace("phoneNumber", '[^0-9]', '', 'g')
          ELSE NULL
        END AS subject
      FROM "User"
      WHERE "phoneNumber" IS NOT NULL
    )
    SELECT 1
    FROM normalized
    WHERE subject IS NOT NULL
    GROUP BY subject
    HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION 'AuthIdentity migration found phone numbers that normalize to the same +86 subject';
  END IF;
END $$;

INSERT INTO "AuthIdentity" (
  "id",
  "userId",
  "provider",
  "providerSubject",
  "verifiedAt",
  "lastUsedAt",
  "createdAt",
  "updatedAt"
)
SELECT
  'auth_' || md5("id" || ':' || "phoneNumber"),
  "id",
  CASE
    WHEN trim("phoneNumber") ~ '^[+0-9 ()-]+$'
      AND (
        regexp_replace("phoneNumber", '[^0-9]', '', 'g') ~ '^1[3-9][0-9]{9}$'
        OR regexp_replace("phoneNumber", '[^0-9]', '', 'g') ~ '^861[3-9][0-9]{9}$'
      )
      THEN 'PHONE'::"AuthProvider"
    ELSE 'DEV'::"AuthProvider"
  END,
  CASE
    WHEN trim("phoneNumber") ~ '^[+0-9 ()-]+$'
      AND regexp_replace("phoneNumber", '[^0-9]', '', 'g') ~ '^1[3-9][0-9]{9}$'
      THEN '+86' || regexp_replace("phoneNumber", '[^0-9]', '', 'g')
    WHEN trim("phoneNumber") ~ '^[+0-9 ()-]+$'
      AND regexp_replace("phoneNumber", '[^0-9]', '', 'g') ~ '^861[3-9][0-9]{9}$'
      THEN '+' || regexp_replace("phoneNumber", '[^0-9]', '', 'g')
    ELSE trim("phoneNumber")
  END,
  NULL,
  "updatedAt",
  "createdAt",
  CURRENT_TIMESTAMP
FROM "User"
WHERE "phoneNumber" IS NOT NULL;
