#!/usr/bin/env sh
# ============================================================
# cs — shorthand for claude-switch / claude-switch 简写命令
# Auto-select runtime: Node.js first, fallback to Python
# 自动选择运行环境：优先 Node.js，其次 Python
# ============================================================
DIR="$(cd "$(dirname "$0")" && pwd)"
if command -v node >/dev/null 2>&1; then
    node "$DIR/claude-switch.js" "$@"
elif command -v python3 >/dev/null 2>&1; then
    PYTHONIOENCODING=utf-8 python3 "$DIR/claude-switch.py" "$@"
elif command -v python >/dev/null 2>&1; then
    PYTHONIOENCODING=utf-8 python "$DIR/claude-switch.py" "$@"
else
    echo "错误: 未找到 Node.js 或 Python。请安装 Node.js 8+ 或 Python 3.6+。"
    echo "Error: Neither Node.js nor Python found. Install Node.js 8+ or Python 3.6+."
    exit 1
fi
