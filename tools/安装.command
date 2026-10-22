#!/bin/bash
# ════════════════════════════════════════════════════════════════
#  小鲸鱼安装器（macOS / Linux 版 安装.bat）—— qq-bridge 装好、依赖装好、配置生成好
#
#  这个脚本做五件事：
#    ① 检查 Node.js（没有或太旧就自动下便携版，不碰系统）
#    ② 准备 qq-bridge（旁边已经有一份就直接用；没有就从 GitHub 下）
#    ③ npm install
#    ④ 生成 config.json，并预先设成 NapCat 模式
#    ⑤ 打开文本编辑让你填几个值
#
#  它【不会】：
#    × 装 DSH / NapCat（这两个你得自己装，见 docs/macOS-NapCat-适配.md）
#    × 动你现有的任何文件（config.json 已存在就不改）
#
#  用法：双击；或 ./安装.command [装到哪个目录]
# ════════════════════════════════════════════════════════════════
source "$(dirname "$0")/_env.sh"

echo
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║      小鲸鱼 · 一键安装（qq-bridge · macOS）      ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo

# ── 选安装目录：参数 > 已经有的 qq-bridge > 问一下（默认 ~/qq-bridge）──
TARGET="$1"
if [ -z "$TARGET" ]; then
  if TARGET=$(find_bridge); then
    echo "  找到现成的 qq-bridge：$TARGET（就用它，不再下载）"
  else
    echo "  装到哪个文件夹？（直接回车 = $HOME/qq-bridge）"
    read -r -p "  路径：" TARGET
    [ -n "$TARGET" ] || TARGET="$HOME/qq-bridge"
  fi
fi
TARGET="${TARGET/#\~/$HOME}"
echo
echo "  安装到：$TARGET"
echo

# ── ① Node.js（qq-bridge 要求 22.13+）────────────────────────────
echo "  [1/5] 检查 Node.js..."
if ! node_at_least 22 13; then
  if command -v node >/dev/null 2>&1; then
    echo "        系统里的 Node $(node -v) 太旧（qq-bridge 要 22.13+）"
  else
    echo "        系统里没有 Node.js"
  fi
  echo "        自动下载便携版（约 50MB，只给这套东西用，不改系统）"
  echo
  if ! bash "$TOOLS/install-node.sh" --dest "$TOOLS/_runtime/node"; then
    echo
    echo "  ✗ 便携版也没下下来（大概率是网络问题）"
    echo "    A. 过一会儿再跑一次本脚本"
    echo "    B. 自己装：brew install node@22，或去 nodejs.org 下 LTS 的 .pkg"
    pause; exit 1
  fi
  PATH="$TOOLS/_runtime/node/bin:$PATH"
fi
echo "        OK  Node.js $(node -v)"
command -v npm >/dev/null 2>&1 || { echo "  ✗ 有 node 但没 npm —— Node 装坏了，删掉 tools/_runtime/node 再跑一次"; pause; exit 1; }
echo "        OK  npm"

# ── ② qq-bridge ───────────────────────────────────────────────
echo
echo "  [2/5] 准备 qq-bridge..."
if [ -f "$TARGET/src/bridge.js" ]; then
  echo "        已经在了，跳过下载"
  if [ ! -f "$TARGET/src/onebot-impl.js" ]; then
    echo "        ⚠️  这份 qq-bridge 没有 NapCat 适配（缺 src/onebot-impl.js）"
    echo "           聊天能用，但「收藏表情 / 改表情备注」在 NapCat 下会失败"
  fi
else
  if [ -e "$TARGET" ] && [ -n "$(ls -A "$TARGET" 2>/dev/null)" ]; then
    echo "        !! 目录已存在但不是 qq-bridge：$TARGET"
    echo "        换个目录，或者先把它挪走"
    pause; exit 1
  fi
  echo "        ⚠️  从 GitHub 下的是原版 qq-bridge，没有 NapCat 表情适配；"
  echo "           有改好的那份就把它放到 ai-companion-kit 旁边，再跑一次本脚本"
  tmp=$(mktemp -d)
  ok=""
  for u in \
    "https://gh-proxy.com/https://github.com/Derpyu520/qq-bridge/archive/refs/heads/main.zip" \
    "https://github.com/Derpyu520/qq-bridge/archive/refs/heads/main.zip"; do
    echo "        正在下载：$u"
    if curl -fL --connect-timeout 15 --max-time 300 -o "$tmp/qqb.zip" "$u" 2>/dev/null; then ok=1; break; fi
    echo "        这个源不行，换下一个"
  done
  if [ -z "$ok" ]; then
    rm -rf "$tmp"
    echo
    echo "  ✗ 下载失败（多半是网络）。手动下："
    echo "    1. 浏览器打开 github.com/Derpyu520/qq-bridge"
    echo "    2. 绿色 Code 按钮 → Download ZIP"
    echo "    3. 解压到 $TARGET"
    echo "    4. 再跑一次本脚本（它会跳过下载）"
    pause; exit 1
  fi
  echo "        正在解压..."
  # macOS 自带的 unzip 遇到仓库里的中文文件名会报 write error，用系统的 ditto 解
  if [ "$(uname)" = "Darwin" ]; then
    ditto -x -k "$tmp/qqb.zip" "$tmp/x"
  else
    unzip -q "$tmp/qqb.zip" -d "$tmp/x"
  fi || { rm -rf "$tmp"; echo "  ✗ 解压失败"; pause; exit 1; }
  inner=$(find "$tmp/x" -mindepth 1 -maxdepth 1 -type d | head -1)
  mkdir -p "$TARGET"
  cp -R "$inner"/. "$TARGET"/
  rm -rf "$tmp"
  echo "        OK  解压完成"
fi

# ── ③ npm install ─────────────────────────────────────────────
echo
echo "  [3/5] 安装依赖（npm install）..."
echo "        第一次可能要几分钟，别关窗口"
echo
if ! (cd "$TARGET" && npm install --no-audit --no-fund); then
  echo
  echo "  !! npm install 报错了 —— 十有八九是网络"
  read -r -p "  要换国内镜像（registry.npmmirror.com）再装一次吗？[Y/n] " yn
  case "$yn" in
    [nN]*) echo "  好，没换。手动：cd \"$TARGET\" && npm install --registry=https://registry.npmmirror.com" ;;
    *) (cd "$TARGET" && npm install --no-audit --no-fund --registry=https://registry.npmmirror.com) ;;
  esac
fi
echo "        OK  依赖装好了"

# ── ④ config.json（新建时预设 NapCat 模式）──────────────────────
echo
echo "  [4/5] 生成配置文件..."
CFG="$TARGET/config.json"
if [ -f "$CFG" ]; then
  echo "        已有 config.json，不动它（NapCat 要改的地方见 docs/macOS-NapCat-适配.md）"
elif [ ! -f "$TARGET/config.example.json" ]; then
  echo "        !! 没找到 config.example.json（下载可能不完整）"
else
  # impl=napcat：不用每次探测；followDiscoveredEndpoint=false：别让 SnowLuma 的自愈逻辑改写端点
  node -e '
    const fs = require("fs");
    const [src, dst] = process.argv.slice(1);
    const c = JSON.parse(fs.readFileSync(src, "utf8").replace(/^﻿/, ""));
    c.snowluma = { ...(c.snowluma || {}), impl: "napcat", followDiscoveredEndpoint: false };
    fs.writeFileSync(dst, JSON.stringify(c, null, 2) + "\n", { mode: 0o600 });
  ' "$TARGET/config.example.json" "$CFG" && echo "        OK  生成了 config.json（已设成 NapCat 模式）"
fi

# ── ⑤ 打开编辑 ────────────────────────────────────────────────
echo
echo "  [5/5] 打开配置文件，要填这几个地方："
echo
echo "   ──────────────────────────────────────────────────"
echo "    ① ownerQQ              → 改成【你的】QQ 号"
echo "    ② allow.private        → 方括号里填数字（一般就是你的号）"
echo "    ③ snowluma.accessToken → NapCat 网络配置里设的 token"
echo "                             （HTTP 和 WebSocket 两个服务要设成同一个）"
echo "    ④ snowluma.wsUrl / httpUrl → 默认 3001 / 3000，和 NapCat 里一致就不用改"
echo "   ──────────────────────────────────────────────────"
echo
echo "   填完保存（⌘S）、关掉编辑器就行"
echo
pause "  按回车打开 config.json…"
if [ "$(uname)" = "Darwin" ]; then open -e "$CFG"; else "${EDITOR:-nano}" "$CFG"; fi

echo
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║  装好了                                          ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo
echo "  接下来："
echo "    ① 确认 NapCat 已经扫码登录、HTTP(3000)/WebSocket(3001) 两个服务开着"
echo "    ② 确认 DeepSeek Harness 已经开着"
echo "    ③ 双击 tools/启动.command"
echo
[ -x "$TOOLS/_runtime/node/bin/node" ] && echo "  （便携版 Node 在 tools/_runtime/node，启动脚本会自动用它）" && echo
echo "  装在： $TARGET"
echo
pause
