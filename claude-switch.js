/**
 * ============================================================
 * claude-switch.js — Claude Code Profile Switcher / 配置文件切换器
 * Requires Node.js 8+ / 需要 Node.js 8 及以上版本
 *
 * Quickly switch between API providers (DeepSeek, Mimo, Anthropic, etc.)
 * 在不同 API 提供商之间快速切换，支持：
 *
 *   claude-switch list      List all profiles & models  / 列出全部配置文件及模型
 *   claude-switch current   Show current profile       / 查看当前使用的配置文件
 *   claude-switch <name>    Switch to a profile        / 切换到指定配置文件
 *
 * Profiles live in ~/.claude/settings.json under "profiles".
 * 配置文件存储在 ~/.claude/settings.json 的 profiles 字段下。
 *
 * Each profile configures up to 5 model slots / 每个配置文件最多有 5 个模型槽位：
 *   ANTHROPIC_MODEL               Main model       / 主模型
 *   ANTHROPIC_DEFAULT_OPUS_MODEL  Opus model
 *   ANTHROPIC_DEFAULT_SONNET_MODEL Sonnet model
 *   ANTHROPIC_DEFAULT_HAIKU_MODEL  Haiku model
 *   CLAUDE_CODE_SUBAGENT_MODEL     Sub-agent model  / 子代理模型
 * ============================================================
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');
const { spawn } = require('child_process');
const readline = require('readline');
const { URL } = require('url');

const HOME = process.env.HOME || process.env.USERPROFILE;
const SETTINGS_PATH = path.join(HOME, '.claude', 'settings.json');

/** Read settings.json 读取配置文件 */
function loadSettings() {
  if (!fs.existsSync(SETTINGS_PATH)) {
    console.error(`错误 / Error: 找不到 ${SETTINGS_PATH} not found`);
    process.exit(2);
  }
  try {
    return JSON.parse(fs.readFileSync(SETTINGS_PATH, 'utf-8'));
  } catch (e) {
    console.error(`错误 / Error: 无法解析 ${SETTINGS_PATH} / Failed to parse`);
    console.error(e.message);
    process.exit(2);
  }
}

/** Write settings.json 写入配置文件 */
function saveSettings(settings) {
  fs.writeFileSync(SETTINGS_PATH, JSON.stringify(settings, null, 2) + '\n', 'utf-8');
}

/** Mask token — show only first 6 + last 4 chars 遮盖 token，只显示首尾几位 */
function maskToken(token) {
  if (!token) return '(未设置 / not set)';
  if (token.length <= 10) return token.slice(0, 4) + '...';
  return token.slice(0, 6) + '...' + token.slice(-4);
}

/**
 * Balance API configuration per provider hostname
 * 各服务商余额查询 API 配置
 */
/**
 * Balance API configuration per provider
 * 各服务商余额查询 API 配置
 *
 * Each entry specifies the balance endpoint path and response parser.
 * If `hostname` differs from the API base hostname, set it explicitly.
 * 如果余额查询的 hostname 与 API base hostname 不同，需显式指定。
 */
const BALANCE_APIS = {
  'api.deepseek.com': {
    hostname: 'api.deepseek.com',
    path: '/user/balance',
    parse: (data) => {
      const bi = data.balance_infos;
      if (!bi || bi.length === 0) return null;
      const i = bi[0];
      const currency = i.currency === 'CNY' ? '¥' : i.currency;
      let parts = [];
      if (i.total_balance)  parts.push(`总额: ${currency}${i.total_balance}`);
      if (i.topped_up_balance) parts.push(`充值: ${currency}${i.topped_up_balance}`);
      if (i.granted_balance) parts.push(`赠送: ${currency}${i.granted_balance}`);
      parts.push(i.is_available !== false ? '✅ 可用' : '❌ 不可用');
      return parts.join(' | ');
    }
  },
  // MiMo balance API is on platform.xiaomimimo.com (not api.xiaomimimo.com)
  // Uses cookie auth in browser; API-key Bearer auth may work
  'api.xiaomimimo.com': {
    hostname: 'platform.xiaomimimo.com',
    path: '/api/v1/balance',
    parse: (data) => {
      // Handle auth errors
      if (data.code === 401) return '需浏览器登录 / browser login required';
      if (data.code && data.msg) return `状态: ${data.msg}`;
      // Balance data patterns
      if (data.total_balance !== undefined) return `总额: ¥${data.total_balance}`;
      if (data.balance !== undefined) return `总额: ${data.balance}`;
      if (data.data && data.data.total_balance !== undefined) return `总额: ¥${data.data.total_balance}`;
      if (data.data && data.data.balance !== undefined) return `总额: ${data.data.balance}`;
      const keys = Object.keys(data);
      return keys.length > 0 ? `原始响应: ${JSON.stringify(data).substring(0, 120)}` : '无法解析';
    }
  },
  // Zhipu / GLM — Quota API (endpoint unverified, may need adjustment)
  'open.bigmodel.cn': {
    hostname: 'open.bigmodel.cn',
    path: '/api/platform/billing/balance',
    parse: (data) => {
      if (data.balance !== undefined) return `余额: ${data.balance}`;
      if (data.data && data.data.balance) return `余额: ${data.data.balance}`;
      return null;
    }
  }
};

/** Extract hostname from a URL string 从 URL 中提取主机名 */
function hostnameFromUrl(baseUrl) {
  try {
    return new URL(baseUrl).hostname;
  } catch (e) {
    return null;
  }
}

/**
 * Fetch balance from a provider's API
 * 从服务商 API 查询余额
 * @returns {Promise<string|null>} balance string or null on failure
 */
function fetchBalance(baseUrl, token) {
  return new Promise((resolve) => {
    const apiHostname = hostnameFromUrl(baseUrl);
    const api = BALANCE_APIS[apiHostname];
    if (!api) {
      resolve(null); // Provider not supported / 不支持的服务商
      return;
    }

    const balanceHostname = api.hostname || apiHostname;
    const module = baseUrl.startsWith('https') ? https : http;
    const options = {
      hostname: balanceHostname,
      path: api.path,
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer ' + token,
        'Content-Type': 'application/json'
      },
      timeout: 10000
    };

    const req = module.request(options, (res) => {
      let chunks = [];
      res.on('data', (chunk) => { chunks.push(chunk); });
      res.on('end', () => {
        try {
          const body = Buffer.concat(chunks).toString('utf-8');
          const data = JSON.parse(body);
          const result = api.parse(data);
          resolve(result);
        } catch (e) {
          resolve(null);
        }
      });
    });

    req.on('error', () => { resolve(null); });
    req.on('timeout', () => { req.destroy(); resolve(null); });
    req.end();
  });
}

/**
 * Batch-fetch balances for multiple profiles
 * 批量查询多个配置文件的余额
 * @returns {Promise<Object>} { profileName: balanceString }
 */
async function fetchAllBalances(profiles) {
  const results = {};
  const names = Object.keys(profiles);
  if (names.length === 0) return results;

  // Fetch all in parallel with a global timeout
  await Promise.all(
    names.map(async (name) => {
      const env = profiles[name].env || {};
      const baseUrl = env.ANTHROPIC_BASE_URL;
      const token = env.ANTHROPIC_AUTH_TOKEN;
      if (baseUrl && token) {
        results[name] = await fetchBalance(baseUrl, token);
      }
    })
  );
  return results;
}

/** List all profiles with their model slots 列出所有配置文件及全部模型 */
function listProfiles(settings, balances) {
  const profiles = settings.profiles || {};
  const names = Object.keys(profiles);
  if (names.length === 0) {
    console.log('没有找到任何配置文件。/ No profiles configured.');
    return;
  }
  console.log('可用的配置文件 / Available profiles:\n');
  names.forEach((name, i) => {
    const env = profiles[name].env || {};
    // Collect all configured model slots / 收集所有已配置的模型槽位
    const modelSlots = [
      ['Model',      env.ANTHROPIC_MODEL],
      ['Opus',       env.ANTHROPIC_DEFAULT_OPUS_MODEL],
      ['Sonnet',     env.ANTHROPIC_DEFAULT_SONNET_MODEL],
      ['Haiku',      env.ANTHROPIC_DEFAULT_HAIKU_MODEL],
      ['Subagent',   env.CLAUDE_CODE_SUBAGENT_MODEL],
    ].filter(([, v]) => v);  // only show configured slots / 只显示已配置的模型

    console.log(`  ${i + 1}) ${name}`);
    console.log(`     URL:   ${env.ANTHROPIC_BASE_URL || '未知 / unknown'}`);
    console.log(`     Token: ${maskToken(env.ANTHROPIC_AUTH_TOKEN)}`);
    // Show balance if available / 显示余额
    const balance = balances && balances[name];
    if (balance) {
      console.log(`     余额:  ${balance}`);
    } else if (balances && balances[name] === null) {
      console.log(`     余额:  查询失败或暂不支持 / unavailable`);
    }
    console.log(`     Models / 模型:`);
    modelSlots.forEach(([label, model]) => {
      console.log(`       ${label.padEnd(9)} ${model}`);
    });
    console.log();
  });
}

/** Detect current active profile 检测当前使用的配置文件 */
function detectCurrent(settings, balance) {
  const currentEnv = settings.env || {};
  const profiles = settings.profiles || {};
  const currentUrl = currentEnv.ANTHROPIC_BASE_URL;
  const currentToken = currentEnv.ANTHROPIC_AUTH_TOKEN;

  // Match by URL + Token / 通过 URL + Token 匹配当前配置文件
  for (const [name, profile] of Object.entries(profiles)) {
    const env = profile.env || {};
    if (env.ANTHROPIC_BASE_URL === currentUrl && env.ANTHROPIC_AUTH_TOKEN === currentToken) {
      const modelSlots = [
        ['Model',      env.ANTHROPIC_MODEL],
        ['Opus',       env.ANTHROPIC_DEFAULT_OPUS_MODEL],
        ['Sonnet',     env.ANTHROPIC_DEFAULT_SONNET_MODEL],
        ['Haiku',      env.ANTHROPIC_DEFAULT_HAIKU_MODEL],
        ['Subagent',   env.CLAUDE_CODE_SUBAGENT_MODEL],
      ].filter(([, v]) => v);

      console.log(`当前配置文件 / Current profile: ${name}`);
      console.log(`  URL:    ${env.ANTHROPIC_BASE_URL || '未知 / unknown'}`);
      console.log(`  Token:  ${maskToken(env.ANTHROPIC_AUTH_TOKEN)}`);
      // Show balance if available / 显示余额
      if (balance) {
        console.log(`  余额:   ${balance}`);
      } else if (balance === null) {
        console.log(`  余额:   查询失败或暂不支持 / unavailable`);
      }
      console.log(`  Models / 模型:`);
      modelSlots.forEach(([label, model]) => {
        console.log(`    ${label.padEnd(9)} ${model}`);
      });
      return;
    }
  }

  // No matching profile — show current custom settings / 没有匹配的配置文件，显示当前自定义设置
  console.log('当前: 自定义 / 无匹配配置文件 / Current: Custom / no matching profile');
  console.log(`  URL:   ${currentUrl || '未知 / unknown'}`);
  console.log(`  Token: ${maskToken(currentToken)}`);
  if (currentEnv.ANTHROPIC_MODEL) {
    console.log(`  Models / 模型:`);
    if (currentEnv.ANTHROPIC_MODEL)              console.log(`    Model     ${currentEnv.ANTHROPIC_MODEL}`);
    if (currentEnv.ANTHROPIC_DEFAULT_OPUS_MODEL)  console.log(`    Opus      ${currentEnv.ANTHROPIC_DEFAULT_OPUS_MODEL}`);
    if (currentEnv.ANTHROPIC_DEFAULT_SONNET_MODEL) console.log(`    Sonnet    ${currentEnv.ANTHROPIC_DEFAULT_SONNET_MODEL}`);
    if (currentEnv.ANTHROPIC_DEFAULT_HAIKU_MODEL)  console.log(`    Haiku     ${currentEnv.ANTHROPIC_DEFAULT_HAIKU_MODEL}`);
    if (currentEnv.CLAUDE_CODE_SUBAGENT_MODEL)     console.log(`    Subagent  ${currentEnv.CLAUDE_CODE_SUBAGENT_MODEL}`);
  }
}

/** Switch profile: deep-clone profile.env and replace settings.env
 *  切换配置文件：深拷贝 profile.env 替换 settings.env */
function switchProfile(settings, profileName) {
  const profiles = settings.profiles || {};
  const profile = profiles[profileName];

  if (!profile) {
    console.error(`错误 / Error: 找不到配置文件 '${profileName}' not found.`);
    const available = Object.keys(profiles);
    if (available.length > 0) {
      console.error(`可用的配置文件 / Available: ${available.join(', ')}`);
    } else {
      console.error('settings.json 中没有配置任何配置文件。/ No profiles configured.');
    }
    process.exit(1);
  }

  if (!profile.env || Object.keys(profile.env).length === 0) {
    console.error(`错误 / Error: 配置文件 '${profileName}' 缺少 env 字段 / has no env section.`);
    process.exit(1);
  }

  // Direct replace, no merge / 直接替换，不合并
  settings.env = JSON.parse(JSON.stringify(profile.env));
  saveSettings(settings);
  console.log(`已切换到配置文件 / Switched to profile: ${profileName}`);
}

/** Launch Claude Code 启动 Claude Code */
function launchClaude() {
  console.log('正在启动 Claude Code... / Starting Claude Code...');
  const claude = spawn('claude', [], { stdio: 'inherit', shell: true });
  claude.on('error', (err) => {
    console.error('无法启动 Claude Code / Failed to launch:', err.message);
    process.exit(1);
  });
  claude.on('exit', (code) => {
    process.exit(code || 0);
  });
}

/** Interactive profile selection (when run without args in terminal)
 *  交互式选择配置文件（终端无参数运行时） */
function interactiveSwitch(settings) {
  const profiles = settings.profiles || {};
  const names = Object.keys(profiles);

  if (names.length === 0) {
    console.log('没有找到任何配置文件。/ No profiles configured.');
    process.exit(1);
  }

  console.log('可用的配置文件 / Available profiles:\n');
  names.forEach((name, i) => {
    const env = profiles[name].env || {};
    console.log(`  ${i + 1}) ${name}  (${env.ANTHROPIC_MODEL || '未知 / unknown'})`);
  });

  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  rl.question(`\n请选择配置文件 / Select profile [1-${names.length}]（q 退出）: `, (answer) => {
    rl.close();
    answer = answer.trim();

    if (answer.toLowerCase() === 'q') {
      console.log('已取消 / Cancelled.');
      process.exit(0);
    }

    let target = null;

    // Try numeric index first / 先尝试数字序号
    const idx = parseInt(answer, 10);
    if (!isNaN(idx) && idx >= 1 && idx <= names.length) {
      target = names[idx - 1];
    } else if (names.includes(answer)) {
      // Then try name match / 再尝试名称匹配
      target = answer;
    }

    if (!target) {
      console.error('无效的选择 / Invalid selection.');
      process.exit(1);
    }

    switchProfile(settings, target);
    launchClaude();
  });
}

/** Main entry point 主入口 */
async function main() {
  const args = process.argv.slice(2);
  const cleanArgs = args.map(a => a.trim()).filter(Boolean);

  // Check for --no-launch flag (used inside Claude Code, don't spawn new window)
  // 检查 --no-launch 标志（Claude Code 内部调用，不启动新窗口）
  const noLaunchIdx = cleanArgs.indexOf('--no-launch');
  const noLaunch = noLaunchIdx !== -1;
  if (noLaunch) cleanArgs.splice(noLaunchIdx, 1);

  // Check for --no-balance flag (skip balance query for speed)
  // 检查 --no-balance 标志（跳过余额查询，快速显示）
  const noBalanceIdx = cleanArgs.indexOf('--no-balance');
  const noBalance = noBalanceIdx !== -1;
  if (noBalance) cleanArgs.splice(noBalanceIdx, 1);

  if (cleanArgs.length === 0) {
    if (noLaunch) {
      // Inside Claude Code: show list, can't do interactive
      // 在 Claude Code 内部：只显示列表，不做交互式选择
      const s = loadSettings();
      const balances = noBalance ? null : await fetchAllBalances(s.profiles || {});
      listProfiles(s, balances);
      console.log('用法 / Usage: /cs <profile-name>  [--no-balance 跳过余额查询]');
      return;
    }
    // Terminal direct run: interactive selection mode
    // 终端直接运行：进入交互式选择模式
    interactiveSwitch(loadSettings());
    return;
  }

  const cmd = cleanArgs[0].toLowerCase();

  if (cmd === 'list' || cmd === 'ls') {
    const s = loadSettings();
    const balances = noBalance ? null : await fetchAllBalances(s.profiles || {});
    listProfiles(s, balances);
  } else if (cmd === 'current' || cmd === 'cur') {
    const s = loadSettings();
    const currentEnv = s.env || {};
    const currentUrl = currentEnv.ANTHROPIC_BASE_URL;
    const currentToken = currentEnv.ANTHROPIC_AUTH_TOKEN;
    const balance = (noBalance || !currentUrl || !currentToken)
      ? null
      : await fetchBalance(currentUrl, currentToken);
    detectCurrent(s, balance);
  } else if (cmd === 'switch' && cleanArgs.length >= 2) {
    const s = loadSettings();
    switchProfile(s, cleanArgs[1]);
    if (!noLaunch) launchClaude();
  } else {
    // Direct profile name / 直接传配置文件名称
    const s = loadSettings();
    switchProfile(s, cleanArgs[0]);
    if (!noLaunch) launchClaude();
  }
}

main();
