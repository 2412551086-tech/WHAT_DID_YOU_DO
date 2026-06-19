# API Contract

本文记录《你今天干啥啦》MVP API 契约。除“当前已实现”明确标记的接口外，家庭成员身份、加入审核、记录删除与点赞接口均为下一阶段待实现设计。

## 1. 基础约定

- 本地 Base URL：`http://127.0.0.1:3000`
- 鉴权：`Authorization: Bearer <accessToken>`
- JSON 字段使用 lower camel case。
- 家庭数据必须按当前用户的家庭成员关系隔离。
- 只有 `memberStatus = ACTIVE` 的成员可以读取家庭数据或创建互动数据。
- `familyIdentity` 只用于展示；权限只由 `memberRole` 决定。

## 2. 枚举与字段

### 2.1 memberRole

| 值 | 说明 |
| ---- | ---- |
| `OWNER` | 一家之主，家庭创建人 |
| `MEMBER` | 普通家庭成员 |

### 2.2 memberStatus

| 值 | 说明 |
| ---- | ---- |
| `PENDING` | 等待 OWNER 审核 |
| `ACTIVE` | 已加入，可访问家庭数据 |
| `REJECTED` | 已拒绝，不可访问家庭数据 |

### 2.3 familyIdentity

预设值：男主人、女主人、老公、老婆、老妈、老爸、儿子、女儿、哥哥、姐姐、弟弟、妹妹、爷爷、奶奶、室友、自定义。

选择自定义时必须同时提交非空 `customIdentity`。

### 2.4 avatarKey

MVP 使用字符串标识本地头像资源，例如 `avatar_default_01`。后端只保存 key，不接收真实图片文件。

## 3. 当前已实现接口

以下接口已支持当前 iOS 主链路：

- `POST /auth/mock-login`
- `POST /families`
- `GET /families/me`
- `GET /chores`
- `POST /chore-records`
- `GET /families/:familyId/activity`
- `GET /families/:familyId/leaderboard?range=day|month`
- `GET /families/:familyId/monthly-report?month=YYYY-MM`

### 3.1 Mock 登录

`POST /auth/mock-login`

```json
{
  "displayName": "iOS联调用户"
}
```

返回 `user` 与 `accessToken`。

### 3.2 创建家务记录

`POST /chore-records`

```json
{
  "familyId": "family-id",
  "choreId": "chore-id",
  "actualMinutes": 20,
  "note": "从 iOS 创建",
  "imageUrls": []
}
```

规则：

1. `actualMinutes` 可选，范围 1 到 180。
2. 未传时使用家务标准时长。
3. `points = round(defaultPoints * actualMinutes / standardMinutes)`。
4. 返回记录中的 `actualMinutes` 与最终 `points`。

## 4. 家庭身份扩展

### 4.1 创建家庭

扩展现有 `POST /families`。

```json
{
  "name": "周末厨房保卫处",
  "requirePhotoProof": false,
  "familyIdentity": "老妈",
  "customIdentity": null,
  "avatarKey": "avatar_default_01"
}
```

服务端行为：

1. 创建家庭。
2. 创建人的成员关系自动为 `memberRole = OWNER`。
3. 成员状态自动为 `memberStatus = ACTIVE`。
4. 保存 `familyIdentity`、`customIdentity` 与 `avatarKey`。

返回建议：

```json
{
  "id": "family-id",
  "name": "周末厨房保卫处",
  "inviteCode": "ABC123",
  "requirePhotoProof": false,
  "myMembership": {
    "id": "membership-id",
    "memberRole": "OWNER",
    "memberStatus": "ACTIVE",
    "familyIdentity": "老妈",
    "customIdentity": null,
    "avatarKey": "avatar_default_01"
  }
}
```

### 4.2 获取我的家庭

扩展现有 `GET /families/me`，每个家庭返回当前用户的成员信息：

```json
{
  "id": "family-id",
  "name": "周末厨房保卫处",
  "myMembership": {
    "memberRole": "OWNER",
    "memberStatus": "ACTIVE",
    "familyIdentity": "老妈",
    "customIdentity": null,
    "avatarKey": "avatar_default_01"
  }
}
```

## 5. 加入审核接口

### 5.1 提交加入申请

`POST /families/join-requests`

```json
{
  "inviteCode": "ABC123",
  "familyIdentity": "自定义",
  "customIdentity": "铲屎官",
  "avatarKey": "avatar_default_04"
}
```

返回：

```json
{
  "id": "join-request-id",
  "familyId": "family-id",
  "memberRole": "MEMBER",
  "memberStatus": "PENDING",
  "familyIdentity": "自定义",
  "customIdentity": "铲屎官",
  "avatarKey": "avatar_default_04"
}
```

### 5.2 查看待审核申请

`GET /families/:familyId/join-requests?status=PENDING`

权限：仅该家庭 `ACTIVE + OWNER`。

### 5.3 批准申请

`PATCH /families/:familyId/join-requests/:requestId/approve`

权限：仅该家庭 `ACTIVE + OWNER`。成功后申请人成为 `ACTIVE + MEMBER`。

### 5.4 拒绝申请

`PATCH /families/:familyId/join-requests/:requestId/reject`

权限：仅该家庭 `ACTIVE + OWNER`。成功后状态变为 `REJECTED`。

### 5.5 审核错误建议

| 场景 | HTTP | code |
| ---- | ---- | ---- |
| 当前用户不是 ACTIVE 成员 | 403 | `MEMBERSHIP_NOT_ACTIVE` |
| 当前用户不是 OWNER | 403 | `OWNER_REQUIRED` |
| 申请不存在或不属于该家庭 | 404 | `JOIN_REQUEST_NOT_FOUND` |
| 申请已被处理 | 409 | `JOIN_REQUEST_ALREADY_REVIEWED` |

## 6. Activity 扩展

扩展现有 `GET /families/:familyId/activity`。

每条记录建议返回：

```json
{
  "id": "record-id",
  "familyId": "family-id",
  "user": {
    "id": "user-id",
    "displayName": "张三",
    "familyIdentity": "老妈",
    "customIdentity": null,
    "avatarKey": "avatar_default_01"
  },
  "chore": {
    "id": "chore-id",
    "name": "洗碗",
    "category": "厨房类",
    "icon": "fork.knife"
  },
  "minutes": 15,
  "actualMinutes": 20,
  "points": 20,
  "likeCount": 3,
  "likedByMe": true,
  "canDelete": true,
  "createdAt": "2026-06-19T12:00:00.000Z"
}
```

规则：

1. 仅返回未软删除的记录。
2. `familyIdentity` 使用自定义身份时，客户端展示 `customIdentity`。
3. `likedByMe` 按当前登录用户计算。
4. `canDelete` 根据记录创建人及当前成员 `memberRole` 计算。

## 7. 记录删除

`DELETE /chore-records/:recordId`

权限：

1. 记录创建人可以删除自己的记录。
2. 记录所属家庭的 `ACTIVE + OWNER` 可以删除任意成员记录。
3. 普通成员删除他人记录返回 403。

服务端使用软删除：

```text
deletedAt = current timestamp
deletedById = current user id
```

软删除后：

- activity 不返回该记录。
- leaderboard 不累计该记录积分。
- monthly-report 不累计该记录积分。
- 点赞接口拒绝操作该记录。

错误建议：

| 场景 | HTTP | code |
| ---- | ---- | ---- |
| 无删除权限 | 403 | `CHORE_RECORD_DELETE_FORBIDDEN` |
| 记录不存在或已删除 | 404 | `CHORE_RECORD_NOT_FOUND` |

## 8. 点赞

### 8.1 点赞

`PUT /chore-records/:recordId/like`

要求：当前用户是记录所属家庭的 `ACTIVE` 成员。接口应幂等，同一用户重复调用不会产生重复点赞。

```json
{
  "recordId": "record-id",
  "likeCount": 4,
  "likedByMe": true
}
```

### 8.2 取消点赞

`DELETE /chore-records/:recordId/like`

接口应幂等，不存在点赞时仍可返回成功状态。

```json
{
  "recordId": "record-id",
  "likeCount": 3,
  "likedByMe": false
}
```

数据约束：

```text
UNIQUE(userId, choreRecordId)
```

点赞不影响积分、排行榜或月报积分。

## 9. 统计接口约束

以下现有接口必须增加统一过滤条件：

- `GET /families/:familyId/activity`
- `GET /families/:familyId/leaderboard`
- `GET /families/:familyId/monthly-report`

约束：

1. 请求者必须是该家庭 `ACTIVE` 成员。
2. 查询只统计 `deletedAt IS NULL` 的记录。
3. 排行榜和月报始终使用记录快照中的 `points`。

## 10. 后续实现顺序

1. 扩展 Prisma `FamilyMember`：`memberRole`、`memberStatus`、`familyIdentity`、`customIdentity`、`avatarKey`。
2. 新增加入申请与 OWNER 审核接口。
3. 扩展 `ChoreRecord` 软删除字段并统一统计过滤。
4. 新增 `ChoreRecordLike` 唯一关系和点赞接口。
5. 扩展 activity DTO。
6. iOS 增加身份选择、头像占位、审核列表、左滑删除和点赞交互。
