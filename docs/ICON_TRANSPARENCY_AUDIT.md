# iOS 图标与插画透明底审计

日期：2026-09-11

## 结论

旧成就、普通头像和家庭身份图原有的真实 alpha 已保留；六张 `achv2_atlas_1...6` 已使用本地确定性脚本生成真实 RGBA，保持 1536x1024 画布、4x2 格子和原始坐标不变。ImageGen 返回的棋盘格伪透明图没有写入工程。最终已修正 atlas1/r1c1 笔记本和 atlas2/r2c4 裤腿的局部保护区域，并在深色背景检查图案完整性。

旧 27 张成就以及明确的 27 张 chore/report 小图标也已按原 alpha 外缘最多 5 px 的窄带规则清理外部白色贴纸边；内部白色图案、彩色圆角底板和头像/身份图均未被全图白色阈值处理。

## 资产覆盖

| 范围 | 实际资源 | 结果 | 依据 |
| --- | --- | --- | --- |
| 旧成就独立插画 | `Assets.xcassets/Achievements/` 下 27 张 512x512 PNG | 保留真实 alpha，清理外缘白色贴纸边 | 原图备份及深色对照图 |
| 普通头像 | `avatar_01...13`，13 张 256x256 PNG | 已有真实 alpha | `sips -g hasAlpha` 返回 `yes` |
| 家庭身份中性图 | `family_avatar_neutral_01...13`，13 张 600x900 PNG | 已有真实 alpha | `sips -g hasAlpha` 返回 `yes` |
| 家庭身份动作图 | `family_avatar_action_01...13`，13 张 600x900 PNG | 已有真实 alpha | `sips -g hasAlpha` 返回 `yes` |
| 家务/报表独立插画 | `chore_core_*` 10 张、`chore_catalog_*` 7 张、`chore_premium_*` 3 张、`monthly_*` 7 张 | 已有真实 alpha | `sips -g hasAlpha` 返回 `yes` |
| 自定义/主题家务图标 | `chore_custom_*` 14 张、`chore_theme_*` 16 张 | 其中 12 张 custom 与 16 张 theme 为不透明彩色圆角底板；底板是图标构图的一部分，实际使用由 `DSChoreIconTile` 同形圆角裁切，不会露出外部白角 | 视觉抽查 + `sips -g hasAlpha`；不是独立透明插画，不应把底板白色高光误删 |
| V2 成就与新人物 | `achv2_atlas_1...6`，每张 1536x1024、4x2 格 | 已生成真实 RGBA；48 个格位保留原布局，含 44 个成就/剪影入口与 4 个新角色 | `alpha-report.json`；深浅背景检查；两处内部白区已从原图恢复 |
| 旧成就与 chore/report 小图标 | 27 张旧成就 + 27 张 `chore_core/catalog/premium/monthly` | 已清理外部白色贴纸边；内部白色细节保留 | 原 alpha 边界窄带（最多 5 px）+ 外缘连通中性白 |
| 普通头像/家庭身份图 | 13 张头像 + 26 张身份图 | 保持原状；圆形彩底/身份图构图不是白色外圈 | 视觉抽查；未进入处理集合 |

## 本轮改动

### `AchievementArtworkV2.swift`

- 已撤销本轮临时的“旧图优先”和“不透明 atlas 回退系统图标”逻辑。
- V2 映射与切格渲染保持原路径：只要 key 在 atlas 映射中，就直接显示对应 V2 格位；没有把新版成就/角色替换成旧图或系统图标。当前文件只撤销了本轮临时 fallback 逻辑。

### 本地资产处理

- `scripts/process-icon-transparency.py` 按每格边界连通背景生成真实 alpha，并对两个已确认的内部白区使用原图多边形保护。
- 旧 alpha 图标使用原 alpha 边界向内最多 5 px 的窄带，不向图像内部任意传播；三个确认的邻格溢出仅删除孤立边界组件。
- 原始六张 atlas 位于 `design-assets/Final_product/02-screens/icon-transparency-review/originals/`；预览和 JSON 统计位于同目录。
- 没有删除锁徽章、等级胶囊、头像描边或阴影；这些是状态/组件语义，不是插画的白底。头像的 `.flat` 展示仍用于无额外装饰的场景。

## 接入边界

旧成就和 chore/report 的外部白边处理已完成；`chore_custom_*` 与 `chore_theme_*` 的彩色圆角底板属于图标构图，本轮保留。图案内的白色物件及原有细描线不属于白色方底，不做全白像素删除。

## 验证证据

- 资源尺寸与 alpha：六张 atlas 均为 `1536x1024` RGBA，alpha 非空且四边 alpha 为 0；48 个单元格均有非空前景。逐张像素统计见 `alpha-report.json`。
- V2 视觉检查：`contact-sheets/achv2-cells-8x6-dark.png`、`...-light.png`、`...-color.png`；最终局部保护区域对照为 `final-corrected-targets-dark.png`。
- 旧资源视觉检查：`legacy-after-dark.png`；chore/report 视觉检查：`contact-sheets/chore-report-27-dark.png`。
- ImageGen 输出检查：棋盘格伪透明结果继续弃用；本次 RGBA 文件均由 `scripts/process-icon-transparency.py` 本地处理。
- 主任务已通过图集 alpha/透明角点断言、48 点头像渲染，以及人物与成就页面深浅模式、小屏大字体截图测试。未部署后端或修改云端数据。

## 运行时

- 本地处理使用的 Python：`/Users/aoxideni/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3`
