# tools/*.command 共用的环境（macOS / Linux）。不单独运行，由各脚本 source。
#
# - TOOLS / KIT：tools 目录和仓库根目录
# - 便携版 Node（install-node.sh 装在 tools/_runtime/node）优先于系统 Node
# - pause：双击打开的终端窗口跑完别一闪而过

TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT="$(cd "$TOOLS/.." && pwd)"

if [ -x "$TOOLS/_runtime/node/bin/node" ]; then
  PATH="$TOOLS/_runtime/node/bin:$PATH"
  export PATH
fi

pause() { read -r -p "${1:-按回车关闭…}" _; }

# node 版本是否 ≥ $1.$2（默认 18.0）
node_at_least() {
  command -v node >/dev/null 2>&1 || return 1
  node -e "const [a,b]=process.versions.node.split('.').map(Number);process.exit(a>${1:-18}||(a===${1:-18}&&b>=${2:-0})?0:1)"
}

# 本机端口有没有人在听（不依赖 nc 的参数差异）
port_open() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }

# 找 qq-bridge：参数 > HER_BRIDGE_DIR > 和本仓库并排的 qq-bridge > ~/qq-bridge
find_bridge() {
  local c
  for c in "$1" "$HER_BRIDGE_DIR" "$KIT/../qq-bridge" "$HOME/qq-bridge"; do
    [ -n "$c" ] && [ -f "$c/src/bridge.js" ] && { (cd "$c" && pwd); return 0; }
  done
  return 1
}
