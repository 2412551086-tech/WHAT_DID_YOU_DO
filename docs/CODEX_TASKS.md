# Codex Tasks

本文件是按依赖顺序排列的实施队列。完成一项后同步更新 `PRD_ACCEPTANCE_MATRIX.md` 状态。

## Milestone 0：当前 MVP 基线

- [x] NestJS + Prisma + PostgreSQL 后端可运行。
- [x] SwiftUI + MVVM iOS 工程与 DesignSystem 可运行。
- [x] Mock/API 模式切换。
- [x] 登录、创建家庭、家务列表、记录、动态、排行、月报主链路。
- [x] 实际耗时选择器与 `actualMinutes` 后端支持。
- [x] API loading、error 与 DebugPanel 基础能力。

## Milestone 1：Schema 与迁移

- [ ] 定义 Prisma enum：`MemberRole`、`MemberStatus`。
- [ ] 扩展 `FamilyMember`：身份、自定义身份、头像、角色、状态。
- [ ] 扩展 `ChoreRecord`：`deletedAt`、`deletedById`。
- [ ] 新增 `ChoreRecordLike` 与唯一约束。
- [ ] 确定加入申请复用 `FamilyMember(PENDING)` 或独立表；优先复用成员关系，减少模型数量。
- [ ] 生成 migration，并为现有 FamilyMember 数据回填安全默认值。
- [ ] 更新 Prisma seed 与测试 fixture。

## Milestone 2：后端身份与审核

- [ ] 扩展创建家庭 DTO，接收 `familyIdentity`、`customIdentity`、`avatarKey`。
- [ ] 创建家庭时写入 `ACTIVE + OWNER`。
- [ ] 实现提交加入申请接口，初始为 `PENDING + MEMBER`。
- [ ] 实现 OWNER 查看待审核申请。
- [ ] 实现 approve/reject。
- [ ] 将家庭访问守卫升级为只允许 ACTIVE 成员。
- [ ] 增加 OWNER 权限守卫或 service 级权限检查。
- [ ] 添加 DTO 校验与错误 code。
- [ ] 添加 OWNER/MEMBER/PENDING/REJECTED 权限测试。

## Milestone 3：后端记录互动

- [ ] 扩展 activity，返回 identity、avatarKey、likeCount、likedByMe、canDelete。
- [ ] 实现记录软删除接口。
- [ ] activity 统一过滤 `deletedAt IS NULL`。
- [ ] leaderboard 统一过滤 `deletedAt IS NULL`。
- [ ] monthly-report 统一过滤 `deletedAt IS NULL`。
- [ ] 实现点赞接口并保证幂等。
- [ ] 实现取消点赞接口并保证幂等。
- [ ] 禁止对已删除记录点赞。
- [ ] 添加删除、点赞和聚合回归 e2e。

## Milestone 4：iOS Mock 实现

- [ ] 新增家庭身份枚举与自定义身份输入。
- [ ] 新增 avatarKey 本地头像映射和占位 Assets。
- [ ] 创建家庭流程保存身份与头像。
- [ ] Mock 加入申请、审核状态与 OWNER/MEMBER 权限。
- [ ] Activity 卡片展示头像和家庭身份。
- [ ] Mock 记录支持左滑删除和权限判断。
- [ ] Mock 记录支持点赞/取消点赞。

## Milestone 5：iOS API 接入

- [ ] 更新 Family/Member/Activity DTO。
- [ ] 接入加入申请和审核接口。
- [ ] 接入删除记录接口，成功后刷新首页、排行和月报。
- [ ] 接入点赞与取消点赞接口。
- [ ] 保留全部 loading、error 与 DebugPanel 诊断信息。
- [ ] 验证 Mock/API 模式行为一致。

## Milestone 6：验收与回归

- [ ] 后端 build、unit、e2e 全部通过。
- [ ] iOS Debug build 通过。
- [ ] OWNER 完整流程通过。
- [ ] MEMBER 完整流程通过。
- [ ] PENDING/REJECTED 越权请求均被拒绝。
- [ ] 删除后动态、排行、月报立即一致。
- [ ] 点赞计数与 likedByMe 状态一致。
- [ ] 实际耗时和积分主流程无回归。
- [ ] 更新 API curl 清单与 Xcode 手工验收清单。

## Guardrails

- 本轮不做真实头像上传。
- 本轮不新增管理员、儿童成员、评论、通知等复杂功能。
- familyIdentity 不得参与权限判断。
- 所有家庭写操作必须校验 ACTIVE 成员关系。
- 所有 OWNER 操作必须校验记录或申请属于同一家庭。
- 不删除现有 migration，不重建项目，不破坏 Mock/API 开关。
