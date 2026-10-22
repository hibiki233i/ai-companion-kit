#!/bin/bash
# ════════════════════════════════════════════════════════════════
#  双击 = 让她自己写一篇日记（读角色卡、记得的人、今天聊的话、最近几篇）
#
#  想自己手打：./写日记.command 手动
#  日记默认存在：packages/companion/data/diary
# ════════════════════════════════════════════════════════════════
source "$(dirname "$0")/_env.sh"
cd "$KIT" || exit 1
DIARY="packages/companion/src/diary.js"
CFG="packages/companion/config.json"

if ! node_at_least 18; then
  echo "没找到 node（18+）—— 先跑一次 tools/安装.command"
  pause; exit 1
fi

# 第一次用：自动生成 config.json + role.md，然后打开编辑让你填 key
if [ ! -f "$CFG" ]; then
  if [ -f "packages/companion/config.example.json" ]; then
    cp "packages/companion/config.example.json" "$CFG"
    [ -f "packages/companion/role.md" ] || cp "packages/companion/role.example.md" "packages/companion/role.md"
    echo
    echo " 第一次用：已经帮你生成了 config.json"
    echo " 把 apiKey 那行换成你自己的 key（platform.deepseek.com 注册就有）"
    echo " 保存、关掉编辑器，再双击一次这个文件"
    echo
    if [ "$(uname)" = "Darwin" ]; then open -e "$CFG"; else "${EDITOR:-nano}" "$CFG"; fi
    pause; exit 0
  fi
  echo "找不到 packages/companion/config.example.json —— 仓库下载不完整"
  pause; exit 1
fi

if [ "$1" = "手动" ]; then
  echo
  echo "──────────────────────────────────────────────"
  echo "  手动写 · 写完回车（空着直接回车 = 不写了）"
  echo "──────────────────────────────────────────────"
  echo
  while true; do
    read -r -p "今天发生了什么：" TEXT
    [ -n "$TEXT" ] || { echo "空的就不写了"; break; }
    read -r -p "心情（一两个字，可以空着）：" MOOD
    read -r -p "标题（可以空着）：" TITLE
    node "$DIARY" add "$TEXT" --mood "$MOOD" --title "$TITLE"
    echo
    read -r -p "再写一条？(y/N)：" MORE
    case "$MORE" in [yY]*) ;; *) break ;; esac
  done
else
  echo
  echo "──────────────────────────────────────────────"
  echo "  写日记 · 她自己写，你看着就行"
  echo "──────────────────────────────────────────────"
  if ! node "$DIARY" auto; then
    echo
    echo "没写成。常见原因：apiKey 不对、没联网、额度用光了。"
    pause; exit 1
  fi
fi

echo
echo "── 最近 3 篇 ──"
node "$DIARY" list -n 3
echo
pause
