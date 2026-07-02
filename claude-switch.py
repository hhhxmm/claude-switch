"""
============================================================
claude-switch.py — Claude Code Profile Switcher / 配置文件切换器
Requires Python 3.6+ / 需要 Python 3.6 及以上版本

Quickly switch between API providers (DeepSeek, Mimo, Anthropic, etc.)
在不同 API 提供商之间快速切换，支持：

  python claude-switch.py list       List all profiles & models  / 列出全部配置文件及模型
  python claude-switch.py current    Show current profile       / 查看当前使用的配置文件
  python claude-switch.py <name>     Switch to a profile        / 切换到指定配置文件

Profiles live in ~/.claude/settings.json under "profiles".
配置文件存储在 ~/.claude/settings.json 的 profiles 字段下。

Each profile configures up to 5 model slots / 每个配置文件最多有 5 个模型槽位：
  ANTHROPIC_MODEL                Main model       / 主模型
  ANTHROPIC_DEFAULT_OPUS_MODEL   Opus model
  ANTHROPIC_DEFAULT_SONNET_MODEL  Sonnet model
  ANTHROPIC_DEFAULT_HAIKU_MODEL   Haiku model
  CLAUDE_CODE_SUBAGENT_MODEL      Sub-agent model  / 子代理模型
============================================================
"""

import json
import os
import sys
import subprocess
import urllib.request
import urllib.error
from pathlib import Path
from urllib.parse import urlparse
from concurrent.futures import ThreadPoolExecutor, as_completed

# Fix Windows console encoding for Chinese output / 修复 Windows 控制台中文编码
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")   # Python 3.7+
    except Exception:
        pass
    try:
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

HOME = Path(os.environ.get("HOME") or os.environ.get("USERPROFILE") or "~").expanduser()
SETTINGS_PATH = HOME / ".claude" / "settings.json"


def load_settings():
    """Read settings.json / 读取配置文件"""
    if not SETTINGS_PATH.exists():
        print(f"错误 / Error: 找不到 {SETTINGS_PATH} not found")
        sys.exit(2)
    try:
        with open(SETTINGS_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError) as e:
        print(f"错误 / Error: 无法解析 {SETTINGS_PATH} / Failed to parse")
        print(str(e))
        sys.exit(2)


def save_settings(settings):
    """Write settings.json / 写入配置文件"""
    with open(SETTINGS_PATH, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write("\n")


def mask_token(token):
    """Mask token — show only first 6 + last 4 chars / 遮盖 token，只显示首尾几位"""
    if not token:
        return "(未设置 / not set)"
    if len(token) <= 10:
        return token[:4] + "..."
    return token[:6] + "..." + token[-4:]


# ============================================================
# Balance API configuration per provider / 各服务商余额查询 API 配置
# ============================================================

BALANCE_APIS = {
    "api.deepseek.com": {
        "hostname": "api.deepseek.com",
        "path": "/user/balance",
        "parse": lambda d: _parse_deepseek(d),
    },
    # MiMo balance API is on platform.xiaomimimo.com (not api.xiaomimimo.com)
    # Uses cookie auth in browser; API-key Bearer auth may work
    "api.xiaomimimo.com": {
        "hostname": "platform.xiaomimimo.com",
        "path": "/api/v1/balance",
        "parse": lambda d: _parse_mimo(d),
    },
    # Zhipu / GLM — Quota API (endpoint unverified)
    "open.bigmodel.cn": {
        "hostname": "open.bigmodel.cn",
        "path": "/api/platform/billing/balance",
        "parse": lambda d: _parse_glm(d),
    },
}


def _parse_deepseek(data):
    bi = data.get("balance_infos", [])
    if not bi:
        return None
    i = bi[0]
    currency = "¥" if i.get("currency") == "CNY" else i.get("currency", "")
    parts = []
    if i.get("total_balance"):
        parts.append(f"总额: {currency}{i['total_balance']}")
    if i.get("topped_up_balance"):
        parts.append(f"充值: {currency}{i['topped_up_balance']}")
    if i.get("granted_balance"):
        parts.append(f"赠送: {currency}{i['granted_balance']}")
    parts.append("✅ 可用" if i.get("is_available") is not False else "❌ 不可用")
    return " | ".join(parts)


def _parse_mimo(data):
    # Handle auth errors
    if data.get("code") == 401:
        return "需浏览器登录 / browser login required"
    if data.get("code") is not None and data.get("msg"):
        return f"状态: {data['msg']}"
    # Balance data patterns
    if "total_balance" in data:
        return f"总额: ¥{data['total_balance']}"
    if "balance" in data:
        return f"总额: {data['balance']}"
    if "data" in data:
        d = data["data"]
        if isinstance(d, dict):
            if "total_balance" in d:
                return f"总额: ¥{d['total_balance']}"
            if "balance" in d:
                return f"总额: {d['balance']}"
    return f"原始响应: {str(data)[:120]}"


def _parse_glm(data):
    if "balance" in data:
        return f"余额: {data['balance']}"
    if "data" in data and isinstance(data["data"], dict) and "balance" in data["data"]:
        return f"余额: {data['data']['balance']}"
    return None


def fetch_balance(base_url, token):
    """Fetch balance from a provider's API / 从服务商 API 查询余额"""
    try:
        parsed = urlparse(base_url)
        api_hostname = parsed.hostname
        api = BALANCE_APIS.get(api_hostname)
        if not api:
            return None  # Provider not supported

        balance_hostname = api.get("hostname") or api_hostname
        scheme = parsed.scheme or "https"
        url = f"{scheme}://{balance_hostname}{api['path']}"

        req = urllib.request.Request(url)
        req.add_header("Accept", "application/json")
        req.add_header("Authorization", f"Bearer {token}")
        req.add_header("Content-Type", "application/json")

        with urllib.request.urlopen(req, timeout=10) as resp:
            body = resp.read().decode("utf-8")
            data = json.loads(body)
            return api["parse"](data)

    except Exception:
        return None


def fetch_all_balances(profiles):
    """Batch-fetch balances for multiple profiles / 批量查询多个配置文件的余额"""
    results = {}
    names = list(profiles.keys())
    if not names:
        return results

    with ThreadPoolExecutor(max_workers=min(len(names), 5)) as executor:
        futures = {}
        for name in names:
            env = profiles[name].get("env", {})
            base_url = env.get("ANTHROPIC_BASE_URL")
            token = env.get("ANTHROPIC_AUTH_TOKEN")
            if base_url and token:
                futures[executor.submit(fetch_balance, base_url, token)] = name

        for future in as_completed(futures):
            name = futures[future]
            try:
                results[name] = future.result()
            except Exception:
                results[name] = None

    return results


def list_profiles(settings, balances=None):
    """List all profiles with their model slots / 列出所有配置文件及全部模型"""
    profiles = settings.get("profiles", {})
    names = list(profiles.keys())
    if not names:
        print("没有找到任何配置文件。/ No profiles configured.")
        return
    print("可用的配置文件 / Available profiles:\n")
    for i, name in enumerate(names, 1):
        env = profiles[name].get("env", {})
        # Collect all configured model slots / 收集所有已配置的模型槽位
        model_slots = [
            ("Model",     env.get("ANTHROPIC_MODEL")),
            ("Opus",      env.get("ANTHROPIC_DEFAULT_OPUS_MODEL")),
            ("Sonnet",    env.get("ANTHROPIC_DEFAULT_SONNET_MODEL")),
            ("Haiku",     env.get("ANTHROPIC_DEFAULT_HAIKU_MODEL")),
            ("Subagent",  env.get("CLAUDE_CODE_SUBAGENT_MODEL")),
        ]
        model_slots = [(label, model) for label, model in model_slots if model]

        print(f"  {i}) {name}")
        print(f"     URL:   {env.get('ANTHROPIC_BASE_URL') or '未知 / unknown'}")
        print(f"     Token: {mask_token(env.get('ANTHROPIC_AUTH_TOKEN'))}")
        # Show balance if available / 显示余额
        balance = balances.get(name) if balances else None
        if balance:
            print(f"     余额:  {balance}")
        elif balances is not None and balances.get(name) is None:
            print(f"     余额:  查询失败或暂不支持 / unavailable")
        print("     Models / 模型:")
        for label, model in model_slots:
            print(f"       {label.ljust(9)} {model}")
        print()


def detect_current(settings, balance=None):
    """Detect current active profile / 检测当前使用的配置文件"""
    current_env = settings.get("env", {})
    profiles = settings.get("profiles", {})
    current_url = current_env.get("ANTHROPIC_BASE_URL")
    current_token = current_env.get("ANTHROPIC_AUTH_TOKEN")

    # Match by URL + Token / 通过 URL + Token 匹配当前配置文件
    for name, profile in profiles.items():
        env = profile.get("env", {})
        if env.get("ANTHROPIC_BASE_URL") == current_url and env.get("ANTHROPIC_AUTH_TOKEN") == current_token:
            model_slots = [
                ("Model",     env.get("ANTHROPIC_MODEL")),
                ("Opus",      env.get("ANTHROPIC_DEFAULT_OPUS_MODEL")),
                ("Sonnet",    env.get("ANTHROPIC_DEFAULT_SONNET_MODEL")),
                ("Haiku",     env.get("ANTHROPIC_DEFAULT_HAIKU_MODEL")),
                ("Subagent",  env.get("CLAUDE_CODE_SUBAGENT_MODEL")),
            ]
            model_slots = [(label, model) for label, model in model_slots if model]

            print(f"当前配置文件 / Current profile: {name}")
            print(f"  URL:    {env.get('ANTHROPIC_BASE_URL') or '未知 / unknown'}")
            print(f"  Token:  {mask_token(env.get('ANTHROPIC_AUTH_TOKEN'))}")
            # Show balance if available / 显示余额
            if balance:
                print(f"  余额:   {balance}")
            elif balance is None:
                print(f"  余额:   查询失败或暂不支持 / unavailable")
            print("  Models / 模型:")
            for label, model in model_slots:
                print(f"    {label.ljust(9)} {model}")
            return

    # No matching profile — show current custom settings / 没有匹配的配置文件，显示当前自定义设置
    print("当前: 自定义 / 无匹配配置文件 / Current: Custom / no matching profile")
    print(f"  URL:   {current_url or '未知 / unknown'}")
    print(f"  Token: {mask_token(current_token)}")
    if current_env.get("ANTHROPIC_MODEL"):
        print("  Models / 模型:")
        for label, key in [
            ("Model", "ANTHROPIC_MODEL"),
            ("Opus", "ANTHROPIC_DEFAULT_OPUS_MODEL"),
            ("Sonnet", "ANTHROPIC_DEFAULT_SONNET_MODEL"),
            ("Haiku", "ANTHROPIC_DEFAULT_HAIKU_MODEL"),
            ("Subagent", "CLAUDE_CODE_SUBAGENT_MODEL"),
        ]:
            if current_env.get(key):
                print(f"    {label.ljust(9)} {current_env[key]}")


def switch_profile(settings, profile_name):
    """Switch profile: deep-clone profile.env and replace settings.env
    切换配置文件：深拷贝 profile.env 替换 settings.env"""
    profiles = settings.get("profiles", {})
    profile = profiles.get(profile_name)

    if not profile:
        print(f"错误 / Error: 找不到配置文件 '{profile_name}' not found.")
        available = list(profiles.keys())
        if available:
            print(f"可用的配置文件 / Available: {', '.join(available)}")
        else:
            print("settings.json 中没有配置任何配置文件。/ No profiles configured.")
        sys.exit(1)

    env = profile.get("env", {})
    if not env:
        print(f"错误 / Error: 配置文件 '{profile_name}' 缺少 env 字段 / has no env section.")
        sys.exit(1)

    # Direct replace, no merge / 直接替换，不合并
    settings["env"] = json.loads(json.dumps(env))
    save_settings(settings)
    print(f"已切换到配置文件 / Switched to profile: {profile_name}")


def launch_claude():
    """Launch Claude Code / 启动 Claude Code"""
    print("正在启动 Claude Code... / Starting Claude Code...")
    try:
        subprocess.run(["claude"], shell=True)
    except FileNotFoundError:
        print("无法启动 Claude Code / Failed to launch: claude not found")
        sys.exit(1)
    except KeyboardInterrupt:
        pass


def interactive_switch(settings):
    """Interactive profile selection (when run without args in terminal)
    交互式选择配置文件（终端无参数运行时）"""
    profiles = settings.get("profiles", {})
    names = list(profiles.keys())

    if not names:
        print("没有找到任何配置文件。/ No profiles configured.")
        sys.exit(1)

    print("可用的配置文件 / Available profiles:\n")
    for i, name in enumerate(names, 1):
        env = profiles[name].get("env", {})
        print(f"  {i}) {name}  ({env.get('ANTHROPIC_MODEL') or '未知 / unknown'})")

    try:
        answer = input(f"\n请选择配置文件 / Select profile [1-{len(names)}]（q 退出）: ").strip()
    except (EOFError, KeyboardInterrupt):
        print("\n已取消 / Cancelled.")
        sys.exit(0)

    if answer.lower() == "q":
        print("已取消 / Cancelled.")
        sys.exit(0)

    target = None

    # Try numeric index first / 先尝试数字序号
    try:
        idx = int(answer)
        if 1 <= idx <= len(names):
            target = names[idx - 1]
    except ValueError:
        pass

    # Then try name match / 再尝试名称匹配
    if target is None and answer in names:
        target = answer

    if target is None:
        print("无效的选择 / Invalid selection.")
        sys.exit(1)

    switch_profile(settings, target)
    launch_claude()


def main():
    """Main entry point / 主入口"""
    args = [a.strip() for a in sys.argv[1:] if a.strip()]

    # Check for --no-launch flag (used inside Claude Code, don't spawn new window)
    # 检查 --no-launch 标志（Claude Code 内部调用，不启动新窗口）
    no_launch = False
    if "--no-launch" in args:
        no_launch = True
        args.remove("--no-launch")

    # Check for --no-balance flag (skip balance query for speed)
    # 检查 --no-balance 标志（跳过余额查询，快速显示）
    no_balance = False
    if "--no-balance" in args:
        no_balance = True
        args.remove("--no-balance")

    if not args:
        if no_launch:
            # Inside Claude Code: show list, can't do interactive
            # 在 Claude Code 内部：只显示列表，不做交互式选择
            s = load_settings()
            balances = None if no_balance else fetch_all_balances(s.get("profiles", {}))
            list_profiles(s, balances)
            print("用法 / Usage: /cs <profile-name>  [--no-balance 跳过余额查询]")
            return
        # Terminal direct run: interactive selection mode
        # 终端直接运行：进入交互式选择模式
        interactive_switch(load_settings())
        return

    cmd = args[0].lower()

    if cmd in ("list", "ls"):
        s = load_settings()
        balances = None if no_balance else fetch_all_balances(s.get("profiles", {}))
        list_profiles(s, balances)
    elif cmd in ("current", "cur"):
        s = load_settings()
        current_env = s.get("env", {})
        current_url = current_env.get("ANTHROPIC_BASE_URL")
        current_token = current_env.get("ANTHROPIC_AUTH_TOKEN")
        balance = None
        if not no_balance and current_url and current_token:
            balance = fetch_balance(current_url, current_token)
        detect_current(s, balance)
    elif cmd == "switch" and len(args) >= 2:
        s = load_settings()
        switch_profile(s, args[1])
        if not no_launch:
            launch_claude()
    else:
        # Direct profile name / 直接传配置文件名称
        s = load_settings()
        switch_profile(s, args[0])
        if not no_launch:
            launch_claude()


if __name__ == "__main__":
    main()
