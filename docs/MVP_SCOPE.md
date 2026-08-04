# MVP Scope

更新时间：2026-08-04

## 1. 当前 MVP 定义

当前 MVP 是一个可在本地完成双用户家庭协作主链路的 iOS App：

手机号开发登录 → 创建/使用邀请码加入家庭 → OWNER 审核 → 选择家务与实际耗时 → 创建积分记录 → 查看本周/最近动态、排行和可切换月份的月报 → 点赞或软删除记录。

手机号开发登录仅用于联调，不代表正式短信验证码能力。

## 2. 已完成范围

### 2.1 iOS

- SwiftUI + MVVM 与现有 DesignSystem。
- Mock/API 模式切换。
- Login、CreateFamily、JoinFamily、JoinRequests、Home、ChoreSelection、FamilyDashboard、Profile。
- 底部四 Tab：本周战况、记一下、月度战报、我的。
- 选择家庭身份、自定义身份和 `avatarKey` 头像占位。
- 实际耗时滚轮：1 到 180 分钟，步长 1 分钟。
- 免费版按家务系统倍率计算；家庭高级版可在每次记录时调整 0.5x...2.0x 积分倍率，预计积分实时更新。
- 每个 choreId 的上次确认耗时通过 UserDefaults 持久化。
- activity 点赞、取消点赞、点赞头像和按权限左滑删除。
- 创建家庭后由 OWNER 从日常家庭、恋爱陪伴、育儿、宠物四主题家务库配置家庭常用项；免费版可选 1...6 项并同步给全家，任一 ACTIVE 成员开通后全家获得高级版，系统家务不限数量且每位成员可保存个人布局。
- 日常“记一下”只显示家庭已选系统家务和自定义位置；OWNER 可从页面底部继续上拉回到家务库调整，不保留独立“编辑常用”按钮。
- 免费账号每个家庭 2 个共享自定义家务槽位，测试高级账号 10 个；常用页仅显示已有自定义项和接下来的 2 个空位。支持 10 项图标、自定义名称、统计大类、默认时长和 0.5x...2.0x 积分倍率。
- 月度战报支持历史月份切换，按当月积分第一名动态显示配套人物立绘，并展示主题圆环与家务大类分段分布。
- OWNER 可在目标成员详情中转让一家之主；ACTIVE 成员可切换一一对应的立绘与头像。
- ACTIVE MEMBER 可退出当前家庭；OWNER 需先转让一家之主，转让和退出后 iOS 立即刷新当前家庭权限状态。
- 登录页和个人页均支持开发用户昵称修改。
- OWNER 可编辑家庭名称；所有 ACTIVE 成员可查看其他成员滚动近 30 天的未删除家务动态。
- 开发测试账号可使用兑换码为当前家庭解锁“常用家务不限数量、10 项自定义家务、每位成员个人布局、记录时自定义积分倍率”，同一家庭全部 ACTIVE 成员共享；这不等于正式 StoreKit 购买能力。
- 超过免费 6 项、免费创建自定义家务、免费普通成员尝试编辑布局时会展示原生免费/高级权益对比页。
- Keychain 会话保存、启动恢复和退出清理。
- API loading、error 和仅 Debug 显示的 DebugPanel。

### 2.2 后端

- 开发登录与 Bearer token。
- 创建家庭；创建者为 `ACTIVE + OWNER`。
- 使用 `inviteCode` 申请加入；申请者为 `PENDING + MEMBER`。
- OWNER 查询、批准或拒绝加入申请。
- 36 项全部免费的系统家务目录，按日常家庭、恋爱陪伴、育儿、宠物四主题组织。
- 常用家务配置；免费账号最多 6 项，仅 OWNER 修改家庭共享布局；高级账号不限数量，每位 ACTIVE 成员保存自己的 `FamilyMember` 布局。
- 家庭级自定义家务创建、编辑、查询和归档；后端按账号套餐强制 2/10 个有效槽位。免费版仅 OWNER 管理，高级 ACTIVE 成员可管理。
- `actualMinutes` 校验、积分换算和记录持久化。
- activity 的 `day | week | recent` 查询。
- leaderboard 的 `day | week | month` 查询。
- 指定 `YYYY-MM` 的 monthly-report。
- 点赞、取消点赞、软删除和权限校验。
- OWNER 转让、成员形象更新和测试高级会员兑换。
- OWNER 修改家庭名称；ACTIVE 成员读取指定成员近 30 天未删除动态。
- monthly-report 返回按 `themeKey` 聚合的 `themeStats` 和按统计大类聚合的 `categoryStats`。
- 所有统计过滤 `deletedAt != null` 的记录。

## 3. 关键规则

### 身份与权限

- `identityLabel`/`customIdentity` 仅用于展示。
- `memberRole` 决定权限：`OWNER | MEMBER`。
- `status` 决定访问资格：`PENDING | ACTIVE | REJECTED`。
- 只有 ACTIVE 成员能读取家庭数据、记录家务和互动。

### 实际耗时与积分

- `actualMinutes` 范围为 1 到 180。
- 未传 `actualMinutes` 时使用家务标准时长。
- `points = round(defaultPoints * actualMinutes / standardMinutes)`。
- 标准时长为 0 时回退到默认积分，避免除零。

### 动态与删除

- `range=day`：按家庭 `timezone` 计算的本地今天内全部未删除记录。
- `range=recent`：最近 30 条未删除记录；不传 range 时默认 recent。
- 创建者可删除自己的记录；OWNER 可删除家庭内任意记录。
- 删除只写入 `deletedAt`、`deletedById`，不物理移除。
- 已删除记录不进入 activity、leaderboard 或 monthly-report。

### 图片凭证

- Prisma 和后端校验逻辑保留 `requirePhotoProof`、`imageUrls`。
- iOS MVP 不提供真实图片选择/上传，入口隐藏或禁用。
- iOS 创建家庭固定发送 `requirePhotoProof=false`。

## 4. 不在当前 MVP 范围

- 正式短信验证码、Apple 登录、微信登录。
- 真实头像和图片凭证上传。
- StoreKit 购买、收据验证和生产订阅体系。
- 语音识别、常做任务和重复任务。
- 评论、通知、任务排班、积分兑换。
- 多管理员和成员退出/移除策略。
- 复杂家庭时区选择 UI、生产监控和 App Store 正式发布。

## 5. 当前完成定义

当前 MVP 代码范围已经达到本地联调完成定义。下一阶段完成定义转为：自动化回归稳定、生产密钥与测试兑换隔离、签名归档和 TestFlight 可安装验证。
