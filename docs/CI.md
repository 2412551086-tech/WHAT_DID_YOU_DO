# Continuous Integration

更新时间：2026-06-22

项目在每次 `push` 和 `pull_request` 时运行两条独立 GitHub Actions workflow：

- `.github/workflows/backend-ci.yml`
- `.github/workflows/ios-ci.yml`

## 后端 CI

后端任务运行在 `ubuntu-24.04`，使用 Node.js 22、pnpm 11.6.0 和 PostgreSQL 16 service。

检查顺序：

1. `pnpm install --frozen-lockfile`
2. `pnpm exec prisma validate`
3. `pnpm exec prisma generate`
4. `pnpm exec prisma migrate deploy`
5. `pnpm exec prisma db seed`
6. `pnpm run build`
7. `pnpm test --runInBand`
8. `pnpm run test:e2e`
9. 使用 `node dist/main.js` 启动构建产物
10. `pnpm run smoke:mvp`

CI 使用 workflow `env` 提供一次性测试配置，不读取或提交 `.env`：

```text
DATABASE_URL=postgresql://app:app123456@127.0.0.1:5432/ni_gan_sha_la?schema=public
JWT_SECRET=ci-only-secret
BASE_URL=http://127.0.0.1:3000
```

这些值只用于隔离的 GitHub runner，不是生产密钥。未来接入外部 Staging 服务时，应改用 GitHub Actions Secrets。

## iOS CI

iOS 任务运行在 `macos-15`：

1. 打印当前 Xcode 路径和版本。
2. 从 `xcrun simctl list devices available -j` 动态选择可用 iPhone Simulator。
3. 启动并等待 Simulator ready。
4. 对 `WhatDidYouDo` scheme 执行 `build-for-testing`。
5. 执行增量 `xcodebuild test`，运行现有 XCTest。
6. 测试失败时上传 `.xcresult`，保留 7 天。

workflow 不写死本机 UUID、iPhone 型号或 iOS 版本。如果 GitHub 更新 runner 镜像，只要存在满足 deployment target 的 iPhone Simulator，任务仍可运行。

## 本地等价命令

### 后端

先启动 Docker PostgreSQL，然后执行：

```sh
cd /Users/aoxideni/Documents/what_did_you_do
pnpm install --frozen-lockfile

cd backend
pnpm exec prisma validate
pnpm exec prisma generate
pnpm exec prisma migrate deploy
pnpm exec prisma db seed
pnpm run build
pnpm test --runInBand
pnpm run test:e2e
```

smoke test 需要另一个终端中的后端监听 `3000`：

```sh
cd /Users/aoxideni/Documents/what_did_you_do/backend
pnpm run start
```

然后运行：

```sh
BASE_URL=http://127.0.0.1:3000 pnpm run smoke:mvp
```

### iOS

查看可用 Simulator：

```sh
xcrun simctl list devices available
```

选择一个 UDID 后运行：

```sh
SIMULATOR_ID=<可用的模拟器 UDID>

xcodebuild build-for-testing \
  -project apps/ios/WhatDidYouDo.xcodeproj \
  -scheme WhatDidYouDo \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath /tmp/WhatDidYouDoDerivedData \
  CODE_SIGNING_ALLOWED=NO

xcodebuild test \
  -project apps/ios/WhatDidYouDo.xcodeproj \
  -scheme WhatDidYouDo \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath /tmp/WhatDidYouDoDerivedData \
  CODE_SIGNING_ALLOWED=NO
```

Debug 构建默认使用 `localSimulator` API 环境，即 `http://127.0.0.1:3000`。真机或局域网联调时，不要使用 `127.0.0.1`，可在 Xcode Scheme 的 `Run > Arguments > Environment Variables` 中配置：

```text
WDD_API_ENV=localNetwork
WDD_LOCAL_NETWORK_BASE_URL=http://<Mac 局域网 IP>:3000
```

Release/Production 构建默认使用预留 HTTPS 地址，并禁止使用 `localSimulator`，避免发布包误连本机地址。

## 常见失败原因

### PostgreSQL 未启动

本地确认 Docker Desktop 和数据库容器运行：

```sh
docker ps
```

GitHub Actions 中检查 PostgreSQL service 的 health check 日志。

### DATABASE_URL 错误

确认用户名、密码、端口、数据库名与 PostgreSQL 容器一致。CI 使用 workflow env，本地默认读取 `backend/.env`。

### migration 未执行

出现表或字段不存在时运行：

```sh
pnpm exec prisma migrate deploy
```

开发新 migration 时仍使用 `prisma migrate dev`，CI 只应用已经提交的 migration。

### seed 未执行

`/chores` 没有核心家务时运行：

```sh
pnpm exec prisma db seed
```

### 3000 端口未启动

smoke test 依赖已启动的后端。检查：

```sh
curl -i http://127.0.0.1:3000/chores
```

CI 会等待最多 30 秒，并在失败时打印后端日志。

### iOS Simulator 不匹配

本地不要复制其他机器的设备名或 UUID，使用：

```sh
xcrun simctl list devices available
```

CI 已动态选择可用 iPhone。如果 runner 没有兼容 runtime，可调整 `runs-on`，或在 workflow 中使用 `xcode-select` 选择已安装的 Xcode。

部分 Xcode/Simulator 组合在 `test-without-building` 时可能出现 test runner channel disconnected，因此 CI 在 `build-for-testing` 后使用增量 `xcodebuild test`。它会复用同一 DerivedData，执行时间略长，但通常更稳定。

## 尚未自动化

- iOS UI 双账号完整主链路。
- 真机网络和局域网联调。
- 更完整的多时区矩阵和 DST 边界。
- 弱网、超时和断网恢复。
- TestFlight 签名、归档与安装验证。
