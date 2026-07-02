@echo off
REM ============================================================
REM cs-py.bat — Shorthand (Python version) / 简写命令（Python 版）
REM Requires Python 3.6+ / 需要 Python 3.6 及以上版本
REM ============================================================
chcp 65001 >nul 2>&1
set PYTHONIOENCODING=utf-8
python "%~dp0claude-switch.py" %*
