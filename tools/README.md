# tools · 给不想手敲命令的人

这两个 `.bat` 是给**完全不想碰命令行**的人准备的。

| 文件 | 干什么 |
|---|---|
| `安装.bat` | 下 qq-bridge → 装依赖 → 生成 config.json → 打开记事本让你填三个值 |
| `启动.bat` | 检查前置 → 启动 qq-bridge |

## 怎么用

1. 双击 `安装.bat`，一路回车
2. 按提示填三个值（你的 QQ 号 / 她的 QQ 号 / SnowLuma 的访问令牌）
3. 把 `启动.bat` 复制到 qq-bridge 文件夹里，双击它

## 它们不会做什么

- ❌ 不装 DSH / SnowLuma（那两个你得自己装，见[傻瓜版教程](../docs/小黑盒/06-傻瓜版.txt)）
- ❌ 不动你现有的任何文件（都放新目录）
- ❌ 不联网发任何东西出去

## 出错了怎么办

`安装.bat` 每一步都会告诉你卡在哪。最常见的两个：

- **"没找到 Node.js"** → 去 nodejs.org 下 LTS 版，装完**重启电脑**
- **npm install 报红** → 脚本会问你要不要换国内镜像，选 Y
## macOS / Linux

同样的事，换成 `.command`（Finder 里双击会开一个终端窗口跑）：

| 文件 | 干什么 |
|---|---|
| `安装.command` | 装 Node 便携版（缺或太旧时）→ 准备 qq-bridge → 装依赖 → 生成 NapCat 模式的 config.json → 打开文本编辑填值 |
| `启动.command` | 按 config.json 的端口检查 NapCat / DSH → 启动 qq-bridge 守护（不用复制进 qq-bridge 目录） |
| `配置.command` | 浏览器里改 qq-bridge 的连接配置（网关地址 / token、DSH、白名单），能当场测试连接 |
| `写日记.command` / `看日记.command` | 同 Windows 版 |
| `install-node.sh` | 单独下 Node 便携版到 `tools/_runtime/node` |

Mac 上没有 SnowLuma，QQ 网关用 NapCat。完整步骤和 config 怎么填：[macOS + NapCat 适配](../docs/macOS-NapCat-适配.md)。
