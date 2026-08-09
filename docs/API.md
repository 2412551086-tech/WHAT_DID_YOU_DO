# API Contract

更新时间：2026-08-05

本文仅记录当前 `backend/src` controller 中真实存在的本地 MVP 路由。

## 1. 通用约定

- 本地默认 Base URL：`http://127.0.0.1:3000`
- iOS Debug 模拟器默认使用 `localSimulator`；真机联调需切换为 `localNetwork` 并使用 Mac 局域网 IP；Release/Production 预留 HTTPS 地址。
- Content-Type：`application/json`
- 受保护接口：`Authorization: Bearer <accessToken>`
- `POST /auth/mock-login` 是开发登录，不发送或验证短信验证码。
- `GET /chores` 当前为公开接口，其余家庭、记录和报告接口均受 `DevAuthGuard` 保护。
- 家庭身份字段为 `identityLabel`/`customIdentity`；权限字段为 `memberRole`。
- 成员只有在 `status=ACTIVE` 时才能访问家庭数据或互动。

## 2. 路由清单

| Method | Path | 鉴权 | 状态 |
| ---- | ---- | ---- | ---- |
| POST | `/auth/mock-login` | 否 | 已实现 |
| GET | `/auth/me` | 是 | 已实现，恢复当前开发用户 |
| PATCH | `/auth/me` | 是 | 已实现，修改当前开发用户昵称 |
| POST | `/auth/redeem-premium` | 是 | 已实现，仅开发测试兑换 |
| POST | `/families` | 是 | 已实现 |
| GET | `/families/me` | 是 | 已实现 |
| PATCH | `/families/:familyId` | 是，OWNER | 已实现，修改家庭名称 |
| GET | `/families/invitations/:inviteCode` | 是 | 已实现，加入前预览 |
| GET | `/families/join-requests/me` | 是 | 已实现，恢复申请状态 |
| POST | `/families/join-requests` | 是 | 已实现，iOS 当前使用 |
| POST | `/families/:familyId/join-requests` | 是 | 已实现，旧调用兼容 |
| GET | `/families/:familyId/join-requests` | 是，OWNER | 已实现 |
| PATCH | `/families/:familyId/join-requests/:memberId` | 是，OWNER | 已实现 |
| PATCH | `/families/:familyId/owner` | 是，OWNER | 已实现，转让一家之主 |
| DELETE | `/families/:familyId/members/me` | 是，ACTIVE MEMBER | 已实现，退出当前家庭 |
| PATCH | `/families/:familyId/members/me/appearance` | 是，ACTIVE | 已实现，更新家庭形象 |
| GET | `/chores` | 否 | 已实现 |
| GET | `/families/:familyId/chore-layout` | 是，ACTIVE | 已实现，读取家庭常用家务布局 |
| PATCH | `/families/:familyId/chore-layout` | 是，OWNER | 已实现，保存选择、排序与置顶 |
| GET | `/families/:familyId/custom-chores` | 是，ACTIVE | 已实现 |
| POST | `/families/:familyId/custom-chores` | 是，ACTIVE | 已实现，免费最多 2 个、高级测试账号最多 10 个有效模板；免费版仅 OWNER 可管理 |
| PATCH | `/families/:familyId/custom-chores/:choreId` | 是，ACTIVE | 已实现 |
| DELETE | `/families/:familyId/custom-chores/:choreId` | 是，ACTIVE | 已实现，归档模板 |
| POST | `/chore-records` | 是 | 已实现 |
| GET | `/families/:familyId/activity` | 是 | 已实现 |
| GET | `/families/:familyId/members/:memberId/activity` | 是，ACTIVE | 已实现，指定成员近 30 天未删除动态 |
| GET | `/families/:familyId/leaderboard` | 是 | 已实现，支持 day/week/month |
| GET | `/families/:familyId/monthly-report` | 是 | 已实现 |
| DELETE | `/chore-records/:recordId` | 是 | 已实现 |
| POST | `/chore-records/:recordId/like` | 是 | 已实现、幂等 |
| DELETE | `/chore-records/:recordId/like` | 是 | 已实现、幂等 |

## 3. Auth

### POST `/auth/mock-login`

请求至少提供一个字段：

```json
{
  "phoneNumber": "123456",
  "displayName": "可选显示名"
}
```

- 提供手机号时按 `phoneNumber` upsert，同一手机号返回同一开发用户。
- 只提供 `displayName` 时每次创建一个新开发用户。
- 返回 `user` 和开发 Bearer `accessToken`。

```json
{
  "user": {
    "id": "user-id",
    "phoneNumber": "123456",
    "displayName": "用户123456",
    "plan": "free",
    "premiumRedeemedAt": null
  },
  "accessToken": "payload.signature"
}
```

该 token 是本地 HMAC 开发实现，不是生产 JWT/短信认证方案。

### GET `/auth/me`

使用 Bearer token 返回当前开发用户。iOS 从 Keychain 恢复 token 后先调用此接口恢复昵称和手机号，再继续恢复家庭或加入申请状态。

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
- 更新后家庭成员列表和 activity 会读取最新头像。

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
  "customChoreLimit": 2,
  "isPersonalized": false
}
```

### PATCH `/families/:familyId/chore-layout`

`choreIds` 至少 1 项且不可重复，`pinnedChoreIds` 必须是其中的子集，数组顺序即展示顺序。

- 免费家庭：最多 6 项，仅 OWNER 可保存到 `Family`，所有 ACTIVE 成员读取同一布局。
- 家庭高级版：只要任意 ACTIVE 成员已开通，系统家务数量不限，所有 ACTIVE 成员都可保存到自己的 `FamilyMember` 布局，不覆盖其他成员。
- 高级成员尚未保存个人布局时，先读取家庭共享布局；保存后返回 `scope=member`、`isPersonalized=true`。
- 自定义家务使用独立的免费 2 / 高级 10 项额度，不计入 `choreIds`。

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

- 免费家庭最多 2 个未归档自定义家务；家庭高级版最多 10 个，超出返回 409。
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
- `actualMinutes` 可选，范围 1...180；不传时使用家务 `standardMinutes`。
- `pointsMultiplier` 可选，范围 0.5...2.0、最多一位小数，仅家庭高级版权益生效时允许传入。
- 不传倍率时：`points = round(defaultPoints * actualMinutes / standardMinutes)`。
- 高级版传入倍率时：`points = round(actualMinutes * pointsMultiplier)`。
- `standardMinutes <= 0` 时回退到 `defaultPoints`。
- 服务端忽略客户端自行计算的 points，使用服务端计算值。
- 所有系统家务均可直接记录；开发兑换码用于验证“常用家务不限数量、10 项自定义家务、成员个人常用布局、记录时自定义积分倍率”四项高级权益。
- 返回完整 activity 记录结构，包括 `actualMinutes`、`points`、`likeCount`、`likedByMe` 和 `canDelete`。
- 创建时同时保存创建者昵称、家庭身份、自定义身份和头像 key 快照。后续改名、换形象、退出或重新加入不会改写历史动态的创建者展示。
- 如果家庭开启 `requirePhotoProof`，`imageUrls` 至少需要一项。iOS MVP 固定创建家庭为 false，暂不开放上传。

### GET `/families/:familyId/activity?range=day|week|recent`

- 不传 `range` 时默认 `recent`。
- `day`：按当前家庭 `timezone` 计算出的本地今天内全部未删除记录。
- `week`：按当前家庭 `timezone` 计算本周周一 00:00 至下周一 00:00 的全部未删除记录；iOS“本周战况”使用此范围。
- `recent`：最近 30 条未删除记录。
- 仅家庭 ACTIVE 成员可访问。

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
  "createdAt": "2026-06-21T08:00:00.000Z"
}
```

### DELETE `/chore-records/:recordId`

- 记录创建者可删除自己的记录。
- 家庭 ACTIVE OWNER 可删除家庭内任意成员记录。
- 其他 MEMBER 删除他人记录返回 403。
- 采用软删除，写入 `deletedAt`、`deletedById`。

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

## 7. Statistics

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

## 8. 当前暂缓契约

- 正式短信验证码、Apple、微信认证接口尚不存在。
- 图片上传接口尚不存在。
- StoreKit 购买、收据校验和正式订阅接口尚不存在；当前仅有生产环境禁用的开发测试兑换接口。
- 暂无复杂家庭时区选择 UI；iOS 创建家庭先默认发送系统时区。
