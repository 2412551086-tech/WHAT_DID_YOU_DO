#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
umask 077

if [[ -f production.env ]]; then
  echo "production.env already exists; refusing to overwrite it."
  exit 1
fi

read -r -s -p "请输入阿里云 DirectMail SMTP 密码（输入不会显示），然后按回车：" SMTP_PASSWORD
echo

if [[ -z "$SMTP_PASSWORD" || "$SMTP_PASSWORD" == *$'\n'* ]]; then
  echo "SMTP 密码不能为空。"
  exit 1
fi

POSTGRES_PASSWORD="$(openssl rand -hex 32)"
JWT_SECRET="$(openssl rand -hex 48)"
EMAIL_OTP_SECRET="$(openssl rand -hex 48)"

cat > production.env <<EOF
NODE_ENV=production
PORT=3000

POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
DATABASE_URL=postgresql://familyguard:${POSTGRES_PASSWORD}@database:5432/familyguard?schema=public

JWT_SECRET=${JWT_SECRET}
EMAIL_OTP_SECRET=${EMAIL_OTP_SECRET}
AUTH_DISTRIBUTION_REGION=CN

EMAIL_DELIVERY_MODE=ALIYUN_DM
EMAIL_OTP_EXPOSE_CODE=false
ALIYUN_DM_SMTP_HOST=smtpdm.aliyun.com
ALIYUN_DM_SMTP_PORT=465
ALIYUN_DM_SMTP_SECURE=true
ALIYUN_DM_SMTP_USER=no-reply@mail.douxiaolang.com
ALIYUN_DM_SMTP_PASS=${SMTP_PASSWORD}
ALIYUN_DM_FROM_NAME=家庭保卫战

ACHIEVEMENTS_ENABLED=true

TEST_PREMIUM_REDEMPTION_ENABLED=false
TEST_PREMIUM_REDEMPTION_EMAILS=
TEST_PREMIUM_REDEMPTION_CODE=
EOF

unset SMTP_PASSWORD POSTGRES_PASSWORD JWT_SECRET EMAIL_OTP_SECRET
chmod 600 production.env

echo "生产密钥已生成并写入受限配置文件。"
