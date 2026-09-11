# 官方网站与协议草稿

## 2026-09-07 网站改版审阅

用户已确认旧版官网正式发布、HTTPS 生效及数据库每日备份最多保留 30 天。本次不重复执行发布，不改变线上服务或现有 `dist`。

新版仅生成到 `review/`：`node website/build-review.mjs`，再运行 `node website/serve-review.mjs`，浏览 `http://127.0.0.1:4318/`。服务仅绑定本机，支持新目录路由和浏览器语言切换，因此请通过这个地址而不是直接打开 HTML。

- `/` 是个人主页，使用域名署名 douxiaolang，不额外公开实名、手机号或住址。
- `/familyguard/` 是家庭保卫战官网，四份说明分别在其下级目录。
- `/en/` 和 `/en/familyguard/` 提供完整英文页面。首次按浏览器首选语言选择中文或英文；手动选择仅存本机，可恢复跟随本机语言。无 IP 判断、无语言追踪。
- 旧 `/privacy`、`/terms`、`/subscription`、`/support` 及 `.html` 版本在预览中兼容跳转，后续发布建议改为服务器永久跳转，不能让已安装 App 的链接失效。
- 精简公开正文但保留数据用途、共享范围、第三方、保留期限、注销、未成年人及联系信息。实名集中于协议；客服邮箱集中在支持页及政策联系段；ICP备案号保留页脚。移除开发验收清单、备份执行时间和反复出现的运营者信息。
- 中文现有保留期限和备份约定读取正式本地配置，不改变原承诺；英文为审阅翻译，发布前应同步核对。

批准后再将新版纳入正式构建流程并移除审阅标识；部署时需要同步更新 Caddy CSP 以允许同源 `style-src 'self'` 和 `script-src 'self'`，保留其余安全限制。当前未改 Caddy、未上传服务器、未变更 App 链接。

本地检查脚本 `check-review.cjs` 使用 Playwright 与已安装 Chrome，覆盖三种尺寸、两种语言、锚点、语言偏好、旧链接及图片加载。

信息保留依据：[个人信息保护法第十七条](https://www.jh.gov.cn/jh/gkgd/202405/bc9715222c60405aa73fdb22e229ddc3.shtml)要求告知处理者名称或姓名及联系方式；[备案管理办法第十三条](https://www.miit.gov.cn/gyhxxhb/jgsj/cyzcyfgs/bmgz/xxtxl/art/2024/art_84a0cfa0ebd049bbbe751dca9a008e56.html)要求主页底部展示备案编号并链接查询。以下为早期发布说明，保留供参考。

本轮验证：24 个页面/尺寸/语言组合通过；包含 320px 中英文窄屏、图片加载、无横向溢出、浏览器默认语言、手动偏好、重载保持、切回自动、锚点和旧协议链接兼容。

对应主域名 `https://douxiaolang.com`，不修改 API 主机或既有在线站点。

## 本地审阅

运行 `node website/build.mjs --preview`，打开 `website/preview/index.html`。无需服务器。
内容源 `content.mjs` 包含首页、隐私政策、用户协议、订阅说明和支持页。

## 发布前必须确认

1. 将 example 配置复制为本地 `website/site.config.json`，填写公开运营者、ICP备案号、客服邮箱、日期。
2. 核实验证码挑战、已撤销会话、安全日志的清理机制与期限。现有代码不能据有效期推断数据库已经删除过期数据。
3. 核实云端备份保留周期、注销数据从备份中到期删除或恢复后重新删除的执行流程。
4. 由运营者审阅政策及条款，必要时请专业人员审查；本草稿不保证法律合规或审核通过。
5. 填写 `retentionStatement`、`backupStatement`，确认后设置 `policyApproved=true`。
6. `node website/build.mjs` 必须通过。不得把 `preview` 草稿目录作为正式协议发布。

## 部署顺序

1. 先核对域名的 DNS、现有站点和证书。备份当前 Caddyfile 及网页，不覆盖未知既有站点。
2. 把 `website/dist` 拷贝到服务器专用静态目录。
3. 在 Caddy 容器只读挂载该目录到 `/srv/familyguard-site`。审核 `deploy/production/Caddyfile.website` 后合并到服务配置，保留原 `api.douxiaolang.com` 反代段。
4. 验证 `caddy validate` 后 reload；不要重建数据库/API 容器。
5. 验证主域名及 `/privacy`、`/terms`、`/subscription`、`/support` HTTPS 200、移动端可读、备案链接正确。
6. 再发布使用这些链接的 App；协议网页不可用时不应提交商店审核。

当前生成的网页不含广告、追踪代码或外部字体。Apple、邮件投递等第三方处理仍需单独对照隐私政策。
