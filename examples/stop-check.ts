#!/usr/bin/env npx tsx
// Stop Hook: 检查任务是否真正完成
// 防止 Claude Code 在任务未完成时提前结束

import { existsSync, readFileSync, accessSync, constants } from "fs";
import { homedir } from "os";
import { join, basename } from "path";
import { spawnSync } from "child_process";

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

function getProjectName(): string {
  const cwd = process.cwd();
  return basename(cwd);
}

function sendNotification(): void {
  const notifier = join(
    homedir(),
    ".claude/apps/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier",
  );
  const soundFile = join(homedir(), ".claude/sounds/done.aiff");
  const projectName = getProjectName();
  const message = `${projectName} 项目任务已完成`;

  try {
    accessSync(notifier, constants.X_OK);
    spawnSync(notifier, ["-t", "Claude Code", "-m", message, "-f", soundFile], {
      stdio: "ignore",
    });
  } catch {
    // ClaudeNotifier 不可用，静默跳过
  }
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
    // JSON 解析失败，视为通过
    return { passed: true };
  }
}

function main(): void {
  const result = checkTodos();

  if (!result.passed) {
    logWarn(`阻止结束: ${result.reason}`);
    console.log(JSON.stringify({ decision: "block", reason: result.reason }));
  } else {
    logInfo("任务检查通过，允许结束");
    sendNotification();
    console.log(JSON.stringify({ decision: "approve" }));
  }
}

main();
