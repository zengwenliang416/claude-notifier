# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **任务状态区分**：新增 `--status` 参数支持 success/failure/warning
  - 失败时标题前缀 ❌，警告时前缀 ⚠️
  - 失败状态自动使用 Basso 声音（更明显的警告音）
- **通知摘要增强**：
  - `--subtitle` 参数：显示副标题（简短摘要）
  - `--duration` 参数：自动格式化耗时（如 120 秒 → "2m"）
- **结构化历史记录**：JSONL 格式记录到 `~/.claude/notifier-history.jsonl`
  - 包含时间戳、PID、标题、消息、项目信息、状态、耗时等字段
  - 支持 jq 查询和分析
- **点击跳转功能**：点击通知自动跳转到对应项目窗口
  - 支持 Zed、VS Code、Cursor 等主流编辑器
  - 智能窗口匹配：基于项目路径和名称的加权评分系统
  - 跨 Space 支持：通过应用 CLI 命令实现跨桌面跳转
  - 配置文件 `~/.claude/notifier-app-commands.json` 支持自定义应用命令

### Changed

- **默认安装路径**：改为 `/Applications`，移除 `~/.claude/apps` 支持
- **窗口匹配逻辑优化**：
  - 支持 Zed workspace 场景：当窗口标题是项目的父目录时，自动提取 workspace 路径用于 CLI
  - CLI 触发阈值降至 >= 30，支持父目录匹配场景
  - 新增 `extractWorkspacePath` 函数从项目路径提取 workspace 根路径
  - 无匹配窗口时不再回退 raise 第一个窗口

### Fixed

- 修复 Zed workspace 场景下点击通知无法跳转的问题（窗口标题显示 workspace 根目录而非项目名）
- 修复 Zed 多窗口场景下跳转到错误窗口的问题
- 修复点击通知后打开新窗口而非聚焦现有窗口的问题
- 修复 CLI 命令双重引号导致路径解析错误的问题（配置模板不再需要手动加引号）
- 修复 `--no-sound` 参数无效的问题（静音模式现在正常工作）

### Security

- 添加 AppleScript 字符串转义，防止通过恶意项目名/路径注入代码
- 添加 Shell 参数转义，防止通过 CLI 命令模板注入恶意命令
- 配置文件 `{path}` 占位符现在自动转义，无需手动加引号

### Performance

- 优化点击跳转响应速度
- 使用应用原生 CLI 替代 CGEvent 点击方案
- 合并重复的 CG 窗口扫描逻辑，减少系统调用
- 移除未使用的 `getZedFocusedWindowTitle` 函数

## [0.1.0] - 2024-12-20

### Added

- 初始版本发布
- macOS 原生通知支持（UNUserNotificationCenter）
- Claude 星芒图标显示
- 系统声音和自定义音效支持
- 通知显示项目名称
- 多渠道远程推送（ntfy/Telegram/Bark）
- TypeScript Hook 脚本支持

---

[Unreleased]: https://github.com/zengwenliang416/claude-notifier/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/zengwenliang416/claude-notifier/releases/tag/v0.1.0
