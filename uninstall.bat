@echo off
chcp 65001 >nul 2>&1
REM ============================================================
REM uninstall.bat — claude-switch uninstaller (Windows) / 卸载脚本
REM Removes files installed by install.bat / 删除 install.bat 安装的文件
REM ============================================================
setlocal enabledelayedexpansion

set "BIN_DIR=%USERPROFILE%\bin"
set "CMD_DIR=%USERPROFILE%\.claude\commands"
set "COUNT=0"

echo === claude-switch 卸载程序 / uninstaller ===
echo.

REM 1-4. Remove all installed files / 删除所有已安装文件
call :remove "%BIN_DIR%\claude-switch.js"
call :remove "%BIN_DIR%\claude-switch.py"
call :remove "%BIN_DIR%\claude-switch.bat"
call :remove "%BIN_DIR%\claude-switch.ps1"
call :remove "%BIN_DIR%\cs.bat"
call :remove "%BIN_DIR%\cs.ps1"
call :remove "%BIN_DIR%\claude-switch-py.bat"
call :remove "%BIN_DIR%\claude-switch-py.ps1"
call :remove "%BIN_DIR%\cs-py.bat"
call :remove "%BIN_DIR%\cs-py.ps1"
call :remove "%BIN_DIR%\claude-switch"
call :remove "%BIN_DIR%\cs"
call :remove "%BIN_DIR%\claude-switch-py"
call :remove "%BIN_DIR%\cs-py"
call :remove "%CMD_DIR%\claude-switch.md"
call :remove "%CMD_DIR%\cs.md"

echo.
if !COUNT! gtr 0 (
    echo Removed !COUNT! files / 已删除 !COUNT! 个文件
) else (
    echo No files to remove / 没有需要删除的文件
)

REM 5. Remove from PATH / 从 PATH 中移除
echo.
echo Remove %BIN_DIR% from your User PATH? / 是否从用户 PATH 中移除？
echo   ^(effective in new terminal / 新终端窗口生效^)
echo.
set "REMOVE_PATH="
set /p REMOVE_PATH="Enter y to confirm / 输入 y 确认 [y/N]: "
if /i "!REMOVE_PATH!"=="y" (
    powershell -Command "[Environment]::SetEnvironmentVariable('Path', (([Environment]::GetEnvironmentVariable('Path', 'User') -split ';' ^| ? {$_ -ne '%BIN_DIR%'}) -join ';'), 'User')" 2>nul
    if !errorlevel! equ 0 (
        echo   OK - Removed from User PATH / 已从用户 PATH 中移除
    ) else (
        echo   FAILED - Please remove manually / 移除失败，请手动操作
    )
)

echo.
echo Done / 卸载完成！
pause
exit /b

REM ============================================================
REM Subroutine: remove a single file and report / 删除单个文件
REM ============================================================
:remove
if exist "%~1" (
    del "%~1"
    set /a COUNT+=1
    echo   OK %~nx1
) else (
    echo   -  %~nx1  ^(not found^)
)
exit /b
