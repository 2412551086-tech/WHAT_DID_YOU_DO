# 2026-08-01 上午改动汇总

记录时间：2026-08-01（Asia/Shanghai）

> 今天上午没有产生新的 Git commit。本文根据当前工作区代码、Prisma migration、素材目录和自动化测试结果整理；提交前应将本文与对应业务改动一起纳入版本控制。

## 1. 产品与交互变化

### 登录与启动

- 登录页完成高保真重构，并修复多层描边/阴影叠加造成的重影。
- 手机号开发登录支持用户输入昵称；同一手机号再次登录时可更新显示名。
- Keychain 会话恢复继续保留，恢复期间先显示启动 Loading 状态，不闪现登录页。
- 等待审核页使用固定人物立绘；首页无人记录空状态使用同人物配套圆形头像。

### 首页与统计

- 第一 Tab 从“今日战况”调整为“本周战况”。
- 首页记录数、积分和家庭排名改用家庭时区内的本周数据。
- 后端 activity 与 leaderboard 新增 `range=week`，周范围为家庭当地时间周一 00:00 至下周一 00:00。
- 最近家庭动态仍使用 `range=recent`，不会因首页改为周统计而丢失跨周浏览能力。

### 月度战报

- 月度战报支持向前切换历史月份，也可返回当前月份，不能切换到未来月份。
- 月报继续使用 `month=YYYY-MM` 与家庭时区聚合。
- 月报主视觉人物改为当前所选月份积分第一名成员的配套立绘；没有有效排名时使用默认立绘。

### 家庭与个人设置

- OWNER 可将“一家之主”转让给同家庭另一位 `ACTIVE + MEMBER`。
- 成员可在“我的”页面切换人物立绘；`family_avatar_action_XX` 与 `avatar_XX` 一一对应。
- 后端只保存 `avatarKey`，头像、立绘、动态和排行榜展示自动同步。
- 创建家庭、邀请码加入、审核列表、等待/通过/拒绝状态页面完成高保真重构。

### 家务目录

- 免费版每个家庭提供 2 个共享自定义家务槽位。
- 自定义家务支持 10 项本地图标、名称、默认时长和 `0.5x...2.0x` 积分倍率。
- 自定义家务支持创建、编辑和归档；归档释放槽位但保留历史记录。
- 高级家务改为与免费家务相同的双列卡片布局，未解锁时使用轻玻璃遮罩、小锁和明确标签。
- 新增开发测试兑换流程：任意开发账号输入兑换码 `241255` 后获得测试高级会员，可记录 10 项高级家务。
- API 模式权益保存到后端 User；Mock 模式保存在本地。生产环境默认禁用测试兑换接口。

## 2. 后端与数据库变化

新增或扩展接口：

- `POST /auth/redeem-premium`
- `PATCH /families/:familyId/owner`
- `PATCH /families/:familyId/members/me/appearance`
- `GET|POST /families/:familyId/custom-chores`
- `PATCH|DELETE /families/:familyId/custom-chores/:choreId`
- `GET /families/:familyId/activity?range=week`
- `GET /families/:familyId/leaderboard?range=week`

Prisma 变化：

- `User.plan`、`User.premiumRedeemedAt`。
- Chore 增加 `catalogKey`、家庭归属、创建人、自定义槽位和归档字段。
- 新增 migration：`20260801114000_add_custom_chores`。
- 新增 migration：`20260801170000_add_test_premium_access`。
- seed 现在写入核心 10 项和高级 10 项家务。

## 3. 素材与 DesignSystem

- 新增 13 组头像与配套人物立绘。
- 新增核心家务、高级家务和 10 项自定义家务图标资源。
- 新增登录主视觉、等待审核人物、首页空状态头像等资源。
- 页面重构继续遵循高保真图优先，同时保留 iOS 17 Material、透明度、描边和阴影回退方案。
- 素材清单记录在 `docs/ASSET_MANIFEST.md`；设计过程文件不作为 App 运行资源。

## 4. 自动化验证

本日上午最终验证结果：

- Backend build：通过。
- Backend Jest：1/1 通过。
- Backend e2e：10/10 通过。
- MVP smoke：最近基线 19/19 通过。
- iOS Simulator build：通过。
- iOS XCTest：32/32 通过。

新增覆盖包括自定义家务额度与积分、家主转让、人物形象切换、本周统计、月份切换、昵称更新、测试会员兑换和高级家务记录。

## 5. 仍未完成

- `241255` 仅为开发测试兑换码，不是正式 StoreKit 购买或生产兑换码体系。
- 正式短信验证码、Apple 登录、微信登录未接入。
- 真实头像上传、图片凭证上传、语音识别、常做/重复任务仍暂缓。
- 尚未建立覆盖完整双账号流程的 XCUITest。
- TestFlight 签名、归档、隐私材料和真机发布验收仍未完成。
