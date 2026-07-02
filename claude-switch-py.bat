@echo off
chcp 65001 >nul 2>&1
REM ============================================================
REM claude-switch-py.bat — Profile switcher (Python version) / 配置文件切换器（Python 版）
REM Requires Python 3.6+ / 需要 Python 3.6 及以上版本
REM ============================================================
set PYTHONIOENCODING=utf-8
python "%~dp0claude-switch.py" %*