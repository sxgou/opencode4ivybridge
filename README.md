# opencode4ivybridge: 在 Ivy Bridge CPU 上从源码运行 OpenCode

在 Ivy Bridge CPU 上通过自编译的 bun 运行 OpenCode（AI 编码助手 CLI），避开没有兼容二进制的问题。

## 适用环境（已在本机验证）

- **CPU**: Intel Xeon E5-2696 v2 (Ivy Bridge, 2013)
- **操作系统**: macOS 12+ (Monterey，已验证 12.7.6)
- **运行时**: 依赖自编译的 bun（参见 `../bun4ivybridge/` 项目）

> ⚠️ **兼容性说明**
> - 本项目的核心仅涉及配置 bun 运行参数和创建包装脚本，本身不涉及编译
> - **已在 macOS 12+ 上验证**，其他操作系统未测试
> - 关键依赖是 bun4ivybridge 项目编译出的 bun，该 bun 的兼容性由其编译参数决定
> - `~/.bun/bin/bun` 路径在不同安装方式下可能不同，需根据实际情况调整
> - opencode 的 `--conditions=browser` 参数是 opencode 自身的要求，未来版本可能变化

## 问题背景

OpenCode 是一个用 TypeScript 编写的 AI 编码助手 CLI。它通过 `bun run` 执行，但有以下前置条件：

1. macOS 上标记为 "baseline" 的预构建二进制需要 Haswell 以上 CPU（与 bun 的 WebKit baseline 问题相同），在 Ivy Bridge 上无法运行
2. 需要依赖一个自定义编译的 bun（见 `../bun4ivybridge/`）
3. 直接从源码运行需要使用正确的 bun 参数（`--conditions=browser`、`--define` 等）

## 目录结构

```
opencode4ivybridge/
├── README.md                          # 本文件
└── scripts/
    └── setup.sh                       # 自动化配置脚本
```

## 前置依赖

- **bun**: 必须是从源码编译、兼容 Ivy Bridge 的版本。编译方法见 `../bun4ivybridge/README.md`
- **git**: 用于从 GitHub 克隆 OpenCode 源码

## 设置步骤

### 1. 克隆 OpenCode 源码

```bash
mkdir -p ~/.local/share/opencode
cd ~/.local/share/opencode
git clone https://github.com/sst/opencode.git .
```

### 2. 安装依赖

```bash
cd ~/.local/share/opencode/packages/opencode
bun install
```

### 3. 创建命令行包装脚本

```bash
# 使用项目提供的包装脚本（推荐）
cp scripts/opencode-wrapper.sh ~/.local/bin/opencode
chmod +x ~/.local/bin/opencode

# 或手动创建（需根据实际 bun 路径调整）
cat > ~/.local/bin/opencode << 'SCRIPT'
#!/bin/bash
BUN="${BUN:-$HOME/.bun/bin/bun}"
OPENCODE_DIR="${OPENCODE_DIR:-$HOME/.local/share/opencode}"
OPENCODE_VERSION=$(python3 -c "import json; print(json.load(open('${OPENCODE_DIR}/packages/opencode/package.json'))['version'])")
exec "$BUN" run \
  --cwd "${OPENCODE_DIR}/packages/opencode" \
  --define OPENCODE_VERSION:"\"${OPENCODE_VERSION}\"" \
  --conditions=browser ./src/index.ts "$@"
SCRIPT
chmod +x ~/.local/bin/opencode
```

**确保 `~/.local/bin` 在 `PATH` 中**。如果不存在，添加以下内容到 `~/.zshrc`：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### 4. 创建到 `~/.bun/bin/` 的符号链接（可选）

```bash
ln -sf ~/.local/bin/opencode ~/.bun/bin/opencode
```

### 5. 验证

```bash
opencode --version
# 期望输出: 如 1.17.8（具体的版本号）

opencode --help
# 期望输出: OpenCode 的帮助信息
```

## 遇到的问题及解决办法

### 问题 1: macOS "baseline" 二进制需要 BMI2 — SIGILL

**现象**: 下载的预构建二进制或依赖的 bun 运行时报 SIGILL (exit code 132)。

**原因**: macOS 平台上所谓 "baseline" 二进制是由 Apple 定义的，Apple 的 baseline 门槛是 Haswell（2014），包含 BMI2 指令。这比 x86-64 的实际基线（Nehalem）高了一代。Ivy Bridge (2013) 不支持 BMI2。

**解决**: bun 必须从源码用 `-march=nehalem` 编译（见 `../bun4ivybridge/`）。OpenCode 本身是用 bun 运行的 TypeScript 源码，不需要单独编译——只要 bun 能正常运行，OpenCode 就能运行。

### 问题 2: `opencode --version` 显示 "local"

**现象**: 运行 `opencode --version` 显示 `opencode-local`，而不是正确的版本号如 `opencode-1.17.8`。

**原因**: OpenCode 源码中通过 `OPENCODE_VERSION` 编译时常量（build-time define）来设置版本。当从源码直接运行（`bun run ./src/index.ts`）时，如果没有注入这个常量，代码会 fallback 到 `"local"`。

**解决**: 使用 bun 的 `--define` 参数在运行时注入版本常量：

```bash
bun run --define OPENCODE_VERSION:"\"1.17.8\"" --conditions=browser ./src/index.ts
```

包装脚本自动从 `package.json` 读取版本号并注入。

**关键语法**: `--define` 参数的格式是 `--define KEY:JSON_VALUE`（空格分隔，值必须是 JSON 字符串，需要用引号包裹）。注意这与一些工具的 `--define:KEY:VALUE`（冒号分隔）语法不同。

### 问题 3: `--preload` + `globalThis` 在 ESM 中不起作用

**现象**: 尝试使用 `--preload` 脚本设置 `globalThis.OPENCODE_VERSION = "1.17.8"` 然后让主程序引用 `OPENCODE_VERSION`，但 `bun run` 在包含 `package.json` 的目录中把 `-e` 参数解释为脚本名称。

**根因**: 
1. 在包含 `package.json` 的目录中，`bun run -e script-name` 会在 scripts 对象中查找 `-e` 这个 key
2. 即使在模块作用域中通过 `globalThis` 设置变量，ES Module 的严格模式下也无法通过裸标识符引用全局变量（`globalThis.X` 不会使 `X` 成为可访问的裸标识符）

**解决**: 直接使用 `--define` 替代 `--preload` 方案。

### 问题 4: `bun run` 在 package 目录下的参数解析

**现象**: 在有 `package.json` 的目录中执行 `bun run --define ...` 时，如果 `--define` 语法不正确，bun 可能将其解释为脚本名称。

**解决**: 确保 `--define` 使用正确的格式：

```bash
# 正确（空格分隔，值用双引号包裹 JSON 字符串）
bun run --define OPENCODE_VERSION:"\"1.17.8\"" ./src/index.ts

# 错误（冒号分隔，bun 不支持此语法）
bun run --define:OPENCODE_VERSION="1.17.8" ./src/index.ts
```

## 快速重建备忘

```bash
# 1. 确保 bun 可用（见 bun4ivybridge 项目）
bun --version

# 2. 克隆 OpenCode
mkdir -p ~/.local/share/opencode
cd ~/.local/share/opencode
git clone https://github.com/sst/opencode.git .

# 3. 安装依赖
cd ~/.local/share/opencode/packages/opencode
bun install

# 4. 创建包装脚本
cp /path/to/opencode4ivybridge/scripts/opencode-wrapper.sh ~/.local/bin/opencode
chmod +x ~/.local/bin/opencode
# 如果需要自定义 BUN 路径:
# BUN=/opt/bun ./opencode-wrapper.sh

# 5. 验证
opencode --version
```
