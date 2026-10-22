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
