#!/bin/bash
# install-node.sh —— install-node.ps1 的 macOS / Linux 版：把 Node.js 免安装版下到 tools/_runtime/node。
# 不碰系统、不改 PATH 配置文件，只给这些脚本自己用。
#
# 用法：
#   bash install-node.sh
#   bash install-node.sh --dest ~/qq-bridge/_runtime/node --version v22.23.3
# 出口码：0 = node 可用；1 = 失败

DEST=""
VERSION="v22.23.3"
while [ $# -gt 0 ]; do
  case "$1" in
    --dest) DEST="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[ -n "$DEST" ] || DEST="$(cd "$(dirname "$0")" && pwd)/_runtime/node"

step() { echo "        $*"; }

case "$(uname -s)" in
  Darwin) os=darwin ;;
  Linux) os=linux ;;
  *) step "❌ 不认识的系统：$(uname -s)"; exit 1 ;;
esac
case "$(uname -m)" in
  arm64|aarch64) arch=arm64 ;;
  x86_64) arch=x64 ;;
  *) step "❌ 不认识的 CPU：$(uname -m)"; exit 1 ;;
esac
pkg="node-$VERSION-$os-$arch"

# ── 已经可用就直接返回 ─────────────────────────────────────────
if [ -x "$DEST/bin/node" ] && v=$("$DEST/bin/node" -v 2>/dev/null); then
  step "便携版已存在：$v（$DEST）"
  exit 0
fi

# ── 依次试镜像 ────────────────────────────────────────────────
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
got=""
for u in \
  "https://npmmirror.com/mirrors/node/$VERSION/$pkg.tar.gz" \
  "https://mirrors.tuna.tsinghua.edu.cn/nodejs-release/$VERSION/$pkg.tar.gz" \
  "https://nodejs.org/dist/$VERSION/$pkg.tar.gz"; do
  step "下载中：$u"
  if curl -fL --connect-timeout 15 --max-time 600 -o "$tmp/node.tar.gz" "$u" 2>/dev/null \
     && [ "$(wc -c < "$tmp/node.tar.gz")" -gt 10000000 ]; then
    got="$u"; break
  fi
  step "这个源不行，换下一个"
done
[ -n "$got" ] || { step "❌ 三个源都没下下来"; exit 1; }

# ── 解压、去掉外层目录、落位 ──────────────────────────────────
step "解压中…"
tar -xzf "$tmp/node.tar.gz" -C "$tmp" || { step "❌ 解压失败"; exit 1; }
[ -d "$tmp/$pkg" ] || { step "❌ 压缩包里没有 $pkg"; exit 1; }
rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
mv "$tmp/$pkg" "$DEST" || { step "❌ 放不进 $DEST"; exit 1; }

# ── 验收 ─────────────────────────────────────────────────────
v=$("$DEST/bin/node" -v 2>/dev/null) || { step "❌ node 跑不起来"; exit 1; }
step "✅ 便携版 Node $v 已就位：$DEST"
[ -x "$DEST/bin/npm" ] && step "✅ npm 也在" || step "⚠️ 没看到 npm"
exit 0
