# PRD Acceptance Matrix

更新时间：2026-08-10

状态定义：`已完成`、`部分完成`、`暂缓`、`未开始`。状态以当前真实代码和最近验证结果为准。

| ID | 模块 | 验收条件 | 状态 | 说明 |
| ---- | ---- | ---- | ---- | ---- |
| AUTH-01 | 开发登录 | 手机号可登录，同一手机号复用同一开发用户 | 已完成 | 非正式短信验证码 |
| AUTH-02 | 正式认证 | 短信验证码、Apple、微信登录可用于生产 | 未开始 | 登录按钮可有占位，但无真实认证 |
| AUTH-03 | Token 存储 | token 可用于 API 会话 | 已完成 | API 模式 accessToken 已迁移到 Keychain，支持启动恢复和退出清理 |
| FAMILY-01 | 创建家庭 | 创建者自动成为 `ACTIVE + OWNER` | 已完成 | 后端及 e2e 已覆盖 |
| FAMILY-02 | 家庭身份 | 创建/加入时可选择预设或自定义身份 | 已完成 | 自定义身份为空会被拦截 |
| FAMILY-03 | 头像占位 | 保存 avatarKey，并在 iOS 显示本地占位头像 | 已完成 | 不含真实图片上传 |
| JOIN-01 | 邀请码 | 创建家庭后显示并可复制 inviteCode | 已完成 | UI 不暴露数据库 familyId |
| JOIN-02 | 加入申请 | 使用 inviteCode 创建 `PENDING + MEMBER` 申请 | 已完成 | 重复申请不重复创建 |
| JOIN-03 | 审核 | 仅 ACTIVE OWNER 可 approve/reject | 已完成 | OWNER 审核页面已接 API |
| JOIN-04 | 状态隔离 | PENDING/REJECTED 不能读取家庭数据或创建记录 | 已完成 | service 权限校验及 e2e 覆盖 |
| CHORE-01 | 家务目录 | 返回 36 项免费系统家务，并按日常家庭/恋爱陪伴/育儿/宠物展示 | 已完成 | Mock/API 目录、themeKey 和配套图标已同步 |
| CHORE-02 | 高级权益 | 任一 ACTIVE 成员开发兑换后，全家解锁不限常用、10 项自定义、成员个人布局和记录倍率 | 部分完成 | 家庭共享权益、对比页和 e2e 已完成；StoreKit 未接入 |
| CHORE-03 | 自定义家务 | 免费 2 项、高级 10 项；可自定义图标、统计大类、时长和倍率 | 已完成 | Mock/API、额度、归档释放槽位和记录积分均已覆盖；常用页最多显示 2 个空位 |
| CHORE-04 | 家庭常用 | 免费最多 6 项且 OWNER 家庭共享；高级不限数量且成员个人定制 | 已完成 | GET/PATCH chore-layout 返回 scope/canEdit/limit，首次配置、拖动排序和底部家务库均已接入 |
| CHORE-05 | 会员触发 | 超过 6 项、免费创建自定义、免费 MEMBER 编辑时展示权益页 | 已完成 | 原生对比页支持开发兑换；OWNER 在 2 个免费名额内可继续使用免费额度 |
| RECORD-01 | 耗时选择 | 点击家务先选择 1...180 分钟，再确认记录 | 已完成 | 取消不会创建记录 |
| RECORD-02 | 耗时记忆 | 每个 choreId 记住上次确认耗时，重启后保留 | 已完成 | 使用 UserDefaults |
| RECORD-03 | 积分 | 按 actualMinutes 比例计算并保存 points | 已完成 | iOS 预估和后端规则一致 |
| RECORD-05 | 高级倍率 | 高级家庭成员可为本次记录调整 0.5x...2.0x，免费版不能伪造 | 已完成 | iOS 实时预估；后端校验家庭权益并按 actualMinutes × pointsMultiplier 入账 |
| RECORD-04 | 动态展示 | 展示头像、身份、家务、actualMinutes、points | 已完成 | ActivityRow 已实现 |
| ACTIVITY-01 | 今日范围 | `range=day` 只返回家庭本地今天的未删除记录 | 已完成 | 按 `Family.timezone` 计算；e2e 覆盖跨 UTC 日期 |
| ACTIVITY-02 | 最近范围 | `range=recent` 返回最近 30 条未删除记录 | 已完成 | 不传 range 默认 recent |
| ACTIVITY-03 | 本周范围 | `range=week` 返回家庭本地周一至下周一的未删除记录 | 已完成 | 首页“本周战况”使用此范围 |
| LIKE-01 | 快速点赞 | ACTIVE 成员可单击点赞，activity 返回总回应数和本人状态 | 已完成 | 同时返回回应成员头像信息 |
| LIKE-02 | 幂等 | 重复回应/取消回应不报冲突且计数正确 | 已完成 | upsert 更新类型、deleteMany 取消 + e2e |
| LIKE-03 | 表情回应 | 长按可选点赞、击掌、黑脸、笑哭、调侃；同一用户仅保留一种 | 已完成 | 原创 SwiftUI 矢量图标；首次普通点赞后提供一次性提示 |
| DELETE-01 | 删除权限 | 创建者删自己，OWNER 删家庭内任意记录 | 已完成 | iOS 使用 canDelete 控制左滑入口 |
| DELETE-02 | 软删除 | 写入 deletedAt、deletedById | 已完成 | 不物理删除记录 |
| DELETE-03 | 统计过滤 | 已删除记录不进入日/周动态、最近动态、排行、月报 | 已完成 | 查询统一过滤 deletedAt |
| REPORT-01 | 排行榜 | 支持 day/week/month 并使用记录 points 聚合 | 已完成 | 首页使用家庭时区内本周范围；删除记录不参与统计 |
| REPORT-02 | 月报 | 可切换月份并按家庭时区的 YYYY-MM 聚合 | 已完成 | 主立绘跟随所选月份积分第一名；删除记录不参与统计 |
| REPORT-03 | 月报结构统计 | 月报返回四主题和家务大类的积分、次数与占比 | 已完成 | `themeStats` 驱动主题圆环；`categoryStats` 驱动分段比例条和图例 |
| FAMILY-04 | 家主转让 | OWNER 可将角色转让给另一 ACTIVE MEMBER | 已完成 | 数据库事务同时降级原 OWNER、升级目标成员 |
| FAMILY-05 | 形象切换 | ACTIVE 成员可更新一一对应的立绘和头像 | 已完成 | 后端只保存 avatarKey，iOS 映射两套素材 |
| FAMILY-06 | 家庭名称 | OWNER 可在个人页顶部身份卡修改家庭名称，MEMBER 只读 | 已完成 | `PATCH /families/:familyId` 仅 ACTIVE OWNER 可调用 |
| FAMILY-07 | 成员详情 | ACTIVE 成员可查看其他成员滚动近 30 天未删除动态 | 已完成 | 成员详情展示次数、分钟、积分和记录；OWNER 在目标 MEMBER 详情中可转让家主 |
| FAMILY-08 | 退出家庭 | MEMBER 可退出；OWNER 必须先转让，一旦退出立即清理当前家庭状态 | 已完成 | 后端 DELETE 路由和 iOS 退出入口已接通 |
| FAMILY-09 | 退出后重入 | 退出只标记 LEFT；再次申请复用原成员关系，不按昵称匹配 | 已完成 | migration、service 和 e2e 已覆盖 |
| HISTORY-01 | 历史展示快照 | 改名、换形象、退出或重入后，旧动态仍显示记录发生时的昵称、身份和头像 | 已完成 | ChoreRecord 保存创建者展示快照 |
| AUTH-04 | 昵称更新 | 登录不要求昵称；创建/加入家庭时可确认或修改昵称 | 已完成 | 仍不是正式注册资料系统 |
| AUTH-05 | 个人页昵称 | 已登录用户可在个人页修改昵称并立即刷新 | 已完成 | `PATCH /auth/me` 已接入 |
| PHOTO-01 | 图片凭证字段 | 后端保留 requirePhotoProof/imageUrls 和校验 | 已完成 | 为后续上传能力保留 |
| PHOTO-02 | iOS 图片凭证 | 用户可拍照/选择并上传凭证 | 暂缓 | iOS 入口隐藏/禁用，创建固定 false |
| UI-01 | 主界面 | 四 Tab、DesignSystem、卡片化视觉可运行 | 已完成 | SwiftUI Debug build 已验证 |
| UI-02 | 网络反馈 | API 主请求有 loading、error 提示 | 已完成 | DebugPanel 仅 Debug 显示 |
| UI-03 | 月报视觉层级 | 页面只有领跑者主卡使用一级强调，其余摘要、结构和排行降级 | 已完成 | 月份控件无独立阴影，排行使用平面列表，避免色块同时抢焦点 |
| UI-04 | 外观模式 | 用户可选择跟随系统、浅色或深色，核心页面保持可读和一致 | 已完成 | AppStorage + 自适应 DesignSystem token |
| UI-05 | 常用家务手势 | 滚动不误触；轻触记录；长按进入布局；拖动排序/删除；离开时退出编辑态 | 已完成 | UIKit 手势协调层和 XCTest 覆盖关键状态机 |
| ACHIEVEMENT-01 | 成长成就 | 首记与连续 3/5/7 日奖励可查询并幂等发放 | 未开始 | 方案已完成，见 `ACHIEVEMENTS.md` |
| ACHIEVEMENT-02 | 成就页面 | Home/Profile 可进入成就页并查看进度、徽章和奖励 | 未开始 | 不增加第五个 Tab |
| TEST-01 | 后端回归 | build、unit、test、e2e 通过 | 已完成 | 提交前仍需重复执行 |
| TEST-02 | iOS 自动化 | 关键纯逻辑具备 XCTest，主流程具备 UI Test | 部分完成 | 当前 64 项 Simulator XCTest 为 63 通过、1 项环境跳过、0 失败；双账号 UI Test 仍未开始 |
| TEST-03 | API Smoke | 一条命令验证双账号 MVP API 主链路 | 已完成 | `pnpm run smoke:mvp` 共 19 项检查 |
| TEST-04 | GitHub Actions | push/PR 自动执行后端和 iOS 基础验收 | 已完成 | backend-ci 与 ios-ci 独立运行 |
| ENV-01 | 环境隔离 | Debug、局域网联调、Release/Production 独立配置 | 已完成 | Debug 默认模拟器本机后端，Scheme 环境变量可切换局域网；Release 禁止使用 `127.0.0.1` |
| RELEASE-01 | TestFlight | 签名、归档、隐私信息、内测安装完成 | 未开始 | 下一阶段重点 |
