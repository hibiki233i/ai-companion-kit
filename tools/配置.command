#!/bin/bash
# 打开 qq-bridge 的「连接配置」页面：QQ 网关地址 / token、DSH、白名单，还能当场测试连接。
# 不用先启动桥接。找 qq-bridge 的顺序同 启动.command。
# 用法：双击；或 ./配置.command [qq-bridge 目录]
source "$(dirname "$0")/_env.sh"

if ! BRIDGE=$(find_bridge "$1"); then
  echo "  ✗ 找不到 qq-bridge —— 先跑一次 安装.command，或者：./配置.command /你的/qq-bridge"
  pause; exit 1
fi
if [ ! -f "$BRIDGE/scripts/config-gui.mjs" ]; then
  echo "  ✗ 这份 qq-bridge 没有配置页（缺 scripts/config-gui.mjs）。"
  echo "    用改过的那份，或者直接编辑：$BRIDGE/config.json"
  pause; exit 1
fi
if ! node_at_least 22 13; then
  echo "  ✗ 没有 Node.js 22.13+ —— 先跑一次 安装.command（会自动下便携版）"
  pause; exit 1
fi
exec node "$BRIDGE/scripts/config-gui.mjs" --config "$BRIDGE/config.json"
