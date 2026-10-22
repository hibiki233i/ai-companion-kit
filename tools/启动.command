#!/bin/bash
# ════════════════════════════════════════════════════════════════
#  启动 qq-bridge（macOS / Linux 版 启动.bat）
#  先查前置（QQ 网关、DSH），再进守护模式：崩了 5 秒后自动拉起。
#  这个窗口要一直开着 —— 关了她就下线了。
#
#  不用像 Windows 版那样复制进 qq-bridge 目录：它会自己找
#  （参数 > HER_BRIDGE_DIR > 和本仓库并排的 qq-bridge > ~/qq-bridge）
#  用法：双击；或 ./启动.command [qq-bridge 目录]
# ════════════════════════════════════════════════════════════════
source "$(dirname "$0")/_env.sh"

echo
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║                 小鲸鱼 · 启动中                  ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo

if ! BRIDGE=$(find_bridge "$1"); then
  echo "  ✗ 找不到 qq-bridge"
  echo "    先跑一次 安装.command，或者：./启动.command /你的/qq-bridge"
  pause; exit 1
fi
if [ ! -f "$BRIDGE/config.json" ]; then
  echo "  ✗ $BRIDGE 里没有 config.json —— 先跑一次 安装.command"
  pause; exit 1
fi
if ! node_at_least 22 13; then
  echo "  ✗ 没有 Node.js 22.13+ —— 先跑一次 安装.command（会自动下便携版）"
  pause; exit 1
fi

echo "  检查前置服务..."
echo

# 端口从 config.json 里读，不写死
read -r HTTP_PORT WS_PORT DSH_PORT IMPL < <(node -e '
  const c = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8").replace(/^﻿/, ""));
  const port = (u, d) => { try { const x = new URL(u); return x.port || (x.protocol === "https:" ? 443 : 80); } catch { return d; } };
  const s = c.snowluma || {};
  console.log(port(s.httpUrl, 3000), port(s.wsUrl, 3001), port(c.dsh && c.dsh.baseUrl, 3080), s.impl || "auto");
' "$BRIDGE/config.json")

GW="QQ 网关"
[ "$IMPL" = "napcat" ] && GW="NapCat"
if port_open "$WS_PORT" && port_open "$HTTP_PORT"; then
  echo "    OK   $GW（WebSocket $WS_PORT / HTTP $HTTP_PORT）"
else
  port_open "$WS_PORT" || echo "    XX   $GW 的 WebSocket 端口 $WS_PORT 没人听"
  port_open "$HTTP_PORT" || echo "    XX   $GW 的 HTTP 端口 $HTTP_PORT 没人听"
  echo "         → 打开 NapCat、扫码登录，并在「网络配置」里把这两个服务都开上"
  echo
  pause; exit 1
fi

if port_open "$DSH_PORT"; then
  echo "    OK   DeepSeek Harness（$DSH_PORT）"
else
  echo "    !!   DeepSeek Harness 好像没开（$DSH_PORT）"
  echo "         她不理你的话，八成是这个原因"
fi

echo
echo "  ══════════════════════════════════════════════════"
echo "   下面会刷很多日志，正常，不用看"
echo
echo "   ★ 这个窗口别关 ★"
echo "   现在去 QQ 上跟她说句话试试"
echo
echo "   想让她下线：关掉这个窗口（或 Ctrl+C）"
echo "  ══════════════════════════════════════════════════"
echo

if [ -x "$BRIDGE/start.command" ]; then
  exec "$BRIDGE/start.command"
fi
# 老版本 qq-bridge 没有 start.command：直接跑一次，不带守护
cd "$BRIDGE" && node src/bridge.js
echo
echo "  她下线了。"
pause
