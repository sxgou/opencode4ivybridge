#!/bin/bash
#
# setup.sh — opencode4ivybridge: 配置 OpenCode CLI
#
# 依赖: 已编译安装的 bun (见 ../bun4ivybridge/)
#
# 使用方法:
#   ./setup.sh                          # 默认安装到 ~/.local/share/opencode
#   OPENCODE_DIR=/opt/opencode ./setup.sh  # 自定义路径
#
# 环境变量:
#   OPENCODE_DIR    安装路径 (默认: ~/.local/share/opencode)
#   BUN_PATH        bun 路径 (默认: ~/.bun/bin/bun)
#   INSTALL_BIN     包装脚本目标 (默认: ~/.local/bin/opencode)
#
set -euo pipefail

OPENCODE_DIR="${OPENCODE_DIR:-$HOME/.local/share/opencode}"
BUN_PATH="${BUN_PATH:-$HOME/.bun/bin/bun}"
INSTALL_BIN="${INSTALL_BIN:-$HOME/.local/bin/opencode}"

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ============================================================
# 辅助函数
# ============================================================
info()  { printf "\033[36m[INFO]\033[0m %s\n" "$*"; }
ok()    { printf "\033[32m[OK]\033[0m   %s\n" "$*"; }
err()   { printf "\033[31m[ERROR]\033[0m %s\n" "$*"; }

confirm() {
  printf "\033[33m%s [Y/n]:\033[0m " "$1"
  read -r ans
  case "$ans" in
    n|N|no|NO) return 1 ;;
    *) return 0 ;;
  esac
}

# ============================================================
# 前置检查
# ============================================================
info "opencode4ivybridge - OpenCode 配置脚本"
echo "  opencode 目录: $OPENCODE_DIR"
echo "  bun 路径:      $BUN_PATH"
echo "  包装脚本:       $INSTALL_BIN"

# 检查 bun
if ! "$BUN_PATH" --version &>/dev/null; then
  err "bun 不可用: $BUN_PATH"
  err "请先完成 bun4ivybridge 项目编译 bun"
  err "  cd ../bun4ivybridge && bash scripts/build.sh"
  exit 1
fi
BUN_VER=$("$BUN_PATH" --version)
ok "bun $BUN_VER 可用"

# 检查 git
if ! command -v git &>/dev/null; then
  err "请先安装 git"
  exit 1
fi

# ============================================================
# 克隆 opencode
# ============================================================
if [[ -d "$OPENCODE_DIR/.git" ]]; then
  info "opencode 已存在，更新..."
  cd "$OPENCODE_DIR"
  git pull
else
  mkdir -p "$OPENCODE_DIR"
  info "克隆 opencode ..."
  git clone https://github.com/sst/opencode.git "$OPENCODE_DIR"
fi
ok "opencode 源码已就绪"

# ============================================================
# 安装依赖
# ============================================================
OPCODE_PKG="$OPENCODE_DIR/packages/opencode"
if [[ ! -d "$OPCODE_PKG" ]]; then
  err "未找到 packages/opencode 目录，opencode 仓库结构可能已变化"
  exit 1
fi

cd "$OPCODE_PKG"
info "安装依赖 (bun install)..."
"$BUN_PATH" install
ok "依赖安装完成"

# ============================================================
# 创建包装脚本
# ============================================================
mkdir -p "$(dirname "$INSTALL_BIN")"

# 使用项目中的独立包装脚本模板，填入实际路径
sed -e "s|\${BUN:-\$HOME/.bun/bin/bun}|$BUN_PATH|g" \
    -e "s|\${OPENCODE_DIR:-\$HOME/.local/share/opencode}|$OPENCODE_DIR|g" \
    -e "s|\$HOME|$HOME|g" \
    "$PROJECT_DIR/scripts/opencode-wrapper.sh" > "$INSTALL_BIN"

chmod +x "$INSTALL_BIN"
ok "包装脚本已创建: $INSTALL_BIN（基于 opencode-wrapper.sh 模板）"

# ============================================================
# 可选: 符号链接
# ============================================================
BUN_BIN_DIR="$(dirname "$BUN_PATH")"
if [[ "$BUN_BIN_DIR" != "$(dirname "$INSTALL_BIN")" ]]; then
  if confirm "创建符号链接 $BUN_BIN_DIR/opencode ?"; then
    ln -sf "$INSTALL_BIN" "$BUN_BIN_DIR/opencode"
    ok "符号链接已创建: $BUN_BIN_DIR/opencode"
  fi
fi

# ============================================================
# 验证
# ============================================================
if ! "$INSTALL_BIN" --version 2>&1 | grep -qv "local"; then
  warn "opencode --version 显示 'local'，版本注入可能未生效"
else
  ok "opencode --version: $("$INSTALL_BIN" --version 2>&1)"
fi

echo ""
info "==========================================="
info "opencode 配置完成!"
info "  运行: opencode"
info "==========================================="
