#!/usr/bin/env npx tsx
// Stop Hook: 检查任务是否真正完成 + 发送通知
// 配置方式：环境变量
//   CLAUDE_NOTIFY_CHANNEL: telegram | ntfy | bark (可选)
//   Telegram: TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
//   Bark: BARK_KEY
//   ntfy: NTFY_TOPIC, NTFY_TOKEN (可选)

import { existsSync, readFileSync, accessSync, constants } from "fs";
import { homedir } from "os";
import { join, basename } from "path";
import { spawn, execSync } from "child_process";

function getProjectName(): string {
  return basename(process.cwd());
}

function getProjectPath(): string {
  return process.cwd();
}

function detectHostBundleId(): string | undefined {
  const bundleMap: Record<string, string> = {
    apple_terminal: "com.apple.Terminal",
    iterm: "com.googlecode.iterm2",
    "iterm.app": "com.googlecode.iterm2",
    vscode: "com.microsoft.VSCode",
    cursor: "com.todesktop.230313mzl4w4u92",
    warp: "dev.warp.Warp-Stable",
    alacritty: "org.alacritty",
    kitty: "net.kovidgoyal.kitty",
    hyper: "co.zeit.hyper",
    zed: "dev.zed.Zed",
  };

  // Zed 特殊检测（通过环境变量）
  if (process.env.ZED_WINDOW_ID || process.env.ZED_PANE_ID) {
    return "dev.zed.Zed";
  }

  // 通过 TERM_PROGRAM 检测
  const termProgram = process.env.TERM_PROGRAM?.toLowerCase();
  if (termProgram && bundleMap[termProgram]) {
    return bundleMap[termProgram];
  }

  // JetBrains IDE 检测
  if (process.env.TERMINAL_EMULATOR === "JetBrains-JediTerm") {
    const bundleId = process.env.__CFBundleIdentifier;
    if (bundleId) return bundleId;
    return "com.jetbrains.intellij";
  }

  return undefined;
}

function getTty(): string | undefined {
  try {
    const tty = execSync("tty", { encoding: "utf-8" }).trim();
    return tty !== "not a tty" ? tty : undefined;
  } catch {
    return undefined;
  }
}

const GREEN = "\x1b[0;32m";
const YELLOW = "\x1b[1;33m";
const NC = "\x1b[0m";

const logInfo = (msg: string) =>
  console.error(`${GREEN}[STOP-CHECK]${NC} ${msg}`);
const logWarn = (msg: string) =>
  console.error(`${YELLOW}[STOP-CHECK]${NC} ${msg}`);

interface Todo {
  content: string;
  status: "pending" | "in_progress" | "completed";
}

interface CheckResult {
  passed: boolean;
  reason?: string;
}

// 使用 curl 发送 HTTP 请求
function curlPost(
  url: string,
  headers: Record<string, string>,
  body: string,
): Promise<void> {
  return new Promise((resolve, reject) => {
    const args = ["-s", "-X", "POST", url, "-d", body];
    for (const [key, value] of Object.entries(headers)) {
      args.push("-H", `${key}: ${value}`);
    }
    const proc = spawn("curl", args, { stdio: ["ignore", "pipe", "pipe"] });
    let stderr = "";
    proc.stderr?.on("data", (d) => (stderr += d));
    proc.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`curl exit ${code}: ${stderr}`));
    });
    proc.on("error", reject);
  });
}

// ntfy 推送
async function sendNtfy(title: string, message: string): Promise<void> {
  const topic = process.env.NTFY_TOPIC;
  if (!topic) throw new Error("NTFY_TOPIC 未设置");

  const server = process.env.NTFY_SERVER || "https://ntfy.sh";
  const url = `${server}/${topic}`;
  const headers: Record<string, string> = { Title: title, Priority: "3" };

  const token = process.env.NTFY_TOKEN;
  if (token) headers.Authorization = `Bearer ${token}`;

  await curlPost(url, headers, message);
}

// Telegram 推送
async function sendTelegram(title: string, message: string): Promise<void> {
  const botToken = process.env.TELEGRAM_BOT_TOKEN;
  const chatId = process.env.TELEGRAM_CHAT_ID;
  if (!botToken || !chatId) {
    throw new Error("TELEGRAM_BOT_TOKEN 或 TELEGRAM_CHAT_ID 未设置");
  }

  const url = `https://api.telegram.org/bot${botToken}/sendMessage`;
  const text = `*${title}*\n${message}`;

  await curlPost(
    url,
    { "Content-Type": "application/json" },
    JSON.stringify({ chat_id: chatId, text, parse_mode: "Markdown" }),
  );
}

// Bark 推送
async function sendBark(title: string, message: string): Promise<void> {
  const deviceKey = process.env.BARK_KEY;
  if (!deviceKey) throw new Error("BARK_KEY 未设置");

  const server = process.env.BARK_SERVER || "https://api.day.app";
  const url = `${server}/${deviceKey}`;

  await curlPost(
    url,
    { "Content-Type": "application/json" },
    JSON.stringify({ title, body: message, group: "Claude" }),
  );
}

// 桌面通知（支持点击跳转到项目窗口）
function sendDesktopNotification(projectName: string): Promise<void> {
  return new Promise((resolve) => {
    const userNotifier = join(
      homedir(),
      ".claude/apps/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier",
    );
    const systemNotifier =
      "/Applications/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier";
    const notifier = existsSync(userNotifier) ? userNotifier : systemNotifier;
    const soundFile = join(homedir(), ".claude/sounds/done.aiff");
    const message = `${projectName} 项目任务已完成`;

    const hostBundleId = detectHostBundleId();
    const projectPath = getProjectPath();
    const tty = getTty();

    try {
      accessSync(notifier, constants.X_OK);

      const args = ["-t", "Claude Code", "-m", message, "-f", soundFile];

      // 添加点击跳转参数
      if (hostBundleId) {
        args.push("--host-bundle-id", hostBundleId);
      }
      if (projectPath) {
        args.push("--project-path", projectPath);
        args.push("--project-name", projectName);
      }
      if (tty) {
        args.push("--tty", tty);
      }

      const proc = spawn(notifier, args, { stdio: "ignore", detached: true });
      proc.unref();
      resolve();
    } catch {
      resolve();
    }
  });
}

// 远程推送（根据环境变量选择渠道）
async function sendRemoteNotification(projectName: string): Promise<void> {
  const channel = process.env.CLAUDE_NOTIFY_CHANNEL?.toLowerCase();
  if (!channel) return;

  const title = "Claude Code";
  const message = `${projectName} 项目任务已完成`;

  switch (channel) {
    case "telegram":
      await sendTelegram(title, message);
      break;
    case "ntfy":
      await sendNtfy(title, message);
      break;
    case "bark":
      await sendBark(title, message);
      break;
    default:
      logWarn(`未知渠道: ${channel}，支持 telegram/ntfy/bark`);
  }
}

// 并行发送通知
async function sendNotification(): Promise<void> {
  const projectName = getProjectName();
  await Promise.all([
    sendDesktopNotification(projectName),
    sendRemoteNotification(projectName).catch((e) => {
      logWarn(`远程推送失败: ${e}`);
    }),
  ]);
}

function checkTodos(): CheckResult {
  const todoFile = join(homedir(), ".claude/todos.json");

  if (!existsSync(todoFile)) {
    return { passed: true };
  }

  try {
    const content = readFileSync(todoFile, "utf-8");
    const todos: Todo[] = JSON.parse(content);

    const inProgress = todos.filter((t) => t.status === "in_progress");
    if (inProgress.length > 0) {
      logWarn(`发现 ${inProgress.length} 个进行中的任务`);
      return {
        passed: false,
        reason: "仍有未完成的任务，请先完成所有任务再结束",
      };
    }

    const pending = todos.filter((t) => t.status === "pending");
    if (pending.length > 0) {
      logWarn(`发现 ${pending.length} 个待处理的任务`);
      return {
        passed: false,
        reason: "仍有未完成的任务，请先完成所有任务再结束",
      };
    }

    return { passed: true };
  } catch {
    return { passed: true };
  }
}

async function main(): Promise<void> {
  const result = checkTodos();

  if (!result.passed) {
    logWarn(`阻止结束: ${result.reason}`);
    console.log(JSON.stringify({ decision: "block", reason: result.reason }));
    return;
  }

  logInfo("任务检查通过，允许结束");
  console.log(JSON.stringify({ decision: "approve" }));

  try {
    await sendNotification();
    logInfo("通知发送完成");
  } catch (e) {
    logWarn(`通知发送失败: ${e}`);
  }
}

main();
