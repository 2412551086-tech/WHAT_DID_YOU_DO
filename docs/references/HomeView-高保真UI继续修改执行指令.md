# HomeView 高保真 UI 继续修改执行指令

## 使用方式

将本文件整份交给 Codex，并同时附上之前的左右对比图。

对比图角色已确认：

```text
左侧：最终高保真目标稿
右侧：当前 SwiftUI 实际运行效果
```

---

## 给 Codex 的执行指令

你现在要继续修正「你今天干啥啦」App 的 `HomeView`，使其字体、页面结构、卡片比例、列表分组和整体密度接近左侧高保真目标稿。

这是一次“已有页面的视觉纠偏”，不是重写 App，也不是重构业务层。

必须先完整阅读：

```text
agent.md
docs/references/Codex-AI-SwiftUI-高保真UI重构执行指南.md
```

并检查当前相关代码：

```text
apps/ios/Sources/DesignSystem/DSColors.swift
apps/ios/Sources/DesignSystem/DSCard.swift
apps/ios/Sources/DesignSystem/AvatarView.swift
apps/ios/Sources/Features/Home/HomeView.swift
apps/ios/Sources/Features/Home/ActivityRow.swift
apps/ios/Sources/App/MainTabView.swift
apps/ios/Sources/ViewModels/AppViewModel.swift
```

## 一、已确认的问题

不要重新猜测左右图的角色。左侧是目标，右侧是当前实现。

当前实现存在以下明确偏差：

1. 全局 `appTitle` / `appHeadline` / `appBody` 使用 `.rounded`，且广泛使用 `.black` / `.heavy` / `.semibold`，导致功能页中文字形比目标稿更圆、更粗。
2. `HomeView` 用 `List` 组合多个独立卡片，且每个 `ActivityRow` 都包装了一张 `DSQuietCard`。
3. 目标稿中的家庭动态是“一个白色容器里的连续列表行”，不是“每条动态一张独立卡片”。
4. 当前主积分卡、个人统计卡和动态行的 Padding、固定高度、头像和按钮尺寸偏大，使整体比目标稿更松、更高。
5. 左侧目标稿不包含状态栏，右侧实际图包含 Dynamic Island。测量 Y 坐标时必须以 Safe Area 内容起点归一，不得直接比较图片顶部。
6. 两侧数据不同：目标稿为 128 分、6 次、多条动态；实际图为 79 分、3 次、3 条动态。这会影响进度条、列表总高和“查看全部 / 共 N 条”条件文案。

## 二、必须保留的业务能力

必须保留：

- `AppViewModel` 和当前数据来源
- Mock / API 切换
- 家庭信息、今日积分和活动数据
- Loading、Empty、Error 和 Content 状态
- 点赞、取消点赞和请求中状态
- 点赞成员头像
- 有权限用户的左滑软删除
- 删除后刷新
- `NavigationStack`、TabView 和当前四个 Tab
- Safe Area、滚动和 Tab Bar 内容避让
- Dynamic Type、长昵称和大积分数字的可用性

禁止：

- 修改 Model、DTO、API Contract、Network、后端或数据库
- 新建第二套 ViewModel
- 使用生产假数据替换真实数据
- 删除点赞、删除或状态处理来简化 UI
- 把高保真图、卡片、按钮或文字做成页面图片
- 为了单个页面盲目修改所有页面共享的字体 Token

## 三、写代码前的短分析

不要只输出方案后停止。先在 commentary 中给出一份简短《Home 单页视觉合同》，然后直接继续实现。

视觉合同至少包含：

1. 主参考设备、逻辑宽度和 Safe Area 基准。
2. Home 顶层区块顺序。
3. 目标卡片数量与哪些内容共享同一容器。
4. 功能页字体角色表：Font Family / Fallback、Size、Weight、Design、Line Height。
5. 页面边距、主卡宽高、左右分栏比例、统计卡高度、动态行高度和区块间距的估算值。
6. 目标稿数据快照与当前实际数据不可直接比较的部分。

如果 PNG 无法确定精确字体家族，使用以下默认决策继续实现，不要因此停止：

```text
功能页中文：iOS 系统默认字体 / `.default` design
页面大标题：使用测量后的字号，字重优先 `.bold`，不默认 `.black`
正文：`.regular` 或 `.medium`，不默认 `.semibold`
禁止：`.rounded`、`.heavy` 和重复 `.fontWeight(.bold)`
```

## 四、实现要求

### 4.1 字体

1. 不要继续让 Home 使用现有的圆角黑体 `appTitle` / `appHeadline` / `appBody`。
2. 在现有 DesignSystem 中增加或完善功能页语义字体 Token，例如：

```swift
DSFont.functionalPageTitle
DSFont.functionalSectionTitle
DSFont.functionalCardTitle
DSFont.functionalBody
DSFont.functionalCaption
```

3. 功能页 Token 使用 `.default` design。
4. 保留登录页等强表现页面的现有视觉；不要通过全局修改使其回归。
5. 修改前搜索全部字体 Token 调用点。
6. 不使用 `minimumScaleFactor` 掩盖错误的基础字号或容器宽度。

### 4.2 页面与主积分卡

1. 以 Safe Area 内容起点对齐目标稿，不复制目标 PNG “没有状态栏”的裁切方式。
2. 保持顺序：页面标题 → 家庭积分卡 → 个人统计卡 → 家庭动态标题 → 家庭动态列表。
3. 将家庭积分卡收紧到目标稿的比例，重新校准：

- 外部宽高
- 卡片 Padding
- 左侧积分区宽度
- 中间分隔线高度
- 右侧“今日战线”宽度
- 底部汇总行高度

4. 不允许卡片因 `ViewThatFits` 意外切换成竖向布局。主参考设备必须稳定保持目标稿的左右分栏。
5. 真实数据可以不同，但不得因数字不同破坏对齐和卡片结构。

### 4.3 个人统计卡

1. 保留三等分列和两条分隔线。
2. 收紧卡片高度、垂直 Padding、标题与数值间距。
3. 保留蓝、绿、橙三种数值色，但颜色和字重以目标稿为准。
4. 不放大文字来填满卡片。

### 4.4 家庭动态

1. 将动态区改成目标稿的“一个白色容器内的多条连续列表行”。
2. 每个 `ActivityRow` 不再自带完整外层独立卡片。
3. 列表行之间使用目标稿风格的细分隔线。
4. 第一行和最后一行共享外层容器圆角。
5. 保留 `List` 中的左滑删除能力。如果使用 `List` 才能稳定保留 `swipeActions`，则通过连续 `listRowBackground`、去掉行间空隙和首尾圆角来实现单容器视觉，不要为了做大卡片而丢失滑动操作。
6. 缩小到目标稿密度：

- 主头像
- 点赞成员小头像
- 行高
- 文字垂直间距
- 积分文字
- 点赞按钮和计数间距

7. 点赞按钮必须保持至少 44 × 44 pt 可点击区域；可以让视觉圆形更小，但不得牺牲无障碍触控区域。
8. “查看全部”与“共 N 条”必须继续由真实条件决定。为对比目标稿，在 Preview 或 Debug-only Fixture 中提供超过预览上限的动态数据，不要修改生产判断。

### 4.5 Tab Bar

1. 保留当前四个 Tab 和导航行为。
2. 根据目标稿校准透明度、背景、选中色、图标和标签层级。
3. 不允许 Tab Bar 遮住第二条动态或其他列表内容。
4. 如果系统 TabView 已能接近目标，优先保留系统 TabView，不要为静态还原新建一套导航状态。

## 五、参考数据与 Preview

为了可重复对比左侧目标稿，在现有 Preview / Mock 工厂中增加或完善一个 Debug-only Home 参考状态：

- 家庭总积分接近 128
- 今日完成 6 次
- 累计时长接近 145 分钟
- 我的积分接近 42
- 至少 5 条可见动态，总条数超过预览上限
- 包含已点赞、未点赞和多个点赞成员头像
- 包含长度不同的家务名和昵称

参考数据只能进入 Preview、Debug-only Fixture 或现有 Mock 路径，不能污染 API 生产状态。

如果 Simulator 只能显示当前真实数据，则允许数值和条数不同，但对比报告必须将数据差异和视觉差异分开。

## 六、允许修改的文件

优先只修改：

```text
apps/ios/Sources/DesignSystem/DSColors.swift
apps/ios/Sources/DesignSystem/DSCard.swift
apps/ios/Sources/Features/Home/HomeView.swift
apps/ios/Sources/Features/Home/ActivityRow.swift
apps/ios/Sources/App/MainTabView.swift
```

如果字体 Token 值得拆成独立文件，可以在现有 DesignSystem 目录中新增语义化字体文件，但不建立第二套 DesignSystem。

如果确实需要修改其他文件，必须先说明原因和影响范围。

## 七、轻量 Xcode 和 Simulator 验证

代码实现完成后，允许你轻量使用 Xcode 相关命令和 Simulator。

执行顺序：

```text
静态检查
→ 一次目标 Scheme 增量 Build
→ 只运行相关 XCTest
→ 启动或复用一台主参考 Simulator
→ 进入 Home
→ 获取 1–2 张截图
→ 与目标图对比
→ 一次集中修正
→ 最多再执行一次 Build 和截图复核
```

约束：

- 每轮最多 2 次主动 Build
- 只使用 1 台主参考 Simulator
- 每轮只保留 1–2 张必要截图
- 不执行 Clean Build
- 不删除 DerivedData
- 不启动多设备矩阵
- 不运行无关全量 UI 测试
- 不针对单个 padding 反复 Build
- 如果等待或卡住约 5 分钟仍无明显进展，停止自动验证，保留已完成修改，并向用户提供手测清单

## 八、截图视觉 QA

对比前：

1. 从左右拼接图中分离目标稿和当前截图。
2. 归一到同一逻辑宽度。
3. 以 Safe Area 起点对齐。
4. 生成 50% 透明度叠加图或边缘对比图。
5. 将数据状态不同造成的差异单独列出。

差异优先级：

```text
P0：字体整体风格错误、列表分组错误、主卡比例严重错误、Tab Bar 遮挡内容、功能丢失
P1：页边距、字号字重、卡片宽高、分栏比例、Row 高度、头像和图标尺寸不一致
P2：阴影、圆角、细颜色和 1–2 pt 局部差异
```

必须先清除 P0，再一次性集中处理 P1。不对单个数值做无依据的 `+1 / -1` 循环。

## 九、完成标准

只有同时满足以下条件，才能标记本轮 Home 纠偏完成：

- [ ] Home 的功能页字体不再继承 `.rounded + .black/.heavy` 的旧风格
- [ ] 页面标题、副标题、卡片标题、正文和 Caption 层级接近目标稿
- [ ] 主积分卡和统计卡的宽高及分栏比例接近目标稿
- [ ] 动态区是一个连续容器内的多行列表，不是每行独立卡片
- [ ] 点赞、取消点赞、点赞头像和左滑删除保留
- [ ] Loading、Empty、Error 状态保留
- [ ] Tab Bar 没有遮挡列表
- [ ] 不同数据状态不会破坏页面结构
- [ ] 增量 Build 通过，或已说明自动验证无法完成的原因
- [ ] 相关 XCTest 通过，或已转为用户手测
- [ ] 已获取实际截图并完成对比
- [ ] P0 已清零
- [ ] P1 已处理或有明确说明
- [ ] 未修改 Model、ViewModel、API、Network 或后端业务行为

## 十、最终交付格式

完成后输出：

```text
1. 本轮完成结果
2. 修改文件
3. 字体 Token 和组件调整
4. 主卡、统计卡和动态列表的结构变化
5. 明确保留的业务能力
6. Build 和 XCTest 结果
7. Simulator 设备与截图位置
8. 目标稿与实际图的 P0 / P1 / P2 差异
9. 尚未验证的内容
10. 是否修改了业务层；如没有，明确写“本轮未修改业务层”
```

不要在第一次修改后因为“大概相似”就停止。在轻量验证边界内，完成一次截图 QA 和一次集中修正后再交付。
