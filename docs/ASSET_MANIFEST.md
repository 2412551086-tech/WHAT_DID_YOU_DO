# Asset Manifest

更新时间：2026-08-01

## 家庭成员形象

成员形象采用一一对应的头像与立绘。切换立绘时，iOS 同步使用相同编号的圆形头像；不要把头像和立绘拆成两个独立选择。

| 范围 | asset key | 用途 |
| --- | --- | --- |
| 头像 01...13 | `avatar_01` ... `avatar_13` | Activity、成员列表、排行和个人资料 |
| 立绘 01...13 | `family_avatar_action_01` ... `family_avatar_action_13` | 月报冠军主视觉与成员形象选择 |

新增成员形象时必须成对增加同编号 asset key，并同步更新 iOS 的形象目录映射。

## 页面与状态插画

| asset key | 用途 |
| --- | --- |
| `login_household_battle` | 登录页家庭劳动主插画 |
| `join_status_pending_illustration` | 加入家庭后等待 OWNER 审核 |
| `home_empty_waiting_avatar` | 本周尚无家务记录时的圆形占位头像 |
| `monthly_leader_watering` | 月报冠军立绘映射失败时的兼容回退 |

这些文件是 App 运行资源，进入 `Assets.xcassets`。高保真整页图、裁切过程图和 QA 对比图属于设计源文件或临时输出，不应直接作为运行时页面背景。

## 系统家务图标

- 36 项系统家务均为免费家务，不再区分核心区和高级锁定区，并按日常家庭、恋爱陪伴、育儿、宠物四主题组织。
- 已发布的 `chore_core_*`、`chore_premium_*` key 为兼容历史数据继续保留，但不再代表套餐权限。
- 以下 7 项已换成与核心家务一致的粗黑描边贴纸图标：

| 家务 | asset key |
| --- | --- |
| 搬重物 | `chore_catalog_heavy_lifting` |
| 清理猫砂 | `chore_catalog_clean_litter` |
| 陪孩子写作业 | `chore_catalog_homework_help` |
| 预约维修 | `chore_catalog_repair_booking` |
| 喂奶 | `chore_catalog_feed_baby` |
| 遛娃 | `chore_catalog_walk_child` |
| 接送孩子 | `chore_catalog_school_run` |

- 图标 key 必须与后端 seed/catalog 返回值保持一致。

## 自定义家务图标库

自定义家务图标位于 `apps/ios/Resources/Assets.xcassets`。代码和接口只使用稳定的 asset key，不直接引用 PNG 文件名。

| asset key | 默认名称 | 分类 | 常见频率提示 | 推荐时长 | 推荐倍率 |
| --- | --- | --- | --- | ---: | ---: |
| `chore_custom_dust` | 擦桌除尘 | 清洁 | 每周 | 15 分钟 | 1.0x |
| `chore_custom_window` | 擦窗玻璃 | 清洁 | 每月 | 30 分钟 | 1.3x |
| `chore_custom_bed` | 整理床铺 | 整理 | 每日 / 每周 | 10 分钟 | 1.0x |
| `chore_custom_plant` | 浇花养护 | 照顾 | 每周 / 按需 | 10 分钟 | 0.8x |
| `chore_custom_pet` | 宠物照料 | 照顾 | 每日 | 15 分钟 | 1.1x |
| `chore_custom_car` | 清洗车辆 | 清洁 | 每月 / 按需 | 40 分钟 | 1.4x |
| `chore_custom_fridge` | 清理冰箱 | 清洁 | 每月 | 30 分钟 | 1.3x |
| `chore_custom_repair` | 家庭维修 | 家庭事务 | 按需 | 30 分钟 | 1.5x |
| `chore_custom_childcare` | 陪伴孩子 | 照顾 | 每日 | 30 分钟 | 1.2x |
| `chore_custom_admin` | 家庭管理 | 家庭事务 | 每月 | 20 分钟 | 1.1x |

表中的分类只是选择该图标时的推荐值。用户可以在创建表单中独立选择 `烹饪`、`清洁`、`洗护`、`整理`、`照顾`、`家庭事务`；频率提示不生成重复任务。默认值可由用户修改；服务端最终限制时长为 1...180 分钟、倍率为 0.5x...2.0x。免费账号最多保存 2 项自定义家务，开发测试高级账号最多保存 10 项；常用页最多同时展示 2 个尚未使用的空白位置。

## 视觉规则

1. 家务内容图标使用粗黑圆角描边、白色贴纸边和少量高饱和平涂色。
2. 单张图保持方形、主体居中，并确保缩小到 40 pt 后仍可辨认。
3. 新图标必须同时加入 Asset Catalog、`CustomChoreCatalog` 和后端 iconKey 白名单。
4. 已发布 asset key 不重命名；替换画面时保留 key，避免历史模板失效。

## 调研依据

- American Cleaning Institute 将家庭任务分为每日、每周、每月和季节性，并列出台面、除尘、床品、冰箱和窗户等高频任务。
- University of Minnesota Extension 对厨房、浴室和地面清洁给出了餐后、每日、每周及隔月频率建议。
- Utah State University Extension 的家纺清洗建议用于校准床品类的周/月频率。

这些频率只用于产品默认建议，用户家庭的真实节奏始终优先。
