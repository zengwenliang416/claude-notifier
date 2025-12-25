# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **点击跳转功能**：点击通知自动跳转到对应项目窗口
  - 支持 Zed、VS Code、Cursor 等主流编辑器
  - 智能窗口匹配：基于项目路径和名称的加权评分系统
  - 跨 Space 支持：通过应用 CLI 命令实现跨桌面跳转
  - 配置文件 `~/.claude/notifier-app-commands.json` 支持自定义应用命令

### Changed

- **默认安装路径**：改为 `/Applications`，移除 `~/.claude/apps` 支持
- **窗口匹配逻辑优化**：
  - 新增 `windowExistsForProject` 函数检查窗口匹配分数
  - CLI 触发阈值提高到 >= 50，避免父目录匹配（分数 30）误触发
  - 无匹配窗口时不再回退 raise 第一个窗口

### Fixed

- 修复 Zed 多窗口场景下跳转到错误窗口的问题
- 修复点击通知后打开新窗口而非聚焦现有窗口的问题

### Performance

- 优化点击跳转响应速度
- 使用应用原生 CLI 替代 CGEvent 点击方案

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
