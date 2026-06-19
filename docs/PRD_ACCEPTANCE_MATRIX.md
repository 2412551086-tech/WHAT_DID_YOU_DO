# PRD Acceptance Matrix

状态说明：`DONE` 已完成，`PENDING` 待实现，`BLOCKED` 外部条件阻塞。

| ID | 模块 | 验收条件 | 主要验证方式 | 状态 |
| ---- | ---- | ---- | ---- | ---- |
| BASE-01 | 主链路 | 登录、创建家庭、家务列表、实际耗时、创建记录可完成 | iOS + curl | DONE |
| BASE-02 | 积分 | 实际耗时按规则计算并保存 points | e2e | DONE |
| BASE-03 | 统计 | 新记录反映到 activity、leaderboard、monthly-report | e2e | DONE |
| ID-01 | 家庭身份 | 创建家庭时必须选择预设身份或自定义身份 | DTO + iOS 流程 | PENDING |
| ID-02 | 自定义身份 | 选择“自定义”但名称为空时禁止提交 | DTO 校验 + UI | PENDING |
| ID-03 | 身份展示 | Activity 使用 familyIdentity/customIdentity，不用权限名称代替 | API + UI | PENDING |
| ID-04 | 权限隔离 | familyIdentity 的取值不改变 memberRole 权限 | 单元测试 | PENDING |
| AVATAR-01 | 头像占位 | 创建和加入时可保存 avatarKey | API + DB | PENDING |
| AVATAR-02 | 头像展示 | Activity 左侧根据 avatarKey 显示本地头像 | iOS UI | PENDING |
| ROLE-01 | OWNER | 创建家庭的人自动为 ACTIVE + OWNER | e2e + DB | PENDING |
| ROLE-02 | MEMBER | 审核通过后申请人成为 ACTIVE + MEMBER | e2e + DB | PENDING |
| JOIN-01 | 申请加入 | 提交申请后状态为 PENDING | API e2e | PENDING |
| JOIN-02 | 待审核隔离 | PENDING 用户不能读取家庭数据或创建记录 | 权限 e2e | PENDING |
| JOIN-03 | 批准 | 仅 OWNER 可以 approve，成功后状态为 ACTIVE | 权限 e2e | PENDING |
| JOIN-04 | 拒绝 | 仅 OWNER 可以 reject，状态为 REJECTED | 权限 e2e | PENDING |
| JOIN-05 | 拒绝隔离 | REJECTED 用户不能读取家庭数据或创建记录 | 权限 e2e | PENDING |
| RECORD-01 | 动态展示 | 展示头像、身份、家务、actualMinutes、points | API + iOS UI | PENDING |
| DELETE-01 | 删除自己的记录 | ACTIVE 成员可删除自己创建的记录 | API e2e | PENDING |
| DELETE-02 | OWNER 删除 | OWNER 可删除家庭内任意成员记录 | 权限 e2e | PENDING |
| DELETE-03 | MEMBER 限制 | MEMBER 删除他人记录返回 403 | 权限 e2e | PENDING |
| DELETE-04 | 软删除字段 | 删除时写入 deletedAt 与 deletedById | DB 断言 | PENDING |
| DELETE-05 | 统计过滤 | 已删除记录不出现在动态、排行、月报 | 聚合 e2e | PENDING |
| DELETE-06 | iOS 交互 | 有权限的记录支持左滑删除，无权限记录不展示删除操作 | iOS UI | PENDING |
| LIKE-01 | 点赞 | ACTIVE 成员可点赞自己或他人的未删除记录 | API e2e | PENDING |
| LIKE-02 | 唯一性 | 同一用户对同一记录最多一个点赞 | DB 约束 + e2e | PENDING |
| LIKE-03 | 取消点赞 | 已点赞记录可取消，重复取消保持幂等 | API e2e | PENDING |
| LIKE-04 | Activity 字段 | 返回正确的 likeCount 与 likedByMe | API e2e | PENDING |
| LIKE-05 | 积分隔离 | 点赞和取消点赞不改变 points、排行榜和月报积分 | 聚合 e2e | PENDING |
| REG-01 | 回归 | Mock/API 模式切换仍可用 | iOS 手工验收 | PENDING |
| REG-02 | 回归 | 1 到 180 分钟实际耗时选择与积分规则无回归 | iOS + e2e | PENDING |
| REG-03 | 回归 | loading、error 和 DebugPanel 继续正常工作 | iOS 手工验收 | PENDING |
