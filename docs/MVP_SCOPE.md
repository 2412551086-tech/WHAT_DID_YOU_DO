# MVP Scope

更新时间：2026-06-21

## 1. 当前 MVP 定义

当前 MVP 是一个可在本地完成双用户家庭协作主链路的 iOS App：

手机号开发登录 → 创建/使用邀请码加入家庭 → OWNER 审核 → 选择家务与实际耗时 → 创建积分记录 → 查看今日/最近动态、排行和月报 → 点赞或软删除记录。

手机号开发登录仅用于联调，不代表正式短信验证码能力。

## 2. 已完成范围

### 2.1 iOS

- SwiftUI + MVVM 与现有 DesignSystem。
- Mock/API 模式切换。
- Login、CreateFamily、JoinFamily、JoinRequests、Home、ChoreSelection、FamilyDashboard、Profile。
- 底部四 Tab：今日战况、记一下、家庭战况、我的。
- 选择家庭身份、自定义身份和 `avatarKey` 头像占位。
- 实际耗时滚轮：1 到 180 分钟，步长 1 分钟。
- 每个 choreId 的上次确认耗时通过 UserDefaults 持久化。
- activity 点赞、取消点赞、点赞头像和按权限左滑删除。
- API loading、error 和仅 Debug 显示的 DebugPanel。

### 2.2 后端

- 开发登录与 Bearer token。
- 创建家庭；创建者为 `ACTIVE + OWNER`。
- 使用 `inviteCode` 申请加入；申请者为 `PENDING + MEMBER`。
- OWNER 查询、批准或拒绝加入申请。
- 核心免费家务和高级锁定家务目录。
- `actualMinutes` 校验、积分换算和记录持久化。
- activity 的 `day | recent` 查询。
- leaderboard 的 `day | month` 查询。
- 指定 `YYYY-MM` 的 monthly-report。
- 点赞、取消点赞、软删除和权限校验。
- 所有统计过滤 `deletedAt != null` 的记录。

## 3. 关键规则

### 身份与权限

- `identityLabel`/`customIdentity` 仅用于展示。
- `memberRole` 决定权限：`OWNER | MEMBER`。
- `status` 决定访问资格：`PENDING | ACTIVE | REJECTED`。
- 只有 ACTIVE 成员能读取家庭数据、记录家务和互动。

### 实际耗时与积分

- `actualMinutes` 范围为 1 到 180。
- 未传 `actualMinutes` 时使用家务标准时长。
- `points = round(defaultPoints * actualMinutes / standardMinutes)`。
- 标准时长为 0 时回退到默认积分，避免除零。

### 动态与删除

- `range=day`：按家庭 `timezone` 计算的本地今天内全部未删除记录。
- `range=recent`：最近 30 条未删除记录；不传 range 时默认 recent。
- 创建者可删除自己的记录；OWNER 可删除家庭内任意记录。
- 删除只写入 `deletedAt`、`deletedById`，不物理移除。
- 已删除记录不进入 activity、leaderboard 或 monthly-report。

### 图片凭证

- Prisma 和后端校验逻辑保留 `requirePhotoProof`、`imageUrls`。
- iOS MVP 不提供真实图片选择/上传，入口隐藏或禁用。
- iOS 创建家庭固定发送 `requirePhotoProof=false`。

## 4. 不在当前 MVP 范围

- 正式短信验证码、Apple 登录、微信登录。
- Keychain 完整凭证管理。
- 真实头像和图片凭证上传。
- StoreKit 订阅与服务端权益校验。
- 语音识别、自定义家务、常做任务、重复任务。
- 评论、通知、任务排班、积分兑换。
- OWNER 转让、多管理员和成员退出/移除策略。
- 复杂家庭时区选择 UI、生产监控和 App Store 正式发布。

## 5. 当前完成定义

当前 MVP 代码范围已经达到本地联调完成定义。下一阶段完成定义转为：自动化回归稳定、密钥与环境隔离、Keychain、签名归档和 TestFlight 可安装验证。
