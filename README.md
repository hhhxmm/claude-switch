# claude-switch — Claude Code Profile Switcher / 配置文件切换器

> 纯AI(GLM-5.2、GLM-4.7-Flash、deepseek-v4-pro、deepseek-v4-flash、mimo-v2.5-pro、mimo-v2.5、mimo-v2-flash、qwen3.7-max、qwen3.7-plus),0人工

Switch between API providers (DeepSeek, Mimo, Anthropic, etc.) from the terminal or inside Claude Code with `/cs`.
在不同的 API 提供商之间快速切换，支持终端命令行和 Claude Code 内部 `/cs` 斜杠命令。

## Quick install / 快速安装

**Windows** — double-click `install.bat` or run / 双击运行：
```cmd
install.bat
```

**Linux / macOS / Git Bash** — run / 运行：
```bash
bash install.sh
```

The installer copies files to `~/bin/` and `~/.claude/commands/` automatically.
安装器会自动将文件拷贝到 `~/bin/` 和 `~/.claude/commands/`，无需手动操作。

## What you get / 功能一览

Base commands auto-select Node.js first, falling back to Python if Node.js is not installed.
基础命令自动选择 Node.js 运行，若未安装则回退到 Python。

| Command / 命令 | Runtime / 运行环境 | What / 说明 |
|---|---|---|
| `claude-switch list` | Node.js → Python (auto) | List profiles + balance / 列出配置文件及余额 |
| `claude-switch current` | Node.js → Python (auto) | Show active profile + balance / 查看当前及余额 |
| `--no-balance` flag | (add to any query) | Skip balance check for speed / 跳过余额查询，快速显示 |
| `claude-switch <name>` | Node.js → Python (auto) | Switch profile + relaunch Claude Code / 切换并重启 |
| `cs <name>` | Node.js → Python (auto) | Shorthand / 简写 |
| `claude-switch-py list` | Python 3.6+ (force) | Same as above, force Python / 同上，强制 Python |
| `cs-py <name>` | Python 3.6+ (force) | Shorthand, force Python / 简写，强制 Python |
| `/cs` | Inside Claude Code | List profiles (no args) / 列出配置文件 |
| `/cs <name>` | Inside Claude Code | Switch profile (restart required) / 切换（需重启） |
| `/claude-switch` | Inside Claude Code | Same as `/cs` / 等同于 `/cs` |

## Profile setup / 配置文件格式

Profiles live in `~/.claude/settings.json` under the `profiles` key. Each profile needs an `env` block.
配置文件存储在 `~/.claude/settings.json` 的 `profiles` 字段下，每个配置文件需要一个 `env` 块：

```json
{
  "profiles": {
    "deepseek": {
      "env": {
        "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
        "ANTHROPIC_AUTH_TOKEN": "sk-your-key",
        "ANTHROPIC_MODEL": "deepseek-v4-pro",
        "ANTHROPIC_DEFAULT_OPUS_MODEL": "deepseek-v4-pro",
        "ANTHROPIC_DEFAULT_SONNET_MODEL": "deepseek-v4-pro",
        "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-flash",
        "CLAUDE_CODE_SUBAGENT_MODEL": "deepseek-v4-flash"
      }
    },
    "anthropic": {
      "env": {
        "ANTHROPIC_BASE_URL": "https://api.anthropic.com",
        "ANTHROPIC_AUTH_TOKEN": "sk-ant-your-key",
        "ANTHROPIC_MODEL": "claude-sonnet-4-6",
        "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-8",
        "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-4-6",
        "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-4-5",
        "CLAUDE_CODE_SUBAGENT_MODEL": "claude-haiku-4-5"
      }
    }
  }
}
```

## Balance checking / 余额查询

`list` and `current` now automatically show remaining balance for supported providers.
`list` 和 `current` 命令会自动显示支持的服务商的剩余额度。

| Provider | Balance API | Status |
|---|---|---|
| DeepSeek | ✅ `GET /user/balance` | Full support / 完全支持 |
| MiMo | ⚠️ `GET /api/v1/balance` | Browser login required / 需浏览器登录 |
| GLM / 智谱 | ⚠️ Quota API | Endpoint unverified / 端点待验证 |
| Qwen / 百炼 | ❌ None | Console only / 仅限控制台 |

Skip balance queries with `--no-balance`:
```bash
claude-switch list --no-balance   # 快速模式，跳过余额查询
```

## Files in this package / 包内文件

```
claude-switch/
  --- Auto-select wrappers (Node.js first → Python fallback) / 自动选择 ---
  claude-switch.js      # Node.js core / 核心（需 Node.js 8+）
  claude-switch.py      # Python core  / 核心（需 Python 3.6+）
  claude-switch         # Unix wrapper / shell（自动选择运行时）
  claude-switch.bat     # Windows wrapper（自动选择运行时）
  cs / cs.bat           # Unix / Windows 简写（自动选择运行时）
  --- Force-Python wrappers / 强制 Python ---
  claude-switch-py / claude-switch-py.bat
  cs-py / cs-py.bat
  --- Commands / 斜杠命令 ---
  claude-switch.md      # /claude-switch slash command
  cs.md                 # /cs slash command
  --- Installers / 安装与卸载 ---
  install.sh            # Unix installer
  install.bat           # Windows installer
  uninstall.sh          # Unix uninstaller
  uninstall.bat         # Windows uninstaller
  --- Session transcripts / 会话记录 ---
  sessions/             # Claude Code session logs (gitignored)
  README.md             # This file / 本说明文件
```

## Requirements / 运行环境

至少安装一个 / At least one required：

- **Node.js 8+** — preferred, auto-selected first / 优先使用
- **Python 3.6+** — fallback, auto-selected if Node.js is missing / Node.js 缺失时自动使用
- `~/bin` in PATH (the installer warns you if it's not) / `~/bin` 需在 PATH 中（安装器会自动检测）

The installer automatically detects which runtimes are available.
安装器会自动检测可用的运行环境。
