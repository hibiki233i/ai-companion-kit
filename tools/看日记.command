#!/bin/bash
# 双击就能翻她的日记（最近 5 篇）
# 想看某一天：直接打开 packages/companion/data/diary/YYYY-MM-DD.md
source "$(dirname "$0")/_env.sh"
cd "$KIT" || exit 1
DIARY="packages/companion/src/diary.js"

if ! node_at_least 18; then
  echo "没找到 node（18+）—— 先跑一次 tools/安装.command"
  pause; exit 1
fi

echo
echo "── 最近 5 篇 ──"
node "$DIARY" list -n 5
echo
echo "── 一共写了多少 ──"
node "$DIARY" stats
echo
pause
