# MVP 测试报告

测试日期：2026-08-01
测试范围：状态页面、月报聚合、iOS 主页面交互、后端 MVP 主链路

## 自动化结果

| 检查 | 结果 |
| --- | --- |
| Backend `pnpm run build` | 通过 |
| Backend Jest | 1/1 通过 |
| Backend e2e | 10/10 通过 |
| Backend `smoke:mvp` | 19/19 通过 |
| iOS Build & Run | 通过 |
| iOS XCTest | 32/32 通过 |
| `git diff --check` | 通过 |

## 本轮新增测试

1. 网络不可用、连接失败和超时错误能够识别为离线状态。
2. 空状态操作能够切换到“记一下”Tab。
3. Session 恢复成功后记录最后同步时间，并退出离线状态。
4. 月报 DTO 能解码 `totalMinutes` 和 `categoryStats`。
5. 后端月报聚合并返回未删除记录的实际总耗时。
6. 自定义家务 2 个槽位、归档释放槽位和积分计算。
7. 家庭本周 activity/leaderboard 范围与月份切换逻辑。
8. OWNER 转让和成员 avatarKey 形象更新。
9. 错误测试兑换码不能解锁，`241255` 可持久解锁当前账号。
10. 未兑换账号不能创建高级记录，兑换后高级家务按 actualMinutes 正常计分。

## 模拟器交互验证

测试设备：iPhone 17 Pro Simulator，368 × 800 pt。

已自动点击并确认：

- 首页空状态“去记一下”进入 ChoreSelectionView。
- 家务卡片打开 ChoreDurationPickerSheet。
- Sheet“取消”正常关闭。
- Debug 状态页可以打开。
- 请求失败“重试”回调执行并更新可访问状态。
- 状态页“去记一下”返回记录 Tab。
- 高级家务打开锁定提示。
- 高级家务显示同尺寸玻璃锁定卡片；兑换入口已替代旧“即将开放”提示。
- 月度战报 Tab 可进入，并显示真实总耗时字段。

## Smoke 覆盖

双账号登录、创建家庭、邀请码申请、OWNER 审核、获取家务、actualMinutes 记录、day/recent activity、点赞幂等、取消点赞幂等、软删除，以及删除后动态/排行/月报排除均通过。测试会员兑换与高级家务记录由 e2e/XCTest 覆盖，尚未加入 smoke 脚本计数。

## 风险说明

- 本轮没有新增 XCUITest Target，因此系统分享面板、拖拽排序、完整左滑手势仍保留人工验证价值。
- 网络离线验证包含错误分类单测和状态组件交互，没有在系统层真实断网后遍历全部页面。
- 当前运行使用开发 API 和本地 PostgreSQL，不代表生产网络、签名或 TestFlight 环境已完成。
