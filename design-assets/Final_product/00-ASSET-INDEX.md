# Final Product Asset Index

本目录只存放当前 UI 微调与后续 SwiftUI 落地所需的最终视觉资产。

## 目录结构

### `01-characters/current`

当前统一使用的十三个角色系统：十二位人物和一台家庭机器人。原先标记为 `legacy` 的六人也是正式可选角色，现已合并为 `member-07` 至 `member-12`，不再区分新旧版本。

- `portraits/`：统一为脸部、发型与少量肩颈的圆形头像，`1254 x 1254`，透明 PNG；不使用半身或全身裁切。
- `full-body/`：全身立绘，`1024 x 1536`，透明 PNG。
- `action-poses/`：十三个角色的家务动作立绘，`2048 x 3072`，透明 PNG；保留原静态立绘，不互相覆盖。
- `action-portraits/`：由动作立绘整理出的统一圆形头像，`1254 x 1254`，透明 PNG；只保留头部和少量肩颈。
- `reference/current-cast-contact-sheet.jpg`：十三个角色全身立绘总览。
- `reference/all-member-portraits-contact-sheet.jpg`：十三个角色头像总览。
- `reference/all-member-action-portraits-contact-sheet.jpg`：十三个动作版角色头像总览。

角色编号在头像与全身立绘中保持一致：

1. `member-01-yellow-bob`：黄色上衣、黑色短发女性。
2. `member-02-green-short-hair`：绿色上衣、黑色短发男性。
3. `member-03-coral-bun`：珊瑚色上衣、丸子头女性。
4. `member-04-purple-wavy`：紫色上衣、棕色中长发女性。
5. `member-05-blue-curly`：蓝色上衣、黑色卷发男性。
6. `member-06-orange-glasses`：橙色上衣、圆框眼镜男性。
7. `member-07-pink-ponytail`：粉色上衣、黑色高马尾女性。
8. `member-08-blue-hoodie`：蓝色连帽衫、黑色侧分短发男性。
9. `member-09-mint-curly-glasses`：薄荷绿连帽衫、卷发圆框眼镜中性角色。
10. `member-10-yellow-short-bob`：黄色上衣、黑色齐耳短发女性。
11. `member-11-orange-broad`：橙色上衣、宽体型男性。
12. `member-12-purple-short-hair`：紫色上衣、利落短发中性角色。
13. `member-13-household-robot`：奶油白机身、天蓝胸板、薄荷绿装饰的家庭服务机器人。

### `02-screens/main-tabs`

四个底部主导航页面：

1. `01-today-dashboard.png`
2. `02-chore-selection.png`
3. `03-monthly-report.png`
4. `04-profile-owner.png`

### `02-screens/family-flow`

家庭创建与加入流程：

1. `01-create-family.png`
2. `02-create-family-success.png`
3. `03-join-family.png`
4. `04-join-pending.png`
5. `05-join-requests-owner.png`

### `02-screens/activity`

- `01-activity-all-recent.png`：全部家庭动态，当前展示“最近”状态。

### `02-screens/modals`

- `01-chore-duration-picker.png`：实际耗时滚轮 Sheet。

### `02-screens/states`

- `01-launch-session-restoring.png`：启动恢复会话。
- `02-feedback-and-empty-states.png`：错误、离线与空状态组件。

### `03-previews`

- `screens-contact-sheet.jpg`：全部 13 张页面的缩略图总览，仅用于快速定位文件。

## 命名规则

- 文件名统一使用小写英文和连字符。
- 页面文件按用户流程增加两位数字前缀，便于按名称排序。
- 人物文件必须保留稳定编号，头像与全身立绘使用同一个编号。
- 后续微调使用原文件名覆盖，探索版本使用 `-v2`、`-v3` 后缀。
- 不再使用 `exec-UUID`、`avatar_01` 等无法识别用途的临时名称。

## 当前注意事项

- App 中角色选择统一读取 `member-01` 至 `member-13`。
- 每个编号都同时提供头像与全身立绘，页面需使用同一编号，避免头像和人物不一致。
- `member-07` 至 `member-12` 的头像由对应全身立绘直接裁切，保留原人物长相。
- 页面若使用动作立绘，应从同编号的 `action-portraits/` 读取头像；常规静态页面继续使用 `portraits/`。
