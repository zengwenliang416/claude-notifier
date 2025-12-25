# Claude Notifier (macOS)

macOS 原生通知工具，当 Claude Code 完成任务时发送桌面通知 + 语音提醒。

## 功能特性

- 🔔 **桌面通知**：显示 Claude 星芒图标的原生 macOS 通知
- 🔊 **语音提醒**：支持系统声音和自定义音效文件
- 🎯 **点击跳转**：点击通知自动跳转到对应项目窗口
- 🪟 **智能匹配**：通过项目路径/名称匹配正确的编辑器窗口
- 🖥️ **跨 Space 支持**：支持在不同 macOS Space 间跳转窗口

## 系统要求

- macOS 12.0+
- Swift 5.0+

## 快速开始

### 1. 安装

```bash
git clone https://github.com/zengwenliang416/claude-notifier.git
cd claude-notifier/claude-notifier-macos

# 安装到 /Applications（推荐）
make install
```

### 2. 授权通知权限

首次运行时，macOS 会提示授权通知权限：

```bash
/Applications/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier
```

在弹出的对话框中点击「允许」，或前往「系统设置 → 通知 → Claude Notifier」手动开启。

## 使用方法

```bash
# 基本用法（默认标题和消息）
/Applications/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier

# 自定义标题和消息
/Applications/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier -t "标题" -m "消息内容"

# 使用系统声音
/Applications/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier -t "完成" -m "任务已完成" -s "Hero"

# 使用自定义音效文件
/Applications/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier -t "完成" -m "搞定！" -f ~/Music/done.aiff

# 静音模式
/Applications/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier -t "静默通知" -m "无声音" --no-sound
```

## 参数说明

### 基础参数

| 参数               | 说明               | 默认值           |
| ------------------ | ------------------ | ---------------- |
| `-t, --title`      | 通知标题           | "Claude Code"    |
| `-m, --message`    | 通知消息           | "Task completed" |
| `-s, --sound`      | 系统声音名称       | "Glass"          |
| `-f, --sound-file` | 自定义音效文件路径 | -                |
| `--no-sound`       | 禁用通知声音       | -                |
| `-h, --help`       | 显示帮助信息       | -                |

### 点击跳转参数

| 参数               | 说明                            | 示例                   |
| ------------------ | ------------------------------- | ---------------------- |
| `--host-bundle-id` | 宿主应用 Bundle ID              | `dev.zed.Zed`          |
| `--project-path`   | 项目完整路径                    | `/Users/xxx/myproject` |
| `--project-name`   | 项目文件夹名称                  | `myproject`            |
| `--tty`            | 终端 TTY 路径（保留，暂未使用） | `/dev/ttys003`         |

**支持的 Bundle ID**：

| 应用      | Bundle ID                       |
| --------- | ------------------------------- |
| Zed       | `dev.zed.Zed`                   |
| VS Code   | `com.microsoft.VSCode`          |
| Cursor    | `com.todesktop.230313mzl4w4u92` |
| Terminal  | `com.apple.Terminal`            |
| iTerm2    | `com.googlecode.iterm2`         |
| Warp      | `dev.warp.Warp-Stable`          |
| Alacritty | `org.alacritty`                 |
| Kitty     | `net.kovidgoyal.kitty`          |

## 点击跳转功能

### 功能说明

点击通知时，ClaudeNotifier 会：

1. **激活宿主应用**：将指定的 IDE/终端带到前台
2. **聚焦项目窗口**：在多窗口中找到并 raise 对应的项目窗口
3. **跨 Space 支持**：即使窗口在其他 macOS Space 也能正确跳转

### 窗口匹配逻辑

使用加权评分系统匹配最佳窗口：

| 匹配方式                 | 分数 | 说明                                         |
| ------------------------ | ---- | -------------------------------------------- |
| 文档路径完全匹配         | 100  | 窗口的 AXDocument 包含 `--project-path`      |
| 标题精确匹配项目名       | 50   | 窗口标题 == `--project-name`                 |
| 标题包含项目名           | 25   | 窗口标题包含 `--project-name`                |
| 窗口名是项目路径的父目录 | 30   | 如窗口 `.claude` 匹配路径 `/.claude/repos/x` |

> 选择分数最高的窗口进行聚焦。

### 技术实现

ClaudeNotifier 依次尝试以下方法：

1. **AX API**（首选）：通过 `AXUIElementPerformAction` 执行 `kAXRaiseAction`
2. **CLI 命令**（跨 Space）：调用应用自身 CLI 切换窗口（需配置）
3. **CG API + AppleScript**：通过窗口名匹配后使用 AppleScript raise
4. **通用 AppleScript**（兜底）：通过 System Events 控制窗口

### 跨 Space 窗口跳转配置

当窗口位于其他 macOS Space 时，AX API 无法直接操作。需配置应用 CLI 命令：

创建 `~/.claude/notifier-app-commands.json`：

```json
{
  "dev.zed.Zed": "zed \"{path}\"",
  "com.microsoft.VSCode": "code \"{path}\"",
  "com.todesktop.230313mzl4w4u92": "cursor \"{path}\""
}
```

**配置说明**：

- Key：应用的 Bundle ID
- Value：打开项目的 CLI 命令，`{path}` 会替换为项目路径
- **安全机制**：只有当目标项目窗口已存在时才会调用 CLI，避免意外打开新窗口

### 权限要求

点击跳转需要 **辅助功能权限**：

1. 首次使用时会弹出授权提示
2. 或手动前往：**系统设置 → 隐私与安全性 → 辅助功能**
3. 添加 `ClaudeNotifier.app` 并勾选

### 使用示例

```bash
# 完整的点击跳转通知
/Applications/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier \
  -t "Claude Code" \
  -m "myproject 任务完成" \
  --host-bundle-id dev.zed.Zed \
  --project-path /Users/xxx/myproject \
  --project-name myproject
```

## 系统声音

可用的 macOS 系统声音：

```
Basso, Blow, Bottle, Frog, Funk, Glass, Hero,
Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink
```

## 自定义语音音效

### 使用 macOS TTS 生成

```bash
# 使用中文语音生成音效
say -v Tingting "搞定咯~" -o done.aiff

# 可用的中文语音
say -v '?' | grep zh

# 常用语音：Tingting（女声）、Meijia（女声）
```

### 音效文件要求

- **格式**：`.aiff`, `.wav`, `.caf`, `.m4a`
- **时长**：必须小于 30 秒
- **安装**：使用 `-f` 参数时会自动复制到 `~/Library/Sounds/`

## Claude Code Hooks 配置

### 基础配置

编辑 `~/.claude/settings.json`：

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/Applications/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier -t 'Claude Code' -m 'Claude 已完成回答'"
          }
        ]
      }
    ]
  }
}
```

### 带点击跳转的高级配置

推荐使用 TypeScript hook 脚本（`~/.claude/hooks/stop-check.ts`），自动检测宿主应用并支持点击跳转：

```typescript
import { spawn } from "child_process";
import * as path from "path";

const NOTIFIER_PATH =
  "/Applications/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier";

// 检测宿主应用 Bundle ID
function detectHostBundleId(): string | undefined {
  const bundleMap: Record<string, string> = {
    zed: "dev.zed.Zed",
    vscode: "com.microsoft.VSCode",
    cursor: "com.todesktop.230313mzl4w4u92",
    apple_terminal: "com.apple.Terminal",
    iterm: "com.googlecode.iterm2",
    warp: "dev.warp.Warp-Stable",
  };
  const termProgram = process.env.TERM_PROGRAM?.toLowerCase();
  return termProgram ? bundleMap[termProgram] : undefined;
}

// 发送通知
function sendNotification() {
  const projectPath = process.cwd();
  const projectName = path.basename(projectPath);

  const args = ["-t", "Claude Code", "-m", `${projectName} 任务完成`];

  const hostBundleId = detectHostBundleId();
  if (hostBundleId) {
    args.push("--host-bundle-id", hostBundleId);
    args.push("--project-path", projectPath);
    args.push("--project-name", projectName);
  }

  spawn(NOTIFIER_PATH, args, {
    detached: true,
    stdio: "ignore",
  }).unref();
}

sendNotification();
```

然后在 `~/.claude/settings.json` 中配置：

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "npx tsx ~/.claude/hooks/stop-check.ts"
          }
        ]
      }
    ]
  }
}
```

### 带自定义语音的配置

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/Applications/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier -t 'Claude Code' -m 'Claude 已完成回答' -f '$HOME/.claude/sounds/done.aiff'"
          }
        ]
      }
    ]
  }
}
```

## 手动安装

如不使用 Makefile，可手动执行以下步骤：

```bash
# 编译
swiftc -O -o ClaudeNotifier src/ClaudeNotifier.swift

# 创建 App Bundle 结构
mkdir -p /Applications/ClaudeNotifier.app/Contents/{MacOS,Resources}

# 复制文件
cp ClaudeNotifier /Applications/ClaudeNotifier.app/Contents/MacOS/
cp resources/Info.plist /Applications/ClaudeNotifier.app/Contents/
cp resources/AppIcon.icns /Applications/ClaudeNotifier.app/Contents/Resources/

# 签名（Ad-hoc 签名）
codesign --force --deep --sign - /Applications/ClaudeNotifier.app

# 注册到 LaunchServices（使图标和通知正常显示）
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/ClaudeNotifier.app
```

> **注意**：安装到 `/Applications` 需要管理员权限，可使用 `sudo` 或改用 `~/Applications`。

## 技术细节

- **通知 API**: `UNUserNotificationCenter`（Apple 官方通知 API）
- **点击处理**: `UNUserNotificationCenterDelegate.didReceive`
- **窗口聚焦**: Accessibility API (`AXUIElement`) + AppleScript 备用
- **事件循环**: `NSApplication.run()` 接收通知回调
- **图标**: Claude 星芒图标（SVG → iconset → icns）
- **后台运行**: `LSUIElement=true`（不显示 Dock 图标）
- **激活策略**: `.accessory`（隐藏 Dock 图标，仅接收事件）
- **超时机制**: 60 秒无点击自动退出
- **最低系统**: macOS 12.0+

## 卸载

```bash
make uninstall
```

同时清理配置文件（可选）：

```bash
rm -f ~/.claude/notifier-app-commands.json
rm -f ~/Library/Sounds/claude-*.aiff
```

## 常见问题

### 基础问题

| 问题           | 解决方案                                                                            |
| -------------- | ----------------------------------------------------------------------------------- |
| 通知不显示     | 检查「系统设置 → 通知 → ClaudeNotifier」是否允许                                    |
| 图标显示异常   | 重新签名：`codesign --force --deep --sign - <app路径>` 后 `lsregister -f <app路径>` |
| 自定义音效不响 | 确认格式为 `.aiff`、时长 < 30 秒、已复制到 `~/Library/Sounds/`                      |
| 编译失败       | 确认已安装 Xcode Command Line Tools：`xcode-select --install`                       |

### 点击跳转问题

| 问题                         | 解决方案                                                                    |
| ---------------------------- | --------------------------------------------------------------------------- |
| 点击无响应                   | 检查辅助功能权限：「系统设置 → 隐私与安全性 → 辅助功能」添加 ClaudeNotifier |
| 跳转到错误窗口               | 确认 `--project-path` 和 `--project-name` 参数正确                          |
| 跨 Space 无法跳转            | 配置 `~/.claude/notifier-app-commands.json`，添加对应应用的 CLI 命令        |
| 点击后打开新窗口而非聚焦现有 | 这是正常安全行为：如目标窗口不存在，会直接激活应用而非打开新窗口            |

### 跨 Space 跳转配置

如果窗口在其他 Space，需要配置应用的 CLI 命令：

1. 创建配置文件：

```bash
cat > ~/.claude/notifier-app-commands.json << 'EOF'
{
  "dev.zed.Zed": "zed \"{path}\"",
  "com.microsoft.VSCode": "code \"{path}\"",
  "com.todesktop.230313mzl4w4u92": "cursor \"{path}\""
}
EOF
```

2. 确保 CLI 命令在 PATH 中：

```bash
# Zed
which zed  # 应输出 /usr/local/bin/zed 或类似路径

# VS Code（需手动安装 shell command）
# 在 VS Code 中：Cmd+Shift+P → "Shell Command: Install 'code' command in PATH"

# Cursor
which cursor
```

### 调试技巧

```bash
# 查看详细日志
/Applications/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier \
  -t "Test" -m "Debug" \
  --host-bundle-id dev.zed.Zed \
  --project-path /path/to/project \
  --project-name myproject 2>&1

# 检查窗口列表（需要辅助功能权限）
# 日志会显示窗口匹配分数，帮助诊断问题
```

## License

MIT License
