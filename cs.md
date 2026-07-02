When the user invokes /cs, do the following (requires Node.js 8+ or Python 3.6+ / 需要 Node.js 8+ 或 Python 3.6+):

1. If no profile name was given after /cs, run `node ~/bin/claude-switch.js --no-launch list` to show available profiles (with model slots AND remaining balance/额度). If node is not available, fall back to `python ~/bin/claude-switch.py --no-launch list`. To skip balance queries for speed, add `--no-balance`.
2. If a profile name was given (e.g. `/cs deepseek`), run:
    ```
    node ~/bin/claude-switch.js --no-launch <profile-name>
    ```
   (fallback to python if node unavailable)
3. Report the result:
   - If successful: tell the user "Profile switched to `<name>`. Restart Claude Code for the change to take effect." / "已切换到配置文件 `<名称>`。请重启 Claude Code 使更改生效。" Suggest they can type `cs <name>` in the terminal to switch and relaunch in one step. / 建议用户在终端输入 `cs <名称>` 来一步完成切换和重启。
   - If the profile doesn't exist: list the available profiles and tell the user. / 列出所有可用的配置文件并提示用户。
