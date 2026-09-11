# douxiaolang.com

2026-09-11：以当前线上正常运行的新版网站为唯一版本。旧版页面生成器、
旧内容源和独立 Caddy 配置已移除，不再使用 `dist/` 或 `preview/` 部署。
这次仅对齐仓库配置，没有重新发布或修改线上服务。

## 当前构建

内容来自 `review-content.mjs`，样式和语言切换来自 `review.css`、
`review-language.js`。保留既有文件名，但它们同时服务正式版与本地审阅版。

正式构建：`node website/build-review.mjs --production`，输出 `website/release/`。
本地审阅：`node website/build-review.mjs`，输出 `website/review/`；
运行 `node website/serve-review.mjs` 后访问 `http://127.0.0.1:4318/`。

正式构建读取本地、不入库的 `site.config.json`，要求公开运营信息完整且
`policyApproved=true`。沿用已确认内容；修改政策正文仍需重新审阅。
`review/` 带审阅标识，不得当作正式版本发布。

## 路径与兼容

- `/`：个人主页；`/familyguard/`：家庭保卫战。
- `/en/` 和 `/en/familyguard/`：对应英文版本。
- 隐私政策、用户协议、订阅说明与支持页位于 `/familyguard/` 下。
- `/privacy`、`/terms`、`/subscription`、`/support` 及其旧 `.html` 地址
  继续跳转到当前页面。这仅保留入口兼容，不保留旧版网站。

## 部署约定

唯一服务器配置为 `deploy/production/Caddyfile`。
`deploy/production/docker-compose.yml` 将 `website/release/` 只读挂载至
`/srv/familyguard-site`，与正式构建输出一致。CSP 允许同源样式和脚本，
与当前页面的外置资源一致。保留 `api.douxiaolang.com` 的反向代理。

未来发布时先核对服务器的实际静态目录和挂载方式，备份现有网页与配置，
再验证 Caddy 配置及主站、中英文页面、协议旧链接和静态资源。
不要为网页更新重建数据库或 API 容器；本次仓库整理不执行这些线上动作。
