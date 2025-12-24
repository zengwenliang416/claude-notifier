# ClaudeNotifier Makefile

PREFIX ?= $(HOME)/.claude/apps
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
	@echo "Done! Run: $(INSTALL_DIR)/Contents/MacOS/$(APP_NAME)"
	@echo ""
	@echo "Note: First run requires notification permission in System Preferences."

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
	@echo "  make install  Build and install to $(PREFIX)"
	@echo "  make uninstall Remove installed app"
	@echo "  make clean    Remove build artifacts"
	@echo "  make help     Show this help"
	@echo ""
	@echo "Options:"
	@echo "  PREFIX=<path> Custom install prefix (default: ~/.claude/apps)"
