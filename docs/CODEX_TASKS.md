# Codex Tasks

更新时间：2026-06-21

本文件只保留当前真实待办。已经完成的业务能力记录在 `PROJECT_STATUS.md` 和 `PRD_ACCEPTANCE_MATRIX.md`，不再重复伪装成待实现任务。

## 已完成基线

- [x] NestJS + Prisma + PostgreSQL 本地后端。
- [x] SwiftUI + MVVM、DesignSystem、Mock/API 切换。
- [x] 手机号开发登录与 Bearer token。
- [x] 创建家庭、inviteCode 加入、OWNER 审核。
- [x] 家庭身份、头像占位、ACTIVE/PENDING/REJECTED 权限。
- [x] 核心/高级家务目录和高级锁定态。
- [x] actualMinutes 选择、持久化、积分换算。
- [x] day/recent activity、day/month 排行榜、月报。
- [x] 幂等点赞/取消点赞、点赞头像、权限化软删除。
- [x] 删除记录后的动态、今日统计、排行和月报过滤。
- [x] API loading、error、DebugPanel。
- [x] 后端 build/test/e2e 和 iOS Debug build 基线通过。
- [x] 一键 API smoke 脚本覆盖双账号主链路、幂等互动和删除后统计。
- [x] iOS 最小单测覆盖积分、耗时记忆、DTO 和 Mock/API 分流。

## Phase 1：测试与稳定性

- [ ] 将后端 e2e fixture 和数据库清理策略固化，减少测试顺序依赖。
- [ ] 补充 UTC 跨天、跨月和空月报测试；1/180 分钟边界已覆盖。
- [ ] 补充重复申请在 PENDING/ACTIVE/REJECTED 各状态下的预期测试。
- [ ] 扩充 iOS ViewModel 单元测试：审核、记录刷新、点赞和删除失败恢复。
- [ ] 增加一条 iOS UI 主链路测试，覆盖 A 创建、B 申请、A 审核、B 记录。
- [ ] 验证弱网、超时、后端未启动、token 失效时的错误文案和恢复路径。
- [ ] 防止点赞、审核、创建记录按钮在请求中重复触发。
- [ ] 建立发布前手工回归清单并记录实际结果。

## Phase 2：Keychain 与会话

- [ ] 将 accessToken 从内存/普通存储迁移到 Keychain。
- [ ] 明确启动时恢复会话、token 无效时回到登录页的行为。
- [ ] 退出登录时清理 token、当前家庭、用户态和敏感调试信息。
- [ ] 保留 Mock Preview 的无 Keychain 依赖路径。

## Phase 3：环境配置

- [ ] 将 `APIConfig` 拆分为 Debug、Staging、Release 配置。
- [ ] Debug 可使用本机/局域网 URL；Release 禁止指向 `127.0.0.1`。
- [ ] 通过 xcconfig 或构建设置注入 baseURL，不在业务代码硬编码生产地址。
- [ ] 为后端补 `.env.example`，明确 `DATABASE_URL`、`JWT_SECRET` 等变量。
- [ ] Release 构建关闭 DebugPanel 和敏感网络日志。
- [ ] 配置 CI：后端 build/test/e2e 与 iOS Simulator build。

## Phase 4：TestFlight 准备

- [ ] 确认 Bundle ID、版本号、Build Number 和签名团队。
- [ ] 配置 App Icon、Launch Screen、权限说明和隐私清单。
- [ ] 准备隐私政策、测试账号和审核说明。
- [ ] 完成 Release Archive 并上传 App Store Connect。
- [ ] 建立内部 TestFlight 测试组并完成至少一轮真机验收。
- [ ] 记录崩溃、网络失败和数据库迁移回滚方案。

## 暂缓功能

- 正式短信验证码、Apple 登录、微信登录。
- 真实头像和图片凭证上传。
- StoreKit 订阅与服务端权益校验。
- 语音识别、自定义家务、常做/重复任务。
- 评论、推送通知、任务排班和积分兑换。

## Guardrails

- 不混用 npm 与 pnpm。
- 不删除历史 migration，不重建项目。
- 不提交 `.env`、`node_modules`、`DerivedData`、`xcuserdata`、`*.xcuserstate`。
- 家庭身份只用于展示，权限只由 memberRole/status 决定。
- 家庭数据写操作必须校验 ACTIVE 成员关系。
- 发布配置不得包含开发密钥或本机 URL。
