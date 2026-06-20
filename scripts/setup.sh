#!/bin/bash
#
# setup.sh — opencode4ivybridge: Set up OpenCode CLI
#
# Dependencies: A working bun binary (see ../bun4ivybridge/)
#
# Usage:
#   ./setup.sh                              # Default install to ~/.local/share/opencode
#   OPENCODE_DIR=/opt/opencode ./setup.sh   # Custom path
#
# Environment variables:
#   OPENCODE_DIR     Install path (default: ~/.local/share/opencode)
#   BUN_PATH         bun binary path (default: ~/.bun/bin/bun)
#   INSTALL_BIN      Wrapper script target (default: ~/.local/bin/opencode)
#   OPENCODE_TAG     Git tag or branch to clone (default: empty = latest main)
#   BATCH_MODE       Set to 1 to skip all interactive prompts
#
set -euo pipefail

OPENCODE_DIR="${OPENCODE_DIR:-$HOME/.local/share/opencode}"
BUN_PATH="${BUN_PATH:-$HOME/.bun/bin/bun}"
INSTALL_BIN="${INSTALL_BIN:-$HOME/.local/bin/opencode}"
OPENCODE_TAG="${OPENCODE_TAG:-}"
BATCH_MODE="${BATCH_MODE:-0}"

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ============================================================
# Helper functions
# ============================================================
info()  { printf "\033[36m[INFO]\033[0m %s\n" "$*"; }
ok()    { printf "\033[32m[OK]\033[0m   %s\n" "$*"; }
err()   { printf "\033[31m[ERROR]\033[0m %s\n" "$*"; }

confirm() {
  if [[ "$BATCH_MODE" -eq 1 ]]; then
    return 0
  fi
  printf "\033[33m%s [Y/n]:\033[0m " "$1"
  read -r ans
  case "$ans" in
    n|N|no|NO) return 1 ;;
    *) return 0 ;;
  esac
}

# ============================================================
# Pre-flight checks
# ============================================================
info "opencode4ivybridge - OpenCode Setup"
echo "  opencode dir:  $OPENCODE_DIR"
echo "  bun path:      $BUN_PATH"
echo "  wrapper:       $INSTALL_BIN"
echo "  opencode tag:  ${OPENCODE_TAG:-latest (main branch)}"

# Check bun exists and is executable
if ! [[ -x "$BUN_PATH" ]]; then
  err "bun not found at: $BUN_PATH"
  err "Please complete bun4ivybridge first:"
  err "  cd ../bun4ivybridge && bash scripts/build.sh"
  exit 1
fi

# Verify bun version
BUN_VER=$("$BUN_PATH" --version 2>/dev/null || echo "unknown")
info "bun version: $BUN_VER"

# Verify bun does not crash with SIGILL (baseline compatibility test)
if ! "$BUN_PATH" -e 'console.log("bun: ok")' &>/dev/null; then
  err "bun binary failed basic execution test (SIGILL or other crash)."
  err "This likely means the bun binary was not built with baseline compatibility."
  err "Please rebuild bun with: --baseline=true"
  exit 1
fi
ok "bun $BUN_VER - baseline compatibility verified"

# Check git
if ! command -v git &>/dev/null; then
  err "git not found. Please install git first."
  exit 1
fi

# ============================================================
# Clone opencode
# ============================================================
if [[ -d "$OPENCODE_DIR/.git" ]]; then
  info "opencode already cloned, updating..."
  cd "$OPENCODE_DIR"
  git pull
else
  mkdir -p "$OPENCODE_DIR"
  info "Cloning opencode ..."
  git clone https://github.com/sst/opencode.git "$OPENCODE_DIR"
fi

# If OPENCODE_TAG is set, checkout that specific tag/branch
if [[ -n "$OPENCODE_TAG" ]]; then
  info "Checking out tag: $OPENCODE_TAG ..."
  cd "$OPENCODE_DIR"
  git fetch --depth=1 origin "$OPENCODE_TAG" 2>/dev/null || \
    git fetch origin "$OPENCODE_TAG" 2>/dev/null || \
    { err "Cannot fetch tag $OPENCODE_TAG"; exit 1; }
  git checkout "$OPENCODE_TAG"
  ok "Checked out: $(git log --oneline -1)"
fi
ok "opencode source ready"

# ============================================================
# Install dependencies
# ============================================================
OPCODE_PKG="$OPENCODE_DIR/packages/opencode"
if [[ ! -d "$OPCODE_PKG" ]]; then
  err "packages/opencode directory not found."
  err "The opencode repository structure may have changed."
  exit 1
fi

cd "$OPCODE_PKG"
info "Installing dependencies (bun install)..."
"$BUN_PATH" install
ok "Dependencies installed"

# ============================================================
# Create wrapper script
# ============================================================
mkdir -p "$(dirname "$INSTALL_BIN")"

# Populate wrapper template with actual paths
sed -e "s|\${BUN:-\$HOME/.bun/bin/bun}|$BUN_PATH|g" \
    -e "s|\${OPENCODE_DIR:-\$HOME/.local/share/opencode}|$OPENCODE_DIR|g" \
    -e "s|\$HOME|$HOME|g" \
    "$PROJECT_DIR/scripts/opencode-wrapper.sh" > "$INSTALL_BIN"

chmod +x "$INSTALL_BIN"
ok "Wrapper script created: $INSTALL_BIN (from opencode-wrapper.sh template)"

# ============================================================
# Optional: symlink
# ============================================================
BUN_BIN_DIR="$(dirname "$BUN_PATH")"
if [[ "$BUN_BIN_DIR" != "$(dirname "$INSTALL_BIN")" ]]; then
  if confirm "Create symlink $BUN_BIN_DIR/opencode ?"; then
    ln -sf "$INSTALL_BIN" "$BUN_BIN_DIR/opencode"
    ok "Symlink created: $BUN_BIN_DIR/opencode"
  fi
fi

# ============================================================
# Verify
# ============================================================
if ! "$INSTALL_BIN" --version 2>&1 | grep -qv "local"; then
  warn "opencode --version shows 'local' — version injection may not be working"
else
  ok "opencode --version: $("$INSTALL_BIN" --version 2>&1)"
fi

echo ""
info "=========================================="
info "opencode setup complete!"
info "  Run: opencode"
info "=========================================="
