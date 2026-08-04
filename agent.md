# Agent Handoff Notes

更新时间：2026-08-05

## Project Summary

`你今天干啥啦` 是一个 iOS 优先的家庭家务记录与积分 App。当前已完成本地可联调 MVP、Keychain、环境配置和第一轮高保真重构；下一阶段重点是冻结基线、UI/双账号自动化、生产配置隔离和 TestFlight。

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
8. 首页读取家庭时区内本周动态，家庭动态读取 recent；月报支持月份切换。
9. 成员可以单击点赞、长按选择表情回应并取消回应；有权限者可以左滑软删除记录。
10. OWNER 可转让一家之主；成员可切换一一对应的立绘和头像。
11. 系统家务按日常家庭、恋爱陪伴、育儿、宠物四主题展示；免费版最多 6 项常用家务且由 OWNER 同步全家，高级版不限数量且每位成员可保存个人布局。
12. 每个家庭免费可创建 2 个共享自定义家务，开发兑换后扩展为 10 个；常用页只展示已有项和接下来的 2 个空位。
13. 月报按所选月份返回四主题与家务大类统计；iOS 使用主题圆环和大类分段比例条，并只保留领跑者卡为一级视觉锚点。
14. OWNER 可编辑家庭名称；ACTIVE 成员可查看其他成员滚动近 30 天未删除动态，家主转让从目标成员详情发起。
15. MEMBER 可退出当前家庭；OWNER 必须先转让家主，转让和退出后 iOS 立即刷新会话内角色状态。
16. 家庭高级版可在每次记录时调整 `0.5x...2.0x` 积分倍率，免费版使用系统固定倍率。

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
- 四 Tab：本周战况、记一下、月度战报、我的。
- 登录、创建家庭、邀请码加入、OWNER 审核。
- 身份选择、自定义身份、avatarKey 本地占位头像。
- `ChoreDurationPickerSheet` 使用 1...180 分钟 wheel picker。
- 每个 choreId 上次确认耗时通过 UserDefaults 保存；取消不保存。
- activity 展示头像、身份、实际耗时、积分、点赞计数和点赞头像。
- `canDelete=true` 时提供左滑删除。
- API 请求具有 loading、error；DebugPanel 仅 Debug 显示。
- Keychain 保存 token，启动恢复期间不会闪现 LoginView。
- 月报人物立绘跟随所选月份积分第一名。
- 月报消费 `themeStats`/`categoryStats`，使用主题圆环、家务大类分段条和分层卡片结构。
- 13 组 `family_avatar_action_XX`/`avatar_XX` 通过 avatarKey 一一映射。
- 自定义家务支持 10 项图标、默认时长和 0.5x...2.0x 倍率。
- 耗时弹窗显示系统倍率和预计积分；家庭高级版可以调整本次记录倍率，API 通过 `pointsMultiplier` 入账。
- Profile 顶部依次显示家庭名称、身份、昵称；OWNER 可编辑家庭名称，所有 ACTIVE 成员可进入其他成员近 30 天详情。
- Profile 支持修改本人昵称和退出家庭；OWNER 退出前必须先完成家主转让。

实际耗时积分规则：

```text
points = round(defaultPoints * actualMinutes / standardMinutes)
```

标准时长小于等于 0 时回退到默认积分。家庭高级版传入本次倍率时使用 `points = round(actualMinutes * pointsMultiplier)`，范围为 0.5x...2.0x。

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
- `GET /auth/me`
- `POST /auth/redeem-premium`（仅开发测试，production 禁用）
- `POST /families`
- `GET /families/me`
- `PATCH /families/:familyId`（仅 OWNER 修改家庭名称）
- `GET /families/invitations/:inviteCode`
- `GET /families/join-requests/me`
- `POST /families/join-requests`
- `POST /families/:familyId/join-requests`（兼容旧调用）
- `GET /families/:familyId/join-requests`
- `PATCH /families/:familyId/join-requests/:memberId`
- `PATCH /families/:familyId/owner`
- `PATCH /families/:familyId/members/me/appearance`
- `GET /families/:familyId/members/:memberId/activity`（ACTIVE，滚动近 30 天）
- `GET /chores`
- `GET|PATCH /families/:familyId/chore-layout`
- `GET|POST /families/:familyId/custom-chores`
- `PATCH|DELETE /families/:familyId/custom-chores/:choreId`
- `POST /chore-records`
- `GET /families/:familyId/activity?range=day|week|recent`
- `GET /families/:familyId/leaderboard?range=day|week|month`
- `GET /families/:familyId/monthly-report?month=YYYY-MM`
- `DELETE /chore-records/:recordId`
- `POST /chore-records/:recordId/like`
- `DELETE /chore-records/:recordId/like`

后端已经支持 `actualMinutes`：可选、范围 1...180、不传时使用标准时长，并由服务端计算 points。不要再把它列为缺口。

统计约束：

- activity 的 day 按家庭 `timezone` 计算本地今天。
- activity 默认 recent，最多 30 条。
- leaderboard、monthly-report 和 activity 都排除软删除记录。
- monthly-report 同时返回按 `themeKey` 聚合的 `themeStats` 和按家务大类聚合的 `categoryStats`。
- 点赞/表情回应和取消均幂等；支持 `like`、`high_five`、`moon_face`、`laugh_cry`、`tease`，同一用户只保留一种回应。
- 首页周统计使用家庭时区内周一至下周一的范围。
- 系统家务全部免费；开通账号保存 `User.plan=premium`，但权益按家庭共享：任一 ACTIVE 成员开通后，全家扩展常用系统家务数量、自定义家务额度并允许每位成员使用个人布局。测试码默认 `241255`，生产禁用。

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
- 真实头像和图片凭证上传。
- StoreKit、收据校验和正式订阅权益。
- iOS 自动化主链路测试。
- 完整 XCUITest、签名、归档、隐私材料和 TestFlight。

## Engineering Constraints

- 不重建项目，不删除 migration。
- 不混用 npm/pnpm。
- 不丢弃用户未提交改动。
- 不提交 `.env`、`node_modules`、`DerivedData`、`xcuserdata`、`*.xcuserstate`。
- iOS 保持现有 DesignSystem 和 Mock/API Preview 能力。
- 权限由 `memberRole`/`status` 决定，identityLabel 只用于展示。

## Next Recommended Order

1. 冻结当前功能与高保真 UI 基线，清理并提交当前大批工作区改动。
2. 增加双账号 XCUITest、关键截图回归和周边界/DST 测试。
3. 隔离开发兑换码和 Release 配置，正式付费改用 StoreKit + 服务端收据校验。
4. 完成签名、归档、隐私信息和 TestFlight 内测。

详细的 2026-08-01 上午改动见 `docs/CHANGELOG_2026-08-01_AM.md`。
