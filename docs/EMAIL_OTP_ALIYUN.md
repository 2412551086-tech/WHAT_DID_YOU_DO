# 阿里云邮箱验证码配置与验收

更新时间：2026-09-04

## 1. 当前实现

邮箱验证码登录已接入后端和 iOS：发送验证码、摘要保存、频控、过期、单次消费、EMAIL 身份映射、设备会话和 Token Rotation 已完成。生产发信使用阿里云邮件推送 SMTP。

## 2. 阿里云控制台配置

正式发信使用独立子域名 `mail.douxiaolang.com`，避免与官网、API 或企业邮箱共用同一个域名。

1. [已完成] 在“邮件推送 > 发信域名”添加 `mail.douxiaolang.com`。
2. [已完成] 按控制台给出的记录值，在 `douxiaolang.com` DNS 中添加 DKIM、SPF、DMARC 和 MX 记录。
3. [已完成] 阿里云控制台显示 DKIM、SPF、DMARC、MX 四项均验证通过。
4. [已完成] 在“发信地址”创建 `no-reply@mail.douxiaolang.com`，类型为触发邮件，状态正常。
5. [已完成] 为该发信地址设置 SMTP 密码。密码只进入服务器密钥配置，不写入 Git、文档或聊天记录。
6. 第一版使用杭州 SMTP 地址 `smtpdm.aliyun.com`、端口 `465`、SSL 开启。

2026-09-04 已使用上述 SMTP 通道向 QQ 邮箱发送验证码样式邮件，阿里云接受发送请求且收件箱实际收到邮件。真实投递链路验收通过。

## 3. 生产环境变量

```text
NODE_ENV=production
EMAIL_DELIVERY_MODE=ALIYUN_DM
EMAIL_OTP_SECRET=<独立生成且至少 32 字节的随机密钥>
EMAIL_OTP_EXPOSE_CODE=false
ALIYUN_DM_SMTP_HOST=smtpdm.aliyun.com
ALIYUN_DM_SMTP_PORT=465
ALIYUN_DM_SMTP_SECURE=true
ALIYUN_DM_SMTP_USER=no-reply@mail.douxiaolang.com
ALIYUN_DM_SMTP_PASS=<发信地址的 SMTP 密码>
ALIYUN_DM_FROM_NAME=家庭保卫战
```

`EMAIL_OTP_SECRET` 与 `JWT_SECRET` 必须是两个不同的随机值。二者都只放服务器 Secret 管理中，不进入仓库。

2026-09-04 已在阿里云 ECS 完成生产部署：

- `api.douxiaolang.com` 已解析到生产服务器，并由 Caddy 自动管理 HTTPS 证书。
- PostgreSQL、NestJS API 和 Caddy 使用隔离容器运行，数据库端口不向公网开放。
- SMTP 密码、数据库密码、`JWT_SECRET` 和 `EMAIL_OTP_SECRET` 保存在权限为 `600` 的服务器配置文件中。
- `GET /health` 和 `GET /auth/config` 已通过公网 HTTPS 验收，国内 Provider 为 `APPLE + WECHAT + EMAIL`。
- 生产环境不会返回 `developmentCode`，`POST /auth/mock-login` 已明确禁用并返回 `403`。
- 已通过生产 API 向 QQ 邮箱发送真实 OTP；App 内验证码提交和本地草稿认领仍需最后一轮人工验收。

## 4. 费用基线

- 免费额度：累计 2,000 封，免费期内每天最多 200 封。
- 按量付费：2 元 / 1,000 封，即约 0.002 元 / 封。
- 资源包可进一步降低单价，但有有效期；MVP 初期优先使用免费额度与按量付费。
- 实际账单与额度以阿里云控制台当日显示为准。

## 5. 上线验收

- 使用 QQ、163、Outlook 和 iCloud 邮箱各发送一次验证码，确认收件时间和垃圾箱情况。
- 验证 60 秒重发限制、每小时/每天频控、10 分钟过期、5 次错误锁定和验证码单次消费。
- 确认生产 API 响应不含 `developmentCode`，服务端日志不打印验证码或 SMTP 密码。
- 确认同一邮箱大小写不同仍登录同一个 `User.id`。
- 验证创建正式家庭、认领本地草稿和确认加入家庭三条 Auth Gate 路径。
- 检查阿里云退信、投递失败和额度告警；上线初期每日观察送达率。
