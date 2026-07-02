@echo off
chcp 65001 >nul 2>&1
REM ============================================================
REM install.bat — claude-switch installer (Windows) / 安装脚本
REM Copies files to %USERPROFILE%\bin\ and %USERPROFILE%\.claude\commands\
REM 将文件拷贝到 %USERPROFILE%\bin\ 和 %USERPROFILE%\.claude\commands\
REM ============================================================
setlocal enabledelayedexpansion

set "BIN_DIR=%USERPROFILE%\bin"
set "CMD_DIR=%USERPROFILE%\.claude\commands"
set "SCRIPT_DIR=%~dp0"

echo === claude-switch 安装程序 / installer ===
echo.

REM 0. Detect available runtimes / 检测可用的运行环境
echo 检测运行环境 / Detecting runtimes...
set HAS_NODE=0
set HAS_PYTHON=0

where node >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('node --version 2^>nul') do set NODE_VER=%%i
    echo   √ Node.js: !NODE_VER!
    set HAS_NODE=1
) else (
    echo   × Node.js: 未安装 / not found
)

where python >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('python --version 2^>^&1') do set PYTHON_VER=%%i
    echo !PYTHON_VER! | findstr /R "Python [0-9]" >nul 2>&1
    if !errorlevel! equ 0 (
        echo   √ Python:  !PYTHON_VER!
        set HAS_PYTHON=1
    ) else (
        echo   × Python:  stub detected, not installed / 检测到存根，未实际安装
    )
) else (
    echo   × Python:  未安装 / not found
)

if !HAS_NODE! equ 0 if !HAS_PYTHON! equ 0 (
    echo.
    echo 错误：未检测到 Node.js 或 Python。请先安装其中一个。
    echo Error: Neither Node.js nor Python detected. Please install one first.
    echo   Node.js 8+ : https://nodejs.org
    echo   Python 3.6+: https://python.org
    pause
    exit /b 1
)

if !HAS_NODE! equ 1 (
    echo   → 将优先使用 Node.js / Will prefer Node.js
) else (
    echo   → 仅 Python 可用，将使用 Python / Python only, will use Python
)
echo.

REM 1. Create directories / 创建目录
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"
if not exist "%CMD_DIR%" mkdir "%CMD_DIR%"

REM 2. Copy executables to ~/bin / 拷贝可执行文件
echo Installing to / 正在安装到 %BIN_DIR% ...
copy /Y "%SCRIPT_DIR%claude-switch.js"     "%BIN_DIR%\" >nul
copy /Y "%SCRIPT_DIR%claude-switch.py"     "%BIN_DIR%\" >nul

REM Detect runtime for platform-specific wrappers / 检测运行时以选择平台对应的封装脚本
if !HAS_NODE! equ 1 (
    copy /Y "%SCRIPT_DIR%claude-switch.bat" "%BIN_DIR%\" >nul
    copy /Y "%SCRIPT_DIR%cs.bat"            "%BIN_DIR%\" >nul
)
if !HAS_PYTHON! equ 1 (
    copy /Y "%SCRIPT_DIR%claude-switch-py.bat" "%BIN_DIR%\" >nul
    copy /Y "%SCRIPT_DIR%cs-py.bat"            "%BIN_DIR%\" >nul
)

REM 3. Copy slash-command definitions / 拷贝斜杠命令
echo Installing to / 正在安装到 %CMD_DIR% ...
copy /Y "%SCRIPT_DIR%claude-switch.md" "%CMD_DIR%\" >nul
copy /Y "%SCRIPT_DIR%cs.md"            "%CMD_DIR%\" >nul

echo.
echo Done / 安装完成！Installed files / 已安装以下文件：
echo   --- Core scripts / 核心脚本 ---
echo   %BIN_DIR%\claude-switch.js     [Node.js core / Node.js 核心脚本]
echo   %BIN_DIR%\claude-switch.py     [Python core / Python 核心脚本]
if !HAS_NODE! equ 1 (
echo   --- Node.js wrappers / Node.js 封装 ---
echo   %BIN_DIR%\claude-switch.bat    [wrapper / 封装]
echo   %BIN_DIR%\cs.bat               [shorthand / 简写]
)
if !HAS_PYTHON! equ 1 (
echo   --- Python wrappers / Python 封装 ---
echo   %BIN_DIR%\claude-switch-py.bat [wrapper / 封装]
echo   %BIN_DIR%\cs-py.bat            [shorthand / 简写]
)
echo   --- Claude Code commands / 斜杠命令 ---
echo   %CMD_DIR%\claude-switch.md     [slash command]
echo   %CMD_DIR%\cs.md                [slash command]

REM 4. Check PATH / 检查 ~/bin 是否在 PATH 中
echo %PATH% | findstr /C:"%BIN_DIR%" >nul 2>&1
if errorlevel 1 (
    echo.
    echo WARNING / 警告：%BIN_DIR% is not in your PATH / 不在 PATH 环境变量中。
    echo   Add it via / 请通过以下路径添加: System Properties ^> Environment Variables ^> Path
) else (
    echo.
    echo [OK] %BIN_DIR% is in PATH / 已在 PATH 中 — ready / 可以正常使用！
)

echo.
echo Usage / 使用方法：
echo   claude-switch list        # (Node.js) List profiles / 列出配置文件
echo   claude-switch-py list     # (Python)  List profiles / 列出配置文件
echo   cs ^<name^>                # (Node.js) Switch profile / 切换
echo   cs-py ^<name^>             # (Python)  Switch profile / 切换

pause