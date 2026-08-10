# ChoreSelectionView 高保真 UI 继续修改执行指令

## 使用方式

将本文件整份交给 Codex 执行。本任务的目标稿、当前截图和已抠图标素材都已存放在项目内，不需要再从对比图重新抠图。

角色已确认：

```text
对比图左侧：最终高保真目标稿
对比图右侧：当前 SwiftUI 实际运行效果
```

---

## 给 Codex 的执行指令

你现在要继续修正「你今天干啥啦」App 的「记一下」页面 `ChoreSelectionView`，使其字体、图标、卡片密度、分类文案、高级家务横向列表和 Tab Bar 避让接近高保真目标稿。

这是一次已有页面的视觉纠偏和正式资源接入，不是重写业务、计分规则或会员逻辑。

## 一、必须先阅读和检查

必须先阅读：

```text
agent.md
docs/references/Codex-AI-SwiftUI-高保真UI重构执行指南.md
```

目标与 QA 图片：

```text
独立目标稿：
design-assets/Final_product/02-screens/main-tabs/02-chore-selection.png

左右对比图：
design-output/ui-qa/chore-selection-comparison.jpg

当前实际截图：
design-output/ui-qa/chore-selection-final.jpg
```

已抠好的正式图标资源：

```text
design-assets/Final_product/04-chore-icons/extracted-from-chore-selection/
```

联系表：

```text
design-assets/Final_product/04-chore-icons/extracted-from-chore-selection/chore-icons-contact-sheet.png
```

必须检查的现有代码：

```text
apps/ios/Sources/Features/Chores/ChoreSelectionView.swift
apps/ios/Sources/Features/Chores/ChoreDurationPickerSheet.swift
apps/ios/Sources/DesignSystem/DSCard.swift
apps/ios/Sources/DesignSystem/DSColors.swift
apps/ios/Sources/Models/Models.swift
apps/ios/Sources/Mock/MockData.swift
apps/ios/Sources/ViewModels/AppViewModel.swift
apps/ios/Sources/App/MainTabView.swift
apps/ios/Resources/Assets.xcassets
```

不要只看拼接图猜尺寸。优先使用独立目标稿与当前实际截图进行归一化对比。

## 二、已确认的差异

1. 目标稿的核心家务卡使用手绘彩色插画图标，当前实现仍使用 SF Symbols。
2. 目标图标已完成抠图，不得再从截图裁切，也不得使用新生成的近似图替代。
3. 当前页面仍使用 `.rounded` 与过重字重，比目标稿更圆、更黑。
4. 目标稿的图标比当前 SF Symbol Tile 更大、细节更丰富，卡片内文字与图标的比例不同。
5. 目标稿使用更精确的展示分类，例如“烹饪”、“餐厨清洁”、“衣物整理”、“地面清洁”，当前页面直接显示“厨房类”、“洗护类”等后端大类。
6. 高级家务标题与卡片在当前截图中被 Tab Bar 遮挡，底部滚动避让不足。
7. 目标稿不包含状态栏，当前图包含 Dynamic Island。顶部位置必须以 Safe Area 内容起点归一，不得用截图绝对 Y 坐标直接对比。
8. 高级家务目标稿中的时长和积分是设计示例，与当前真实 Model / API 可能不同。不得为匹配截图修改真实时长、积分、锁定状态或权益规则。

## 三、必须保留的能力

必须保留：

- `AppViewModel` 和当前数据来源
- Mock / API 切换
- 核心家务与高级家务的真实分组
- 点击核心家务后打开 `ChoreDurationPickerSheet`
- 实际耗时 1...180 分钟选择
- 上次耗时记忆
- 实时积分计算和提交后刷新
- 高级家务锁定状态和解锁提示
- 编辑模式
- 置顶和取消置顶
- 拖动排序
- Loading 和 Error 状态
- Dynamic Type 下必要时切换单列
- 四个 Tab 和导航状态

禁止：

- 修改 Model、DTO、API Contract、Network、后端、数据库或计分规则
- 修改高级会员判定或锁定逻辑
- 新建第二套 ViewModel
- 用截图中的静态时长和积分替换真实数据
- 删除编辑、置顶、拖动、Sheet 或高级家务提示来简化 UI
- 把整张高保真页面或带文字的卡片作为图片放入 App

## 四、写代码前的短视觉合同

不要只分析后停止。先在 commentary 中输出一份简短《ChoreSelection 单页视觉合同》，然后直接继续实现。

视觉合同至少包含：

1. 主参考设备、逻辑宽度和 Safe Area 基准。
2. 顶层区块顺序：页面标题 → 核心家务 → 两列卡片 → 高级家务 → 横向锁定卡片。
3. 字体角色表：Font Family / Fallback、Size、Weight、Design 和 Line Height。
4. 页边距、标题位置、编辑按钮尺寸、网格间距、卡片宽高、图标尺寸、分类行位置、高级卡片尺寸和底部避让的估算值。
5. 核心与高级图标的资源映射表。
6. 不可直接比较的数据内容，尤其是高级家务的时长和积分。

如果功能页字体 Token 已在 Home 重构中建立，必须复用，不再新建重复 Token。如尚未建立，应在现有 DesignSystem 中建立语义化的功能页字体角色，使用 `.default` design，不得继续使用 `.rounded + .black/.heavy` 作为本页默认字体。

## 五、正式图标资源接入

### 5.1 资源来源

仅使用以下正式素材目录：

```text
design-assets/Final_product/04-chore-icons/extracted-from-chore-selection/
```

不使用 `design-output/icon-extraction/` 里的探索版、`v2`、`v3`、`v4`、`v5` 或 `v6` 中间文件。

这些正式 PNG 都是 256 × 256、带透明通道的资源。

### 5.2 核心家务图标映射

| 家务 | 目标素材文件 | 建议 Asset Name | 显示分类 |
|---|---|---|---|
| 做饭 / 备餐 | `core-cook-prepare.png` | `chore_core_cook_prepare` | 烹饪 |
| 饭后收拾 / 洗碗 | `core-dishes-cleanup.png` | `chore_core_dishes_cleanup` | 餐厨清洁 |
| 洗衣服 | `core-laundry.png` | `chore_core_laundry` | 洗护 |
| 收衣 / 叠衣 | `core-fold-clothes.png` | `chore_core_fold_clothes` | 衣物整理 |
| 扫地 / 吸尘 | `core-sweep-vacuum.png` | `chore_core_sweep_vacuum` | 地面清洁 |
| 拖地 / 地面湿清洁 | `core-mop-floor.png` | `chore_core_mop_floor` | 地面清洁 |
| 整理收纳 | `core-organize-storage.png` | `chore_core_organize_storage` | 整理收纳 |
| 卫生间清洁 | `core-bathroom-clean.png` | `chore_core_bathroom_clean` | 卫生间 |
| 倒垃圾 / 垃圾分类 | `core-trash-recycling.png` | `chore_core_trash_recycling` | 日常杂务 |
| 采购补货 / 家庭物资管理 | `core-shopping-supplies.png` | `chore_core_shopping_supplies` | 采购管理 |

“显示分类”只是 View 层文案映射，不得回写或修改后端 `category`。

### 5.3 高级家务图标映射

| 家务 | 目标素材文件 | 建议 Asset Name |
|---|---|---|
| 换床单 | `premium-change-bedding.png` | `chore_premium_change_bedding` |
| 清理灶台 | `premium-clean-stove.png` | `chore_premium_clean_stove` |
| 運狗 | `premium-walk-dog.png` | `chore_premium_walk_dog` |

`premium-cloud-partial.png` 来自目标稿中横向列表右侧部分可见的下一张卡片。必须先检查它对应的实际家务语义；在无法与真实 `ChoreItem` 匹配时，不得把它随意分配给搬重物、清理猫砂或其他不相关家务。

当前没有对应正式插画的高级家务，继续使用现有 SF Symbol 作为 fallback，不伪造语义错误的图标。

### 5.4 Assets.xcassets 接入规则

1. 将实际运行需要的 PNG 复制到 `apps/ios/Resources/Assets.xcassets` 的语义化 Imageset 中。
2. 每个 Imageset 使用稳定英文名称，不使用中文、空格或随机 UUID。
3. 图片视为已包含目标彩色 Tile、插画、白色边缘和局部阴影。使用时不要再在外层重复叠加实心彩色背景、粗白边或第二层强阴影。
4. 使用 `Image(assetName).resizable().scaledToFit()` 展示，不拉伸，不裁掉插画边缘。
5. 在资源名不存在或新家务没有插画时，安全回退到原有 SF Symbol。
6. 不修改 `ChoreItem.icon` 的 API 含义。可在 View / DesignSystem 层增加纯展示的 `ChoreIconAssetResolver`，根据稳定名称别名或现有 ID 选择 Asset，未命中时使用 `chore.icon` SF Symbol。
7. 检查 Imageset 的 Target Membership / Asset Catalog 归属，并通过实际 Build 验证资源名。
8. 在 `design-assets/Final_product/00-ASSET-INDEX.md` 或现有 App Asset Manifest 中登记最终导入的家务图标名、源文件和用途。

## 六、页面实现要求

### 6.1 页面头部

- 页面标题、副标题和“编辑”按钮以目标稿的 Safe Area 内容基准对齐。
- 页面标题使用功能页字体 Token，不使用 `.rounded + .black`。
- 编辑按钮保留透明 Material、文字和菜单图标，但宽高、内边距、圆角和阴影以目标稿为准。
- 保留编辑与完成状态的真实切换。

### 6.2 核心家务网格

- 主参考设备保持两列网格，Dynamic Type 进入无障碍大字号时可切换单列。
- 卡片必须保留：插画图标、家务名、标准时长、积分和底部分类点。
- 按目标稿重新校准卡片宽高、内边距、图标尺寸、图标与文字间距、标题行高和分类行位置。
- 图标尺寸不得继续沿用当前 48 pt SF Symbol Tile 的视觉比例而不测量目标稿。根据独立目标稿估算并在截图 QA 中校准。
- 卡片背景使用目标稿的浅黄、浅蓝、浅薄荷和浅粉变体，不用图标自带的 Tile 颜色粗暴替代整张卡片背景。
- 点击区域覆盖整张卡片，不因接入图片而缩小按钮可点击范围。
- 编辑模式中的图钉、拖动预览和落点交互必须继续正常。

### 6.3 展示分类映射

在 View / Presentation 层提供语义化显示文案，不修改 Model 或 API 原始分类。

映射优先使用家务的稳定名称别名，因为“厨房类”同时包含“烹饪”和“餐厨清洁”，只根据后端大类无法得到目标文案。

未命中映射时安全回退到 `chore.category`。

### 6.4 高级家务

- 保持横向滚动和“高级家务 · 需解锁”标题。
- 以目标稿校准小卡片宽高、可见卡片数量、卡片间距、锁标记和“高级” Badge。
- 接入已匹配的高级家务插画；未匹配的继续使用 SF Symbol fallback。
- 不修改时长、积分和锁定状态来追求截图文案一致。
- 点击锁定卡片仍然触发当前解锁提示。

### 6.5 底部滚动与 Tab Bar

- 增加足够的 ScrollView 底部安全区或内容 Padding，使“高级家务”标题和卡片可以完整滚动到 Tab Bar 上方。
- 不得通过隐藏高级家务或减少真实卡片数量解决遮挡。
- 保留 TabView 导航，不新建第二套选中状态。

## 七、允许修改的文件

优先只修改：

```text
apps/ios/Sources/Features/Chores/ChoreSelectionView.swift
apps/ios/Sources/DesignSystem/DSCard.swift
apps/ios/Sources/DesignSystem/DSColors.swift
apps/ios/Sources/App/MainTabView.swift
apps/ios/Resources/Assets.xcassets/
```

允许在现有 DesignSystem 或 Chores Feature 内新增一个小型、纯展示的图标与分类解析器，例如：

```text
ChoreIconAssetResolver.swift
ChorePresentation.swift
```

不得在 `AppViewModel` 中堆叠纯 UI 资源名映射。

如果确实需要修改其他文件，先说明原因和影响范围。

## 八、轻量 Xcode 与 Simulator 验证

实现完成后，允许轻量使用 Xcode 相关命令和 Simulator。

执行：

```text
静态检查
→ 一次目标 Scheme 增量 Build
→ 只运行相关 XCTest
→ 启动或复用一台主参考 Simulator
→ 进入“记一下”页面
→ 获取 1–2 张截图
→ 与独立目标稿归一化对比
→ 一次集中修正
→ 最多再执行一次 Build 和截图复核
```

限制：

- 每轮最多 2 次主动 Build
- 只使用 1 台主参考 Simulator
- 每轮只保留 1–2 张必要截图
- 不执行 Clean Build
- 不删除 DerivedData
- 不运行无关的全量 UI 测试
- 不针对单个 padding 反复 Build
- 如果等待或卡住约 5 分钟仍无明显进展，停止自动验证，保留已完成修改并输出用户手测清单

## 九、截图 QA 要求

对比前：

1. 使用独立目标稿，不直接从拼接图测量。
2. 将目标图和实际截图归一到同一逻辑宽度。
3. 以 Safe Area 内容起点对齐。
4. 生成 50% 透明度叠加图或边缘对比。
5. 将高级家务的真实数据差异与视觉差异分开。

必须检查：

- 页面标题和副标题的字体风格
- 标题与编辑按钮位置
- 页边距
- 两列网格宽度和间距
- 核心卡片宽高
- 插画图标尺寸和是否被二次裁切
- 家务名、分钘、积分和分类文案层级
- 卡片背景颜色、圆角、描边和阴影
- 高级家务标题、横向卡片和可见卡片数量
- 高级卡片是否能完整滚动到 Tab Bar 上方
- Tab Bar 是否遮挡内容
- 编辑模式、点击打开 Sheet 和锁定卡片提示是否仍正常

差异优先级：

```text
P0：仍使用 SF Symbols 代替已提供的核心插画、整页字体方向错误、两列结构错误、高级区被 Tab Bar 遮挡、功能丢失
P1：卡片宽高、图标尺寸、页边距、网格间距、字号字重、分类文案和高级卡片比例不一致
P2：阴影、圆角、细颜色和 1–2 pt 局部差异
```

先清除 P0，再一次性集中处理 P1。不针对单个数值进行无依据的 `+1 / -1` 循环。

## 十、完成标准

- [ ] 已将匹配的核心和高级家务 PNG 正确导入 `Assets.xcassets`
- [ ] 图片没有被重复加背景、粗白边或强阴影
- [ ] 没有将语义不匹配的插画分配给其他家务
- [ ] 未命中素材的家务可安全回退到 SF Symbol
- [ ] 功能页字体不再使用 `.rounded + .black/.heavy` 作为默认风格
- [ ] 核心家务两列网格与目标稿结构一致
- [ ] 卡片宽高、图标比例、字体层级和分类文案接近目标稿
- [ ] 高级家务横向列表接近目标稿
- [ ] 高级家务不再被 Tab Bar 遮挡
- [ ] 点击核心家务仍能打开耗时 Sheet
- [ ] 编辑、置顶、拖动、锁定提示、Loading 和 Error 仍正常
- [ ] 未修改时长、积分、Model、API 或会员规则
- [ ] 增量 Build 通过，或已记录无法完成自动验证的原因
- [ ] 相关 XCTest 通过，或已转为用户手测
- [ ] 已获取实际截图并完成对比
- [ ] P0 已清零
- [ ] P1 已处理或有明确说明

## 十一、最终交付格式

完成后输出：

```text
1. 本轮完成结果
2. 修改文件
3. 导入的 Asset 与家务映射表
4. 字体、卡片、网格和高级区调整
5. 保留的业务与交互
6. Build 和 XCTest 结果
7. Simulator 设备与截图位置
8. P0 / P1 / P2 差异和最终复核结果
9. 未匹配正式插画而使用 SF Symbol fallback 的家务
10. 尚未验证的内容
11. 是否修改了业务层；如没有，明确写“本轮未修改业务层”
```

不要在只换完图标后就停止。在轻量验证边界内，还必须完成字体、卡片比例、分类文案、高级区避让和一次集中截图 QA 修正。
