# API Contract

更新时间：2026-09-03

本文仅记录当前 `backend/src` controller 中真实存在的本地 MVP 路由。

## 1. 通用约定

- 本地默认 Base URL：`http://127.0.0.1:3000`
- iOS Debug 模拟器默认使用 `localSimulator`；真机联调需切换为 `localNetwork` 并使用 Mac 局域网 IP；Release/Production 预留 HTTPS 地址。
- Content-Type：`application/json`
- 受保护接口：`Authorization: Bearer <accessToken>`
- `POST /auth/mock-login` 仅用于开发与自动化测试，正式构建不显示该入口。
- `GET /auth/config`、`GET /chores` 和 `GET /family-invitations/:inviteCode` 是公开接口，其余家庭、记录和报告接口受会话保护。
- 家庭身份字段为 `identityLabel`/`customIdentity`；权限字段为 `memberRole`。
- 成员只有在 `status=ACTIVE` 时才能访问家庭数据或互动。

## 2. 路由清单

| Method | Path | 鉴权 | 状态 |
| ---- | ---- | ---- | ---- |
| POST | `/auth/mock-login` | 否 | 已实现 |
| POST | `/auth/email/send-code` | 否 | 已实现，生产通过阿里云邮件推送发送 |
| POST | `/auth/email/verify-code` | 否 | 已实现，创建或复用 EMAIL 身份并签发会话 |
| GET | `/auth/config` | 否 | 已实现，返回发行区域与可用 Provider |
| GET | `/auth/me` | 是 | 已实现，恢复当前开发用户 |
| PATCH | `/auth/me` | 是 | 已实现，修改当前开发用户昵称 |
| DELETE | `/auth/me` | 是 | 已实现，永久注销账号并删除关联个人数据 |
| POST | `/auth/redeem-premium` | 是 | 已实现，仅开发测试兑换 |
| POST | `/families` | 是 | 已实现 |
| POST | `/families/claim-local-draft` | 是 | 已实现，幂等升级本机体验数据 |
| GET | `/families/me` | 是 | 已实现 |
| PATCH | `/families/:familyId` | 是，OWNER | 已实现，修改家庭名称 |
| GET | `/families/invitations/:inviteCode` | 是 | 已实现，加入前预览 |
| GET | `/family-invitations/:inviteCode` | 否 | 已实现，登录前公开预览 |
| GET | `/families/join-requests/me` | 是 | 已实现，恢复申请状态 |
| POST | `/families/join-requests` | 是 | 已实现，iOS 当前使用 |
| POST | `/families/:familyId/join-requests` | 是 | 已实现，旧调用兼容 |
| GET | `/families/:familyId/join-requests` | 是，OWNER | 已实现 |
| PATCH | `/families/:familyId/join-requests/:memberId` | 是，OWNER | 已实现 |
| PATCH | `/families/:familyId/owner` | 是，OWNER | 已实现，转让一家之主 |
| DELETE | `/families/:familyId/members/me` | 是，ACTIVE MEMBER | 已实现，退出当前家庭 |
| DELETE | `/families/:familyId` | 是，OWNER | 已实现，归档家庭并保留只读荣誉历史 |
| PATCH | `/families/:familyId/members/me/appearance` | 是，ACTIVE | 已实现，更新家庭形象 |
| GET | `/chores` | 否 | 已实现 |
| GET | `/families/:familyId/chore-layout` | 是，ACTIVE | 已实现，读取家庭常用家务布局 |
| PATCH | `/families/:familyId/chore-layout` | 是，OWNER | 已实现，保存选择、排序与置顶 |
| GET | `/families/:familyId/custom-chores` | 是，ACTIVE | 已实现 |
| POST | `/families/:familyId/custom-chores` | 是，ACTIVE | 已实现，免费基础 2 个并叠加成就奖励；高级版产品显示不限、服务端保护上限 100；免费版仅 OWNER 可管理 |
| PATCH | `/families/:familyId/custom-chores/:choreId` | 是，ACTIVE | 已实现 |
| DELETE | `/families/:familyId/custom-chores/:choreId` | 是，ACTIVE | 已实现，归档模板 |
| POST | `/chore-records` | 是 | 已实现 |
| PATCH | `/chore-records/:recordId` | 是 | 已实现，仅创建人可编辑 |
| GET | `/families/:familyId/activity` | 是 | 已实现 |
| GET | `/families/:familyId/members/:memberId/activity` | 是，ACTIVE | 已实现，指定成员近 30 天未删除动态 |
| GET | `/families/:familyId/leaderboard` | 是 | 已实现，支持 day/week/month |
| GET | `/families/:familyId/monthly-report` | 是 | 已实现 |
| DELETE | `/chore-records/:recordId` | 是 | 已实现 |
| POST | `/chore-records/:recordId/restore` | 是 | 已实现，仅删除操作者可在 10 秒内撤销 |
| POST | `/chore-records/:recordId/like` | 是 | 已实现、幂等 |
| DELETE | `/chore-records/:recordId/like` | 是 | 已实现、幂等 |
| GET | `/families/:familyId/achievement-sync/:eventId` | 是，ACTIVE | 已实现，查询异步事件状态 |
| GET | `/families/:familyId/achievements/summary` | 是，ACTIVE | 已实现，当前成员成长摘要与家庭容量 |
| GET | `/families/:familyId/achievements/me` | 是，ACTIVE | 已实现，当前成员成长轨道 |
| GET | `/families/:familyId/achievements/:definitionIdOrKey` | 是，ACTIVE | 已实现，当前成员单项详情 |
| PATCH | `/families/:familyId/achievements/visibility` | 是，ACTIVE | 已实现，统一设置自己的成就是否向家庭成员展示 |
| PATCH | `/families/:familyId/achievements/:memberAchievementId/visibility` | 是，ACTIVE | 兼容旧客户端，新版 iOS 不再使用 |
| GET | `/achievements/archive` | 是 | 已实现，读取个人、历史家庭参与和搭档成就档案 |
| GET | `/families/:familyId/achievement-events/failed` | 是，OWNER | 已实现，查看死信事件 |
| POST | `/families/:familyId/achievement-events/:eventId/replay` | 是，OWNER | 已实现，重放失败事件 |
| GET | `/families/:familyId/achievement-maintenance/health` | 是，OWNER | 已实现，查看积压、死信、DIRTY 和账本一致性 |
| POST | `/families/:familyId/achievement-maintenance/reconcile` | 是，OWNER | 已实现，重建脏进度并修复解锁/奖励账本 |

## 3. Auth

### GET `/auth/config`

返回服务端显式配置的发行区域和正式 Provider。国内为
`APPLE + WECHAT + EMAIL`，海外为 `APPLE + GOOGLE + EMAIL`；不根据 IP 推断。

### POST `/auth/mock-login`

请求至少提供一个字段：

```json
{
  "devIdentifier": "test-user-001",
  "displayName": "可选显示名",
  "deviceId": "设备稳定标识",
  "deviceName": "小狼的 iPhone",
  "platform": "iOS",
  "appVersion": "0.1.0"
}
```

- 提供 `devIdentifier` 时通过 `AuthIdentity(DEV)` 复用稳定测试账号；`DEV` 不属于正式版登录方式。
- 只提供 `displayName` 时每次创建一个新开发用户。
- 每次登录创建独立设备会话，返回 `user`、15 分钟 Access Token 和可轮换 Refresh Token。

```json
{
  "user": {
    "id": "user-id",
    "displayName": "开发用户",
    "plan": "free",
    "premiumRedeemedAt": null
  },
  "accessToken": "header.payload.signature",
  "refreshToken": "frt_random-secret",
  "accessTokenExpiresAt": "2026-09-02T08:15:00.000Z",
  "refreshTokenExpiresAt": "2026-10-02T08:00:00.000Z"
}
```

Access Token 使用 HS256 签名并绑定 `User.id + AuthSession.id`；生产环境缺少至少 32 字节的
`JWT_SECRET` 时后端拒绝启动。旧版两段式无过期 Token 不再兼容，升级后需要重新登录一次。
统一身份数据模型和绑定规则见 `docs/AUTH_IDENTITY.md`。正式 Provider 必须先完成服务端凭证验证，
再调用内部身份服务；当前没有允许客户端直接指定任意第三方身份标识的公共接口。

### POST `/auth/email/send-code`

```json
{ "email": "member@example.com" }
```

返回一次性 challenge。验证码有效期 10 分钟，同一邮箱 60 秒后才可重发；达到频控时返回 `429`。
`developmentCode` 只可能在非生产 LOG 模式出现，生产环境永远不返回验证码明文。

```json
{
  "challengeId": "uuid",
  "maskedEmail": "me***@example.com",
  "expiresInSeconds": 600,
  "resendAfterSeconds": 60
}
```

### POST `/auth/email/verify-code`

```json
{
  "email": "member@example.com",
  "challengeId": "uuid",
  "code": "123456",
  "displayName": "可选显示名",
  "deviceId": "设备稳定标识",
  "deviceName": "小狼的 iPhone",
  "platform": "iOS",
  "appVersion": "1.0.0"
}
```

验证码最多尝试 5 次且只能使用一次。成功后创建或复用 `AuthIdentity(EMAIL)`，返回格式与开发登录一致的
`user + accessToken + refreshToken`。邮箱比较不区分大小写。

### POST `/auth/refresh`

```json
{ "refreshToken": "frt_random-secret" }
```

- Refresh Token 采用 30 天滑动有效期，单次登录绝对上限 90 天。
- 每次成功刷新都返回新的 Access/Refresh Token，旧 Refresh Token 立即标记为已使用。
- 再次使用旧 Refresh Token 会撤销整个设备会话，后续新 Token 同样失效。
- 数据库只保存 Refresh Token 的 SHA-256 哈希，不保存原文。

### POST `/auth/logout`

需要 Bearer Token，只撤销当前设备会话。

### POST `/auth/logout-all`

需要 Bearer Token，撤销当前用户全部设备会话。

### GET `/auth/sessions`

列出当前用户仍有效的设备会话，包含设备名称、平台、App 版本、最后活跃时间和是否为当前设备，
不返回任何 Token 或完整 IP。

### GET `/auth/me`

使用 Bearer Token 返回当前用户。iOS 从 Keychain 恢复 Token 对并在 Access Token 剩余约 2 分钟时静默刷新，
随后调用此接口恢复稳定的 `User.id` 与展示资料，再继续恢复家庭或加入申请状态；401 仍作为刷新失败后的兜底处理。

### PATCH `/auth/me`

```json
{ "displayName": "新的昵称" }
```

- 修改当前开发用户昵称，前后空白会被移除。
- 空昵称返回 400。
- 这仍属于开发账号资料能力，不等于正式注册资料系统。

### POST `/auth/redeem-premium`

开发测试兑换接口：

```json
{ "code": "241255" }
```

- 需要 Bearer token，兑换记录归属当前开发账号。
- 默认测试码为 `241255`，可由后端环境变量 `TEST_PREMIUM_REDEMPTION_CODE` 覆盖。
- 成功后把 `User.plan` 更新为 `premium` 并写入 `premiumRedeemedAt`。
- 权益按家庭共享：一个家庭中只要存在任意 `ACTIVE + premium` 成员，该家庭全部 ACTIVE 成员都获得高级权益。PENDING、REJECTED 或已退出成员不参与共享判断。
- 错误兑换码返回 400。
- `NODE_ENV=production` 时接口返回 403，不能作为正式付费或生产兑换码系统。

## 4. Families

### POST `/families`

```json
{
  "name": "今日劳动观察站",
  "requirePhotoProof": false,
  "identityLabel": "男主人",
  "customIdentity": null,
  "avatarKey": "avatar_01",
  "timezone": "Asia/Shanghai"
}
```

- `name` 必填。
- `identityLabel` 当前 DTO 可选；未传时后端回退为“家庭成员”。iOS 创建流程会要求用户选择。
- `identityLabel=自定义` 时 `customIdentity` 必填。
- `requirePhotoProof` 未传时默认 `false`。
- `timezone` 可选；未传时默认 `Asia/Shanghai`。iOS API 模式创建家庭时会传 `TimeZone.current.identifier`。
- 创建者自动成为 `memberRole=OWNER`、`status=ACTIVE`。
- 返回家庭、`inviteCode`、成员数组、`myRole` 和 `myMembership`。

### GET `/families/me`

只返回当前用户 `ACTIVE` 的家庭。每个家庭包含：

- `id`、`name`、`inviteCode`、`requirePhotoProof`、`timezone`
- ACTIVE 成员数组 `members`
- 当前成员的 `identityLabel`、`customIdentity`、`avatarKey`
- `memberRole`、`status`、`myRole`、`myMembership`
- `hasPremiumAccess`：该家庭是否存在任意 ACTIVE 高级成员；iOS 以此决定家庭共享权益，不以当前账号自己的 `plan` 单独判断

### PATCH `/families/:familyId`

修改家庭基础资料。当前 MVP 只开放家庭名称：

```json
{ "name": "周末家务行动队" }
```

- 仅该家庭 `ACTIVE + OWNER` 可调用；普通 MEMBER 返回 403。
- `name` 必填，去除首尾空白后长度为 1...30。
- 返回更新后的家庭对象；iOS 成功后同步刷新 `currentFamily` 和个人页顶部身份卡。

### GET `/families/invitations/:inviteCode`

加入前校验邀请码并展示家庭摘要。`inviteCode` 会 trim 并转为大写；不存在时返回 404。

```json
{
  "id": "family-id",
  "name": "今日劳动观察站",
  "inviteCode": "A5F637F7",
  "memberCount": 4,
  "owner": {
    "id": "owner-user-id",
    "displayName": "用户 123456",
    "identityLabel": "女主人",
    "customIdentity": null,
    "avatarKey": "avatar_01"
  },
  "currentStatus": null
}
```

`currentStatus` 表示当前用户与该家庭已有的有效成员状态，可为 `PENDING`、`ACTIVE`、`REJECTED` 或 `null`。已经退出的 `LEFT` 对前端按 `null` 返回，允许用户重新申请。

### GET `/families/join-requests/me`

返回当前用户最新一条普通成员申请，用于 App 重启后恢复等待审核、审核通过或已拒绝页面；没有申请时返回 JSON `null`。响应包含申请成员字段、用户摘要和 `family` 邀请预览结构。

### POST `/families/join-requests`

当前 iOS 使用邀请码申请加入：

```json
{
  "inviteCode": "A5F637F7",
  "identityLabel": "室友",
  "customIdentity": null,
  "avatarKey": "avatar_02"
}
```

- inviteCode 会 trim 并转为大写后查询。
- 新申请创建为 `MEMBER + PENDING`。
- 同一用户对同一家庭重复提交时返回已有成员关系，不重复创建。
- 已被拒绝或已退出的成员再次提交时复用原成员关系，更新身份和头像，并重新置为 `PENDING`；不会因为昵称相同而新建或匹配成员。
- 邀请码不存在返回 404，消息为 `Invite code not found`。

### POST `/families/:familyId/join-requests`

旧客户端兼容接口。body 与邀请码接口相同，但不包含 `inviteCode`。新 UI 不应要求用户输入数据库 familyId。

### GET `/families/:familyId/join-requests`

仅该家庭 `ACTIVE + OWNER` 可访问，返回按创建时间升序排列的 PENDING 成员关系。

### PATCH `/families/:familyId/join-requests/:memberId`

```json
{ "action": "approve" }
```

`action` 仅允许 `approve | reject`：

- approve：更新为 `ACTIVE`，写入 `approvedAt`、`approvedById`。
- reject：更新为 `REJECTED`，写入 `approvedById`。
- 仅 ACTIVE OWNER 可操作；已审核申请再次操作返回 409。

### PATCH `/families/:familyId/owner`

当前一家之主将管理身份转让给同一家庭内另一位 ACTIVE 普通成员：

```json
{ "memberId": "target-family-member-id" }
```

- `memberId` 是 `GET /families/me` 返回的成员关系 ID，不是用户 ID。
- 仅当前 `ACTIVE + OWNER` 可操作。
- 目标必须是同一家庭内另一位 `ACTIVE + MEMBER`。
- 操作在数据库事务中完成：原家主变为 `MEMBER`，目标成员变为 `OWNER`。
- 返回 `previousOwner` 与 `newOwner` 的最新成员关系。

### PATCH `/families/:familyId/members/me/appearance`

更新当前 ACTIVE 成员在该家庭中的配套立绘与头像：

```json
{ "avatarKey": "avatar_13" }
```

### DELETE `/families/:familyId/members/me`

- 当前 `ACTIVE + MEMBER` 退出家庭，成功返回 `{ "familyId": "...", "left": true }`。
- OWNER 必须先把一家之主转让给另一位 ACTIVE 成员，否则返回 400。
- 退出后该成员不再参与家庭高级权益共享，也不能继续读取家庭数据。
- 后端保留原 FamilyMember 并标记 `status=LEFT`、写入 `leftAt`，不物理删除成员关系；重新申请时复用该关系并回到 `PENDING`。

- 当前支持 `avatar_01` 至 `avatar_13`。
- 同一序号映射一套资源：`family_avatar_action_XX` 为立绘，`avatar_XX` 为圆形头像。
- 后端只保存 `avatarKey`，iOS 根据该 key 自动选择对应立绘，不重复存储素材名称。
- 更新后家庭成员列表和 activity 会读取最新头像；历史记录昵称/身份仍使用记录快照，当前家庭成员头像则优先使用最新成员 avatarKey，成员关系不可用时回退到记录头像快照。

## 5. Chores

### GET `/chores`

返回 36 项免费系统家务。原扩展目录保留稳定 ID 以兼容历史记录，不再锁定或要求会员，并通过 `themeKey` 组织四个主题。统一字段：

```json
{
  "id": "chore-id",
  "name": "洗碗收桌",
  "themeKey": "daily",
  "category": "清洁",
  "minutes": 15,
  "points": 21,
  "difficultyMultiplier": 1.4,
  "icon": "fork.knife",
  "isCustom": false,
  "isCoreFree": true,
  "requiredPlan": "free",
  "isLocked": false
}
```

全部 36 项系统家务均返回 `requiredPlan=free`、`isLocked=false`。`themeKey` 取值为 `daily | love | childcare | pet`，iOS 按“日常家庭、恋爱陪伴、育儿、宠物”顺序展示。

### GET `/families/:familyId/chore-layout`

返回当前用户实际生效的常用家务配置。免费家庭读取家庭共享布局；家庭高级版优先读取当前 `FamilyMember` 的个人布局，尚未定制时回退到家庭共享布局。ACTIVE 成员可读取；未配置时返回空数组，`isConfigured=false`。

```json
{
  "choreIds": ["chore-1", "chore-2", "chore-3", "chore-4", "chore-5", "chore-6"],
  "pinnedChoreIds": ["chore-3"],
  "isConfigured": true,
  "scope": "family",
  "canEdit": true,
  "selectionLimit": 6,
  "customChoreLimit": 3,
  "capacity": {
    "common": { "base": 6, "earned": 1, "limit": 7 },
    "custom": { "base": 2, "earned": 1, "limit": 3 }
  },
  "isPersonalized": false
}
```

### PATCH `/families/:familyId/chore-layout`

`choreIds` 至少 1 项且不可重复，`pinnedChoreIds` 必须是其中的子集，数组顺序即展示顺序。

- 免费家庭：基础最多 6 项，再叠加永久 `COMMON_CHORE_SLOT` 成就奖励；仅 OWNER 可保存到 `Family`，所有 ACTIVE 成员读取同一布局。
- 家庭高级版：只要任意 ACTIVE 成员已开通，系统家务数量不限，所有 ACTIVE 成员都可保存到自己的 `FamilyMember` 布局，不覆盖其他成员。
- 高级成员尚未保存个人布局时，先读取家庭共享布局；保存后返回 `scope=member`、`isPersonalized=true`。
- 自定义家务使用独立的免费 `2 + CUSTOM_CHORE_SLOT` 奖励额度；高级版产品显示“不限”，服务端内部保护上限 100，不计入 `choreIds`。

### GET `/families/:familyId/custom-chores`

返回当前家庭未归档的自定义家务。仅 ACTIVE 成员可访问，按 `customSlot` 排序。

### POST `/families/:familyId/custom-chores`

```json
{
  "name": "擦餐桌",
  "iconKey": "chore_custom_dust",
  "category": "清洁",
  "standardMinutes": 15,
  "difficultyMultiplier": 1.2
}
```

- 免费家庭基础最多 2 个未归档自定义家务，并叠加永久成就槽位奖励；家庭高级版内部最多 100 个，超出返回 409。
- 免费版仅 OWNER 可创建、编辑或归档家庭共享自定义家务；家庭高级版的所有 ACTIVE 成员都可以管理。
- `name` 必填，最多 5 个字符；超过时返回 400。
- `category` 必填，只能为 `烹饪`、`清洁`、`洗护`、`整理`、`照顾`、`家庭事务` 之一。
- `standardMinutes` 范围 1...180。
- `difficultyMultiplier` 范围 0.5...2.0，最多 1 位小数。
- `iconKey` 只提供图标与常见频率建议，不再决定统计分类；用户可以独立选择统计大类。
- `points = round(standardMinutes * difficultyMultiplier)`，最少 1 分。

响应示例：

```json
{
  "id": "custom-chore-id",
  "name": "擦餐桌",
  "category": "清洁",
  "minutes": 15,
  "points": 18,
  "difficultyMultiplier": 1.2,
  "icon": "chore_custom_dust",
  "customSlot": 1,
  "suggestedFrequency": "每周",
  "isCoreFree": false,
  "isCustom": true,
  "requiredPlan": "free",
  "isLocked": false
}
```

### PATCH `/families/:familyId/custom-chores/:choreId`

请求字段与创建接口相同，均可选；修改默认时长或倍率后由后端重算默认积分。

### DELETE `/families/:familyId/custom-chores/:choreId`

归档模板并释放免费槽位，不物理删除模板，因此已经引用该模板的历史 ChoreRecord 继续保留。

## 6. Chore Records

### POST `/chore-records`

建议提供请求头：

```http
Idempotency-Key: <客户端生成的唯一请求 ID，1...128 字符>
```

```json
{
  "familyId": "family-id",
  "choreId": "chore-id",
  "actualMinutes": 20,
  "pointsMultiplier": 1.6,
  "note": "从 iOS 创建",
  "imageUrls": []
}
```

- 仅家庭 ACTIVE 成员可创建。
- `Idempotency-Key` 可选；提供后，同一家庭、同一用户使用相同 key 重试相同请求只创建一条记录。相同 key 用于不同请求返回 409。
- `actualMinutes` 可选，范围 1...180；不传时使用家务 `standardMinutes`。
- `pointsMultiplier` 可选，范围 0.5...2.0、最多一位小数，仅家庭高级版权益生效时允许传入。
- 不传倍率时：`points = round(defaultPoints * actualMinutes / standardMinutes)`。
- 高级版传入倍率时：`points = round(actualMinutes * pointsMultiplier)`。
- `standardMinutes <= 0` 时回退到 `defaultPoints`。
- 服务端忽略客户端自行计算的 points，使用服务端计算值。
- `occurredAt` 由服务端在记录创建成功时生成；客户端传入该字段会返回 400，V1 不允许补记。
- 所有系统家务均可直接记录；开发兑换码用于验证“常用家务不限数量、自定义家务产品显示不限（内部 100 项保护）、成员个人常用布局、记录时自定义积分倍率”四项高级权益。
- 返回完整 activity 记录结构，包括 `actualMinutes`、`points`、`occurredAt`、`likeCount`、`likedByMe` 和 `canDelete`。
- 创建时同时保存创建者昵称、家庭身份、自定义身份和头像 key 快照。昵称与身份作为历史快照保留；当前家庭成员换形象后，activity 优先展示其最新头像，无法关联当前成员时回退头像快照。
- 如果家庭开启 `requirePhotoProof`，`imageUrls` 至少需要一项。iOS MVP 固定创建家庭为 false，暂不开放上传。
- `ACHIEVEMENTS_ENABLED=true` 时，响应额外包含 `achievementEvaluation={eventId,state:"PENDING",retryAfterMs}`；记录保存不等待成就处理。开关关闭时不增加该字段。

### PATCH `/chore-records/:recordId`

仅记录创建人可编辑自己的家务记录，OWNER 也不能修改其他成员创建的记录。

```json
{
  "actualMinutes": 20,
  "pointsMultiplier": 1.5
}
```

- `actualMinutes` 必填，范围 1...180。
- `pointsMultiplier` 可选，范围 0.5...2.0，仅家庭高级版权益生效时允许传入；不传时按家务默认积分和标准时长重新计算。
- 返回更新后的 `actualMinutes`、`points`、`pointsMultiplier`、`canEdit`。
- 成就开关开启时产生 `CHORE_UPDATED` 事件并返回异步 `achievementEvaluation`；编辑可能触发新的成就弹窗。
- iOS 仅在 `canEdit=true` 时提供左滑编辑入口；保存成功后刷新周/最近 activity、leaderboard、monthly-report，并轮询本次成就评估。

## 7. Achievement System

阶段 1–7 的本地成就工程已经完成。默认仍关闭，用于灰度和保证旧主链路不受影响；启用方式：

```bash
ACHIEVEMENTS_ENABLED=true pnpm run start:dev
```

当前事务内事件来源包括：家务创建/删除/恢复、回应新增/变更/取消、成员激活/退出和家庭共享套餐变化。worker 使用数据库轮询和处理租约，默认最多重试 36 次并采用指数退避，单次间隔最多 1 小时，可持续补算约 24 小时；达到上限后事件保留为 `FAILED`，不会删除业务数据。

首批已结算规则：`FIRST_RECORD`、`ACTIVE_DAYS_3/5/7`、`STREAK_7/14`、`HABIT_30`。3/5/7 是累计家庭本地活跃日；7/14 是严格连续；`HABIT_30` 为最近 30 个家庭本地日中至少活跃 25 日。同一天多条记录只算一个活跃日。

### GET `/families/:familyId/achievement-sync/:eventId`

家庭 ACTIVE 成员可查询自己的家庭事件，返回：

```json
{
  "eventId": "event-id",
  "eventType": "CHORE_CREATED",
  "sourceType": "CHORE",
  "sourceId": "record-id",
  "sourceVersion": 1,
  "state": "PENDING",
  "retryCount": 0,
  "retryAfterMs": 800,
  "receivedAt": "2026-08-11T10:00:00.000Z",
  "processedAt": null,
  "lastErrorCode": null,
  "isDeadLetter": false,
  "unlockBatch": null
}
```

`state` 为 `PENDING | PROCESSING | SUCCEEDED | FAILED`。成功且本次有解锁时，`unlockBatch` 返回当前用户的个人解锁、全家共享解锁、与当前用户有关的搭档解锁和本次家庭奖励；技术错误不会改变原家务、回应或成员操作的成功结果。

### GET `/families/:familyId/achievements/summary`

返回当前成员的已解锁数量、下一项成长目标、最近 3 项解锁和家庭当前容量。进行中进度只返回给本人。

### GET `/families/:familyId/achievements/me`

返回当前家庭中可达的成长、专长和家庭羁绊成就。字段包括 `definitionId`、`key`、本地化 key、`ownerType`、`targetValue`、`currentValue`、`rawCurrentValue`、`isUnlocked`、`unlockedAt`、`visibility` 和可选 `reward`。

- `ownerType=MEMBER`：当前成员自己的成长、专长或互动进度，可通过 `memberAchievementId` 修改已解锁项可见性。
- `ownerType=FAMILY`：家庭共享进度，解锁后返回 `familyAchievementId`、`participantUserIds` 和 `participantNames`。
- `ownerType=PAIR`：只聚合与当前成员有关的搭档结果，解锁后返回 `pairAchievementId` 和两位参与者；成员组合由服务端排序归一化。
- 只有 1 位 ACTIVE 成员时，不返回阶段六的回应他人、家庭协作和搭档锁卡。
- 家庭协作详情只提供共同叙事和参与者，不提供贡献百分比或成员差距。
- 家庭长期里程碑包含活跃 30/100/365 日、记录 100/500/1000 条和周年；家庭参与者会返回 `participantRoles`，退出成员标记为 `FORMER`。
- 5 个隐藏彩蛋在当前用户解锁前完全不返回；解锁后以 `PRIVATE` 可见性返回，不暴露其他成员的发现状态。
- 搭档成果返回 `archiveStatus=ACTIVE|HISTORICAL`，成员退出时进入历史态，重新加入同一家庭后恢复活动态。

### GET `/families/:familyId/achievements/:definitionIdOrKey`

使用 definition id 或稳定 key 查询当前成员单项详情。

### PATCH `/families/:familyId/achievements/visibility`

请求 `{ "showToFamily": true }` 或 `{ "showToFamily": false }`。这是当前产品使用的总开关：

- 开启时，当前用户在该家庭中已经解锁和以后新解锁的个人成就统一向家庭成员展示。
- 关闭时，成就仍正常累计、解锁并可由本人查看，但统一设为仅自己可见。
- 设置保存在当前用户的家庭成员关系中，不影响其他家庭成员。

`GET /families/:familyId/achievements/summary` 和 `GET /families/:familyId/achievements/me` 均返回 `showAchievementsToFamily`。

### PATCH `/families/:familyId/achievements/:memberAchievementId/visibility`（兼容）

旧客户端可以请求 `{ "visibility": "FAMILY" }` 或 `{ "visibility": "PRIVATE" }`。新版 iOS 不再展示逐个成就开关，也不再调用此接口。

### iOS 成就同步与展示约定

- Home 和成就页均展示最多 3 个即将完成目标，使用横向分页滑动；Profile 保留成就中心入口，不增加第五个 Tab。
- 成就页使用统一网格：已解锁在前，未解锁在后；有永久奖励的未解锁项排在未解锁区最前。点击任意成就查看名称、条件、进度、奖励和解锁日期。
- 成就隐私只提供一个成员级 `showAchievementsToFamily` 总开关，放在成就页右上角；不展示逐项可见性开关。
- API 模式只使用服务端 summary、me、visibility 和 achievement-sync 结果，不在客户端自行解锁或发放奖励。
- `achievementEvaluation.state=PENDING` 不影响家务记录成功；客户端后台轮询 sync，同批次多项解锁在页面中央合并展示，并可横向滑动查看。
- 最近一次成功的 summary/me 按当前用户和家庭隔离缓存；离线时可读缓存并显示更新时间，401 仍按统一会话规则清理。
- Mock 模式使用固定本地成就数据，不调用上述网络接口。
- iOS 当前接入 27 枚正式 Asset Catalog 成就资源；尚未拥有独立图稿的关联成就复用同主题资源。此为客户端视觉映射，不改变服务端 definition key。

### GET `/families/:familyId/achievement-events/failed`

仅 OWNER 可访问，返回该家庭达到最大重试次数的 `FAILED` 事件，最多 100 条。

### POST `/families/:familyId/achievement-events/:eventId/replay`

仅 OWNER 可重放 `FAILED` 事件。重放会将事件恢复为 `PENDING`、清零重试次数并写入审计日志；`SUCCEEDED/PENDING/PROCESSING` 事件返回 409。

### GET `/families/:familyId/achievement-maintenance/health`

仅 OWNER 可访问。返回事件状态、死信、最老积压、DIRTY/REBUILDING 数量、解锁批次计数差异、奖励账本缺失、近 7 天记录/解锁和 worker 处理量、失败率、队列延迟、P50/P95/P99 耗时。

### POST `/families/:familyId/achievement-maintenance/reconcile`

仅 OWNER 可执行。对 DIRTY/REBUILDING 进度重放相关事件，修复 `unlockCount/primaryUnlockId` 和缺失的永久奖励账本；操作幂等并写入审计日志。

### GET `/achievements/archive`

返回当前账号跨家庭保留的个人荣誉、家庭参与和与本人有关的搭档成果。退出家庭后个人荣誉不删除，参与者角色为 `FORMER`，搭档结果为 `HISTORICAL`；重新加入不会创建重复个人解锁。

### DELETE `/families/:familyId`

仅 OWNER 可归档家庭。家庭成员转为 `LEFT`，家庭不再出现在 `/families/me`，历史家务和家庭荣誉保留供档案读取。

### DELETE `/auth/me`

永久注销当前账号，成功返回：

```json
{
  "deleted": true,
  "deletedAt": "2026-08-14T11:00:00.000Z"
}
```

处理规则：

- 删除用户资料、全部 `AuthIdentity`、成员关系、用户创建的家务记录、点赞、个人成就和搭档成就。
- 多成员家庭中，若注销者是 OWNER，先自动转让给最早加入的 ACTIVE MEMBER。
- 单人成立且没有可转让成员的家庭随账号永久删除。
- 仍被其他成员历史记录引用的自定义家务会清除作者信息、替换为中性名称并归档，避免破坏其他成员数据的引用完整性。
- 旧 Bearer token 随后返回 401。
- 接口必须在线执行；离线状态不能排队注销。
- 当前会统一删除身份和会话；接入 Apple、微信、Google 后，还需按提供方要求补充 token 撤销或解绑调用。

### 成就灰度环境变量

- `ACHIEVEMENTS_ENABLED=true`：启用全局成就事件写入。
- `ACHIEVEMENT_FAMILY_ALLOWLIST=family-id-1,family-id-2`：可选家庭白名单；设置后只有名单中的家庭产生新成就事件。
- 关闭开关或不在白名单中只停止新评估，不影响历史成就和档案读取。

## 8. Activity and Record Interactions

### GET `/families/:familyId/activity?range=day|week|recent`

- 不传 `range` 时默认 `recent`。
- `day`：按当前家庭 `timezone` 计算出的本地今天内全部未删除记录。
- `week`：按当前家庭 `timezone` 计算本周周一 00:00 至下周一 00:00 的全部未删除记录；iOS“本周战况”使用此范围。
- `recent`：最近 30 条未删除记录。
- 仅家庭 ACTIVE 成员可访问。
- iOS 本周动态把 `createdAt` 转换到家庭 timezone 后显示为“周几 HH:mm”；不改变 API 时间戳的 ISO 8601/UTC 传输格式。
- iOS 家庭与个人本周二级分析由当前选中周的 `week` activity 和 `week` leaderboard 本地组合，不需要新增分析接口。

### GET `/families/:familyId/members/:memberId/activity`

- `memberId` 为 FamilyMember 关系 ID，不是 userId。
- 调用者必须是该家庭 ACTIVE 成员，目标成员也必须属于同一家庭。
- 返回目标成员从当前时间向前滚动 30 天内的未删除记录，按 `createdAt` 倒序。
- 响应包含 `member`、`rangeStart`、`rangeEnd`、`totalPoints`、`totalRecords`、`totalMinutes` 和 `records`。
- iOS 成员详情使用该接口；若当前用户为 OWNER 且目标为另一位 ACTIVE MEMBER，页面同时提供家主转让操作。

### GET `/families/:familyId/leaderboard?range=day|week|month`

- `day`：家庭时区内的当天排行。
- `week`：家庭时区内周一至下周一的本周排行；iOS 首页“家庭第几名”使用此范围。
- `month`：家庭时区内当前月份排行；不传时默认 `month`。
- 所有范围均排除已软删除记录。

记录结构核心字段：

```json
{
  "id": "record-id",
  "recordId": "record-id",
  "familyId": "family-id",
  "createdBy": {
    "id": "user-id",
    "displayName": "用户654321",
    "identityLabel": "室友",
    "customIdentity": null,
    "avatarKey": "avatar_02"
  },
  "chore": {
    "id": "chore-id",
    "name": "洗碗收桌",
    "category": "清洁",
    "icon": "fork.knife"
  },
  "choreName": "洗碗收桌",
  "minutes": 15,
  "actualMinutes": 20,
  "points": 28,
  "likeCount": 1,
  "likedBy": [
    {
      "id": "liker-id",
      "displayName": "用户123456",
      "identityLabel": "男主人",
      "customIdentity": null,
      "avatarKey": "avatar_01",
      "reactionKey": "high_five"
    }
  ],
  "likedByMe": false,
  "myReaction": null,
  "reactionCounts": {
    "like": 0,
    "high_five": 1,
    "moon_face": 0,
    "laugh_cry": 0,
    "tease": 0
  },
  "canDelete": true,
  "canEdit": true,
  "createdAt": "2026-06-21T08:00:00.000Z"
}
```

### DELETE `/chore-records/:recordId`

- 记录创建者可删除自己的记录。
- 家庭 ACTIVE OWNER 可删除家庭内任意成员记录。
- 其他 MEMBER 删除他人记录返回 403。
- 采用软删除，写入 `deletedAt`、`deletedById`。
- 响应增加 `undoExpiresAt`，固定为 `deletedAt + 10 秒`。

### POST `/chore-records/:recordId/restore`

- 仅本次删除操作的执行者可以撤销；其他成员即使是记录创建者也不能替代删除者撤销。
- 仅在服务端计算的 10 秒窗口内有效，成功返回 `{ "recordId": "...", "restored": true }`。
- 成功后清空 `deletedAt` 和 `deletedById`，原记录、积分、`occurredAt` 和历史内容保持不变。
- 超过 10 秒返回 409；记录不存在或并非已删除状态返回 404。
- 不提供回收站、删除列表或超时后的用户恢复能力。
- 当前阶段只完成后端接口；iOS 的 10 秒“撤销”提示将在客户端成就基础体验阶段接入。

返回：

```json
{
  "recordId": "record-id",
  "id": "record-id",
  "deletedAt": "2026-06-21T08:30:00.000Z",
  "deletedById": "user-id"
}
```

### POST `/chore-records/:recordId/like`

回应接口保持原点赞路由兼容。请求体可省略，省略时使用默认点赞：

```json
{
  "reactionKey": "high_five"
}
```

支持 `like`、`high_five`、`moon_face`、`laugh_cry`、`tease`。同一用户对同一记录只有一条回应；再次 POST 会更新回应类型而不增加总数，因此请求幂等。

### DELETE `/chore-records/:recordId/like`

取消回应接口幂等。存在时删除，不存在时仍返回成功。

两个接口都返回：

```json
{
  "recordId": "record-id",
  "likeCount": 1,
  "likedByMe": true,
  "myReaction": "high_five",
  "reactionCounts": {
    "like": 0,
    "high_five": 1,
    "moon_face": 0,
    "laugh_cry": 0,
    "tease": 0
  }
}
```

`likeCount` 为全部回应总数，字段名为兼容现有客户端保留。Activity 的 `likedBy` 成员会附带自己的 `reactionKey`。

只能操作未删除记录，且调用者必须是记录所属家庭的 ACTIVE 成员。

## 9. Statistics

### GET `/families/:familyId/leaderboard?range=day|week|month`

- range 可选，默认 `month`。
- 按记录快照中的 `points` 聚合。
- 返回 `rank`、`userId`、`displayName`、`points`、`recordCount`。

### GET `/families/:familyId/monthly-report?month=YYYY-MM`

- `month` 必填并通过 `YYYY-MM` 格式校验。
- 月份范围按当前家庭 `timezone` 计算，例如 `2026-06` 表示家庭本地 6 月。
- 返回 `totalPoints`、`totalRecords`、`totalMinutes`、`headline`、`leaderboard`、`themeStats`、`categoryStats`、`recentRecords`。
- `themeStats` 按家务的 `themeKey` 聚合整月积分和记录次数，当前主题为 `daily`、`love`、`childcare`、`pet`。
- `categoryStats` 按家务大类聚合整月积分和记录次数。
- recentRecords 包含标准 `minutes` 和 `actualMinutes`。

activity、leaderboard、monthly-report 均过滤 `deletedAt IS NOT NULL` 的记录，因此已软删除记录不会进入日/周统计、最近动态、排行或月报。

## 10. 当前暂缓契约

- Apple、微信、邮箱验证码和 Google 的真实认证接口尚未接入；身份模型、区域配置与客户端入口已经预留。
- 图片上传接口尚不存在。
- StoreKit 购买、收据校验和正式订阅接口尚不存在；当前仅有生产环境禁用的开发测试兑换接口。
- 暂无复杂家庭时区选择 UI；iOS 创建家庭先默认发送系统时区。
