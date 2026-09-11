# 家庭保卫战：Android 开发与上架手册

> 更新日期：2026-08-11
> 当前状态：仓库中尚未创建 Android 客户端。本手册是 Android 立项、开发和上架路线，不代表相关功能已经完成。
> 域名、服务器、备案、正式登录和生产部署请先阅读 [DEPLOYMENT_AND_STORE_RELEASE_GUIDE.md](./DEPLOYMENT_AND_STORE_RELEASE_GUIDE.md)。

## 1. 推荐路线

家庭保卫战的 Android 版建议使用原生技术栈：

- Kotlin
- Jetpack Compose
- MVVM
- Coroutines + Flow
- Retrofit/OkHttp 或 Ktor Client
- Hilt
- Android Keystore + 加密本地存储

Android 与 iOS 共用：

- NestJS 后端和 PostgreSQL 数据库
- API 协议和 DTO 含义
- 账号、家庭、权限、积分和会员规则
- 品牌颜色、插画和验收场景

Android 不直接复用 SwiftUI 代码。两个客户端分别实现系统原生交互，后端契约保持一致。

## 2. 开工前先冻结的内容

1. 应用名称：`家庭保卫战`。
2. 正式包名：建议 `com.jiatingbaowei.android`。
3. 正式签名 keystore。
4. 生产 API：建议 `https://api.jiatingbaowei.com`。
5. 上架主体：优先公司，或先核实目标渠道是否接受个体工商户。
6. 最低 Android 版本：建议 Android 8.0 / API 26 起步。
7. targetSdk：按提交时 Google Play 最新要求；以当前计划应直接适配 API 36。

Google Play 从 2026-08-31 起要求新应用和更新以 Android 16 / API 36 或更高为目标，参见[官方 Target API 要求](https://developer.android.com/google/play/requirements/target-sdk?hl=zh-CN)。

## 3. 推荐工程目录

```text
apps/android/
├── app/
├── core/
│   ├── designsystem/
│   ├── network/
│   ├── database/
│   └── security/
├── feature/
│   ├── auth/
│   ├── family/
│   ├── chores/
│   ├── dashboard/
│   ├── reports/
│   └── profile/
└── build-logic/
```

先保持单 App module 也可以。只有当编译速度和团队规模确实需要时再拆更多 module。

## 4. Android 开发顺序

### 阶段 A：工程基础

- 创建 Compose 工程和统一 DesignSystem。
- 建立 `debug`、`localNetwork`、`release` 环境。
- Release 只允许 HTTPS 正式 API。
- 配置网络、JSON、错误映射和 token 自动刷新。
- 使用 Keystore 支持的安全存储保存 token。
- 增加 unit test、lint 和 CI release build。

### 阶段 B：核心主链路

按以下顺序与 iOS 对齐：

1. 国内 Apple/微信/邮箱与海外 Apple/Google/邮箱的区域登录策略。
2. 创建家庭、邀请码加入、OWNER 审核。
3. 家务库、常用家务、自定义家务和实际耗时。
4. 动态、表情互动、删除和成员权限。
5. 本周战况、月报和成就。
6. 家庭会员状态和购买恢复。
7. 修改资料、退出家庭和注销账号。

### 阶段 C：Android 专项

- 返回手势和系统导航。
- 不同屏幕密度、折叠屏和横屏的基础适配。
- 字体缩放和 TalkBack。
- 后台恢复、进程被杀和网络切换。
- 权限按需申请，不在启动时集中索取。
- 首次隐私同意前不初始化非必要第三方 SDK。

## 5. 签名管理

正式签名一旦用于上架，就属于应用身份。

1. 创建独立 release keystore。
2. alias 和密码使用密码管理器保存。
3. keystore 至少保存两份离线加密备份。
4. 不要提交 keystore、`keystore.properties` 或密码到 GitHub。
5. 国内所有渠道使用同一包名和同一正式签名。
6. Google Play 使用 Play App Signing。

官方说明：[Android App Signing](https://developer.android.com/studio/publish/app-signing)。

## 6. 中国大陆上架资质

通常需要准备：

- 主体证件和开发者账号认证
- App 备案号
- 软件著作权或商店认可的版权材料
- 隐私政策和用户协议 URL
- 第三方 SDK 清单
- 个人信息收集清单
- 权限用途说明
- App 图标、截图、简介和内容分级
- 包名、版本号和签名信息
- App 内账号注销路径

软件著作权申请入口：[中国版权保护中心登记系统](https://register.ccopyright.com.cn/registration.html#/registerSoft)。

App 备案中需要补充 Android 包名、签名公钥/摘要等平台信息，可参考[腾讯云 App 备案材料说明](https://cloud.tencent.com/document/product/243/97691)。

## 7. 国内商店推荐顺序

### 第一批

1. 华为 AppGallery
2. 小米应用商店
3. OPPO 软件商店
4. vivo 应用商店
5. 荣耀应用市场
6. 应用宝

建议先提交华为，使用第一轮审核反馈修正隐私、备案和版权材料，再批量提交其他商店。

### 官方入口

- [华为 AppGallery](https://developer.huawei.com/consumer/cn/appgallery/)
- [小米开放平台](https://dev.mi.com/)
- [OPPO 开放平台](https://open.oppomobile.com/)
- [vivo 开放平台](https://dev.vivo.com.cn/)
- [荣耀开发者服务平台](https://developer.honor.com/cn/)
- [腾讯开放平台 / 应用宝](https://open.tencent.com/)

各渠道可能要求不同格式的安装包、截图、版权和隐私表格。以提交当天后台显示为准。

## 8. 华为上架示例流程

1. 注册并认证华为开发者账号。
2. 在 AppGallery Connect 创建应用。
3. 填写应用名称、默认语言、包名和分类。
4. 上传正式签名的 release 包。
5. 填写版本说明、截图、图标、隐私政策和备案信息。
6. 上传应用版权证书或代理证书。
7. 完成隐私、安全、内容分级和适配检查。
8. 先进行开放测试或分阶段发布，再正式上架。

华为当前说明中，发布范围包含中国大陆的手机应用需要应用版权证书或代理证书，参见[版权信息要求](https://developer.huawei.com/consumer/cn/doc/App/agc-help-release-app-copyright-0000002278981450)。

## 9. Google Play 路线

Google Play 主要用于海外市场。准备：

- Google Play Console 开发者账号和身份验证
- Android App Bundle（AAB）
- Play App Signing
- Data safety 表单
- 隐私政策 URL
- 内容分级
- 商店图、截图和介绍
- 内部、封闭和开放测试轨道
- Google Play Billing 数字会员

构建和上传说明：[Upload Your App to Play Console](https://developer.android.com/studio/publish/upload-bundle)。

新账号可能有额外的测试和身份验证要求，以 Play Console 当前提示为准。

## 10. 会员付费

家庭保卫战的规则是“家庭中任一成员有效开通，全家共享会员”。实现时：

1. 客户端发起平台购买。
2. 后端验证购买凭证。
3. 后端把有效权益记录到家庭，而不是只存在某台手机。
4. 家庭成员刷新后获得相同会员状态。
5. 退款、过期或撤销后，后端同步回免费状态。

Google Play 版使用 Google Play Billing。国内安卓渠道需分别核实其数字内容支付规则。正式渠道包不能保留测试兑换码作为绕过商店支付的通道。

## 11. Android 测试清单

- [ ] 单元测试覆盖积分、权限、DTO 和会员规则。
- [ ] API 契约测试保证 Android/iOS 字段一致。
- [ ] Compose UI 测试覆盖登录、家庭和记录主链路。
- [ ] 真机覆盖至少一台华为系和一台非华为设备。
- [ ] 弱网、断网、token 失效和进程被杀后可恢复。
- [ ] 大字体和 TalkBack 可操作。
- [ ] 隐私同意前没有非必要数据请求。
- [ ] 权限拒绝后 App 不崩溃且有替代路径。
- [ ] 账号注销后本地 token 和用户数据清理。
- [ ] release 包连接生产 API，不包含调试入口和测试兑换码。

## 12. Android 上架时间估算

在 iOS 功能和 API 已稳定的前提下，一名主要开发者建议预留：

| 阶段 | 估算 |
|---|---:|
| 工程、环境、DesignSystem、网络 | 1 周 |
| 登录和家庭主流程 | 1–2 周 |
| 家务、动态、排行、月报和会员 | 3–4 周 |
| 兼容、无障碍、测试与合规 | 1–2 周 |
| 商店内测和审核缓冲 | 1–2 周 |

合计约 6–10 周。备案、软件著作权和开发者账号应与开发并行，避免代码完成后等待资质。

## 13. 你与 Codex 的分工

你需要完成：

- 主体认证、购买和法律协议。
- Android 商店开发者账号实名认证。
- 软件著作权和 App 备案中的身份核验。
- 正式签名备份的最终保管。
- 商店后台涉及主体责任的最终提交。

Codex 可以完成：

- 创建 Android 工程和功能实现。
- 配置 API、签名读取、测试和 CI。
- 整理隐私、SDK、权限和商店素材清单。
- 生成 release 候选包并进行自动化检查。
- 根据商店审核反馈修复代码或材料。

## 14. Android 开工检查

- [ ] 上架主体已经确定。
- [ ] 正式包名已经确定。
- [ ] 主域名和生产 API 已经确定。
- [ ] 后端正式认证和账号注销方案已确定。
- [ ] Android 签名保管方案已确定。
- [ ] 软件著作权已经开始准备。
- [ ] App 备案计划包含 Android 平台信息。
- [ ] 首批目标商店已经确定。
- [ ] 设计资产确认可以跨平台使用。
- [ ] Android 开发排期和测试设备已经准备。
