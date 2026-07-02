#!/usr/bin/env bash
# ============================================================
# uninstall.sh — claude-switch uninstaller / 卸载脚本
# For Linux / macOS / Git Bash
# Removes files installed by install.sh / 删除 install.sh 安装的文件
# ============================================================

BIN_DIR="$HOME/bin"
CMD_DIR="$HOME/.claude/commands"
COUNT=0

echo "=== claude-switch 卸载程序 / uninstaller ==="
echo ""

# 1. Remove core scripts / 删除核心脚本
for f in "$BIN_DIR/claude-switch.js" "$BIN_DIR/claude-switch.py"; do
    if [ -f "$f" ]; then
        rm "$f" && echo "  ✓ $(basename "$f")" && ((COUNT++))
    else
        echo "  - $(basename "$f")  (not found / 未找到)"
    fi
done

# 2. Remove Node.js wrappers / 删除 Node.js 封装
for f in "$BIN_DIR/claude-switch" "$BIN_DIR/cs" "$BIN_DIR/claude-switch.bat" "$BIN_DIR/cs.bat"; do
    if [ -f "$f" ]; then
        rm "$f" && echo "  ✓ $(basename "$f")" && ((COUNT++))
    else
        echo "  - $(basename "$f")  (not found / 未找到)"
    fi
done

# 3. Remove Python wrappers / 删除 Python 封装
for f in "$BIN_DIR/claude-switch-py" "$BIN_DIR/cs-py" "$BIN_DIR/claude-switch-py.bat" "$BIN_DIR/cs-py.bat"; do
    if [ -f "$f" ]; then
        rm "$f" && echo "  ✓ $(basename "$f")" && ((COUNT++))
    else
        echo "  - $(basename "$f")  (not found / 未找到)"
    fi
done

# 4. Remove slash-command definitions / 删除斜杠命令
for f in "$CMD_DIR/claude-switch.md" "$CMD_DIR/cs.md"; do
    if [ -f "$f" ]; then
        rm "$f" && echo "  ✓ $(basename "$f")" && ((COUNT++))
    else
        echo "  - $(basename "$f")  (not found / 未找到)"
    fi
done

echo ""
if [ $COUNT -eq 0 ]; then
    echo "No files to remove / 没有需要删除的文件。"
else
    echo "Removed $COUNT file(s) / 已删除 $COUNT 个文件。"
fi

# 5. Optional: remove empty directories / 可选：删除空目录
echo ""
read -r -p "  是否删除空目录？/ Remove empty directories? (bin, .claude/commands) [y/N]: " CONFIRM
if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
    # Only remove if empty / 仅空目录时删除
    [ -d "$BIN_DIR" ] && [ -z "$(ls -A "$BIN_DIR" 2>/dev/null)" ] && rmdir "$BIN_DIR" 2>/dev/null && echo "  ✓ Removed empty: $BIN_DIR"
    [ -d "$CMD_DIR" ] && [ -z "$(ls -A "$CMD_DIR" 2>/dev/null)" ] && rmdir "$CMD_DIR" 2>/dev/null && echo "  ✓ Removed empty: $CMD_DIR"
    # Try parent .claude dir only if empty
    CLAUDE_DIR="$HOME/.claude"
    [ -d "$CLAUDE_DIR" ] && [ -z "$(ls -A "$CLAUDE_DIR" 2>/dev/null)" ] && rmdir "$CLAUDE_DIR" 2>/dev/null && echo "  ✓ Removed empty: $CLAUDE_DIR"
fi

# 6. Remove from PATH / 从 PATH 中移除
echo ""
if echo "$PATH" | tr ':' '\n' | grep -qFx "$BIN_DIR"; then
    echo "⚠ WARNING: $BIN_DIR is still in your PATH / 仍在 PATH 环境变量中。"
    echo "  如需彻底清理，请检查以下文件并删除相关 export 行："
    for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.bash_profile"; do
        if [ -f "$rc" ] && grep -q "$BIN_DIR" "$rc" 2>/dev/null; then
            echo "    → $rc"
            grep -n "$BIN_DIR" "$rc" 2>/dev/null | while read -r line; do
                echo "      $line"
            done
        fi
    done
    echo ""
    read -r -p "  是否自动从上述文件中删除？/ Auto-remove from config files? [y/N]: " REMOVE_PATH
    if [ "$REMOVE_PATH" = "y" ] || [ "$REMOVE_PATH" = "Y" ]; then
        for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.bash_profile"; do
            if [ -f "$rc" ]; then
                # Create backup, remove lines containing BIN_DIR
                sed -i.bak "\|$BIN_DIR|d" "$rc" 2>/dev/null && echo "  ✓ Cleaned: $rc (backup: $rc.bak)"
            fi
        done
        echo "  已清理配置文件，请重新打开终端生效。"
    fi
fi

echo ""
echo "Done / 卸载完成！"
