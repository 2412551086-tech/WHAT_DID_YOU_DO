# MVP Scope

## 1. 当前已跑通基线

当前 iOS 与后端已完成并跑通以下主链路：

1. Mock/API 模式切换。
2. Mock 登录。
3. 创建和获取家庭。
4. 获取家务列表。
5. 选择 1 到 180 分钟实际耗时。
6. 按实际耗时创建家务记录并计算积分。
7. 首页刷新积分和家庭动态。
8. 查看月排行榜。
9. 查看月报。

## 2. 本轮 MVP 增量范围

### 2.1 家庭成员身份

- 创建家庭时选择家庭身份。
- 申请加入家庭时选择家庭身份。
- 支持默认身份列表与自定义身份。
- 自定义身份必须填写名称。
- 身份只用于展示，不参与权限判断。

### 2.2 权限与成员状态

- 创建家庭的人为 `ACTIVE + OWNER`。
- 被批准加入的人为 `ACTIVE + MEMBER`。
- 加入申请初始状态为 `PENDING`。
- OWNER 可以批准或拒绝申请。
- 只有 ACTIVE 成员可以访问家庭数据和创建记录。

### 2.3 头像占位

- 创建或加入家庭时选择 `avatarKey`。
- 后端保存 key，iOS 映射本地 Assets 头像。
- MVP 不上传真实头像文件。

### 2.4 家务记录互动

- Activity 展示头像、家庭身份、家务、实际耗时和积分。
- 记录支持左滑删除。
- 创建人可删除自己的记录。
- OWNER 可删除家庭内任意记录。
- 记录采用软删除并从动态、排行榜、月报中排除。
- ACTIVE 成员可以点赞和取消点赞。
- 同一用户对同一记录最多一个点赞。
- Activity 返回 `likeCount` 与 `likedByMe`。

## 3. MVP 数据字段

### FamilyMember

- `memberRole`: `OWNER | MEMBER`
- `memberStatus`: `PENDING | ACTIVE | REJECTED`
- `familyIdentity`
- `customIdentity?`
- `avatarKey`

### ChoreRecord

- 保留当前 `actualMinutes` 与 `points`
- 新增 `deletedAt?`
- 新增 `deletedById?`

### ChoreRecordLike

- `userId`
- `choreRecordId`
- `createdAt`
- 唯一约束：`userId + choreRecordId`

## 4. 明确不在本轮范围

1. 真实头像图片上传、裁剪与云存储。
2. OWNER 转让、多个 OWNER、管理员角色。
3. 儿童成员特殊权限。
4. 记录删除恢复与回收站。
5. 点赞通知、评论、表情回应。
6. 加入申请的推送通知。
7. 家庭成员封禁、退出与历史归档策略。
8. 复杂审核流或多级审批。

## 5. 完成定义

本轮 MVP 完成需满足：

1. Prisma migration、seed 和现有数据兼容策略明确。
2. 后端权限测试覆盖 OWNER、MEMBER、PENDING、REJECTED。
3. 软删除后 activity、leaderboard、monthly-report 结果一致。
4. 点赞接口幂等且唯一约束生效。
5. iOS Mock/API 两种模式都支持新增字段与互动。
6. iOS 主流程与现有实际耗时功能无回归。
7. DebugPanel 能辅助确认 token、家庭和最后一次请求状态。
