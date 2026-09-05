# iOS UI 最终巡检报告

更新时间：2026-08-01

## 结论

当前 iOS MVP 的主要页面已按照最终高保真方向完成重构，核心页面使用真实 `AppViewModel` 与 API/Mock 数据源，没有建立第二套演示业务。启动恢复、Loading、Error、Offline、Empty 和 Content 状态均已有明确呈现。

本轮最终结论：**P0 阻断问题为 0，页面重构范围通过。**

## 页面覆盖

| 页面/流程 | 状态 | 说明 |
| --- | --- | --- |
| LoginView | 已更新 | 仅作为按需 Auth Gate；按发行区域展示 Apple、微信/Google 与邮箱入口 |
| Launch Session Restoring | 已完成 | 恢复期间不闪现 LoginView，匹配高保真启动状态 |
| CreateFamilyView | 已完成 | 家庭名称、头像、身份、自定义身份、创建成功、邀请分享 |
| JoinFamilyView | 已完成 | 邀请码校验、家庭预览、申请提交、等待/通过/拒绝状态 |
| JoinRequestsView | 已完成 | OWNER 列表、空状态、通过、拒绝、重试与确认 |
| HomeView / ActivityRow | 已完成 | 今日统计、最近动态、点赞、软删除、Loading/Error/Offline/Empty |
| ChoreSelectionView | 已完成 | 核心/自定义/高级家务、编辑、置顶、排序、玻璃锁定态和测试兑换 |
| ChoreDurationPickerSheet | 已完成 | 实际耗时、积分预估、取消和确认记录 |
| FamilyDashboardView | 已完成 | 月度积分、次数、总耗时、排行、分类占比和空数据回退 |
| ProfileView | 已完成 | 家庭信息、邀请码、成员、OWNER 审核/转让、立绘切换、Debug、退出登录 |
| DebugPanel / 状态组件 | 已完成 | Debug 环境可检查请求失败、离线和空状态组件 |

## 本轮修复

1. 启动恢复页由通用 `ProgressView` 升级为高保真品牌恢复状态。
2. 建立统一的请求失败、离线、Loading 和带行动按钮的空状态组件。
3. 首页空状态的“去记一下”现在真实切换到记录 Tab。
4. 首页与月报错误状态提供真实重试，支持下拉刷新。
5. API 连接错误会进入离线状态，并显示上次成功同步时间。
6. “开通高级会员”不再静默关闭弹窗，会明确告知功能尚未开放。
7. 月报接通 `totalMinutes` 与 `categoryStats`，不再显示永久破折号或“正在整理”。

## 按钮与操作巡检

| 操作 | 结果 |
| --- | --- |
| 按需 Auth Gate、协议勾选、登录 Sheet | 通过 |
| Apple/微信占位入口 | 通过，展示诚实提示 |
| 创建家庭、复制/分享邀请码 | 通过 |
| 邀请码校验、加入、刷新申请状态 | 通过 |
| OWNER 审核通过/拒绝 | 通过 |
| 首页空状态“去记一下” | 通过，模拟器自动点击验证 |
| 状态页“重试” | 通过，模拟器确认回调执行 |
| 家务卡片、耗时 Sheet 取消/确认 | 通过 |
| 高级家务提示 | 通过，锁定卡进入测试兑换；兑换成功后可选择耗时并记录 |
| Tab 切换、Profile Debug 状态页 | 通过 |
| 点赞、取消点赞、软删除 | 后端 e2e 与 Smoke 通过 |
| 退出登录与 Keychain 清理 | XCTest 通过 |

## 非阻断缺口

- 尚未建立 XCUITest 主链路目标；当前按钮巡检由 XcodeBuildMCP 短时运行和 XCTest 共同完成。
- 离线状态在请求失败后触发，尚未使用 `NWPathMonitor` 做主动网络状态监听。
- Apple 登录、微信登录、StoreKit、高级会员、隐私协议正式页面仍属于产品规划，不是当前 MVP 已实现能力。
- 真实图片上传、正式第三方认证与生产部署仍未完成。

## 下一阶段建议

1. 冻结当前 UI 基线，补充关键页面截图回归，避免继续大范围视觉改动。
2. 新增最小 XCUITest：登录、记录家务、点赞、删除、退出登录。
3. 做 iPhone SE 尺寸、常规尺寸、Max 尺寸和 Dynamic Type/VoiceOver 验收。
4. 补齐隐私政策、用户协议与生产认证方案。
5. 完成签名、生产环境配置、隐私清单和 TestFlight 内测。
