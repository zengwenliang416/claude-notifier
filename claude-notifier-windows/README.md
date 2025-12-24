# Claude Notifier (Windows)

Windows 原生 Toast 通知工具，当 Claude Code 完成任务时发送桌面通知 + 音效提醒。

## 系统要求

- Windows 10 1903+ 或 Windows 11
- 无需管理员权限

## 快速开始

### 方法一：使用安装包（推荐）

1. 下载 `dist/` 文件夹（包含 `claude-notifier.exe`、`task-complete.wav`、`install.ps1`）
2. 右键 `install.ps1` → **使用 PowerShell 运行**
3. 脚本将自动完成安装、注册和测试

### 方法二：手动安装

#### 1. 下载

从 [Releases](https://github.com/zengwenliang416/claude-notifier/releases) 下载 `claude-notifier.exe`。

#### 2. 复制到安装目录

```powershell
# 创建目录
mkdir -Force "$env:USERPROFILE\.claude\apps"
mkdir -Force "$env:USERPROFILE\.claude\sounds"

# 复制文件
Copy-Item claude-notifier.exe "$env:USERPROFILE\.claude\apps\"
Copy-Item task-complete.wav "$env:USERPROFILE\.claude\sounds\"
```

#### 3. 首次运行（必需）

```powershell
# 注册 AUMID 并创建开始菜单快捷方式
& "$env:USERPROFILE\.claude\apps\claude-notifier.exe" --init
```

> **重要**：Windows Toast 通知需要开始菜单快捷方式才能正常显示自定义图标。

#### 4. 测试通知

```powershell
& "$env:USERPROFILE\.claude\apps\claude-notifier.exe" -t "测试" -m "通知配置成功！" -f "$env:USERPROFILE\.claude\sounds\task-complete.wav"
```

## 使用方法

```powershell
# 基本用法（默认标题和消息）
.\claude-notifier.exe

# 自定义标题和消息
.\claude-notifier.exe -t "标题" -m "消息内容"

# 使用自定义音效文件（仅支持 .wav）
.\claude-notifier.exe -t "完成" -m "搞定！" -f "C:\sounds\done.wav"

# 静音模式
.\claude-notifier.exe -t "静默通知" -m "无声音" --no-sound

# 卸载（删除快捷方式）
.\claude-notifier.exe --uninstall
```

## 参数说明

| 参数               | 说明               | 默认值           |
| ------------------ | ------------------ | ---------------- |
| `-t, --title`      | 通知标题           | "Claude Code"    |
| `-m, --message`    | 通知消息           | "Task completed" |
| `-s, --sound`      | 系统声音名称       | Default          |
| `-f, --sound-file` | 自定义音效文件路径 | -                |
| `--no-sound`       | 禁用通知声音       | -                |
| `--init`           | 首次运行注册       | -                |
| `--uninstall`      | 清理注册信息       | -                |
| `-h, --help`       | 显示帮助信息       | -                |

## Claude Code Hooks 配置

编辑 `%USERPROFILE%\.claude\settings.json`：

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "%USERPROFILE%\\.claude\\apps\\claude-notifier.exe -t \"Claude Code\" -m \"Claude 已完成回答\""
          }
        ]
      }
    ]
  }
}
```

### 带自定义音效

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "%USERPROFILE%\\.claude\\apps\\claude-notifier.exe -t \"Claude Code\" -m \"Claude 已完成回答\" -f \"%USERPROFILE%\\.claude\\sounds\\done.wav\""
          }
        ]
      }
    ]
  }
}
```

## 自定义语音音效

### 方法一：使用 Windows TTS 生成

```powershell
# 使用 PowerShell 生成语音
Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.SetOutputToWaveFile("$env:USERPROFILE\.claude\sounds\done.wav")
$synth.Speak("搞定咯")
$synth.Dispose()
```

### 方法二：使用在线 TTS 服务

推荐网站：

- [MiniMax](https://www.minimax.io/audio/text-to-speech/chinese) - 国产，声音真实
- [ElevenLabs](https://elevenlabs.io/text-to-speech/chinese) - 最自然

下载后确保格式为 `.wav`（Windows Toast 仅支持 WAV）。

### 格式转换

```powershell
# 使用 ffmpeg 转换 MP3 到 WAV
ffmpeg -i input.mp3 -acodec pcm_s16le -ar 44100 output.wav
```

## 从源码构建

### 前置条件

- Rust 1.70+
- Windows 10 SDK

### 构建步骤

```powershell
cd claude-notifier-windows
cargo build --release
```

编译产物位于 `target/release/claude-notifier.exe`。

## 技术细节

- **API**: Windows Runtime (`Windows.UI.Notifications`)
- **语言**: Rust + windows-rs
- **注册机制**: AUMID + 开始菜单快捷方式
- **音频**: MediaPlayer API（自定义 .wav）

## 与 macOS 版本差异

| 特性     | macOS                    | Windows                  |
| -------- | ------------------------ | ------------------------ |
| 语言     | Swift                    | Rust                     |
| 通知 API | UNUserNotificationCenter | ToastNotificationManager |
| 图标     | App Bundle (.icns)       | 快捷方式 (.lnk)          |
| 音频格式 | .aiff, .wav, .caf        | 仅 .wav                  |
| 首次运行 | 自动授权弹窗             | 需手动 `--init`          |

## 常见问题

| 问题             | 解决方案                          |
| ---------------- | --------------------------------- |
| 通知不显示       | 确认已运行 `--init` 完成注册      |
| 通知无图标       | 检查开始菜单快捷方式是否存在      |
| SmartScreen 警告 | 点击「更多信息」→「仍要运行」     |
| 自定义音效不响   | 确认文件格式为 .wav，时长 < 30 秒 |

## License

MIT License
