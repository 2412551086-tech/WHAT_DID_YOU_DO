# MVP QA Checklist

更新时间：2026-06-22

## 1. 本地启动后端

### 1.1 启动 PostgreSQL

先打开 Docker Desktop，然后检查容器：

```sh
docker ps
```

如果数据库容器已经创建但未运行：

```sh
docker start ni-gan-sha-la-postgres
```

如果尚未创建：

```sh
docker run --name ni-gan-sha-la-postgres \
  -e POSTGRES_USER=app \
  -e POSTGRES_PASSWORD=app123456 \
  -e POSTGRES_DB=ni_gan_sha_la \
  -p 5432:5432 \
  -d postgres:16
```

### 1.2 初始化并启动 NestJS

```sh
cd /Users/aoxideni/Documents/what_did_you_do/backend
pnpm install
pnpm exec prisma generate
pnpm exec prisma migrate dev
pnpm exec prisma db seed
pnpm run start:dev
```

保持这个终端窗口运行。看到服务监听 `3000` 后，另开终端执行自动验收：

```sh
cd /Users/aoxideni/Documents/what_did_you_do/backend
pnpm run smoke:mvp
```

覆盖其他地址：

```sh
BASE_URL=http://192.168.1.10:3000 pnpm run smoke:mvp
```

## 2. 本地启动 iOS

1. 用 Xcode 打开 `/Users/aoxideni/Documents/what_did_you_do/apps/ios/WhatDidYouDo.xcodeproj`。
2. 顶部 Scheme 选择 `WhatDidYouDo`。
3. 选择已安装的 iPhone Simulator。
4. 确认 `APIConfig.useMockData = false`，用于 API 联调。
5. 模拟器 Debug 默认使用 `localSimulator`，访问 `http://127.0.0.1:3000`。
6. 确认后端仍在 `http://127.0.0.1:3000` 运行。
7. 按 `Command + R` 启动 App。

### 2.1 API 环境切换

iOS 当前支持三种 API 环境：

- `localSimulator`：模拟器联调，默认 `http://127.0.0.1:3000`。
- `localNetwork`：真机或其他设备联调，使用 Mac 的局域网 IP，例如 `http://192.168.1.10:3000`。
- `production`：Release/Production 预留 HTTPS 地址。

Debug 模式默认 `localSimulator`。在 Xcode 中临时切换：

1. 点击顶部 scheme `WhatDidYouDo`。
2. 选择 `Edit Scheme...`。
3. 进入 `Run > Arguments > Environment Variables`。
4. 添加：

```text
WDD_API_ENV=localNetwork
WDD_LOCAL_NETWORK_BASE_URL=http://你的Mac局域网IP:3000
```

如果要回到模拟器本机后端，删除这两个环境变量，或设置：

```text
WDD_API_ENV=localSimulator
```

Release 构建不会使用 `localSimulator`，避免把 `127.0.0.1` 带进发布包。

运行 iOS 单元测试：

- Xcode：按 `Command + U`。
- 命令行：

```sh
xcodebuild test \
  -project /Users/aoxideni/Documents/what_did_you_do/apps/ios/WhatDidYouDo.xcodeproj \
  -scheme WhatDidYouDo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

如果模拟器名称或系统版本不同，先运行：

```sh
xcrun simctl list devices available
```

## 3. 双账号主链路手测

建议每轮使用两个新的测试手机号，例如时间戳后缀，避免旧家庭状态干扰。

### 用户 A 创建家庭

1. 输入手机号 `123456`，点击手机号登录。
2. 创建家庭并选择身份、头像占位。
3. 确认图片凭证入口不可开启，创建请求保持 `requirePhotoProof=false`。
4. 进入“我的”，复制家庭邀请码。
5. 确认当前成员身份为 OWNER/一家之主。

### 用户 B 申请加入

1. 用户 A 退出登录。
2. 输入手机号 `654321` 登录。
3. 选择加入家庭，粘贴邀请码，不输入数据库 familyId。
4. 选择身份和头像，提交申请。
5. 确认页面提示等待一家之主审核。
6. 审核前确认用户 B 不能进入家庭记录家务。

## 4. OWNER 审核

1. 用户 B 退出登录，重新用 `123456` 登录。
2. 进入“我的”或家庭设置中的审核入口。
3. 确认列表显示用户 B 的昵称、身份和头像。
4. 点击通过。
5. 再次使用 `654321` 登录。
6. 确认用户 B 可以看到家庭并创建家务记录。
7. 另建一条申请验证拒绝后，申请人不能读取家庭数据。

## 5. 家务与实际耗时

1. 用户 B 点击“记一下”。
2. 点击一个未锁定家务，确认不会立即创建记录。
3. 确认滚轮首次使用家务标准时长。
4. 修改耗时并确认记录。
5. 回到首页，确认今日积分和今日记录立即更新。
6. 再次点击同一家务，确认默认值为上次确认耗时。
7. 修改滚轮后点取消，再次打开，确认取消值没有保存。
8. 点击另一家务，确认耗时记忆互不影响。

## 6. 点赞与取消点赞

1. 使用用户 A 查看用户 B 的记录。
2. 点击点赞，确认图标、likeCount 和点赞头像更新。
3. 快速或重复点击，确认 App 不崩溃，likeCount 不重复增加。
4. 点击取消点赞，确认计数和本人状态更新。
5. 再次取消，确认接口幂等且页面不报冲突。

## 7. 左滑软删除

1. 用户 B 左滑自己创建的记录，确认显示删除按钮。
2. 用户 B 查看用户 A 的记录，确认不能删除。
3. 用户 A 作为 OWNER，确认可以删除用户 B 的记录。
4. 删除后确认记录从今日动态和最近动态消失。
5. 重新启动 App，确认记录不会重新出现。

## 8. 今日、最近、排行和月报

1. 连续创建两条记录，确认今日积分等于两条记录 points 之和。
2. 今日战况使用 `activity?range=day`，只统计当前家庭时区里的本地今天记录。
3. 家庭最近动态使用 `activity?range=recent`，最多展示后端最近 30 条。
4. 删除一条记录后，确认今日积分和记录数立即减少。
5. 确认月排行榜的积分和记录数同步减少。
6. 确认当前月份月报的 totalPoints、totalRecords 和 recentRecords 同步刷新。

## 9. 自动化回归命令

GitHub Actions 配置和 runner 排障见 `docs/CI.md`。每次 push 或 pull request 会自动执行后端和 iOS 基础验收。

后端数据库可用时执行：

```sh
cd /Users/aoxideni/Documents/what_did_you_do/backend
pnpm run build
pnpm test --runInBand
pnpm run test:e2e
```

后端服务已运行时执行：

```sh
pnpm run smoke:mvp
```

## 10. 常见问题排查

### 3000 端口被占用

```sh
lsof -i :3000
kill <PID>
```

优先正常 `kill`，进程无法退出时再使用 `kill -9 <PID>`。

### 浏览器访问 `/` 返回 404

这是正常现象，后端没有根路由。使用下面的地址验证家务接口：

```sh
curl -i http://127.0.0.1:3000/chores
```

### inviteCode 无效

- 使用家庭页面显示的 8 位邀请码，不要使用 `cm...` 形式的数据库 familyId。
- 检查是否复制了空格；后端会自动 trim 并转为大写。
- 确认该邀请码来自当前数据库中的家庭。

### token 丢失或返回 401

- accessToken 已使用 Keychain 持久化；退出登录会清除 token。
- 如果 token 过期或后端返回 401，App 会清除本地登录态并回到登录页。
- 退出登录后 token 会被清除。
- 检查 DebugPanel 的 token 状态、最后请求和状态码。

### iOS 仍处于 Mock 模式

打开 `apps/ios/Sources/Core/Network/APIConfig.swift`，确认：

```swift
static let useMockData = false
```

修改后停止 App，再按 `Command + R` 重新运行。

### 真机不能访问 `127.0.0.1`

真机中的 `127.0.0.1` 指向 iPhone 自己。请切换到 `localNetwork`，并把 `WDD_LOCAL_NETWORK_BASE_URL` 配成 Mac 的局域网 IP，例如：

```text
http://192.168.1.10:3000
```

Mac 与 iPhone 必须在同一局域网，并允许防火墙放行 Node/Nest 服务。
