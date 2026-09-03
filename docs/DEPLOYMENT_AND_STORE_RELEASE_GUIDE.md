# 家庭保卫战：部署与双平台上架手册

> 更新日期：2026-08-11
> 适用项目：NestJS + Prisma + PostgreSQL 后端、SwiftUI iOS 客户端，以及后续 Kotlin/Jetpack Compose Android 客户端。
> 本文面向第一次部署和上架 App 的开发者。平台规则会变化，正式购买和提交前请再次打开文中的官方链接核对。

## 1. 先看结论

当前项目可以继续在局域网内进行 iPhone 真机联调，但还不能直接提交 App Store 或安卓应用市场。

正式上线前至少需要完成：

1. 确定上架主体，统一域名、服务器、备案和开发者账号的实名信息。
2. 购买正式域名和中国大陆云服务器，部署 HTTPS 后端。
3. 完成网站备案和 App 备案；面向中国大陆分发时，iOS 和 Android 平台信息都要填入 App 备案。
4. 完成 Apple、邮箱验证码以及对应发行区域的微信或 Google 登录。
5. 增加用户在 App 内注销账号的完整流程。
6. 把测试兑换码升级会员的逻辑从正式版本中移除，改为符合商店规则的应用内购买。
7. 准备隐私政策、用户协议、技术支持和账号注销说明网页。
8. 完成生产安全、备份、监控、健康检查和自动部署。
9. iOS 走 TestFlight 和 App Store 审核；Android 客户端完成后，分别提交国内安卓商店，海外可再提交 Google Play。

### 推荐的总体方案

- 上架主体：计划长期运营、微信登录、短信和付费时，优先使用公司主体；预算有限时，可先核实各平台是否接受个体工商户。
- 主域名：优先考虑 `jiatingbaowei.com`，同时保护性购买 `jiatingbaowei.cn`。
- API 地址：`https://api.jiatingbaowei.com`。
- 首发服务器：中国大陆腾讯云轻量应用服务器，建议 `2 核 4 GB / 100 GB SSD / 7 Mbps` 档位。
- 首发部署：NestJS、PostgreSQL 16、Redis 7 使用 Docker Compose；数据库和 Redis 不开放公网端口。
- 数据备份：每天加密备份到腾讯云 COS，并定期做恢复演练。
- Android 技术栈：原生 Kotlin + Jetpack Compose + MVVM，共用现有后端 API。

## 2. 两份 Notion 资料的校正结论

参考资料：

- [安卓上架全流程地图 · 总纲](https://app.notion.com/p/3aee37f436638170bb9ef8fece4ebfd9)
- [上架资质对照表 · 华为安卓 vs 苹果](https://app.notion.com/p/92af92e3ee224aba9dc08b5122952d1c?v=8ff9fbce2cdb4a9bb94eff5ccf3442ec)

资料整体方向合理，正确地覆盖了主体、域名、服务器、备案、软著和商店账号。但执行时需要注意：

- 网站备案和 App 备案是不同的备案事项，不应简单理解成绝对的前后置关系。对本项目而言，使用同一云厂商、同一主体和同一域名办理最省事。
- `ICP备案` 是非经营性互联网信息服务常见的基础备案；`ICP许可证` 只在符合特定经营性业务条件时涉及，不能混为一谈。
- Apple 通常不要求软件著作权，但中国大陆安卓商店常要求应用版权材料，因此本项目应尽早申请软件著作权。
- 纯离线 App 不一定需要服务器；家庭保卫战需要账号、家庭、排行和同步，因此必须有稳定的生产后端。
- 不要为了省备案时间长期使用中国香港或海外服务器服务中国大陆用户。它可以用于早期测试，但不适合作为本项目国内正式首发的默认方案。

工信部明确要求，在中国境内提供互联网信息服务的 App 主办者履行 App 备案手续。参见[工信部 App 备案通知](https://www.gov.cn/zhengce/zhengceku/202308/content_6897341.htm?type=mobile-internet)。

## 3. 当前项目真实状态

### 已经具备

- NestJS、Prisma、PostgreSQL 后端和数据库 migration。
- SwiftUI iOS 客户端、Keychain token 保存和 Mock/API 环境切换。
- 免登录本机体验、统一身份与设备会话、家庭创建/加入/审核、家务记录、积分、动态、排行和月报。
- 后端 build、Jest、e2e、smoke test，以及 iOS XCTest 和 GitHub Actions CI。
- Debug 模拟器和局域网真机联调能力。

### 上架阻断项

| 阻断项 | 当前情况 | 上架前动作 |
|---|---|---|
| 生产 API | 仍是 `api.whatdidyoudo.example.com` 占位地址 | 替换为正式 HTTPS 域名 |
| 正式认证 | 统一身份和区域入口已完成，真实提供方未接入 | 接入 Apple、邮箱及对应区域的微信或 Google |
| Token | Access/Refresh Token Rotation 与设备会话已完成 | 在生产环境配置 JWT Secret 并演练撤销和轮换 |
| 账号注销 | App 内流程与服务端清理已完成 | 用生产提供方补充 token 撤销并完成审核演练 |
| 付费 | 当前兑换码仅用于测试 | 正式版使用 StoreKit / 各安卓渠道支付规则 |
| 后端部署 | 没有生产 Dockerfile、Compose、反向代理和部署 workflow | 建立可重复部署方案 |
| 运维 | 缺少健康检查、告警、异地备份和恢复演练 | 上线前补齐 |
| Android | 仓库中目前没有 Android 客户端 | 新建 Kotlin/Compose 工程并实现功能对齐 |

此外，iOS 最终 Bundle ID 已确定为 `com.douxiaolang.familyguard`。Apple Developer、App 备案、App Store Connect 和 Xcode 必须使用同一标识；App 上传商店后不再变更。

## 4. 先决定上架主体

### 个人主体

适合：只做免费独立 App、暂时不做复杂商业化。
注意：App Store 卖家名称会显示个人法定姓名；国内安卓商店、微信能力和商业化资质可能受限。

### 个体工商户

适合：希望控制成本，同时尝试付费和国内渠道。
注意：每个开发者平台是否接受个体工商户、接受哪些能力，需要在购买和认证前逐一核实。

### 公司主体

适合：计划正式运营、短信、微信登录、多安卓商店、订阅付费、商标和团队协作。
这是本项目长期最稳妥的方案。

### 本项目建议

如果确定会做高级会员、微信登录和国内 Android 上架，建议先确定公司或合适的个体工商户主体，再购买域名、服务器和注册各平台账号。以下信息尽量保持一致：

- 域名实名认证主体
- 云服务器账号主体
- 网站/App 备案主体
- Apple Developer 或安卓开发者主体
- 隐私政策运营者名称
- 短信签名和微信开放平台主体
- 软件著作权人

不要用多个亲友姓名分别注册，后期迁移会非常麻烦。

## 5. 域名选择与购买

### 推荐域名

2026-08-11 查询时，以下名称未发现公开注册记录，但域名状态随时变化，最终以购买页面为准：

1. `jiatingbaowei.com`：首选，品牌清晰，长度可接受。
2. `jiatingbaowei.cn`：建议保护性购买，并跳转到 `.com`。
3. `jtbaowei.com`：较短，可作为跳转或营销短域名。

不优先推荐 `jiatingbaoweizhan.com`，长度较长，输入和口头传播都不方便。

购买入口可使用[腾讯云域名注册](https://cloud.tencent.com/product/domain)。购买时选择与备案一致的实名主体，并开启自动续费和域名安全锁。

### 子域名规划

| 地址 | 用途 |
|---|---|
| `www.jiatingbaowei.com` | 简单官网和下载入口 |
| `api.jiatingbaowei.com` | 正式 API |
| `staging-api.jiatingbaowei.com` | 测试环境，可选 |
| `status.jiatingbaowei.com` | 服务状态页，可后置 |

官网至少提供：

- `/privacy` 隐私政策
- `/terms` 用户协议
- `/support` 技术支持与联系方式
- `/account-deletion` 账号注销说明

## 6. 服务器规格推荐

腾讯云轻量应用服务器的套餐和促销会变化，购买时以[腾讯云轻量应用服务器](https://cloud.tencent.com/product/lighthouse)页面为准。

### A. MVP、TestFlight、安卓内测和首批用户

推荐：

- 地域：离主要用户近的中国大陆地域。
- 系统：Ubuntu 24.04 LTS。
- 配置：2 核 CPU、4 GB 内存、100 GB SSD、约 7 Mbps 带宽。
- 进程：NestJS + PostgreSQL 16 + Redis 7 + Caddy/Nginx。
- 备份：每天上传到 COS，至少保留 7 个日备份和 4 个周备份。

这比 2 核 2 GB 更适合本项目。Node、PostgreSQL、Redis 和 Docker 同机运行时，2 GB 的余量太小。

### B. 正式公开上线后的推荐方案

- 应用服务器：2 核 4 GB 或 4 核 8 GB。
- 数据库：迁移到[腾讯云 PostgreSQL](https://cloud.tencent.com/product/postgres)，与应用服务器同地域、走内网。
- Redis：使用托管 Redis 的入门规格。
- 图片：未来的头像和凭证放 COS，不直接存在服务器磁盘。
- 告警：CPU、内存、磁盘、5xx、数据库连接数和备份失败都要告警。

此方案比单机贵，但数据库备份、恢复和故障风险更可控。

### C. 用户增长后

- 4 核 8 GB 或更高的应用服务器。
- 两个应用实例和负载均衡。
- 多可用区数据库、Redis、COS/CDN。
- 日志与监控独立服务。

不要一开始就买这一档。先用真实监控数据决定扩容。

### 粗略预算

| 项目 | 精简首发 | 稳定公开版 |
|---|---:|---:|
| 云服务器 | 约 1,000 元/年上下 | 视 4C8G 或多实例而定 |
| 域名 | 通常几十元/年起 | 主域名 + 保护域名 |
| 数据库/Redis | 与应用同机 | 托管服务按实时价格 |
| 对象存储 | 前期很低 | 按容量和流量计费 |
| Apple Developer | 99 美元/年 | 99 美元/年 |
| 短信 | 按审核后的套餐和发送量 | 按量增长 |
| 软件著作权/代理 | 自办与代理价格不同 | 加急服务另计 |

以上只是预算，不是报价。优惠、税费和平台政策会变化。

## 7. 备案路线

### 第一步：域名实名认证

使用最终主体完成域名实名认证。实名信息同步可能需要时间，不要买完域名立即提交备案。

### 第二步：购买大陆云资源

备案通常需要符合接入商要求的中国大陆云资源。使用腾讯云服务器时，建议同时通过腾讯云备案系统办理，减少跨接入商沟通。

### 第三步：网站备案

准备主体证件、负责人信息、域名和服务器。按腾讯云指引提交：[网站备案快速入门](https://cloud.tencent.com/document/product/243/39038)。

### 第四步：App 备案

准备：

- App 中文名称和图标
- iOS Bundle ID
- Android package name
- Android 签名证书公钥和 MD5 等平台信息
- SDK 清单
- 域名和云资源信息
- 主体和负责人信息

可以参考[腾讯云 App 备案材料说明](https://cloud.tencent.com/document/product/243/97691)。Android 客户端尚未建立时，可以先完成基础资料，但最终提交 Android 平台信息前必须确定包名和正式签名。

### 第五步：在 App 中展示备案号

备案完成后，在 App 容易找到的位置展示备案号，并按主管部门要求链接备案查询系统。iOS 和 Android 都要核对。

## 8. 后端生产部署：小白步骤

以下是目标流程，当前仓库还需要补生产 Docker 和部署文件。

### 8.1 云服务器准备

1. 创建非 root 的部署用户。
2. SSH 只允许密钥登录，关闭密码登录。
3. 防火墙只开放 `80`、`443`，以及限制来源 IP 的 `22`。
4. 不要向公网开放 PostgreSQL `5432` 和 Redis `6379`。
5. 安装 Docker Engine 和 Docker Compose。

### 8.2 DNS 与 HTTPS

1. 给 `api.jiatingbaowei.com` 添加 A 记录，指向服务器公网 IP。
2. 使用 Caddy 自动申请和续期 HTTPS 证书，或使用 Nginx + 可信证书。
3. API 只接受 HTTPS，HTTP 自动跳转到 HTTPS。

### 8.3 生产环境变量

生产 `.env` 只保存在服务器或 GitHub Actions Secret 中，绝不能提交到 Git：

```dotenv
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://app:强密码@postgres:5432/what_did_you_do
REDIS_URL=redis://redis:6379
JWT_SECRET=至少32字节的随机密钥
CORS_ORIGINS=https://www.jiatingbaowei.com

AUTH_DISTRIBUTION_REGION=CN
APPLE_CLIENT_ID=
WECHAT_APP_ID=
WECHAT_APP_SECRET=
EMAIL_PROVIDER=
GOOGLE_CLIENT_ID=
```

还应把 `JWT_SECRET` 的开发兜底值移除，生产缺少密钥时直接拒绝启动。

### 8.4 发布顺序

1. CI 完成 build、test、e2e 和 smoke test。
2. 构建不可变的后端镜像。
3. 在服务器执行 `prisma migrate deploy`。
4. 只在需要初始化固定家务时执行安全的、可重复运行的 seed。
5. 启动新版本并检查 `/health`。
6. 执行生产 smoke test。
7. 异常时回滚应用镜像；数据库 migration 必须提前设计回滚或兼容策略。

### 8.5 备份与监控

- 每天自动备份 PostgreSQL 到 COS。
- 备份必须加密，COS 权限设为私有。
- 每月至少实际恢复一次到临时数据库，确认备份可用。
- 监控 HTTPS、API 5xx、响应时间、CPU、内存、磁盘和数据库连接。
- 日志不能打印完整 token、邮箱验证码、稳定身份标识或其他隐私数据。

## 9. 正式登录能力

正式版采用统一 `User + AuthIdentity`：国内显示 Apple、微信和邮箱，海外显示 Apple、Google 和邮箱。
发行区域必须由构建与服务端环境变量显式配置，不依赖 IP。邮箱第一版使用一次性验证码，不建立密码体系。

### Apple 登录

1. 加入 [Apple Developer Program](https://developer.apple.com/programs/enroll/)。
2. 在 Identifier 中给 App ID 开启 Sign in with Apple。
3. Xcode target 添加对应 capability。
4. iOS 获取 Apple identity token，后端验证签名、issuer、audience 和 nonce。
5. Apple 可能只在首次授权返回姓名和邮箱，后端要正确保存。

参考：[Implementing User Authentication with Sign in with Apple](https://developer.apple.com/documentation/authenticationservices/implementing-user-authentication-with-sign-in-with-apple)。

如果使用微信等第三方登录作为主要登录方式，Apple 审核通常要求同时提供符合其规则的等效登录方案，Sign in with Apple 应一起实现。

### 微信登录

1. 注册并认证[微信开放平台](https://open.weixin.qq.com/)。
2. 创建移动应用，提交 Bundle ID、Android 包名和签名等资料。
3. 审核通过后获得 AppID；AppSecret 只能放后端，不能写进客户端。
4. 客户端获得临时 code，后端用 code 换取身份并绑定本地账号。
5. 按微信最新 SDK 文档处理 URL Scheme、Universal Link 和 Android 签名。

正式开发前应再次核实当前认证主体、审核和费用规则。

## 10. iOS 上架手册

### 10.1 账号与标识

1. 注册 Apple ID 并开启双重认证。
2. 加入 [Apple Developer Program](https://developer.apple.com/programs/whats-included/)，费用为 99 美元/年。
3. 公司主体准备 D-U-N-S 编号和授权人信息；个人主体的卖家名称会显示法定姓名。
4. 确定最终 Bundle ID。推荐与域名一致，例如 `com.jiatingbaowei.ios`。
5. 在 App Store Connect 创建 App，名称使用“家庭保卫战”。App 名称最长 30 个字符。

### 10.2 提交前代码清单

- Release API 改为 `https://api.jiatingbaowei.com`。
- Release 不再请求仅用于局域网调试的权限。
- 移除或禁用所有未实现的 Apple、微信和测试兑换码入口。
- 完成正式登录和账号注销。
- 所有网络请求只使用 HTTPS。
- 会员购买使用 StoreKit，并支持恢复购买。
- 权限申请文案与实际功能一致。
- 后端始终在线，审核账号可以完成 OWNER/MEMBER 双账号流程。

Apple 要求提供账号注册的 App 允许用户在 App 内发起账号删除。参见[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)。

### 10.3 App Store Connect 素材

准备：

- App 图标和启动画面。
- iPhone 截图，按后台当前要求提供相应尺寸。
- App 名称、副标题、描述和关键词。
- 隐私政策 URL、技术支持 URL。
- 年龄分级问卷。
- App Privacy 数据收集问卷，包含第三方 SDK。
- 中国大陆 App 备案信息。
- 审核说明和两个可用测试账号。

隐私问卷参考：[Manage App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)。

### 10.4 TestFlight

1. Xcode 选择 `Any iOS Device`，执行 Product > Archive。
2. 在 Organizer 选择 Distribute App > App Store Connect > Upload。
3. 先添加内部测试人员。
4. 完成内部主流程测试后，再申请外部 TestFlight 测试。
5. 每个候选版本都验证登录、家庭审核、记录、点赞、删除、排行、月报、会员和注销。

参考：[TestFlight Overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview)。

### 10.5 提交审核

1. 选择已处理完成的 build。
2. 填写版本说明和审核信息。
3. 提供审核测试账号，并说明如何用邀请码完成双账号流程。
4. 确保后端在审核期间持续可用。
5. 提交审核后关注 App Review 消息，并及时回复。
6. 建议首版选择手动发布，确认线上 API 和备案无误后再点发布。

参考：[App Store Connect 工作流](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow)和[提交 App 审核](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)。

## 11. Android 开发与上架手册

### 11.1 当前状态

当前仓库没有 Android 客户端，因此现在只能准备账号、资质、域名、备案、软著和后端，不能直接生成安卓安装包并提交商店。

### 11.2 推荐技术方案

- 语言：Kotlin。
- UI：Jetpack Compose。
- 架构：MVVM，与 iOS 的页面和状态职责保持一致。
- 网络：Retrofit/OkHttp 或 Ktor Client。
- 本地安全存储：Android Keystore + 加密存储，不把 token 明文放普通 SharedPreferences。
- 依赖注入：Hilt。
- 异步：Kotlin Coroutines + Flow。
- 包名：第一次提交前固定，例如 `com.jiatingbaowei.android`。
- 最低系统：可从 Android 8.0 / API 26 起步，再根据目标用户调整。
- 目标 SDK：从项目创建时直接按 API 36 适配。Google Play 从 2026-08-31 起要求新应用和更新以 Android 16 / API 36 或更高为目标，参见[官方要求](https://developer.android.com/google/play/requirements/target-sdk?hl=zh-CN)。

不要把 SwiftUI 代码机械翻译成 Compose。应共用 API 协议、产品规则、视觉资产和验收用例，各平台保留符合系统习惯的交互。

### 11.3 Android 开发阶段

1. 创建独立的 `apps/android` 工程。
2. 建立 Debug、局域网和 Production 三套 API 环境。
3. 实现登录、家庭、家务、动态、排行、月报和会员状态。
4. 复用现有后端 DTO，并增加契约测试，防止 iOS/Android 字段不一致。
5. 完成深色模式取舍、字体缩放、TalkBack 和不同屏幕尺寸适配。
6. 增加单元测试、Compose UI 测试和真机冒烟测试。
7. 在 CI 中增加 Android lint、unit test 和 release build。

### 11.4 签名文件

1. 创建正式 keystore，使用强密码。
2. keystore、alias 和密码不要提交 Git。
3. 至少保存两份离线加密备份；丢失签名可能导致国内渠道无法更新同一个 App。
4. 所有国内商店使用相同的包名和正式签名。
5. Google Play 新应用使用 Play App Signing，参见[Android App Signing](https://developer.android.com/studio/publish/app-signing)。

### 11.5 软件著作权

国内 Android 商店经常要求应用版权材料。建议尽早通过[中国版权保护中心登记系统](https://register.ccopyright.com.cn/registration.html#/registerSoft)准备软件著作权。

华为当前说明中，包含中国大陆的手机应用需要应用版权证书或代理证书，电子版权证书为可选材料，参见[华为版权信息要求](https://developer.huawei.com/consumer/cn/doc/App/agc-help-release-app-copyright-0000002278981450)。

不要把“电子版权证书”默认视为所有商店都接受的软件著作权替代品。

### 11.6 国内安卓商店顺序

建议第一批覆盖：华为、小米、OPPO、vivo、荣耀、应用宝。

| 平台 | 官方入口 | 提交前重点 |
|---|---|---|
| 华为 AppGallery | [开发者联盟](https://developer.huawei.com/consumer/cn/appgallery/) | 版权材料、App 备案、隐私与 SDK 清单 |
| 小米应用商店 | [小米开放平台](https://dev.mi.com/docs/appsmarket/distribution/app_submit/) | 实名、包名签名、隐私和资质 |
| OPPO 软件商店 | [OPPO 开放平台](https://open.oppomobile.com/) | 隐私合规、自测和资质 |
| vivo 应用商店 | [vivo 开放平台](https://dev.vivo.com.cn/) | 隐私、权限、SDK 和兼容性 |
| 荣耀应用市场 | [荣耀开发者服务平台](https://developer.honor.com/cn/) | 版权、备案、隐私和测试 |
| 应用宝 | [腾讯开放平台](https://open.tencent.com/) | 包名签名、备案、隐私与安全检测 |

各商店页面和材料名称会调整，提交前以后台显示为准。不要同时盲目提交，建议顺序是：华为试投并修正材料，再批量处理其他市场。

### 11.7 国内 Android 隐私合规

重点准备：

- 首次运行隐私弹窗，在同意前不要初始化非必要 SDK 或收集数据。
- 隐私政策列出每类数据、用途、保存期限和删除方式。
- 单独列出第三方 SDK 名称、提供方、目的、数据类型和隐私链接。
- 权限按使用时申请，不在启动时一次性索要。
- App 内提供账号注销入口。
- 备案号、隐私政策和运营主体信息容易找到。
- 对短信、设备标识和日志进行最小化收集。

### 11.8 构建和提交

1. 生成经过正式 keystore 签名的 release 包。
2. 国内商店按后台要求上传 APK 或 AAB。
3. Google Play 上传 AAB，参考[Upload Your App to Play Console](https://developer.android.com/studio/publish/upload-bundle)。
4. 填写应用名称、简介、详细介绍、截图、图标、隐私政策、内容分级和数据安全表。
5. 先发布到内部/封闭测试，再逐步开放生产版本。
6. 每个渠道记录版本号、审核意见和差异化要求。

### 11.9 Android 会员付费

- 国内商店需要按各渠道当前支付政策分别核实。
- Google Play 版的数字会员使用 Google Play Billing。
- 服务器负责校验购买凭证并维护家庭会员权益。
- 不要在商店正式版本中使用测试兑换码绕过数字内容支付。
- “家庭任一成员开通，全家可用”可以保留，但必须由后端验证有效购买并同步权益。

## 12. 双平台共用的版本规则

建议统一产品版本，例如 `1.0.0`，但平台内部构建号分别递增：

- iOS：Marketing Version `1.0.0`，Build `1`、`2`、`3`。
- Android：versionName `1.0.0`，versionCode `1`、`2`、`3`。

每次发布都记录：

- 后端镜像版本和数据库 migration。
- iOS build number。
- Android versionCode 和各渠道审核状态。
- 隐私政策版本。
- 回滚方式。

## 13. 推荐排期

下面按一名主要开发者估算，可以并行办理资质。审核时间不受开发者完全控制，要留余量。

### 第 0 周：冻结身份和品牌

- 决定个人、个体工商户或公司主体。
- 最终确认“家庭保卫战”、域名、iOS Bundle ID 和 Android 包名。
- 购买域名、服务器，申请 Apple Developer。
- 启动软件著作权准备。

### 第 1–2 周：基础设施与备案

- 域名实名认证、DNS、网站和 HTTPS。
- 提交网站备案与 App 备案资料。
- 注册微信开放平台和安卓商店账号。
- 验证邮箱发信域名和验证码模板，完成 Apple/微信或 Google 平台资料。
- Codex 可并行建立生产 Docker、备份、监控和部署 workflow。

### 第 2–4 周：生产正确性

- Apple、邮箱验证码及对应发行区域的微信或 Google 登录。
- access/refresh token、限流和安全日志。
- App 内账号注销。
- StoreKit 会员和后端凭证校验。
- 部署 staging，进行双账号端到端测试。

### 第 4–5 周：iOS 候选版本

- 隐私政策和支持网页定稿。
- 内部 TestFlight、外部 TestFlight。
- 整理截图、元数据、备案和审核账号。
- 提交 App Store 审核。

### Android 客户端：建议另计 6–10 周

- 第 1 周：工程、DesignSystem、网络和环境配置。
- 第 2–3 周：登录和家庭流程。
- 第 4–6 周：家务、动态、排行、月报和会员。
- 第 7–8 周：适配、测试、合规和性能。
- 第 9–10 周：商店材料、内测和首批市场审核缓冲。

可以在 Android 开发期间并行完成开发者账号、软著和 App 备案平台信息准备。

## 14. 哪些事情需要你本人完成

### 必须由你完成

- 决定和提供真实上架主体。
- 支付域名、服务器、Apple Developer 和平台认证费用。
- 完成身份证、营业执照、人脸识别、短信验证和法律声明。
- 接收并确认备案电话或核验信息。
- 签署 Apple、微信、云服务和安卓商店协议。
- 最终确认隐私政策、用户协议和付费条款。
- 在后台进行涉及主体责任的最终提交和发布确认。

### Codex 可以协助完成

- 编写生产 Docker、Compose、Caddy/Nginx 和部署脚本。
- 补齐环境变量模板、健康检查、备份和监控。
- 实现正式认证、账号注销和购买凭证校验。
- 准备备案技术参数、SDK 清单和隐私政策初稿。
- 整理 App Store 和安卓商店文案、截图尺寸和审核说明。
- 创建 Android 工程并实现与 iOS 对齐的功能。
- 配置 CI/CD、执行自动化测试和发布前审计。

Codex 不能代替你购买服务、冒用身份、完成人脸核验或替你接受法律条款。

## 15. 推荐执行顺序

1. **先定主体**：这是域名、备案、开发者账号和支付能力的根。
2. **买域名和服务器**：首选 `jiatingbaowei.com` + 腾讯云 2C4G 大陆服务器。
3. **立即启动备案和软著**：它们的审核等待时间可以和开发并行。
4. **完成生产后端基础设施**：HTTPS、Docker、备份、监控、健康检查。
5. **完成正式登录和注销**：这是 iOS 与 Android 的共同上架阻断项。
6. **先完成 iOS TestFlight**：已有客户端，离上架最近。
7. **再建立 Android 客户端**：直接采用 API 36、正式包名和正式签名，避免后期返工。
8. **安卓先投一家市场校正材料**：通过后再扩展到其他渠道。

## 16. 最终发布检查

### 公共基础设施

- [ ] 主体、域名、服务器、备案和开发者账号一致。
- [ ] 正式 API 使用 HTTPS，生产域名不再是占位地址。
- [ ] 数据库和 Redis 未暴露公网。
- [ ] 生产 secret 未进入 Git。
- [ ] migration、备份、恢复、监控和回滚已经演练。
- [ ] 隐私、协议、支持和注销网页已上线。
- [ ] Apple、邮箱及对应发行区域的微信或 Google 登录按实际展示状态可用。
- [ ] App 内账号注销可用。
- [ ] 生产环境不包含测试会员兑换入口。

### iOS

- [ ] Bundle ID 和品牌名已冻结。
- [ ] Release 不使用局域网地址或占位域名。
- [ ] Archive 和 TestFlight 主流程通过。
- [ ] App Privacy、年龄分级、截图和审核账号完整。
- [ ] 中国大陆备案信息正确。
- [ ] StoreKit 购买和恢复购买通过沙盒测试。

### Android

- [ ] Android 客户端已创建并完成核心流程。
- [ ] 包名和正式签名已冻结并离线备份。
- [ ] targetSdk 达到提交时最新要求。
- [ ] App 备案已增加 Android 平台信息。
- [ ] 软件著作权/版权材料满足目标商店要求。
- [ ] 隐私弹窗、权限、SDK 清单和账号注销通过合规自查。
- [ ] 各渠道包和会员支付规则分别验证。

## 17. 官方入口汇总

- [Apple Developer Program](https://developer.apple.com/programs/enroll/)
- [App Store Connect](https://appstoreconnect.apple.com/)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple 中国大陆合规信息](https://developer.apple.com/cn/help/app-store-connect/manage-compliance-information/view-mainland-china-compliance-information/)
- [工信部 App 备案通知](https://www.gov.cn/zhengce/zhengceku/202308/content_6897341.htm?type=mobile-internet)
- [腾讯云备案](https://cloud.tencent.com/product/ba)
- [腾讯云轻量应用服务器](https://cloud.tencent.com/product/lighthouse)
- [腾讯云短信](https://cloud.tencent.com/document/product/382)
- [微信开放平台](https://open.weixin.qq.com/)
- [中国版权保护中心登记系统](https://register.ccopyright.com.cn/registration.html#/registerSoft)
- [Android Developer](https://developer.android.com/)
- [Google Play Console](https://play.google.com/console/)
- [华为 AppGallery](https://developer.huawei.com/consumer/cn/appgallery/)
- [小米开放平台](https://dev.mi.com/)
- [OPPO 开放平台](https://open.oppomobile.com/)
- [vivo 开放平台](https://dev.vivo.com.cn/)
- [荣耀开发者服务平台](https://developer.honor.com/cn/)
- [腾讯开放平台](https://open.tencent.com/)
