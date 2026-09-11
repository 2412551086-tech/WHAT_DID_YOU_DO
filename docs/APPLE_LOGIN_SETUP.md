# Apple 登录接入记录

## 当前进度（2026-09-05）

- [x] Apple Developer 已启用主 App ID 的 Sign in with Apple 能力。
- [x] Bundle ID：`com.douxiaolang.familyguard`，Team ID：`3WY4649N39`。
- [x] 注册专用密钥 `FamilyGuard Apple Login`，Key ID：`F92P7M35DU`，仅启用 Apple 登录服务。
- [x] iOS Debug / Release 指定 `Resources/WhatDidYouDo.entitlements`。
- [x] entitlements 与 Xcode project 通过 `plutil -lint` 检查。
- [x] 用户已下载一次性 `.p8` 私钥，已验证为 P-256，文件权限设为 600；私钥不在仓库内。
- [x] 实现后端 Apple 凭证校验、授权码兑换及账户删除时撤销 Apple 授权。
- [x] 实现 iOS 原生授权，并复用现有登录后的家庭导航和会话存储。
- [x] 配置生产服务器密钥，前向迁移已部署，API 容器健康。
- [x] 更新签名描述文件，Release 真机包构建成功，包内确认包含 Apple 登录 entitlement。
- [ ] 安装到手机并完成真实 Apple 授权；无线安装因设备连接超时未完成，等待数据线连接和解锁。

注意：启用 App ID 能力会使旧 provisioning profiles 失效，需要重新生成。
代码和生产后端已部署；仍需用户在真机完成 Apple 授权，不能将接口健康检查当成真实登录验收。

## 实现约束

- 以 Apple 的稳定 `sub` 映射 `AuthIdentity`，不凭邮箱、昵称或头像自动合并用户。
- 保留 EMAIL、Access Token、Refresh Token Rotation、AuthSession 和 Keychain。
- 校验签名、issuer、audience、有效期及一次性 nonce；拒绝重复使用授权请求。
- 私钥与 Apple refresh token 不得写入代码、日志、客户端或 Git；服务端凭证须安全存储。
- 登录、取消、首次授权、隐藏邮箱、重复登录、过期凭证、身份冲突、注销账户均需测试。
- 原生 iOS 登录使用 Bundle ID；本阶段不额外创建网页登录 Service ID。

## 接口与部署

- `POST /auth/apple/challenge`：返回五分钟有效的服务端 nonce 与 challenge ID。
- `POST /auth/apple/login`：提交 challenge ID、identity token、authorization code 和设备元数据。
- 使用 Apple JWKS 验证 RS256 签名、issuer、Bundle ID audience、nonce、sub 和有效期。
- 原子消费 challenge 后用授权码向 Apple 换取凭证；再次校验返回 identity token 的 nonce 和 sub。
- AuthIdentity 的 Apple refresh token 用独立密钥 AES-256-GCM 加密，绑定 sub 作为 AAD。
- `DELETE /auth/me` 对 Apple 用户先撤销 Apple 授权，成功后执行现有删除事务；Apple 服务故障时返回可重试错误，不假报删除成功。
- 独立前向迁移 `20260905090000_apple_login`，不修改历史 migration。

服务器安全配置命令（在服务器执行，私钥先通过安全通道上传）：

```sh
node deploy/production/configure-apple-env.mjs /secure/path/AuthKey_F92P7M35DU.p8
```

脚本保持其他 production.env 配置不变，生成或保留独立加密密钥，设置文件权限为 600，私钥目录为 700。
Compose 只读挂载 `.secrets` 到 `/run/familyguard-secrets`，不把私钥打包进 Docker 镜像。
服务端必须备份 `.secrets` 和 production.env；不得随意更换 `APPLE_TOKEN_ENCRYPTION_KEY`，否则旧凭证无法解密。

## 验收边界

2026-09-06 生产验证：`https://api.douxiaolang.com/health` 正常；Apple challenge 返回成功，伪造 identity token 返回 401。
容器中验证 ES256 客户端断言签名和 SMTP 认证通过，开发验证码暴露为 false。
备份位于服务器 `/opt/familyguard-backups/apple-20260905`（私有目录），包含部署前源码、数据库及部署后 Apple 密钥配置备份。
部署通过临时 SSH 密钥进行，收尾已撤销并验证新连接被拒绝；本地临时 SSH 私钥已删除，用户提供的 Apple 私钥保留。

2026-09-05 本地验证：后端 build 通过，单元测试 56/56，全量 E2E 35/35；
iOS build-for-testing 通过，Apple 登录和邮箱登录回归测试 3/3。
全量 E2E 首次运行一项原有家庭审核测试出现事务超时，单项复测及全量重跑均通过，未修改家庭逻辑。

- 单元测试包含真实 RSA 签名校验及异常 claims、安全加密、重放和撤销。
- E2E 的 Apple 外部响应使用 stub，验证 HTTP / 数据库 / 会话 / 删除链路；不等于真实 Apple 授权验收。
- iOS 测试覆盖凭证提交、Keychain 抽象层会话保存及家庭流程续接。
- 上线前仍需真机完成首次授权（含隐藏邮箱）、重启保持登录、退出重登及注销。
- 本轮不按相同邮箱自动合并已有 EMAIL 和 APPLE 账号；用户主动绑定的 UI 仍属后续账号管理工作。
- Apple 服务端通知与用户在系统设置撤销授权后的主动会话失效需后续补充验证。
