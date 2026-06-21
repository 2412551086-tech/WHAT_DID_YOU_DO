# Agent Handoff Notes

更新时间：2026-06-21

## Project Summary

`你今天干啥啦` 是一个 iOS 优先的家庭家务记录与积分 App。当前已完成本地可联调 MVP 主链路，下一阶段重点是测试、稳定性、Keychain、环境配置和 TestFlight，不应重复实现已经落地的业务功能。

## Repository Layout

- `apps/ios`：SwiftUI + MVVM iOS App。
- `backend`：NestJS + Prisma + PostgreSQL API。
- `backend/prisma`：schema、migration、seed 和 Prisma 配置。
- `docs`：PRD、API、范围、验收矩阵和状态文档。

## Current Product Baseline

真实主链路：

1. 手机号开发登录。
2. 创建家庭，创建者成为 `ACTIVE + OWNER`。
3. 复制 `inviteCode`。
4. 其他开发账号使用 inviteCode 申请加入，状态为 `PENDING + MEMBER`。
5. OWNER approve/reject。
6. ACTIVE 成员选择家务和实际耗时。
7. 后端保存 `actualMinutes` 并按比例计算 `points`。
8. 首页读取今日/最近动态，刷新排行榜和月报。
9. 成员可以点赞/取消点赞；有权限者可以左滑软删除记录。

手机号登录只是 MVP 开发登录，不发送短信验证码，也不是生产认证。Apple/微信登录尚未接入。

## iOS State

技术与入口：

- SwiftUI + MVVM。
- `apps/ios/WhatDidYouDo.xcodeproj`
- `apps/ios/Sources/ViewModels/AppViewModel.swift`
- `apps/ios/Sources/Core/Network/APIClient.swift`
- `apps/ios/Sources/Core/Network/APIConfig.swift`
- `apps/ios/Sources/Core/Network/APIDTOs.swift`

当前能力：

- `APIConfig.useMockData` 切换 Mock/API。
- 四 Tab：今日战况、记一下、家庭战况、我的。
- 登录、创建家庭、邀请码加入、OWNER 审核。
- 身份选择、自定义身份、avatarKey 本地占位头像。
- `ChoreDurationPickerSheet` 使用 1...180 分钟 wheel picker。
- 每个 choreId 上次确认耗时通过 UserDefaults 保存；取消不保存。
- activity 展示头像、身份、实际耗时、积分、点赞计数和点赞头像。
- `canDelete=true` 时提供左滑删除。
- API 请求具有 loading、error；DebugPanel 仅 Debug 显示。

实际耗时积分规则：

```text
points = round(defaultPoints * actualMinutes / standardMinutes)
```

标准时长小于等于 0 时回退到默认积分。

当前本机 API 配置：

```swift
APIConfig.baseURL = http://127.0.0.1:3000
APIConfig.useMockData = false
```

`127.0.0.1` 适用于同一台 Mac 上的 iOS Simulator；真机需使用 Mac 局域网 IP，Release 必须改为正式 HTTPS 地址。

## Backend State

技术栈：NestJS、TypeScript、Prisma 7、PostgreSQL 16、pnpm。

模块：

- `AuthModule`
- `FamiliesModule`
- `ChoresModule`
- `ChoreRecordsModule`
- `ReportsModule`
- `PrismaModule`

真实路由：

- `POST /auth/mock-login`
- `POST /families`
- `GET /families/me`
- `POST /families/join-requests`
- `POST /families/:familyId/join-requests`（兼容旧调用）
- `GET /families/:familyId/join-requests`
- `PATCH /families/:familyId/join-requests/:memberId`
- `GET /chores`
- `POST /chore-records`
- `GET /families/:familyId/activity?range=day|recent`
- `GET /families/:familyId/leaderboard?range=day|month`
- `GET /families/:familyId/monthly-report?month=YYYY-MM`
- `DELETE /chore-records/:recordId`
- `POST /chore-records/:recordId/like`
- `DELETE /chore-records/:recordId/like`

后端已经支持 `actualMinutes`：可选、范围 1...180、不传时使用标准时长，并由服务端计算 points。不要再把它列为缺口。

统计约束：

- activity 的 day 当前按 UTC 自然日。
- activity 默认 recent，最多 30 条。
- leaderboard、monthly-report 和 activity 都排除软删除记录。
- 点赞和取消点赞均幂等。

图片凭证：后端字段和开启后的校验保留；iOS MVP 隐藏/禁用入口并创建家庭时固定发送 false。不要删除后端字段，也不要在未实现上传前开放 iOS 开关。

## Local Commands

只使用 pnpm，不混用 npm：

```sh
cd /Users/aoxideni/Documents/what_did_you_do/backend
pnpm install
pnpm exec prisma generate
pnpm exec prisma migrate dev
pnpm exec prisma db seed
pnpm run start:dev
```

验证：

```sh
pnpm run build
pnpm test --runInBand
pnpm run test
pnpm run test:e2e
```

iOS：

```sh
xcodebuild -project apps/ios/WhatDidYouDo.xcodeproj \
  -scheme WhatDidYouDo \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

## Current Gaps

- 正式短信验证码、Apple、微信认证。
- Keychain 会话存储和恢复。
- Debug/Staging/Release 环境隔离。
- 真实头像和图片凭证上传。
- StoreKit 与服务端权益校验。
- iOS 自动化主链路测试。
- CI、签名、归档、隐私材料和 TestFlight。

## Engineering Constraints

- 不重建项目，不删除 migration。
- 不混用 npm/pnpm。
- 不丢弃用户未提交改动。
- 不提交 `.env`、`node_modules`、`DerivedData`、`xcuserdata`、`*.xcuserstate`。
- iOS 保持现有 DesignSystem 和 Mock/API Preview 能力。
- 权限由 `memberRole`/`status` 决定，identityLabel 只用于展示。

## Next Recommended Order

1. 补后端边界测试与 iOS ViewModel/UI 回归。
2. 完成弱网、超时、token 失效和跨天边界处理。
3. 使用 Keychain 管理 token 和退出登录清理。
4. 拆分 Debug/Staging/Release 配置并接 CI。
5. 完成签名、归档、隐私信息和 TestFlight 内测。
