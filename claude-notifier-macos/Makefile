# ClaudeNotifier Makefile

PREFIX ?= /Applications
APP_NAME = ClaudeNotifier
APP_BUNDLE = $(APP_NAME).app
INSTALL_DIR = $(PREFIX)/$(APP_BUNDLE)

LSREGISTER = /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

.PHONY: all build install uninstall clean help

all: build

build: $(APP_NAME)

$(APP_NAME): src/ClaudeNotifier.swift
	@echo "Compiling $(APP_NAME)..."
	swiftc -O -o $(APP_NAME) src/ClaudeNotifier.swift

install: build
	@echo "Installing to $(INSTALL_DIR)..."
	@mkdir -p $(INSTALL_DIR)/Contents/MacOS
	@mkdir -p $(INSTALL_DIR)/Contents/Resources
	@cp $(APP_NAME) $(INSTALL_DIR)/Contents/MacOS/
	@cp src/ClaudeNotifier.swift $(INSTALL_DIR)/Contents/MacOS/
	@cp resources/Info.plist $(INSTALL_DIR)/Contents/
	@cp resources/AppIcon.icns $(INSTALL_DIR)/Contents/Resources/
	@echo "Signing app..."
	@codesign --force --deep --sign - $(INSTALL_DIR)
	@echo "Registering with LaunchServices..."
	@$(LSREGISTER) -f $(INSTALL_DIR)
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "✅ 安装完成！"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "📍 安装路径: $(INSTALL_DIR)"
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "📋 下一步操作"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "1️⃣  测试通知（首次运行需授权通知权限）:"
	@echo "    $(INSTALL_DIR)/Contents/MacOS/$(APP_NAME)"
	@echo ""
	@echo "2️⃣  配置 Claude Code Hooks（需手动配置）:"
	@echo "    编辑 ~/.claude/settings.json，添加以下内容:"
	@echo ""
	@echo '    {'
	@echo '      "hooks": {'
	@echo '        "Stop": [{'
	@echo '          "matcher": "",'
	@echo '          "hooks": [{'
	@echo '            "type": "command",'
	@echo '            "command": "$(INSTALL_DIR)/Contents/MacOS/$(APP_NAME) -t '\''Claude Code'\'' -m '\''Claude 已完成回答'\''"'
	@echo '          }]'
	@echo '        }]'
	@echo '      }'
	@echo '    }'
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "📖 详细文档: https://github.com/zengwenliang416/claude-notifier"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

uninstall:
	@echo "Uninstalling from $(INSTALL_DIR)..."
	@rm -rf $(INSTALL_DIR)
	@echo "Done!"

clean:
	@echo "Cleaning..."
	@rm -f $(APP_NAME)
	@echo "Done!"

help:
	@echo "ClaudeNotifier - macOS notification tool with Claude icon"
	@echo ""
	@echo "Usage:"
	@echo "  make          Build the executable"
	@echo "  make install  Build and install to /Applications"
	@echo "  make uninstall Remove installed app"
	@echo "  make clean    Remove build artifacts"
	@echo "  make help     Show this help"
