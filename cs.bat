@echo off
chcp 65001 >nul 2>&1
REM ============================================================
REM cs.bat — Shorthand for claude-switch (Windows wrapper) / 简写命令
REM Auto-select runtime: Node.js first, fallback to Python
REM 自动选择运行环境：优先 Node.js，其次 Python
REM ============================================================
set "DIR=%~dp0"
where node >nul 2>&1
if %errorlevel% equ 0 (
    node "%DIR%claude-switch.js" %*
    exit /b
)
where python >nul 2>&1
if %errorlevel% equ 0 (
    set PYTHONIOENCODING=utf-8
    python "%DIR%claude-switch.py" %*
    exit /b
)
echo 错误: 未找到 Node.js 或 Python。请安装 Node.js 8+ 或 Python 3.6+。
echo Error: Neither Node.js nor Python found. Install Node.js 8+ or Python 3.6+.
exit /b 1