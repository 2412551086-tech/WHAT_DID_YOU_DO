# 家庭保卫战 App 图标矢量候选

本目录保存三份可编辑 SVG 母稿。它们是设计源文件，不直接放入
`Assets.xcassets/AppIcon.appiconset`。

根目录中的 SVG 是结构清晰、便于继续修改的精简路径版；`high-fidelity/`
中的同名 SVG 是从最终候选图高保真路径化得到的正式视觉母稿，节点较多，
但外观最接近确认的 PNG。

- `app-icon-candidate-01-medal-star.svg`：房屋边框 + 彩色功劳章
- `app-icon-candidate-02-crowned-home.svg`：蓝底房屋 + 皇冠
- `app-icon-candidate-03-house-medal.svg`：红蓝家庭 + 金色功劳章

最终选定图标后，应从对应 SVG 导出无透明通道的 1024 x 1024 PNG，再替换
`apps/ios/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`。
