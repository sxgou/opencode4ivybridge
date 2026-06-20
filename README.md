# opencode4ivybridge: Run OpenCode on Ivy Bridge CPUs

在 Ivy Bridge CPU 上通过自编译的 bun 运行 OpenCode。

Run OpenCode (AI coding assistant CLI) on Ivy Bridge CPUs using a self-compiled bun, bypassing compatibility issues with prebuilt binaries.

## Environment / 适用环境

- **CPU**: Intel Xeon E5-2696 v2 (Ivy Bridge, 2013)
- **OS**: macOS 12+ (Monterey, verified 12.7.6)
- **Runtime**: Requires self-compiled bun (see `../bun4ivybridge/`)

> ⚠️ **Compatibility / 兼容性说明**
> - This project only involves configuring bun runtime parameters and creating wrapper scripts — no compilation needed
> - **Only tested on macOS 12+**, other OS untested
> - Key dependency is the bun binary from bun4ivybridge; its compatibility is determined by build flags
> - `--conditions=browser` is a requirement of opencode itself; may change in future versions

## Background / 问题背景

OpenCode is an AI coding assistant CLI written in TypeScript. It runs via `bun run`, with these requirements:

1. macOS "baseline" prebuilt binaries require Haswell+ CPUs (same WebKit baseline issue as bun) — won't run on Ivy Bridge
2. Needs a custom-compiled bun (see `../bun4ivybridge/`)
3. Running from source requires correct bun flags (`--conditions=browser`, `--define`, etc.)

OpenCode 是一个用 TypeScript 编写的 AI 编码助手 CLI，通过 `bun run` 执行。主要问题：
1. macOS baseline 预构建二进制在 Ivy Bridge 上无法运行
2. 需要使用自定义编译的 bun
3. 直接从源码运行需要正确的 bun 参数

## Directory Structure / 目录结构

```
opencode4ivybridge/
├── README.md                          # This file / 本文件
└── scripts/
    ├── setup.sh                       # Automated setup script / 自动化配置脚本
    └── opencode-wrapper.sh            # Portable wrapper template / 可移植包装脚本模板
```

## Prerequisites / 前置依赖

- **bun**: Must be a source-compiled version compatible with Ivy Bridge. See `../bun4ivybridge/README.md`
- **git**: For cloning OpenCode from GitHub

## Quick Start / 快速设置

### Using setup.sh / 使用自动化脚本

```bash
# Default install to ~/.local/share/opencode
bash scripts/setup.sh

# Custom paths / 自定义路径
# OPENCODE_DIR=/opt/opencode BUN_PATH=/opt/bun/bin/bun bash scripts/setup.sh
```

### Manual Setup / 手动设置

### 1. Clone OpenCode / 克隆源码

```bash
mkdir -p ~/.local/share/opencode
cd ~/.local/share/opencode
git clone https://github.com/sst/opencode.git .
```

### 2. Install Dependencies / 安装依赖

```bash
cd ~/.local/share/opencode/packages/opencode
bun install
```

### 3. Create Wrapper Script / 创建包装脚本

```bash
# Using the portable wrapper template (recommended / 推荐)
cp /path/to/opencode4ivybridge/scripts/opencode-wrapper.sh ~/.local/bin/opencode
chmod +x ~/.local/bin/opencode

# Customize / 如需自定义:
# BUN=/opt/bun/bin/bun opencode
```

**Ensure `~/.local/bin` is in your PATH**. Add to `~/.zshrc` if needed:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

### 4. Optional Symlink / 可选符号链接

```bash
ln -sf ~/.local/bin/opencode ~/.bun/bin/opencode
```

### 5. Verify / 验证

```bash
opencode --version
# Expected: e.g. 1.17.8 (actual version)

opencode --help
# Expected: OpenCode help information
```

## Known Issues & Solutions / 遇到的问题及解决办法

### Issue 1: macOS "baseline" binary needs BMI2 — SIGILL

**Symptom**: Prebuilt binary or bun crashes with SIGILL (exit code 132).

**Cause**: Apple's macOS "baseline" threshold is Haswell (2014), including BMI2 instructions. Ivy Bridge (2013) doesn't support BMI2.

**Solution**: Build bun from source with `-march=nehalem` (see `../bun4ivybridge/`). OpenCode itself is TypeScript source run by bun — no separate compilation needed.

### Issue 2: `opencode --version` shows "local"

**Symptom**: `opencode --version` prints `opencode-local` instead of a version number.

**Cause**: OpenCode uses `OPENCODE_VERSION` compile-time constant. When running from source without this constant, it falls back to `"local"`.

**Solution**: Use bun's `--define` flag to inject the version at runtime. The wrapper script reads the version from `package.json` automatically.

**Key syntax**: `--define` format is `--define KEY:JSON_VALUE` (space-separated, value must be a JSON string with quotes).

### Issue 3: `--preload` + `globalThis` doesn't work in ESM

**Symptom**: Trying to use `--preload` to set `globalThis.OPENCODE_VERSION` fails.

**Root cause**:
1. `bun run -e script-name` in a directory with `package.json` interprets `-e` as a script name
2. In ESM strict mode, setting `globalThis.X` doesn't make `X` accessible as a bare identifier

**Solution**: Use `--define` instead of `--preload`.

### Issue 4: `bun run` argument parsing in package directories

**Symptom**: Wrong `--define` syntax gets interpreted as a script name.

**Solution**: Use correct format:
```bash
# Correct / 正确（spaces, JSON-quoted value）
bun run --define OPENCODE_VERSION:"\"1.17.8\"" ./src/index.ts

# Wrong / 错误（colon-separated, bun doesn't support this）
bun run --define:OPENCODE_VERSION="1.17.8" ./src/index.ts
```

## Quick Rebuild Reference / 快速重建备忘

```bash
# 1. Ensure bun is available / 确认 bun 可用
bun --version

# 2. Clone OpenCode / 克隆
mkdir -p ~/.local/share/opencode
cd ~/.local/share/opencode
git clone https://github.com/sst/opencode.git .

# 3. Install deps / 安装依赖
cd ~/.local/share/opencode/packages/opencode
bun install

# 4. Create wrapper / 创建包装脚本
cp /path/to/opencode4ivybridge/scripts/opencode-wrapper.sh ~/.local/bin/opencode
chmod +x ~/.local/bin/opencode

# 5. Verify / 验证
opencode --version
```
