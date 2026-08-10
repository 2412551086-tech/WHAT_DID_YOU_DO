# Codex Tasks

更新时间：2026-08-10

本文件只保留当前真实待办。已经完成的业务能力记录在 `PROJECT_STATUS.md` 和 `PRD_ACCEPTANCE_MATRIX.md`，不再重复伪装成待实现任务。

## 已完成基线

- [x] NestJS + Prisma + PostgreSQL 本地后端。
- [x] SwiftUI + MVVM、DesignSystem、Mock/API 切换。
- [x] 手机号开发登录与 Bearer token。
- [x] 创建家庭、inviteCode 加入、OWNER 审核。
- [x] 家庭身份、头像占位、ACTIVE/PENDING/REJECTED 权限。
- [x] 36 项免费系统家务，按日常家庭、恋爱陪伴、育儿、宠物四主题组织。
- [x] 家庭常用权益：免费最多 6 项且由 OWNER 同步全家；高级不限数量并支持成员个人布局。
- [x] 开发兑换码、原生权益对比页和家庭共享 premium 权益（任一 ACTIVE 成员开通后，全家获得无限常用、10 项自定义、成员个人布局和记录倍率）。
- [x] actualMinutes 选择、持久化、积分换算。
- [x] day/week/recent activity、day/week/month 排行榜和可切换月份月报。
- [x] 幂等点赞/取消点赞、点赞头像、权限化软删除。
- [x] 删除记录后的动态、今日统计、排行和月报过滤。
- [x] API loading、error、DebugPanel。
- [x] 后端 build/test/e2e 和 iOS Debug build 基线通过。
- [x] 一键 API smoke 脚本覆盖双账号主链路、幂等互动和删除后统计。
- [x] iOS 最小单测覆盖积分、耗时记忆、DTO 和 Mock/API 分流。
- [x] OWNER 转让和成员配套立绘/头像切换。
- [x] OWNER 修改家庭名称、成员近 30 天动态详情，以及从目标成员详情转让一家之主。
- [x] MEMBER 退出家庭、OWNER 转让后即时刷新，以及创建/加入家庭流程和个人页昵称修改。
- [x] 家庭高级版记录时自定义 0.5x...2.0x 积分倍率，免费版由后端拦截伪造请求。
- [x] 免费 2 / 高级 10 个共享自定义家务槽位和 10 项图标库；常用页仅展示接下来的 2 个空位。
- [x] 月报四主题聚合、主题圆环、家务大类分段分布和主次视觉层级收口。
- [x] 高保真页面、等待审核/空状态素材和关键按钮巡检。
- [x] 跟随系统/浅色/深色外观模式与自适应 DesignSystem。
- [x] 常用家务页轻触、滚动、长按布局、拖动排序/删除和底部家务库触发边界收口。
- [x] 家庭共享/成员个人常用布局切换，以及相关 ViewModel/XCTest 覆盖。
- [x] MEMBER 退出保留历史关系、重新加入复用成员身份，以及活动创建者信息快照。

## Phase 1：测试与稳定性

- [ ] 将后端 e2e fixture 和数据库清理策略固化，减少测试顺序依赖。
- [x] 补充家庭时区跨 UTC 日期和月报边界测试；1/180 分钟边界已覆盖。
- [ ] 补充重复申请在 PENDING/ACTIVE/REJECTED 各状态下的预期测试。
- [ ] 扩充 iOS ViewModel 单元测试：审核、记录刷新、点赞和删除失败恢复。
- [ ] 增加一条 iOS UI 主链路测试，覆盖 A 创建、B 申请、A 审核、B 记录。
- [ ] 验证弱网、超时、后端未启动、token 失效时的错误文案和恢复路径。
- [ ] 防止点赞、审核、创建记录按钮在请求中重复触发。
- [ ] 建立发布前手工回归清单并记录实际结果。
- [ ] 为本周统计补充 DST、周一边界和不同时区组合测试。
- [ ] 为家庭名称修改、成员近 30 天详情和定向转让补充 iOS ViewModel/XCUITest 覆盖。
- [ ] 为月报主题圆环、空数据回退和历史月份切换建立稳定截图回归。

## Phase 2：Keychain 与会话

- [x] 将 accessToken 从内存/普通存储迁移到 Keychain。
- [x] 明确启动时恢复会话、token 无效时回到登录页的行为。
- [x] 退出登录时清理 token、当前家庭、用户态和敏感调试信息。
- [x] 保留 Mock Preview 的无 Keychain 依赖路径。

## Phase 3：环境配置

- [x] 将 `APIConfig` 拆分为 Debug、局域网联调、Production 配置。
- [x] Debug 可使用本机/局域网 URL；Release 禁止指向 `127.0.0.1`。
- [x] 支持通过 Xcode Scheme 环境变量覆盖 API 环境和局域网 baseURL。
- [ ] 为后端补 `.env.example`，明确 `DATABASE_URL`、`JWT_SECRET` 等变量。
- [ ] Release 构建关闭 DebugPanel 和敏感网络日志。
- [ ] Release/Production 明确禁用测试兑换码，并将正式付费改为 StoreKit + 服务端收据校验。
- [x] 配置 CI：后端 Prisma/build/test/e2e/smoke 与 iOS Simulator build/XCTest。

## Phase 4：TestFlight 准备

- [ ] 确认 Bundle ID、版本号、Build Number 和签名团队。
- [ ] 配置 App Icon、Launch Screen、权限说明和隐私清单。
- [ ] 准备隐私政策、测试账号和审核说明。
- [ ] 完成 Release Archive 并上传 App Store Connect。
- [ ] 建立内部 TestFlight 测试组并完成至少一轮真机验收。
- [ ] 记录崩溃、网络失败和数据库迁移回滚方案。

## Phase 5：成就系统

- [x] 确定首版产品原则、3/5/7 日成长奖励和技能/互动成就方向。
- [x] 冻结 V1 关键决策：禁止补记、全部 ACTIVE 成员参与、10 秒撤销、通知暂缓、保留现有排行、异步结算。
- [ ] 将 Premium 自定义家务从当前 10 项升级为产品“不限”口径，并实现每家庭 100 个未归档项目的可配置服务端保护上限。
- [ ] 新增成就定义、成员进度和家庭容量奖励数据模型。
- [ ] 新增服务端 `occurredAt`、10 秒记录撤销接口及对应 e2e；不提供回收站。
- [ ] 实现数据库 Outbox 和异步成就 worker，保证家务成功不依赖成就处理结果。
- [ ] 实现按家庭时区计算连续记录日，并保证奖励发放幂等。
- [ ] 先实现首记、连续 3 日、5 日、7 日四项成长成就及后端边界测试。
- [ ] 新增成就查询接口和 iOS `AchievementsView`，入口放在 Home/Profile，不增加第五个 Tab。
- [ ] 接入解锁反馈、技能称号和家庭互动成就。

完整规则见 `docs/家庭家务成就系统完整开发文档.md`，工程阶段见 `docs/ACHIEVEMENT_DEVELOPMENT_PLAN.md`。在数据库和接口完成前，不要把成就标为已上线能力。

## 暂缓功能

- 正式短信验证码、Apple 登录、微信登录。
- 真实头像和图片凭证上传。
- StoreKit 订阅与服务端权益校验。
- 语音识别、常做/重复任务。
- 评论、统一通知系统（含成就应用内通知与 Push）、任务排班和积分兑换。

## Guardrails

- 不混用 npm 与 pnpm。
- 不删除历史 migration，不重建项目。
- 不提交 `.env`、`node_modules`、`DerivedData`、`xcuserdata`、`*.xcuserstate`。
- 家庭身份只用于展示，权限只由 memberRole/status 决定。
- 家庭数据写操作必须校验 ACTIVE 成员关系。
- 发布配置不得包含开发密钥或本机 URL。
