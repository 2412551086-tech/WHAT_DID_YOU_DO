# Codex AI：SwiftUI 高保真 UI 重构执行指南 V3.1

## 1. 指南目的

本指南用于指导 Codex 将已经确认的高保真设计，稳定地落地到现有 SwiftUI App。

本项目已经完成可联调 MVP，UI 重构的目标是：

> 在不破坏真实业务、数据、导航、鉴权和自动化验收能力的前提下，建立统一的视觉语言，并逐页完成高保真 SwiftUI 实现。

这不是重新生成 App，也不是借 UI 重构之名重写业务架构。

核心原则：

```text
先冻结功能基线
→ 明确设计真相
→ 审计现有代码与 DesignSystem
→ 建立设计、数据和代码映射
→ 冻结字体、画布、组件分组和几何规格
→ 先完成代表性纵向切片
→ Codex 完成静态检查和轻量编译验证
→ Codex 短时运行单一 Simulator 并截图
→ 集中校准视觉
→ 再扩展到其他页面
→ 最后统一验收状态、适配和无障碍
```

---

## 2. 当前功能基线

UI 重构开始前，必须把当前已经跑通的 MVP 能力视为受保护基线。

当前受保护主链路包括：

```text
免登录创建本地体验家庭
→ 本地家务与记录持久化
→ 需要云端能力时通过 Apple、微信或邮箱验证码登录
→ Keychain 恢复登录与会话
→ 创建家庭
→ 邀请码申请加入
→ OWNER 审核
→ 获取家务
→ 选择实际耗时
→ 创建家务记录和计算积分
→ 今日动态与最近动态
→ 排行榜与月报
→ 点赞与取消点赞
→ 左滑软删除
→ 家庭时区统计
```

必须保留：

- `AppViewModel` 现有业务行为和状态来源
- Session 恢复状态
- Keychain Token 管理
- Mock / API 模式
- API 环境配置
- Models、DTO 和 API Contract
- Navigation 和 TabView
- Loading、Empty 和 Error 状态
- 点赞、取消点赞、删除和刷新逻辑
- OWNER / MEMBER 权限
- `actualMinutes` 和积分计算
- `day` / `recent` 动态范围
- 家庭时区规则
- 已有 XCTest、后端测试、Smoke Test 和 GitHub Actions

UI 重构默认禁止：

- 新建第二套 ViewModel
- 新建平行的状态管理体系
- 修改 API 字段或请求方式
- 用 Mock 数据替换 API 真实数据
- 写死用户、家庭、积分或动态数据
- 删除原有交互或状态
- 为了贴图效果改变业务行为
- 一次性重写全部页面

如高保真设计包含当前基线不存在的功能，必须进入“功能缺口处理流程”，不能把它伪装成静态 UI。

---

## 3. 设计真相优先级

本项目存在高保真图、风格文档、原型规划和现有代码。发生冲突时，必须按照以下优先级判断：

```text
1. 用户最新明确确认
2. 最终高保真图片
3. docs/STYLE_GUIDE_V2.md
4. docs/UI_PROTOTYPE_PLAN.md
5. 当前 SwiftUI 代码
```

补充规则：

- 视觉规范以最终高保真图片为主要依据。
- 用户最新确认可以覆盖任何旧设计决定。
- 当前代码用于理解已有功能和约束，不自动代表最终视觉标准。
- PRD 和 API 文档仍然是业务能力、数据和权限的事实来源。
- 如果视觉设计与 PRD 或真实业务冲突，必须保留业务并报告冲突。
- 如果两个高保真页面互相矛盾，应暂停相关视觉实现并请用户确认。
- 所有截图测量值都应标记为“估算值”，不能伪装成设计源文件中的精确值。
- 高保真图中的组件顺序、分组方式、容器数量、信息层级和主要交互入口默认视为已冻结，Codex 不得自行重新设计。
- 不得把“一个卡片内的连续列表”改成“每行一张独立卡片”，也不得把设计稿中的按钮、链接或文案擅自换成另一种信息。
- 如果对比图没有标明“目标稿”和“实际运行图”，必须先确认，不得凭感觉猜测。

每轮 UI 任务开始前，需要记录：

```text
目标页面：
目标高保真图：
适用风格文档：
当前业务数据来源：
目标图的参考数据快照：
用户本轮最新确认：
存在的设计冲突：
最终采用依据：
```

---

## 4. Codex、Xcode、Simulator 和用户职责

### 4.1 Codex 默认责任

Codex 负责：

- 阅读仓库规则、业务代码、UI 代码和设计文档
- 审查工作区状态，保护用户已有改动
- 拆解高保真图和 SwiftUI 视图结构
- 建立设计、数据和代码映射
- 修改 SwiftUI、DesignSystem 和必要的 App 运行资源
- 检查真实数据流和原有交互是否保留
- 完成编译前静态检查
- 使用命令行或 XcodeBuildMCP 进行有边界的增量编译和相关 XCTest
- 短时使用单一目标 Simulator 启动 App、进入目标页面并截图
- 对比目标高保真图与实际运行截图
- 输出 P0、P1、P2 差异并集中修正
- 如果自动验证过慢、卡住或环境不稳定，立即停止并将验证清单交给用户

### 4.2 Xcode 与 Simulator 轻量使用约束

本项目允许 Codex 轻量使用 Xcode 相关命令和 Simulator。

允许：

- 完成一个连贯代码修改后，执行一次目标 Scheme 的非交互增量 Build。
- 运行与当前修改直接相关的 XCTest，不运行无关全量测试。
- 复用已启动的 Simulator，或只启动一台主参考设备。
- 短时启动 App、进入当前目标页面、检查主要交互并获取 1–2 张必要截图。
- 完成一次集中视觉修正后，再执行一次最终增量 Build 和截图复核。

禁止：

- 默认打开或长时操作 Xcode GUI。
- 执行 Clean Build、删除 DerivedData 或使用其他破坏性缓存清理方式，除非用户明确授权。
- 启动多台 Simulator、运行全量 UI 自动化或长时占用设备。
- 因为单个 padding 或字号连续反复 Build。
- 关闭、重置或改变用户事先已打开的 Simulator 状态，除非是完成当前任务的必要步骤。

轻量使用上限：

```text
每个视觉修正轮次：最多 2 次主动 Build
主参考 Simulator：1 台
每轮必要截图：1–2 张
无明显进展的等待或卡住：约 5 分钟后停止并报告
```

如果 Build 或 Simulator 明显拖慢设备，Codex 必须停止自动验证，保留已完成修改，并向用户提供人工验证清单。

### 4.3 验证底线

修改后不能把静态检查描述为“已通过 Xcode 验证”。SwiftUI 的类型推断、ViewBuilder、资源名和 Target Membership 问题可能只有编译时才暴露。

完整验证链路是：

```text
Codex 静态检查
→ Codex 轻量增量 Build
→ Codex 运行相关 XCTest
→ Codex 短时 Simulator 手测和截图
→ Codex 完成视觉对比
```

如果自动验证因过慢、卡住、签名、环境或数据条件无法完成，必须明确标记：

```text
代码修改和静态检查已完成，自动 Xcode / Simulator 验证未完成。已停止继续占用设备，请用户按清单完成人工验证。
```

---

## 5. 开始任务前的必做检查

修改任何代码前，必须：

1. 阅读仓库中的 `agent.md`、适用文档和本指南。
2. 检查当前分支、worktree 和工作区状态。
3. 确认没有覆盖用户未提交修改。
4. 记录当前功能基线和已有测试结果。
5. 识别 iOS Project、Scheme、Deployment Target 和目标页面。
6. 查明目标页面的数据来源、状态和交互。
7. 找到现有 DesignSystem、通用组件和 Assets Catalog。
8. 找到目标高保真图及其最终版本。
9. 明确本轮允许修改与禁止修改的文件。
10. 检查设计中是否存在当前业务没有的能力。

如果工作区已有修改：

- 不得覆盖、回滚或丢弃。
- 不得使用破坏性 Git 操作清理工作区。
- 只修改本轮目标文件。
- 如果修改重叠，先解释冲突和处理方式。

---

## 6. 阶段一：审计当前项目

### 6.1 代码审计

重点检查：

- App 启动状态和 Session 恢复
- `AppViewModel` 的状态与行为
- 页面生命周期和请求时机
- NavigationStack、Sheet 和 TabView
- Loading、Empty、Error 和 Content 状态
- 点赞、删除、审核和刷新回调
- Preview 数据是否只用于 Preview
- XCTest 覆盖范围

### 6.2 DesignSystem 审计

在添加 Token 或组件前，检查：

- 颜色是否语义化
- 字体层级是否统一
- 页面间距是否稳定
- 圆角是否有清晰层级
- 描边粗细是否符合最终高保真图
- 阴影是硬阴影、柔和阴影还是玻璃效果
- 相同组件是否被重复实现
- 单个文件是否承载过多不相关组件
- 全局 Token 的修改是否会影响其他页面
- 是否支持 Dynamic Type 和无障碍

特别需要解决的视觉冲突：

```text
登录页可以保留更强的漫画、新粗野主义和冰箱贴表现。
功能页应以高保真图为准，控制粗描边、硬阴影和彩色面积。
全局 Token 不应为了一个页面被盲目修改。
```

审计时必须搜索：

```text
.rounded / .serif / .monospaced
.black / .heavy / .bold / fontWeight
Font.custom
minimumScaleFactor
GeometryReader / UIScreen 宽度缩放
List / Section / listRowInsets
每行包装 DSCard / DSQuietCard 的情况
```

搜索结果必须与高保真的字体角色和结构不变项对照。现有组件只因为“可复用”，不代表它的视觉样式符合目标稿。

### 6.3 审计输出

审计阶段只分析，不改代码。输出至少包括：

```text
A. 当前页面结构
B. 数据和状态来源
C. 必须保留的交互
D. 当前 DesignSystem 能力
E. 可复用组件
F. 需要重构的组件
G. 设计与当前代码的冲突
H. 功能缺口
I. 风险
J. 推荐实施范围
```

---

## 7. 阶段二：工程化拆解高保真设计

### 7.1 页面结构拆解

把视觉稿转换为 SwiftUI 视图树。例如：

```text
HomeView
├── PageHeader
├── TodayScoreCard
├── PersonalStatsRow
├── ActivitySectionHeader
├── ActivityList
│   └── ActivityRow
└── MainTabView
```

视图树必须结合高保真图的视觉分组和实际代码确定。实际代码决定数据与交互怎样保留，高保真图决定内容怎样分组和排列。

必须额外输出“结构不变项”：

```text
顶层区块顺序：
卡片数量：
哪些内容共享同一容器：
哪些内容是容器内的列表行：
分隔线位置：
按钮、链接和计数文案的位置：
Tab Bar 是系统组件还是自定义组件：
```

未记录的结构不得在实现阶段擅自改成另一种卡片或列表模式。

### 7.2 视觉规格提取

记录：

- 画布和目标设备
- Safe Area
- 页面左右边距
- 顶部位置
- 区块间距
- 卡片 Padding
- 卡片尺寸和比例
- 字号、字重和行高
- 颜色和透明度
- 圆角
- 描边
- 阴影
- Material / Blur
- Avatar 和 Icon 尺寸
- Row 高度
- Tab Bar 安全区
- 键盘和滚动行为

无法从位图准确获取时，使用：

```text
估算值：16 pt
依据：393 pt 画布与相邻元素比例
验证方式：用户提供实际运行截图后校准
```

#### 7.2.1 截图画布归一化

测量之前必须先建立同一坐标系。记录：

```text
目标图是否包含状态栏：
实际图是否包含状态栏：
目标设备逻辑宽度：
源图单屏像素宽度：
像素与 point 比例：
顶部坐标基准：图片顶部 / Safe Area 顶部
底部坐标基准：画布底部 / Tab Bar 顶部
```

如果用户提供的是左右拼接对比图，必须先裁出两个独立画面，再分别归一化，不得直接用整张拼接图的宽度计算 SwiftUI point。

换算方式：

```text
scale = 单屏截图像素宽度 / 目标设备逻辑宽度
point = 测得像素 / scale
```

目标图不含状态栏、实际图含 Dynamic Island 或状态栏时，不得直接比较绝对 Y 坐标。应以 Safe Area 内容起点为共同基准。

#### 7.2.2 字体取证与冻结

不得只记录“标题 34 pt”。每个文字角色必须记录：

| 文字角色 | 文案样例 | Font Family / Fallback | Size | Weight | Design | Line Height | 缩放规则 |
|---|---|---|---|---|---|---|---|
| 页面大标题 | 今日战况 | 待确认 | 估算 | 待确认 | default / rounded | 估算 | 不按屏幕宽度缩放 |
| 正文 | 家庭今日总积分 | 待确认 | 估算 | 待确认 | default / rounded | 估算 | Dynamic Type |

优先级：

```text
Figma / 设计源文件的字体信息
→ 用户明确确认的字体
→ App 已注册且与目标稿相符的字体
→ iOS 系统默认中文字体与 `.default` design
```

仅凭 PNG 无法可靠确定字体家族时，必须标记“字体家族待确认”。不得因为现有 DesignSystem 使用 `.rounded`、`.black` 或 `.heavy` 就直接套用到功能页。

中文字体还必须检查 fallback。如果 `Font.custom` 不包含中文字形，中文可能回退到另一字体，导致中英文字重、字宽和行高不一致。

禁止：

- 在已经使用 `.black` 或 `.heavy` 的 Token 上再叠加 `.bold()` 或 `.fontWeight(.bold)`。
- 为追求截图尺寸而按屏幕宽度整体缩放字号。
- 未经设计依据使用 `.rounded`、`.serif` 或 `.monospaced` design。
- 使用 `minimumScaleFactor` 掩盖基础字号或布局错误。

#### 7.2.3 几何规格表

开始写代码前，至少为主参考设备输出：

| 区域 | X | Y（相对 Safe Area） | Width | Height | 内边距 | 与下一区域间距 | 分组方式 |
|---|---:|---:|---:|---:|---:|---:|---|
| PageHeader | 估算 | 估算 | 估算 | 估算 | — | 估算 | 独立 |
| TodayScoreCard | 估算 | 估算 | 估算 | 估算 | 估算 | 估算 | 单一卡片 |
| ActivityList | 估算 | 估算 | 估算 | 估算 | 估算 | — | 一个容器内多行 |

不得只给出“大约 20 pt 边距”就开始实现。顶层卡片的宽高、内部分栏比例、列表容器方式和 Tab Bar 占位必须先写入规格表。

#### 7.2.4 写代码前的视觉合同

Codex 必须先交付一份《单页视觉合同》：

```text
1. 目标图与实际图的角色标记
2. 主参考设备和 Safe Area 基准
3. 视图树与结构不变项
4. 字体角色表
5. 几何规格表
6. 颜色、圆角、描边和阴影表
7. 参考数据快照和条件分支
8. 估算值和待用户确认项
```

在这份合同完成之前，不得开始大规模修改 HomeView 或全局 DesignSystem。字体家族、顶层结构、主卡比例或 Tab Bar 形式存在歧义时，必须等待用户一次性确认这些关键决策；已确认后不在每个小间距上机械询问。

#### 7.2.5 参考数据快照

视觉对比必须尽量使用同一数据状态。从目标图记录：

```text
总积分：
完成次数：
累计时长：
个人积分和排名：
动态条数：
姓名、家务名和文字长度：
点赞数和已点赞状态：
Loading / Empty / Error / Content：
会触发的条件 UI：例如“查看全部”或“共 N 条”
```

如果用户实际数据与目标图不同：

- 优先在 Preview、Debug-only Fixture 或现有 Mock 模式中建立可重复的参考数据，不得写入生产数据路径。
- 用户无法运行同一数据时，将“结构和几何对比”与“文案和条件状态对比”分开。
- 不得为了让不同数据的截图看起来相同，修改正确的业务条件。
- 数据状态不一致时，先在 QA 报告中标记“不可直接比较”，再评估可比较的视觉部分。

### 7.3 状态补全

高保真图通常只展示理想状态。必须补齐：

- Loading
- Empty
- Error
- 0 分
- 无动态
- 长昵称
- 大积分
- 图片缺失
- 点赞中、已点赞、点赞失败
- 删除中、删除失败
- 权限不足
- 网络断开
- 小屏幕
- Dynamic Type
- VoiceOver

---

## 8. 阶段三：建立“设计 → 数据 → SwiftUI”映射

写代码前必须建立映射表：

| 设计区域 | SwiftUI 组件 | 真实数据来源 | 当前是否存在 | 实施方式 | 是否需要运行资源 |
|---|---|---|---|---|---|
| 今日总积分 | `TodayScoreCard` | `AppViewModel.todayPoints` | 是 | 重构视觉 | 否 |
| 动态头像 | `AvatarView` | Activity 成员信息 | 是 | 参数化复用 | 可能 |
| 点赞成员头像 | `ActivityRow` | `likedBy` | 是 | 保留交互并更新布局 | 可能 |

逐项回答：

1. 是否有真实数据支持？
2. 数据来自 Model、DTO、ViewModel 还是派生计算？
3. 哪些内容不能写死？
4. 哪些交互必须保留？
5. 哪些元素使用 SF Symbols？
6. 哪些元素需要 App 运行资源？
7. 哪些只是设计参考，不应进入 App？
8. 是否存在业务、权限或 API 缺口？

---

## 9. 功能缺口处理

高保真图中出现当前项目没有的按钮、数据、页面或流程时，标记为“功能缺口”。

分类：

### A. 纯界面能力

数据和业务已存在，只缺展示或入口。可以作为 UI 重构实施。

### B. 客户端本地能力

需要本地状态或持久化，但不需要后端。必须先确认状态所有权和生命周期。

### C. 现有数据的派生能力

需要新计算规则。必须明确公式和计算位置，不能在 SwiftUI `body` 中堆复杂业务计算。

### D. 完整业务新功能

需要 Model、API、后端、数据库或权限。必须从 UI 重构中拆出，等待用户确认后单独实施。

### E. 设计歧义

无法判断是装饰还是功能时，不猜测交互，列出可选解释并等待确认。

禁止：

- 静默省略
- 画出无效按钮
- 写死假数据
- 假设后端已经支持
- 未经确认修改 Model、API 或数据库

涉及业务层修改时，必须先输出：

```text
功能：
触发方式：
预期结果：
当前支持情况：
缺失层：
最小实现：
影响范围：
需要用户确认：
```

只有业务或产品范围不明确时才需要暂停等待确认。纯视觉实现不应在每一个小步骤机械等待。

---

## 10. DesignSystem 实施规则

### 10.1 Token

优先复用语义 Token：

```swift
DSColor.pageBackground
DSColor.primaryText
DSColor.secondaryText
DSColor.brand
DSColor.success
DSColor.warning

DSSpacing.page
DSSpacing.section
DSSpacing.cardPadding

DSCornerRadius.card
DSCornerRadius.control

DSShadow.soft
DSShadow.sticker
```

规则：

- 不为每个数值建立 Token。
- 页面独有数值保留在页面组件内。
- 相同语义不得重复命名。
- 修改共享 Token 前查明所有调用点。
- 登录页强视觉与功能页轻视觉可以通过 Style 变体区分。
- 不建立第二套 DesignSystem。

#### 字体 Token 规则

字体必须按高保真角色建立语义 Token，不得用一个“全 App 黑体圆角标题”覆盖所有页面。

推荐区分：

```swift
DSFont.functionalPageTitle
DSFont.functionalSectionTitle
DSFont.functionalCardTitle
DSFont.functionalBody
DSFont.functionalCaption

DSFont.expressivePageTitle
DSFont.expressiveHeadline
```

其中：

- `functional*` 用于今日战况、记一下、月度战报和我的等功能页，字体家族、字重和 `design` 必须与高保真图一致。
- `expressive*` 只用于确实需要漫画、新粗野主义或强表现风格的页面。
- 如果功能页目标图是常规 iOS 中文字体，优先使用 `.system(..., design: .default)`，不得继承 `.rounded`。
- `.black` 和 `.heavy` 只能在目标稿明确显示同等字重时使用；功能页不得因旧 Token 默认值而被全局加粗。
- 修改字体 Token 前必须用 `rg` 查明所有调用点，避免为了 Home 破坏登录页或其他页面。
- 如果现有 `appTitle` / `appHeadline` / `appBody` 与高保真不符，不得直接沿用；应先拆分功能页与强表现页的字体角色。

### 10.2 组件

按实际需求实现或完善：

```text
DSCard
DSButton
DSIconButton
DSBadge
AvatarView
DSStatusBanner
```

通用组件必须：

- 使用语义 Token
- 通过参数接收内容
- 不依赖 `AppViewModel`
- 不包含业务请求
- 不写死生产数据
- 支持 Dynamic Type
- 有合理的无障碍标签
- 提供 Preview

避免把所有组件持续堆进一个大文件。按照职责拆分，但不要为了目录整齐过度抽象。

---

## 11. iOS 17 与玻璃效果规则

当前项目需要兼容 iOS 17。

玻璃效果优先使用：

- SwiftUI `Material`
- 合理透明度
- 轻描边
- 柔和阴影
- 背景层次

规则：

- 高保真图中的“系统玻璃”是视觉目标，不等于必须使用最新系统 API。
- 新系统能力必须提供 iOS 17 兼容回退。
- 不为了追求 iOS 26 效果提高最低系统版本。
- 不使用大面积玻璃覆盖正文内容。
- 玻璃主要用于 Tab Bar、浮动工具和 Sheet。
- 玻璃效果不能降低文字对比度和触控辨识度。

---

## 12. 资产治理

### 12.1 三层资产

#### A. App 运行资源

路径：

```text
apps/ios/Resources/Assets.xcassets
```

包括：

- App Icon
- App 启动或登录插画
- 实际使用的人物头像
- 实际使用的人物立绘
- 无法由 SF Symbols 或 SwiftUI Shape 实现的必要图形

这些资源是构建和运行所必需，应经过压缩、命名和 Target Membership 检查后进入 Git。

#### B. 设计源素材

包括：

- Figma 导出页面
- AI 原始生成图
- 人物原稿
- 标注稿
- PSD、FIG、Sketch
- 未选中的方案
- 高分辨率设计过程图

本项目约定：

> 设计源素材不上传 GitHub。

设计源素材保存在本机设计目录，不直接拖进 Xcode，不作为 App 构建输入。

#### C. 临时输出

包括：

- `design-output/`
- `.impeccable/`
- Screenshot QA 临时图
- Codex 生成预览
- 对比图
- 缓存

这些文件不进入 Git。

### 12.2 Asset Manifest

UI 重构前建议建立：

```text
docs/ASSET_MANIFEST.md
```

至少记录：

| key | App Asset 名称 | 来源 | 用途 | 是否进入 App | 压缩状态 |
|---|---|---|---|---|---|
| `avatar_01` | `Avatar01` | 本地人物原稿 | 成员头像 | 是 | 已压缩 |

代码只引用 Asset Catalog 名称：

```swift
Image("Avatar01")
```

禁止引用设计源文件路径或使用：

```swift
Image("final_final_v3_new.png")
```

### 12.3 图片进入 App 的流程

```text
Figma / AI / 原始设计
→ 本地设计源目录
→ 选择最终资源
→ 裁切和压缩
→ 命名
→ Assets.xcassets
→ SwiftUI 使用
→ 编译和截图验证
```

禁止把以下内容导入为位图：

- 完整页面
- 带文字按钮
- 输入框
- 列表
- 进度条
- Tab Bar
- 卡片背景
- 点赞控件

### 12.4 Git 规则

必须忽略：

```text
.impeccable/
design-output/
设计源素材目录
截图对比临时目录
DerivedData/
xcuserdata/
*.xcuserstate
```

暂不对所有 PNG 启用 Git LFS。

只有 App 实际运行需要的大资源接近仓库限制时，才评估压缩、WebP 替代方案、资源拆分或 Git LFS。不能把整个设计目录批量纳入 LFS 后继续上传所有过程素材。

---

## 13. 第一轮实施顺序

### 阶段 0：冻结功能基线

1. 记录当前主链路。
2. 记录当前测试结果。
3. 确认 UI 分支和干净工作区。
4. 确认设计源素材不会进入 GitHub。
5. 确认最终高保真图。
6. 明确标记哪张是目标稿，哪张是实际运行图。
7. 确认主参考设备、逻辑宽度、状态栏和 Safe Area 基准。
8. 完成《单页视觉合同》，再进入实现。

### 阶段 1：审计 DesignSystem

重点统一：

- 描边
- 阴影
- 功能页与强表现页的字体角色
- Font Family / Fallback
- 字号、字重、Design 和行高
- 间距
- 圆角
- 页面背景
- 状态颜色
- 登录页与功能页的 Style 变体

此阶段不重写业务页面。

### 阶段 2：代表性纵向切片

先实现：

```text
HomeView
+ ActivityRow
+ MainTabView / TabBar
```

选择这一组是因为它同时覆盖：

- 页面标题和主卡
- 真实积分数据
- 列表
- 头像
- 点赞
- 删除
- Loading / Empty / Error
- Tab 导航
- Safe Area

写代码前必须冻结：

- Home 顶层区块顺序
- 家庭积分卡的宽高和左右分栏比例
- 个人统计卡的高度和三列比例
- 家庭动态是“一张大卡内多行”还是“每行独立卡片”
- 动态区右侧是“查看全部”还是“共 N 条”，以目标稿与状态规则为准
- Tab Bar 形式、高度和内容避让方式

完成代码后必须：

1. Codex 完成静态检查。
2. Codex 执行一次目标 Scheme 的增量 Build 和相关 XCTest。
3. Codex 短时使用单一主参考 Simulator 启动 App。
4. Codex 验证真实 API / Mock 状态没有被替换。
5. Codex 获取 1–2 张必要截图。
6. Codex 与高保真图比较。
7. 清除 P0，集中处理 P1。
8. 集中修正后最多再执行一次 Build 和截图复核。
9. 冻结组件方向后再继续。

如果上述步骤明显变慢或卡住，停止自动验证并输出用户手测清单。

### 阶段 3：家务选择纵向切片

实现：

```text
ChoreSelectionView
+ ChoreDurationPickerSheet
```

必须保留：

- 免费和高级家务状态
- 锁定逻辑
- 上次耗时记忆
- 1...180 分钟
- 实时积分计算
- Mock / API 创建记录
- 确认后刷新

### 阶段 4：家庭流程

按顺序处理：

```text
CreateFamilyView
→ JoinFamilyView
→ JoinRequestsView
```

必须保留：

- 身份和自定义身份
- Avatar Key
- Timezone
- Invite Code
- PENDING / ACTIVE / REJECTED
- OWNER approve / reject
- 图片凭证入口禁用规则

### 阶段 5：其余主页面

按顺序处理：

```text
MonthlyReportView / FamilyDashboardView
→ ProfileView
→ DebugPanel
```

DebugPanel 只能在 Debug 显示，且不能暴露完整 Token。

### 阶段 6：全局状态与适配

统一验收：

- 小屏幕
- Dynamic Type
- VoiceOver
- Loading
- Empty
- Error
- 长昵称
- 大积分
- 无头像
- 网络失败
- 权限不足
- 键盘遮挡
- Safe Area

---

## 14. Preview 与测试

### 14.1 Preview

每个主要组件至少覆盖适用状态：

1. 普通数据
2. 0 分或空内容
3. 长昵称
4. 大积分
5. 图片缺失
6. Loading
7. Error

Preview 数据只能存在于 Preview 或 Mock 工厂，不能进入 API 生产路径。

### 14.2 编译与 XCTest

每个纵向切片完成后：

- Codex 完成代码静态检查。
- Codex 优先使用非交互命令或 XcodeBuildMCP 执行目标 Scheme 的增量 Build。
- Codex 只运行与当前纵向切片直接相关的 iOS XCTest。
- 每轮最多主动 Build 两次：首次实现后一次，集中修正后一次。
- 如果 Build 明显变慢、卡住或重复失败，Codex 停止自动验证并输出人工测试清单。
- 新增纯 UI 时，不为截图样式编写脆弱业务测试。
- 新增可复用的格式化或派生逻辑时，补充单元测试。
- 不删除或绕过已有测试来获得绿色结果。

GitHub Actions 应继续验证：

- iOS `build-for-testing`
- iOS XCTest
- 后端 Build、Jest、e2e 和 Smoke Test

### 14.3 Simulator 视觉矩阵

默认只在一台与高保真画布宽度一致的主目标 Simulator 上执行轻量视觉验证。较小屏幕、大字号和更广的状态矩阵交给用户或 CI 后续验收，除非当前任务明确要求。

自动验证默认选择：

- 一个与高保真画布宽度一致的主目标设备
- 默认文字大小
- 高保真对应的浅色或深色模式
- 一个可重复的参考数据状态

关键页面至少检查：

- 默认文字大小
- 较大 Dynamic Type
- 浅色模式
- API 正常数据
- Empty 或 Error 状态

当前 MVP 不要求深色模式高保真，但不能出现完全不可读的系统状态。

自动截图或用户返回截图时都应记录：

```text
设备型号：
系统版本：
逻辑宽度：
文字大小：
浅色 / 深色：
页面数据状态：
截图是否包含状态栏和 Tab Bar：
```

---

## 15. 截图视觉 QA

实际运行截图优先由 Codex 通过短时 Simulator 会话获取；如果自动会话过慢、卡住或无法进入目标数据状态，则由用户提供。Codex 使用：

```text
已标明的目标高保真图
+ Codex 或用户获取的 Simulator / 真机实际截图
```

进行对比。

对比前必须：

1. 确认哪张是目标稿，哪张是实际图。
2. 如果是拼接图，先分离两个画面。
3. 把两张图归一到同一逻辑宽度。
4. 统一状态栏、Safe Area 和 Tab Bar 基准。
5. 核对两张图的参考数据快照和条件 UI 是否一致。
6. 优先生成 50% 透明度叠加图或边缘对比图，不只靠肉眼并排观察。

数据不一致时，必须先输出：

```text
可直接比较：字体、页边距、主卡比例、圆角等
不可直接比较：列表总高、条件文案、进度条比例等
需要匹配的参考数据：
```

第一次对比先输出问题，不立即零散改代码。

优先级：

- `P0`：页面错误、内容遮挡、功能不可用、严重偏离
- `P1`：主要层级、尺寸、颜色、间距或组件风格不一致
- `P2`：不影响方向的细节差异

检查：

- 页面边距
- 顶部位置
- 字体家族和中文 fallback
- 字号、字重、Design 和行高
- 顶层区块顺序
- 容器数量和列表分组方式
- Card 尺寸
- Card 内部分栏比例
- 圆角
- 描边
- 阴影
- 背景色
- Accent Color
- Avatar
- Icon
- Row 高度
- Tab Bar
- Safe Area
- 截断
- Dynamic Type 风险

输出格式：

| 优先级 | 区域 | 目标效果 | 当前效果 | 修改建议 | 修改层级 |
|---|---|---|---|---|---|
| P1 | 今日积分卡 | 高度约 188 pt | 约 212 pt | 减少垂直 Padding | 页面组件 |

主参考设备的建议验收差异：

| 项目 | 允许差异 | 超出后的优先级 |
|---|---:|---|
| 顶层区块顺序、分组和容器数量 | 不允许擅自改变 | P0 |
| 主页边距、主卡宽高和顶部位置 | 约 ±4 pt | P1；严重时 P0 |
| 区块间距和 Row 高度 | 约 ±3 pt | P1 |
| 字号 | 约 ±1 pt | P1 |
| 字体家族、Design 和字重档位 | 必须一致 | P1；全页错误时 P0 |
| 圆角 | 约 ±2 pt | P2；方向错误时 P1 |

差异阈值用于防止“大概像”就通过，不用于破坏 Dynamic Type、真实数据展开或无障碍。如果必须偏离目标稿才能保留功能，必须在报告中说明。

修改层级只能是：

```text
DesignSystem Token
通用组件
页面组件
页面布局
```

如果数值来自截图，必须写“约”或“估算”。

---

## 16. 集中视觉修正

视觉修正顺序：

```text
全局 Token 问题
→ 通用组件问题
→ 页面组件问题
→ 页面独有布局
```

允许修改：

- Spacing
- Padding
- Frame
- Typography
- Colors
- Radius
- Shadow
- Material
- Alignment
- Icon Size
- Layout

禁止为了视觉修正修改：

- API
- Network
- 数据库
- 鉴权
- 家庭权限
- 点赞逻辑
- 删除逻辑
- 登录逻辑
- 统计规则

推荐节奏：

```text
第一次实现
→ Codex 静态检查
→ Codex 轻量增量 Build 和相关测试
→ Codex 短时运行单一 Simulator 并截图
→ 一次视觉 QA
→ 一次集中修正
→ Codex 最多再执行一次 Build 和截图复核
```

如果任一自动验证步骤明显变慢或卡住，立即转为用户手测，不继续占用设备。

避免没有依据的 `+1 / -1` 循环。

---

## 17. 无障碍与适配验收

### 17.1 触控

- 主要交互区域至少 44 × 44 pt。
- 图标按钮必须有 Accessibility Label。
- 禁用状态不能只靠透明度表达。

### 17.2 Dynamic Type

- 不使用按屏幕宽度缩放字体。
- 卡片允许纵向扩展。
- 长昵称和大积分不得覆盖其他内容。
- 网格在大字号下必要时切换单列。

### 17.3 VoiceOver

- Activity Row 按自然顺序朗读身份、家务、耗时、积分和点赞状态。
- 装饰图片隐藏无障碍焦点。
- 头像提供成员名称或身份描述。
- 图标按钮说明动作而不是图标名称。

### 17.4 状态

- 错误不能只用红色表达。
- 排名不能只用金银铜颜色表达。
- 选中状态同时使用图标、文字或形状。
- Loading 时防止重复提交。

---

## 18. Git 与工作树规则

UI 重构应在明确的 UI 分支或工作树进行。

每轮开始前：

- 检查当前工作树是否正确。
- 检查基线提交。
- 检查未提交修改。
- 检查忽略文件。

禁止提交：

```text
.env
node_modules/
DerivedData/
xcuserdata/
*.xcuserstate
.DS_Store
.impeccable/
design-output/
设计源素材
临时截图和对比图
```

推荐提交粒度：

```text
refactor(ui): align design tokens and shared components
refactor(ui): implement home activity vertical slice
refactor(ui): implement chore selection vertical slice
refactor(ui): align family flow screens
test(ui): add regression coverage for presentation logic
```

不要把业务功能、数百张设计源图和 UI 代码混在同一个提交中。

---

## 19. 每阶段交付格式

开始前说明：

```text
当前阶段：
目标页面：
设计依据：
目标图 / 实际图标记：
主参考设备与 Safe Area 基准：
视觉合同状态：
预计修改文件：
明确不修改：
需要运行资源：
验证方式：
```

完成后报告：

```text
1. 完成结果
2. 修改文件
3. Token 和组件调整
4. 保留的业务行为
5. Codex 静态检查结果
6. 轻量 Build / XCTest 结果
7. Simulator 设备、会话时长和手测结果
8. Codex 或用户提供的截图位置
9. 如转为用户手测，说明原因和待验证清单
10. 字体、结构和几何的 P0 / P1 / P2 差异
11. 尚存风险
12. 下一阶段
```

未执行或因过慢、卡住而中止的验证必须明确写“未完成，需要用户验证”，不能描述为通过。

---

## 20. 完成标准

单页或纵向切片只有同时满足以下条件，才能标记为完成：

- [ ] 使用真实数据驱动
- [ ] 未修改 API Contract
- [ ] 未创建第二套 ViewModel
- [ ] 未把设计图当页面背景
- [ ] 未把文字、按钮或列表图片化
- [ ] 功能缺口已识别
- [ ] 未用假数据伪装功能
- [ ] 已标明目标稿和实际运行图
- [ ] 已冻结主参考设备、Safe Area 与坐标基准
- [ ] 已交付并遵守《单页视觉合同》
- [ ] 字体家族、Fallback、Size、Weight、Design 和行高已核对
- [ ] 顶层区块顺序、容器数量和列表分组与高保真一致
- [ ] 主卡、统计卡、列表和 Tab Bar 的几何差异在约定范围内
- [ ] Navigation 和 TabView 正常
- [ ] 点赞、删除等原有交互正常
- [ ] Loading、Empty、Error 状态保留
- [ ] 支持长昵称和大积分
- [ ] 支持小屏幕和 Safe Area
- [ ] 支持 Dynamic Type
- [ ] 关键控件有无障碍语义
- [ ] 公共样式已正确沉淀
- [ ] 设计源素材未上传 GitHub
- [ ] App 运行资源经过压缩并登记
- [ ] Codex 已完成静态检查
- [ ] 轻量增量 Build 已通过，或已明确转为用户手测
- [ ] 相关 XCTest 已通过，或已明确转为用户手测
- [ ] 单一主参考 Simulator 运行正常，或已记录无法验证的原因
- [ ] 已获取实际截图和设备信息
- [ ] 已完成高保真对比
- [ ] P0 已清零
- [ ] P1 已处理或有明确说明
- [ ] 未覆盖用户已有修改

---

## 21. 单个纵向切片执行模板

```text
Step 1：确认工作树、分支和功能基线

Step 2：确认用户最新设计决定和最终高保真图

Step 3：标明目标稿与实际图，确认设备、状态栏和 Safe Area 基准

Step 4：按照设计真相优先级解决冲突

Step 5：审查页面、数据、交互、DesignSystem 和测试

Step 6：输出视图树、结构不变项和设计 → 数据 → SwiftUI 映射

Step 7：输出字体角色表，检查中文 Fallback 与现有字体 Token

Step 8：输出几何规格表和《单页视觉合同》

Step 9：识别功能缺口

Step 10：确定允许和禁止修改范围

Step 11：检查需要的 App 运行资源及 Asset Manifest

Step 12：完善 DesignSystem Token 和 Style 变体

Step 13：实现通用组件

Step 14：实现页面组件

Step 15：接入真实数据和已有交互

Step 16：Codex 完成静态检查

Step 17：Codex 执行一次轻量增量 Build 和相关 XCTest

Step 18：Codex 短时运行单一主参考 Simulator 并获取 1–2 张截图

Step 19：Codex 归一化目标图与实际图，生成叠加或边缘对比

Step 20：输出字体、结构、几何和样式的 P0 / P1 / P2

Step 21：集中修正

Step 22：Codex 最多再执行一次增量 Build 和截图复核

Step 23：如自动验证过慢或卡住，停止并输出用户手测清单

Step 24：Codex 提交验收报告
```

最终准则：

> 用户最新确认决定方向，高保真图决定字体、结构和视觉，真实业务决定边界；先冻结视觉合同，再改 DesignSystem 和页面；Codex 可轻量执行增量 Build、相关测试、单一 Simulator 和截图，但过慢或卡住时必须停止并转为用户手测；先完成一个纵向切片并验证，再扩展到全 App。
