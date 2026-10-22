#!/bin/bash
# macOS / Linux 版 开通.bat：开通「她自己发空间」（同一个 open-zone.mjs，参数原样传过去，比如 --dry）
# 注意：NapCat 下只有「发说说」能用，看动态/点赞/评论需要 SnowLuma。
cd "$(dirname "$0")" || exit 1
TOOLS="$(cd ../../tools && pwd)"
[ -x "$TOOLS/_runtime/node/bin/node" ] && PATH="$TOOLS/_runtime/node/bin:$PATH"

echo
echo "=========================================="
echo "  开通 QQ 空间（让她自己发说说）"
echo "=========================================="
echo

if ! command -v node >/dev/null 2>&1; then
  echo "[X] 没找到 Node.js"
  echo "    先跑一次 tools/安装.command，或者 brew install node@22"
  echo
  read -r -p "按回车关闭…" _
  exit 1
fi

node open-zone.mjs "$@"

echo
read -r -p "按回车关闭…" _
