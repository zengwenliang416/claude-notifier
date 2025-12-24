# ClaudeNotifier

macOS 原生通知工具，显示自定义 Claude 图标。

## 为什么需要这个工具？

macOS 通知系统的图标必须来自 App Bundle，无法通过参数指定。`terminal-notifier -appIcon` 等方案在现代 macOS 上已失效。

本工具创建一个轻量级 App Bundle，使用 Claude 星芒图标作为应用图标，通过 `UNUserNotificationCenter` 发送通知。

## 安装

### 快速安装

```bash
git clone https://github.com/your-username/claude-notifier.git
cd claude-notifier
make install
```

### 手动安装

```bash
# 编译
swiftc -o ClaudeNotifier src/ClaudeNotifier.swift

# 创建 App Bundle
mkdir -p ~/.claude/apps/ClaudeNotifier.app/Contents/{MacOS,Resources}
cp ClaudeNotifier ~/.claude/apps/ClaudeNotifier.app/Contents/MacOS/
cp resources/Info.plist ~/.claude/apps/ClaudeNotifier.app/Contents/
cp resources/AppIcon.icns ~/.claude/apps/ClaudeNotifier.app/Contents/Resources/

# 签名并注册
codesign --force --deep --sign - ~/.claude/apps/ClaudeNotifier.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f ~/.claude/apps/ClaudeNotifier.app
```

## 使用方法

```bash
# 基本用法
~/.claude/apps/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier

# 自定义标题和消息
ClaudeNotifier -t "标题" -m "消息内容"

# 自定义声音
ClaudeNotifier -t "标题" -m "消息" -s "Ping"

# 查看帮助
ClaudeNotifier --help
```

### 参数

| 参数            | 说明     | 默认值           |
| --------------- | -------- | ---------------- |
| `-t, --title`   | 通知标题 | "Claude Code"    |
| `-m, --message` | 通知消息 | "Task completed" |
| `-s, --sound`   | 声音名称 | "Glass"          |
| `-h, --help`    | 显示帮助 | -                |

## 首次使用

首次运行时，macOS 会提示授权通知权限。请在系统偏好设置中允许 "Claude Notifier" 发送通知。

## 与 Claude Code Hooks 集成

在 `~/.claude/hooks/stop-check.sh` 中使用：

```bash
send_notification() {
    local title="Claude Code"
    local message="Claude 已完成回答"
    local notifier="$HOME/.claude/apps/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier"

    if [[ -x "$notifier" ]]; then
        "$notifier" -t "$title" -m "$message" 2>/dev/null || \
        osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
    else
        osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
    fi
}
```

## 技术细节

- **API**: `UNUserNotificationCenter`（Apple 官方通知 API）
- **图标**: Claude 星芒图标（SVG → iconset → icns）
- **后台运行**: `LSUIElement=true`（不显示 Dock 图标）
- **最低系统**: macOS 12.0+

## 文件结构

```
claude-notifier/
├── README.md
├── LICENSE
├── Makefile
├── src/
│   └── ClaudeNotifier.swift
├── resources/
│   ├── Info.plist
│   ├── AppIcon.icns
│   └── claude-starburst.svg
└── examples/
    └── stop-check.sh
```

## License

MIT License
