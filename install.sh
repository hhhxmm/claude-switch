#!/usr/bin/env bash
# ============================================================
# install.sh — claude-switch installer / 安装脚本
# For Linux / macOS / Git Bash
# Copies files to ~/bin/ and ~/.claude/commands/
# 将文件拷贝到 ~/bin/ 和 ~/.claude/commands/
# ============================================================
set -e

BIN_DIR="$HOME/bin"
CMD_DIR="$HOME/.claude/commands"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== claude-switch 安装程序 / installer ==="
echo ""

# 0. Detect available runtimes / 检测可用的运行环境
echo "检测运行环境 / Detecting runtimes..."
HAS_NODE=0
HAS_PYTHON=0
NODE_VER=""
PYTHON_VER=""

if command -v node >/dev/null 2>&1; then
    NODE_VER=$(node --version 2>/dev/null)
    HAS_NODE=1
    echo "  ✓ Node.js: $NODE_VER"
else
    echo "  ✗ Node.js: 未安装 / not found"
fi

if command -v python3 >/dev/null 2>&1; then
    PYTHON_VER=$(python3 --version 2>&1)
    HAS_PYTHON=1
    echo "  ✓ Python:  $PYTHON_VER"
elif command -v python >/dev/null 2>&1; then
    PYTHON_VER=$(python --version 2>&1)
    HAS_PYTHON=1
    echo "  ✓ Python:  $PYTHON_VER"
else
    echo "  ✗ Python:  未安装 / not found"
fi

if [ $HAS_NODE -eq 0 ] && [ $HAS_PYTHON -eq 0 ]; then
    echo ""
    echo "⚠  错误：未检测到 Node.js 或 Python。请先安装其中一个。"
    echo "   Error: Neither Node.js nor Python detected. Please install one first."
    echo "   Node.js 8+ : https://nodejs.org"
    echo "   Python 3.6+: https://python.org"
    exit 1
fi

if [ $HAS_NODE -eq 1 ]; then
    echo "  → 将优先使用 Node.js / Will prefer Node.js"
elif [ $HAS_PYTHON -eq 1 ]; then
    echo "  → 仅 Python 可用，将使用 Python / Python only, will use Python"
fi
echo ""

# 1. Create directories / 创建目录（如不存在）
mkdir -p "$BIN_DIR"
mkdir -p "$CMD_DIR"

# 2. Copy executable files to ~/bin / 拷贝可执行文件
echo "Installing to / 正在安装到 $BIN_DIR ..."
cp "$SCRIPT_DIR/claude-switch.js"    "$BIN_DIR/"
cp "$SCRIPT_DIR/claude-switch.py"    "$BIN_DIR/"
cp "$SCRIPT_DIR/claude-switch"       "$BIN_DIR/"
cp "$SCRIPT_DIR/claude-switch.bat"   "$BIN_DIR/"
cp "$SCRIPT_DIR/claude-switch-py"    "$BIN_DIR/"
cp "$SCRIPT_DIR/claude-switch-py.bat" "$BIN_DIR/"
cp "$SCRIPT_DIR/cs"                  "$BIN_DIR/"
cp "$SCRIPT_DIR/cs.bat"              "$BIN_DIR/"
cp "$SCRIPT_DIR/cs-py"               "$BIN_DIR/"
cp "$SCRIPT_DIR/cs-py.bat"           "$BIN_DIR/"

# Make shell wrappers executable / 赋予执行权限
chmod +x "$BIN_DIR/claude-switch"
chmod +x "$BIN_DIR/claude-switch-py"
chmod +x "$BIN_DIR/cs"
chmod +x "$BIN_DIR/cs-py"

# 3. Copy slash-command definitions to ~/.claude/commands / 拷贝斜杠命令
echo "Installing to / 正在安装到 $CMD_DIR ..."
cp "$SCRIPT_DIR/claude-switch.md" "$CMD_DIR/"
cp "$SCRIPT_DIR/cs.md"            "$CMD_DIR/"

echo ""
echo "Done / 安装完成！Installed files / 已安装以下文件："
echo "  --- Node.js version (requires Node.js 8+) / Node.js 版 ---"
echo "  $BIN_DIR/claude-switch.js    (core script / 核心脚本)"
echo "  $BIN_DIR/claude-switch       (shell wrapper / shell 封装)"
echo "  $BIN_DIR/claude-switch.bat   (Windows wrapper)"
echo "  $BIN_DIR/cs                   (shorthand / 简写)"
echo "  $BIN_DIR/cs.bat               (shorthand / 简写)"
echo "  --- Python version (requires Python 3.6+) / Python 版 ---"
echo "  $BIN_DIR/claude-switch.py    (core script / 核心脚本)"
echo "  $BIN_DIR/claude-switch-py    (shell wrapper / shell 封装)"
echo "  $BIN_DIR/claude-switch-py.bat (Windows wrapper)"
echo "  $BIN_DIR/cs-py                (shorthand / 简写)"
echo "  $BIN_DIR/cs-py.bat            (shorthand / 简写)"
echo "  --- Claude Code commands / 斜杠命令 ---"
echo "  $CMD_DIR/claude-switch.md    (slash command)"
echo "  $CMD_DIR/cs.md               (slash command)"

# 4. Check PATH / 检查 ~/bin 是否在 PATH 中
if ! echo "$PATH" | tr ':' '\n' | grep -qFx "$BIN_DIR"; then
    echo ""
    echo "⚠  WARNING / 警告：$BIN_DIR is not in your PATH / 不在 PATH 环境变量中。"
    echo "   Add this line to ~/.bashrc or ~/.zshrc / 请添加以下行："
    echo "     export PATH=\"\$HOME/bin:\$PATH\""
else
    echo ""
    echo "✓ $BIN_DIR is in PATH / 已在 PATH 中 — ready / 可以正常使用！"
fi

echo ""
echo "Usage / 使用方法："
echo "  claude-switch list        # (Node.js) List profiles / 列出配置文件"
echo "  claude-switch-py list     # (Python)  List profiles / 列出配置文件"
echo "  cs <name>                 # (Node.js) Switch profile / 切换"
echo "  cs-py <name>              # (Python)  Switch profile / 切换"
