# 在 macOS 上跑：用 NapCat 代替 SnowLuma

SnowLuma 没有 macOS 版（官方只发 Windows 和 Linux 包）。在 Mac 上，用 **NapCat** 当 QQ 网关：它原生支持 macOS 12+，Intel 和 Apple Silicon 都行。

```
Mac 版 QQ + NapCat ──(OneBot v11 WebSocket :3001 / HTTP :3000)──► qq-bridge ──► DeepSeek Harness
                                                                        ▲
                         ai-companion-kit：qzone-mcp / phone-mcp / own-life / 日记
```

---

## 一、换成 NapCat 之后能用什么

| 功能 | NapCat 下 |
|---|---|
| 私聊、群聊、记忆、拟人化发送、唤醒 | ✅ |
| 拍一拍、群历史、合并转发、"正在输入" | ✅ |
| 表情库：列出、发送、看图 | ✅ |
| 表情库：收藏聊天里的表情、改备注 | ✅（qq-bridge 已适配，见第六节） |
| 日记、定时静默唤醒（own-life） | ✅（和网关无关） |
| 手机控制（phone-mcp） | ✅（和网关无关，见第五节） |
| QQ 空间：**发说说** `qzone_post` | ✅ |
| QQ 空间：看自己的说说、看好友动态、看某人说说、点赞、评论 | ❌ NapCat 没有这些接口。调用时会明确报"当前 QQ 网关不支持"，不会悄悄失败 |

---

## 二、要装的东西

| 东西 | 怎么装 |
|---|---|
| Node.js 22.13+ | 跑 `tools/安装.command` 会自动下便携版；也可以 `brew install node@22` |
| Mac 版 QQ | 官网下载，**必须装在 `/Applications/QQ.app`** |
| NapCat | 按 [NapCat 文档 · Shell](https://napneko.github.io/guide/boot/Shell) 的 macOS 部分：下载 NapCat-Mac-Installer → 安装 → 授权修改 QQ 入口 → 切到 NapCat 启动 |
| DeepSeek Harness | 用 Mac 版（Apple Silicon）桌面应用，或者 npm 版 |

> 登录 NapCat 建议用**小号**。非官方协议端都有风控风险，教程第十三章的限流参数别调大。

---

## 三、NapCat 网络配置（最关键的一步）

打开 NapCat 的 WebUI → **网络配置**，新建两个服务：

| | HTTP 服务器 | WebSocket 服务器 |
|---|---|---|
| 启用 | ✅ | ✅ |
| host | `127.0.0.1` | `127.0.0.1` |
| port | `3000` | `3001` |
| token | **同一个**随机串 | **同一个**随机串 |
| messagePostFormat | `array` | `array` |
| reportSelfMessage | — | 关 |

**两个 token 必须一样。** qq-bridge 只有一个 `snowluma.accessToken`，HTTP 调用和 WebSocket 连接都用它。

**host 别填 `0.0.0.0`。** 填了等于把"能用她账号发消息"的接口暴露给局域网。

随机串可以这样生成：

```bash
openssl rand -hex 16
```

配好后，NapCat 的配置文件（`config/onebot11_<QQ号>.json`）大致长这样（字段名以你那个版本的 WebUI 为准）：

```json
{
  "network": {
    "httpServers": [
      { "name": "http", "enable": true, "host": "127.0.0.1", "port": 3000,
        "enableCors": true, "enableWebsocket": false,
        "messagePostFormat": "array", "token": "你的随机串", "debug": false }
    ],
    "websocketServers": [
      { "name": "ws", "enable": true, "host": "127.0.0.1", "port": 3001,
        "messagePostFormat": "array", "reportSelfMessage": false,
        "token": "你的随机串", "enableForcePushEvent": true,
        "debug": false, "heartInterval": 30000 }
    ],
    "httpClients": [], "websocketClients": [], "httpSseServers": [], "plugins": []
  }
}
```

---

## 四、qq-bridge 的 `config.json` 怎么填

**最省事的办法：双击 `tools/配置.command`**（或者在 qq-bridge 目录下运行 `npm run config`）。它会在浏览器里打开一个配置页，下面这些字段都能直接填：
- 有「测试连接」按钮，能看出 HTTP / WebSocket 通不通、token 对不对、网关是不是 NapCat、登录的是哪个号。
- 会按你填的端口和 token 生成 NapCat 网络配置片段，复制过去就行。
- 不用先启动桥接；只改这几项，其余字段原样保留；保存前会备份成 `config.json.bak`。

想手改的话，对照下面：

`tools/安装.command` 新建的 config.json 已经设好了 `impl` 和 `followDiscoveredEndpoint`，你只需要填下表里标"要填"的项。

**配置块的名字还叫 `snowluma`，不用改。** 桥接代码就是按这个名字读的，接 NapCat 也一样。

```jsonc
{
  "snowluma": {
    "wsUrl": "ws://127.0.0.1:3001",     // = NapCat WebSocket 服务器
    "httpUrl": "http://127.0.0.1:3000", // = NapCat HTTP 服务器
    "accessToken": "你的随机串",          // 要填：NapCat 里那个 token
    "impl": "napcat",                   // 新增：告诉桥接这是 NapCat（不填就自动探测）
    "followDiscoveredEndpoint": false,  // 关掉：这是给 SnowLuma 换账号用的自愈，NapCat 用不上
    "launcherPath": "",                 // 留空（SnowLuma 专用）
    "homeDir": ""                       // 留空（SnowLuma 专用）
  },
  "dsh": {
    "baseUrl": "http://127.0.0.1:3080"  // DeepSeek Harness 的地址，默认就是这个
  },
  "ownerQQ": 10001,                     // 要填：你的 QQ 号（数字，不带引号）
  "allow": {
    "private": [10001],                 // 要填：允许私聊的号，一般就是你自己
    "groups": []                        // 允许她说话的群号
  }
}
```

| 字段 | 说明 |
|---|---|
| `snowluma.impl` | `"napcat"` / `"snowluma"`。不填或填别的值 = 启动后调一次 `get_version_info` 自动识别（NapCat 返回的名字里带 `NapCat`）。日志里会打印一行 `[onebot] 网关实现：napcat` |
| `snowluma.accessToken` | 和 NapCat 两个服务里的 token 一致。留空的前提是 NapCat 那边也没设 token（不推荐） |
| `snowluma.followDiscoveredEndpoint` | 设成 `false`，桥接就不会去找 SnowLuma 的配置目录、也不会改写 URL |

其他字段（`socialV2`、`consolePort` 等）和 Windows 下一样，照原教程填。

---

## 五、ai-companion-kit 各个包

### companion（只要陪聊、不用 qq-bridge 时）

`packages/companion/config.json` 里的 `onebot` 块填同一组值：

```json
"onebot": { "wsUrl": "ws://127.0.0.1:3001", "httpUrl": "http://127.0.0.1:3000", "accessToken": "你的随机串" }
```

### qzone-mcp（发说说）

它会按顺序找令牌：`QZONE_CONFIG` / `HER_BRIDGE_DIR` 指向的 qq-bridge config.json → 环境变量 `SNOWLUMA_ACCESS_TOKEN`。MCP 配置示例：

```json
{
  "mcpServers": {
    "qzone": {
      "command": "node",
      "args": ["/你的路径/ai-companion-kit/packages/qzone-mcp/src/qzone-mcp.js"],
      "env": {
        "QZONE_CONFIG": "/Users/你/qq-bridge/config.json",
        "QZONE_IMAGE_DIRS": "/Users/你/Pictures;/Users/你/her_pics"
      }
    }
  }
}
```

- `QZONE_IMAGE_DIRS` 用**分号**分隔（Windows 版就是分号，这里保持一致）。默认只有 `~/Pictures`。
- 网关不在 3000 端口时，设 `SNOWLUMA_HTTP_URL`。
- 自检命令：`npm run qzone:test`。开通命令：双击 `packages/qzone/开通.command`。
- NapCat 下开通时，第③步会提示"不支持读说说"。这是正常的，发说说不受影响。
- NapCat 下建议把角色卡里"看动态 / 点赞 / 评论"那几句删掉，免得她反复去调用报错的工具。

### phone-mcp（手机）

```bash
brew install android-platform-tools ffmpeg
npm run phone:test
```

- adb 会自动在 `/opt/homebrew/bin`、`/usr/local/bin`、`~/Library/Android/sdk/platform-tools` 里找。
- 雷电模拟器只有 Windows 版。Mac 上用 **Android Studio 自带的模拟器**（Apple Silicon 跑 arm64 镜像，设备名默认 `emulator-5554`，和代码里的默认值一致），或者用一台闲置安卓机通过 USB 或无线 adb 连接。
- `ncm_room_say` 里的点击坐标是按作者那台模拟器的分辨率写死的，换任何设备都要重新校准。这和操作系统无关。

---

## 六、启动顺序

1. 打开 QQ（NapCat 版）→ 确认已登录，WebUI 里两个服务都是"运行中"
2. 打开 DeepSeek Harness
3. 双击 `tools/启动.command`：它会先按 config.json 里的端口检查网关和 DSH，再进守护模式

其他脚本：

| Windows | macOS | 说明 |
|---|---|---|
| `tools/安装.bat` | `tools/安装.command` | 装 Node（便携版）、qq-bridge、依赖，生成 NapCat 模式的 config.json |
| `tools/install-node.ps1` | `tools/install-node.sh` | 单独下载便携版 Node |
| `tools/启动.bat` | `tools/启动.command` | 检查前置并启动。不用复制进 qq-bridge 目录，它会自己找 |
| — | `tools/配置.command` | 打开连接配置页（网关 / DSH / 白名单 + 测试连接）；Windows 上用 `npm run config` |
| `tools/写日记.bat` | `tools/写日记.command` | 她自己写一篇；`./写日记.command 手动` 是你自己写 |
| `tools/看日记.bat` | `tools/看日记.command` | 看最近 5 篇和统计 |
| `packages/qzone/开通.bat` | `packages/qzone/开通.command` | 开通发说说 |
| qq-bridge `start.bat` | qq-bridge `start.command` | 守护：崩溃后 5 秒自动拉起 |
| qq-bridge `restart.bat` | qq-bridge `restart.command` | 按锁文件和进程工作目录找到本目录的旧实例，停掉后重开 |

`启动.command` 找 qq-bridge 的顺序：命令行参数 → `HER_BRIDGE_DIR` → 和 ai-companion-kit 并排的 `qq-bridge` → `~/qq-bridge`。

---

## 七、qq-bridge 为 NapCat 改了什么

NapCat 和 SnowLuma 的大部分接口一样。只有收藏表情这一块不同（对照两边源码确认过）：

| | SnowLuma | NapCat |
|---|---|---|
| 改备注 | `modify_custom_face { emoji_id, desc }` | `set_custom_face_desc { emoji_id（数字 emoId）, res_id, md5, desc }` |
| 收藏 | `add_custom_face { file: "base64://…" }`，返回 `emoji_id` | `add_custom_face { file: 本地路径 }`，不认 base64，也不返回 id |
| 表情列表字段 | `emoji_id` … | `emoId`、`resId`、`md5` … |

对应的改动：

- 新文件 `src/onebot-impl.js`：识别网关，生成改备注的请求，按文件头判断图片扩展名。
- `src/sticker-lib.js`：同步表情库时多保存两个字段：`emoId` 和 `rawMd5`（md5 原值，不转大小写）。
- `src/bridge.js`：
  - 改备注时按网关选接口：NapCat 用 `set_custom_face_desc`，SnowLuma 照旧用 `modify_custom_face`。
  - 收藏表情在 NapCat 下：先把图片字节写到私有临时目录（`$TMPDIR/qq-bridge-faces`，权限 600）→ 把路径交给 `add_custom_face` → 删掉临时文件 → 刷新表情库，按 md5 找回刚收藏的那张 → 再写备注。
  - macOS 上检查控制台端口占用改用 `netstat -an -p tcp` 并只看 LISTEN 行。原来的 `netstat -ltn` 在 BSD netstat 上会列出所有连接，可能误判"已有实例在跑"。
- 新增 `start.command`、`restart.command`、`.gitattributes`（`.sh`/`.command` 强制 LF 换行）。

**用 SnowLuma 的人行为完全不变**：识别不出网关时也按 SnowLuma 处理。

**前提**：NapCat 和 qq-bridge 要跑在同一台机器上，因为 NapCat 收藏表情时读的是本地文件路径。

---

## 八、常见问题

**双击 `.command` 提示"无法打开，因为无法验证开发者"**
这是 macOS 对下载来的文件加了隔离标记。处理方法：右键 → 打开 → 再点"打开"。或者在终端执行一次：

```bash
xattr -dr com.apple.quarantine /你的路径/ai-companion-kit /你的路径/qq-bridge
```

**双击 `.command` 提示没有权限**
执行一次：

```bash
chmod +x /你的路径/ai-companion-kit/tools/*.command
```

**启动时提示 "QQ 网关的 WebSocket 端口 3001 没人听"**
NapCat 没登录，或者 WebSocket 服务器没启用、端口不是 3001。端口不一样的话，就把 config.json 里的 `wsUrl`/`httpUrl` 改成和 NapCat 一致。

**日志一直在重连，或者出现 401 / 1403**
token 不一致。确认 NapCat 两个服务的 token 都等于 `snowluma.accessToken`。

**收藏表情报 "缺少 NapCat 改备注需要的 emoId/resId"**
本地表情库是从旧版同步来的，还没有这两个字段。让她调一次 `qq_list_stickers` 刷新表情库，或者重启桥接。

**图片 / 表情看不了，日志里是 "域名解析到内网/本机地址，已阻止" 或 "看起来是代理的 fake-ip 模式"**
电脑上开着 Clash / Surge / sing-box 这类代理的 TUN + fake-ip 模式。这时所有域名都解析成 `198.18.x.x`，桥接防 SSRF 的检查会把它当成内网地址。验证方法：终端里跑 `dscacheutil -q host -a name example.com`，出来的是 `198.18.` 开头就是这种情况。
- 桥接只在两个地方认 fake-ip：抓图看表情、联网搜索。而且只认几个固定地址的默认端口：QQ 的图片 / 表情 CDN（`multimedia.nt.qq.com.cn`、`gxh.vip.qq.com`、`*.qpic.cn`、`*.qlogo.cn`），以及搜索用的 `api.deepseek.com`、`cn.bing.com`、`www.bing.com`。
- 本机实测过：QQ 头像（qlogo）能抓到，Bing 搜索有结果。**她收到的真 QQ 图片 / 表情还没在 fake-ip 下联调过。**有的表情链接本身就 404，日志会从"已阻止"变成"HTTP 404"，那是 QQ 那边没这张图，不是被拦了。
- 其他网站还是拦，`web_fetch` 抓网页在 fake-ip 下完全不认。这是故意的：fake-ip 下桥接看不到真实地址，全放开等于让代理替任何人连你的电脑和局域网，而 `web_fetch` 的网址可能被群里的话带偏。要用的话，在代理配置的 `fake-ip-filter` 里加上那些域名，或者把代理切到 redir-host / 真实 IP 模式。
- 改完要重启两样才生效：桥接（关掉 `start.command` 的窗口再双击）管看图；联网搜索是 DSH 拉起来的 MCP，要重启 DSH（`dsh web`）。

---

## 九、同时接 Telegram（可选）

qq-bridge 可以再挂一个 Telegram bot 入口。她还是同一个她：人设、记忆、日记、DSH 都和 QQ 共用，只是多了一个能找到她的地方。

**准备**

1. 在 Telegram 里找 @BotFather，发 `/newbot`，按提示起名字，拿到 bot token。
2. 国内直连不通 Telegram，需要本机开着 HTTP 代理（Clash 默认是 `http://127.0.0.1:7890`）。
3. 想让她在群里看到所有消息（而不只是 @ 她的），在 @BotFather 里 `/setprivacy` → 选这个 bot → `Disable`，然后把 bot 移出群再拉回来。

**配置**：双击 `tools/配置.command`，在「Telegram（可选）」那一栏勾选启用，填 token、代理和你自己的 Telegram id，点「测试连接」，再保存，然后重启桥接。也可以直接改 `config.json`：

```json
"telegram": {
  "enabled": true,
  "botToken": "123456789:AA…",
  "proxy": "http://127.0.0.1:7890",
  "ownerId": 123456789,
  "allow": { "private": [], "groups": [] }
}
```

**怎么拿到 id**：保存并启动桥接后，用你自己的号给 bot 发一句话（群就把 bot 拉进去再 @ 它）。桥接日志里会出现 `忽略未授权会话 private:tg123456789` 或 `group:tg-1001234567890`，`tg` 后面那串就是 id。私聊 id 是正数，群 id 是负数。填进名单后重启桥接。`ownerId` 的私聊总是放行，不用另外加名单。

**能用 / 不能用**

| 在 Telegram 上 | 情况 |
|---|---|
| 私聊、群聊收发文字；引用、@ | 能 |
| 收图片（照片、图片文件、静态贴纸）给她看 | 能 |
| 话题群（Topics） | 能，回复发回最近有人说话的那个话题 |
| 她发表情包 | 能：同步进贴纸包的 QQ 表情和她的 Telegram 收藏发成真贴纸；其余以图片发出（GIF 会动；动态 WebP / APNG 只显示第一帧） |
| 她收藏 Telegram 贴纸 | 能：默认存一份进 QQ 收藏表情（QQ 上也能发）；打开收藏贴纸包（要 `ownerId`）还会存进她自己的 Telegram 贴纸包 |
| 管理员命令 `/reset`、`/status` 等 | 能（`ownerId` 本人） |
| 二代仿真模式（她自己决定什么时候说话） | 能，和 QQ 群一样 |
| 拍一拍、语音、合并转发 | 不能，只有 QQ 有；她在 Telegram 会话里调这些会被告知不支持 |
| 封闭 agent 模式（closed-agent） | 只认 QQ 管理员 |

**贴纸**

Telegram 的 bot 读写不了你账号里的"收藏贴纸"，它能长期存贴纸的唯一办法是自己建贴纸包。这两项**默认关闭**，在配置页的 Telegram 一栏里分别打开（需要先填 `ownerId`）：

- **收藏**（包名 `her_fav_<标记>_by_<bot用户名>`）：她在 Telegram 上看到喜欢的贴纸或图片时收藏进来，对应 QQ 那边的"偷表情"。
- **QQ 表情同步**（包名 `her_qq_<标记>_by_<bot用户名>`）：把她的 QQ 收藏表情同步过去，这样在 Telegram 上发出去的是真贴纸。静态图会缩放成 512 像素，GIF 会转成视频贴纸（超过 3 秒的截掉后面），所以要装 ffmpeg（`brew install ffmpeg`）。每 30 分钟同步一轮，每轮最多尝试 20 张，一个包最多 120 张；同一张失败 3 次就不再试（比如有的 ffmpeg 解不了动态 WebP）。

另外，她在 Telegram 上收藏的贴纸或图片**默认会同时存一份进 QQ 收藏表情**，这样在 QQ 上也能发。这一份存在 bot 自己的 QQ 号里，不公开，也不需要填 `ownerId`。静态贴纸存成 PNG，视频贴纸转成 GIF（要 ffmpeg），矢量动画贴纸只能存它的静态缩略图。配置页里的「同时存一份进 QQ 收藏表情」可以关掉。**从旧版本升级的注意**：这一项对已有配置也是默认开着的——白名单里的 Telegram 群友发张图让她收藏，这张图就会进 bot 的 QQ 收藏，之后她在 QQ 群里也可能用它，和 QQ 上"偷表情"一样。不想要就在配置页关掉。从 Telegram 收藏过来的表情不会再被「QQ 表情同步」传回 Telegram。

> ⚠️ **贴纸包是公开的**：知道包名的人都能打开、添加。打开同步，QQ 收藏里的私人照片、截图会进一个挂在你名下的公开包；打开收藏，群友也能发张图让她收进去。确认能接受再打开。

两个包的链接 `t.me/addstickers/包名` 会打在桥接启动日志里，你自己也能添加来用。包名里的 `<标记>` 由 bot 和 `ownerId` 算出来（不会暴露你的 id）：换 bot 或换管理员会改用新包。QQ 里删掉的表情会从同步包里删掉——前提是她的 QQ 表情库是完整的（收藏超过 100 张时，本地表情库本来就不会删旧条目）。

**同一个人**

同一个人在 QQ 和 Telegram 上默认是两段独立的私聊。在配置页 Telegram 一栏的「同一个人」里每行写一对 `QQ号 = Telegram id`，这个人两边的私聊就会并成一段：

- 她不管在哪边都接着同一段聊天（QQ 那边的私聊是主线；Telegram 那边原来的私聊状态不再接着用，备份在 qq-bridge 的 `state/social-v2.linked-backup.json`，取消合并后可以手动找回）。
- 她回的话发到 TA 最后说话的那个平台。想固定一边，在 config.json 的那一组里加 `"prefer": "qq"` 或 `"prefer": "telegram"`。
- 白名单还是两边各管各的：哪边没放行，那边的消息不收、也不往那边发（拍一拍、语音只看 QQ 的白名单）。两边都发不了时（比如 QQ 没放行、Telegram 又没连上），她的话不会发出去。
- 她看到的每条消息开头会标 `[QQ]` 或 `[Telegram]`；拍一拍、语音只能发到 QQ。
- 只合并私聊，群聊不受影响。

**常见问题**

- 日志里 `连不上 Telegram … 国内一般要配 telegram.proxy`：代理没填或者没开。
- 消息能收能发，但时不时冒出 `Client network socket disconnected before secure TLS connection was established` 或 `socket hang up`（看图、发消息偶尔失败）：多半是代理里给 Telegram 用的那个节点不稳，新连接在 TLS 握手时被掐断。已经连上的连接会复用，所以大部分请求还是成功的。
  - 验证方法：终端里连跑几次 `curl -s -o /dev/null -w '%{http_code}\n' https://api.telegram.org/`。经常输出 `000`、而换成 `https://www.google.com/` 一直正常，就是 Telegram 那条线路的问题。
  - 解决：在代理软件里给 Telegram 那个策略组（比如「电报信息」）换一个节点。
  - 桥接这边做了两件事，但节点太差的话照样会失败：
    - 空闲连接保留 60 秒（Node 默认 5 秒），隔一会儿再看图也能用热连接，少碰新建连接。
    - 自动重试：握手前就断的请求肯定没发出去，什么都重试，最多 4 次；握手后才断的只重试看图这类只读请求，最多 2 次，发消息不重试，免得发两遍。
  - 本机实测（那条线路新连接六七成会被掐断）：隔 6 秒调一次，15 次全成功，第一次靠重试花了 3 秒，后面复用连接 0.3 秒。
- 日志里 `botToken 无效`：token 抄错了，或者在 BotFather 里重置过。
- 日志里 `同一个 bot 有别的程序在收消息，或者设置了 webhook`：一个 bot 同时只能有一个接收方，把别处跑着的同一个 bot 停掉。
- 桥接停机期间积压超过 10 分钟的消息，重启后不再回复（免得一上线就对着旧消息刷屏）。
- 收藏贴纸或同步表情时报 `user not found` / `PEER_ID_INVALID` 一类错误：贴纸包要挂在 `ownerId` 名下，先用这个号给 bot 发一句话。
- 同步日志里有 `找不到 ffmpeg`：装 ffmpeg，或在 config.json 的 `socialV2.voice.ffmpegPath` 填它的路径。

