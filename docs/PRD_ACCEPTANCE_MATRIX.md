# PRD Acceptance Matrix

更新时间：2026-06-21

状态定义：`已完成`、`部分完成`、`暂缓`、`未开始`。状态以当前真实代码和最近验证结果为准。

| ID | 模块 | 验收条件 | 状态 | 说明 |
| ---- | ---- | ---- | ---- | ---- |
| AUTH-01 | 开发登录 | 手机号可登录，同一手机号复用同一开发用户 | 已完成 | 非正式短信验证码 |
| AUTH-02 | 正式认证 | 短信验证码、Apple、微信登录可用于生产 | 未开始 | 登录按钮可有占位，但无真实认证 |
| AUTH-03 | Token 存储 | token 可用于 API 会话 | 部分完成 | 尚未迁移到 Keychain |
| FAMILY-01 | 创建家庭 | 创建者自动成为 `ACTIVE + OWNER` | 已完成 | 后端及 e2e 已覆盖 |
| FAMILY-02 | 家庭身份 | 创建/加入时可选择预设或自定义身份 | 已完成 | 自定义身份为空会被拦截 |
| FAMILY-03 | 头像占位 | 保存 avatarKey，并在 iOS 显示本地占位头像 | 已完成 | 不含真实图片上传 |
| JOIN-01 | 邀请码 | 创建家庭后显示并可复制 inviteCode | 已完成 | UI 不暴露数据库 familyId |
| JOIN-02 | 加入申请 | 使用 inviteCode 创建 `PENDING + MEMBER` 申请 | 已完成 | 重复申请不重复创建 |
| JOIN-03 | 审核 | 仅 ACTIVE OWNER 可 approve/reject | 已完成 | OWNER 审核页面已接 API |
| JOIN-04 | 状态隔离 | PENDING/REJECTED 不能读取家庭数据或创建记录 | 已完成 | service 权限校验及 e2e 覆盖 |
| CHORE-01 | 家务目录 | 返回核心 10 项免费和 10 项高级锁定家务 | 已完成 | Mock/API 目录已同步 |
| CHORE-02 | 高级权益 | 高级家务不可直接记录并显示开通提示 | 部分完成 | 锁定交互完成，StoreKit 未接入 |
| RECORD-01 | 耗时选择 | 点击家务先选择 1...180 分钟，再确认记录 | 已完成 | 取消不会创建记录 |
| RECORD-02 | 耗时记忆 | 每个 choreId 记住上次确认耗时，重启后保留 | 已完成 | 使用 UserDefaults |
| RECORD-03 | 积分 | 按 actualMinutes 比例计算并保存 points | 已完成 | iOS 预估和后端规则一致 |
| RECORD-04 | 动态展示 | 展示头像、身份、家务、actualMinutes、points | 已完成 | ActivityRow 已实现 |
| ACTIVITY-01 | 今日范围 | `range=day` 只返回当前 UTC 日未删除记录 | 已完成 | 首页今日统计使用该结果 |
| ACTIVITY-02 | 最近范围 | `range=recent` 返回最近 30 条未删除记录 | 已完成 | 不传 range 默认 recent |
| LIKE-01 | 点赞 | ACTIVE 成员可点赞，activity 返回计数和本人状态 | 已完成 | 同时返回点赞人头像信息 |
| LIKE-02 | 幂等 | 重复点赞/取消点赞不报冲突且计数正确 | 已完成 | upsert/deleteMany + e2e |
| DELETE-01 | 删除权限 | 创建者删自己，OWNER 删家庭内任意记录 | 已完成 | iOS 使用 canDelete 控制左滑入口 |
| DELETE-02 | 软删除 | 写入 deletedAt、deletedById | 已完成 | 不物理删除记录 |
| DELETE-03 | 统计过滤 | 已删除记录不进入今日、动态、排行、月报 | 已完成 | 查询统一过滤 deletedAt |
| REPORT-01 | 排行榜 | 支持 day/month 并使用记录 points 聚合 | 已完成 | 删除记录不参与统计 |
| REPORT-02 | 月报 | 按 YYYY-MM 聚合积分、记录、成员和分类 | 已完成 | 删除记录不参与统计 |
| PHOTO-01 | 图片凭证字段 | 后端保留 requirePhotoProof/imageUrls 和校验 | 已完成 | 为后续上传能力保留 |
| PHOTO-02 | iOS 图片凭证 | 用户可拍照/选择并上传凭证 | 暂缓 | iOS 入口隐藏/禁用，创建固定 false |
| UI-01 | 主界面 | 四 Tab、DesignSystem、卡片化视觉可运行 | 已完成 | SwiftUI Debug build 已验证 |
| UI-02 | 网络反馈 | API 主请求有 loading、error 提示 | 已完成 | DebugPanel 仅 Debug 显示 |
| TEST-01 | 后端回归 | build、unit、test、e2e 通过 | 已完成 | 提交前仍需重复执行 |
| TEST-02 | iOS 自动化 | 主流程具备 XCTest/UI Test 自动回归 | 未开始 | 当前依赖编译和手测 |
| ENV-01 | 环境隔离 | Debug/Staging/Release 独立配置 | 部分完成 | 当前主要使用本机 baseURL |
| RELEASE-01 | TestFlight | 签名、归档、隐私信息、内测安装完成 | 未开始 | 下一阶段重点 |
