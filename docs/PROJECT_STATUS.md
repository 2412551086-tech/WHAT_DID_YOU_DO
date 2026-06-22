# Project Status

更新时间：2026-06-21

## 当前阶段

项目处于“本地可联调 MVP 正确性收口完成，进入稳定性与发布准备”阶段。

- iOS：SwiftUI + MVVM，支持 Mock/API 模式切换。
- 后端：NestJS + Prisma + PostgreSQL，本地端口默认为 `3000`。
- 包管理器：统一使用 `pnpm`，不要与 npm 混用。
- 当前认证：手机号开发登录/显示名 Mock 登录，不是真实短信验证码。
- 当前发布状态：尚未进入 TestFlight。

## 已完成的 MVP 主链路

1. 手机号开发登录，同一手机号复用同一开发用户。
2. 创建家庭，创建者自动成为 `ACTIVE + OWNER`（一家之主）。
3. 展示并复制家庭 `inviteCode`。
4. 其他用户使用 `inviteCode` 申请加入，初始状态为 `PENDING + MEMBER`。
5. OWNER 查看申请并执行 approve/reject。
6. ACTIVE 成员读取核心 10 项免费家务及 10 项高级锁定家务。
7. 点击家务后使用滚轮选择 1 到 180 分钟实际耗时。
8. `actualMinutes` 按家务分别保存在 UserDefaults，下次打开沿用上次确认值。
9. 创建记录时按实际耗时比例计算并保存积分。
10. 首页分别读取今日动态 `range=day` 和最近动态 `range=recent`。
11. 查看日/月排行榜和指定月份月报。
12. 家务动态展示成员身份、头像占位、实际耗时、积分和点赞头像。
13. 点赞和取消点赞均为幂等操作。
14. 创建者可左滑删除自己的记录，OWNER 可删除家庭内任意记录。
15. 删除采用软删除；已删除记录不参与动态、今日统计、排行榜和月报。
16. API 请求具有 loading、error 和 DebugPanel 诊断状态。

## 当前验证状态

最近一轮代码收口已通过：

- `pnpm run build`
- `pnpm test --runInBand`
- `pnpm run test`
- `pnpm run test:e2e`
- iOS Debug Simulator build

后续提交前仍应在当前工作区重新执行一次，防止环境或未提交改动引入回归。

## 部分完成或暂缓

| 能力 | 状态 | 说明 |
| ---- | ---- | ---- |
| 正式手机号验证码 | 暂缓 | 当前只是开发登录，没有短信发送与验证码校验 |
| Apple/微信登录 | 未开始 | UI 可有占位，未接正式认证 |
| Token 安全存储 | 部分完成 | token 可用于联调，尚未迁移到 Keychain |
| 环境配置 | 部分完成 | 当前 baseURL 面向本机联调，需拆分 Debug/Staging/Release |
| 图片凭证 | 暂缓 | 后端字段和校验保留；iOS 隐藏/禁用开关并固定创建为 false |
| 高级会员购买 | 暂缓 | 高级家务可展示锁定态，未接 StoreKit 和订阅校验 |
| 真实头像上传 | 暂缓 | 当前仅保存 `avatarKey` 并显示本地占位头像 |
| 家庭时区 | 部分完成 | activity 的 day 当前按 UTC 自然日 |
| 自动化 iOS 测试 | 部分完成 | 9 项 XCTest 单测已覆盖积分、耗时记忆、DTO 和 Mock/API 分流；UI 自动化未开始 |
| GitHub Actions CI | 已完成 | push/PR 自动执行后端 Prisma/build/test/e2e/smoke 与 iOS build-for-testing/XCTest |
| TestFlight | 未开始 | 尚未配置签名、归档和分发流程 |

## 下一阶段顺序

1. 持续扩充后端边界 e2e、iOS ViewModel 测试和 UI 主链路自动化。
2. 清理错误提示、弱网重试、防连点和跨天/跨月边界问题。
3. 将 token 迁移到 Keychain，并定义退出登录后的清理策略。
4. 拆分 Debug、Staging、Release 的 baseURL、密钥和日志策略。
5. 观察 GitHub-hosted runner 稳定性，并逐步补充 iOS UI Test 和跨日期边界覆盖。
6. 完成 Apple Developer 签名、归档、隐私说明和 TestFlight 内测。
