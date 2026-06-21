# API Contract

更新时间：2026-06-21

本文仅记录当前 `backend/src` controller 中真实存在的本地 MVP 路由。

## 1. 通用约定

- Base URL：`http://127.0.0.1:3000`
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
| POST | `/families` | 是 | 已实现 |
| GET | `/families/me` | 是 | 已实现 |
| POST | `/families/join-requests` | 是 | 已实现，iOS 当前使用 |
| POST | `/families/:familyId/join-requests` | 是 | 已实现，旧调用兼容 |
| GET | `/families/:familyId/join-requests` | 是，OWNER | 已实现 |
| PATCH | `/families/:familyId/join-requests/:memberId` | 是，OWNER | 已实现 |
| GET | `/chores` | 否 | 已实现 |
| POST | `/chore-records` | 是 | 已实现 |
| GET | `/families/:familyId/activity` | 是 | 已实现 |
| GET | `/families/:familyId/leaderboard` | 是 | 已实现 |
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
    "displayName": "用户123456"
  },
  "accessToken": "payload.signature"
}
```

该 token 是本地 HMAC 开发实现，不是生产 JWT/短信认证方案。

## 4. Families

### POST `/families`

```json
{
  "name": "今日劳动观察站",
  "requirePhotoProof": false,
  "identityLabel": "男主人",
  "customIdentity": null,
  "avatarKey": "avatar_01"
}
```

- `name` 必填。
- `identityLabel` 当前 DTO 可选；未传时后端回退为“家庭成员”。iOS 创建流程会要求用户选择。
- `identityLabel=自定义` 时 `customIdentity` 必填。
- `requirePhotoProof` 未传时默认 `false`。
- 创建者自动成为 `memberRole=OWNER`、`status=ACTIVE`。
- 返回家庭、`inviteCode`、成员数组、`myRole` 和 `myMembership`。

### GET `/families/me`

只返回当前用户 `ACTIVE` 的家庭。每个家庭包含：

- `id`、`name`、`inviteCode`、`requirePhotoProof`
- ACTIVE 成员数组 `members`
- 当前成员的 `identityLabel`、`customIdentity`、`avatarKey`
- `memberRole`、`status`、`myRole`、`myMembership`

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

## 5. Chores

### GET `/chores`

返回核心 10 项免费家务和 10 项高级锁定家务。统一字段：

```json
{
  "id": "chore-id",
  "name": "饭后收拾 / 洗碗",
  "category": "厨房类",
  "minutes": 15,
  "points": 21,
  "isCoreFree": true,
  "requiredPlan": "free",
  "isLocked": false
}
```

高级项为 `requiredPlan=premium`、`isLocked=true`。当前未接购买或权益校验。

## 6. Chore Records

### POST `/chore-records`

```json
{
  "familyId": "family-id",
  "choreId": "chore-id",
  "actualMinutes": 20,
  "note": "从 iOS 创建",
  "imageUrls": []
}
```

- 仅家庭 ACTIVE 成员可创建。
- `actualMinutes` 可选，范围 1...180；不传时使用家务 `standardMinutes`。
- `points = round(defaultPoints * actualMinutes / standardMinutes)`。
- `standardMinutes <= 0` 时回退到 `defaultPoints`。
- 服务端忽略客户端自行计算的 points，使用服务端计算值。
- 返回完整 activity 记录结构，包括 `actualMinutes`、`points`、`likeCount`、`likedByMe` 和 `canDelete`。
- 如果家庭开启 `requirePhotoProof`，`imageUrls` 至少需要一项。iOS MVP 固定创建家庭为 false，暂不开放上传。

### GET `/families/:familyId/activity?range=day|recent`

- 不传 `range` 时默认 `recent`。
- `day`：当前 UTC 自然日内全部未删除记录。
- `recent`：最近 30 条未删除记录。
- 仅家庭 ACTIVE 成员可访问。

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
    "name": "饭后收拾 / 洗碗",
    "category": "厨房类",
    "icon": "fork.knife"
  },
  "choreName": "饭后收拾 / 洗碗",
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
      "avatarKey": "avatar_01"
    }
  ],
  "likedByMe": false,
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

点赞接口幂等。未点赞时创建，已点赞时保持现状并返回成功。

### DELETE `/chore-records/:recordId/like`

取消点赞接口幂等。存在时删除，不存在时仍返回成功。

两个接口都返回：

```json
{
  "recordId": "record-id",
  "likeCount": 1,
  "likedByMe": true
}
```

只能操作未删除记录，且调用者必须是记录所属家庭的 ACTIVE 成员。

## 7. Statistics

### GET `/families/:familyId/leaderboard?range=day|month`

- range 可选，默认 `month`。
- 按记录快照中的 `points` 聚合。
- 返回 `rank`、`userId`、`displayName`、`points`、`recordCount`。

### GET `/families/:familyId/monthly-report?month=YYYY-MM`

- `month` 必填并通过 `YYYY-MM` 格式校验。
- 返回 `totalPoints`、`totalRecords`、`headline`、`leaderboard`、`categoryStats`、`recentRecords`。
- recentRecords 包含标准 `minutes` 和 `actualMinutes`。

activity、leaderboard、monthly-report 均过滤 `deletedAt IS NOT NULL` 的记录，因此已软删除记录不会进入今日统计、排行或月报。

## 8. 当前暂缓契约

- 正式短信验证码、Apple、微信认证接口尚不存在。
- 图片上传接口尚不存在。
- 订阅购买和权益校验接口尚不存在。
- 家庭时区字段尚不存在；`activity?range=day` 当前按 UTC 自然日。
