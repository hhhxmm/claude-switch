@echo off
REM ============================================================
REM claude-switch.bat — Profile switcher (Windows wrapper) / 配置文件切换器
REM Auto-select runtime: Node.js first, fallback to Python
REM 自动选择运行环境：优先 Node.js，其次 Python
REM ============================================================
chcp 65001 >nul 2>&1
set "DIR=%~dp0"
where node >nul 2>&1
if %errorlevel% equ 0 (
    node "%DIR%claude-switch.js" %*
    exit /b %errorlevel%
)
where python >nul 2>&1
if %errorlevel% equ 0 (
    set PYTHONIOENCODING=utf-8
    python "%DIR%claude-switch.py" %*
    exit /b %errorlevel%
)
echo 错误: 未找到 Node.js 或 Python。请安装 Node.js 8+ 或 Python 3.6+。
echo Error: Neither Node.js nor Python found. Install Node.js 8+ or Python 3.6+.
exit /b 1
