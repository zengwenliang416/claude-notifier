import Foundation
import UserNotifications
import AppKit
import ApplicationServices
import CoreGraphics

private enum NotificationUserInfoKey {
    static let projectPath = "projectPath"
    static let projectName = "projectName"
    static let hostBundleId = "hostBundleId"
    static let tty = "tty"
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        fputs("[DEBUG] didReceive called, actionId: \(response.actionIdentifier)\n", stderr)

        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
            fputs("[DEBUG] Not default action, ignoring\n", stderr)
            completionHandler()
            return
        }

        let userInfo = response.notification.request.content.userInfo
        fputs("[DEBUG] userInfo: \(userInfo)\n", stderr)

        let hostBundleId = userInfo[NotificationUserInfoKey.hostBundleId] as? String
        let projectPath = userInfo[NotificationUserInfoKey.projectPath] as? String
        let projectName = userInfo[NotificationUserInfoKey.projectName] as? String

        fputs("[DEBUG] hostBundleId=\(hostBundleId ?? "nil"), projectPath=\(projectPath ?? "nil"), projectName=\(projectName ?? "nil")\n", stderr)

        if let hostBundleId, !hostBundleId.isEmpty {
            fputs("[DEBUG] Calling focusHostApp...\n", stderr)
            focusHostApp(hostBundleId: hostBundleId, projectPath: projectPath, projectName: projectName)
            fputs("[DEBUG] focusHostApp completed\n", stderr)
        } else {
            fputs("[DEBUG] No hostBundleId, skipping focus\n", stderr)
        }

        // 移除已处理的通知，防止重复显示
        let notificationId = response.notification.request.identifier
        fputs("[DEBUG] Removing notification: \(notificationId)\n", stderr)
        center.removeDeliveredNotifications(withIdentifiers: [notificationId])

        // 移除所有已投递的通知
        center.removeAllDeliveredNotifications()

        completionHandler()

        // 短暂延迟后退出
        fputs("[DEBUG] Waiting before exit...\n", stderr)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            fputs("[DEBUG] Exiting...\n", stderr)
            NSApplication.shared.terminate(nil)
        }
    }
}

private let notificationDelegate = NotificationDelegate()

private func ensureAccessibilityPermission() -> Bool {
    if AXIsProcessTrusted() {
        return true
    }

    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}

private func activateHostApp(bundleId: String) -> NSRunningApplication? {
    fputs("[DEBUG] activateHostApp: looking for \(bundleId)\n", stderr)

    // 优先查找已运行的应用
    if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
        fputs("[DEBUG] activateHostApp: found running app, activating...\n", stderr)
        let result = running.activate(options: [.activateIgnoringOtherApps])
        fputs("[DEBUG] activateHostApp: activate result = \(result)\n", stderr)
        return running
    }

    // 尝试启动应用（如果未运行）
    guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
        fputs("Host app not found: \(bundleId)\n", stderr)
        return nil
    }

    let semaphore = DispatchSemaphore(value: 0)
    var launchedApp: NSRunningApplication?

    let config = NSWorkspace.OpenConfiguration()
    config.activates = true

    DispatchQueue.main.async {
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { app, error in
            if let error {
                fputs("Failed to launch app: \(error.localizedDescription)\n", stderr)
            }
            launchedApp = app
            semaphore.signal()
        }
    }

    // 等待启动完成，最多 3 秒
    _ = semaphore.wait(timeout: .now() + 3)
    return launchedApp
}

private func axStringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute, &value)
    guard result == .success else {
        return nil
    }

    if let str = value as? String {
        return str
    }
    if let url = value as? URL {
        return url.path
    }
    return nil
}

private func axWindows(for appElement: AXUIElement) -> [AXUIElement] {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
    guard result == .success else {
        return []
    }

    return value as? [AXUIElement] ?? []
}

/// 从路径中提取所有有意义的组件用于匹配
private func extractPathComponents(_ path: String) -> [String] {
    let components = path.split(separator: "/").map(String.init)
    return components.filter { comp in
        comp.count >= 2 && !["Users", "home", "var", "tmp", "usr", "opt"].contains(comp)
    }
}

/// 检查窗口名是否是项目路径的父目录
/// 例如：窗口名 ".claude"，项目路径 "/Users/xxx/.claude/repos/project" → 返回 true
private func isWindowParentOfProject(windowTitle: String, projectPath: String) -> Bool {
    let pathComponents = projectPath.split(separator: "/").map(String.init)
    // 检查窗口名是否是路径中的某个目录组件
    return pathComponents.contains { $0 == windowTitle }
}

/// 计算窗口与项目的匹配分数（分数越高匹配越精确）
private func calculateMatchScore(windowTitle: String?, document: String?, projectPath: String?, projectName: String?) -> Int {
    var score = 0

    // 1. 完整文档路径匹配（最高优先级：100分）
    if let doc = document, let path = projectPath, !doc.isEmpty, !path.isEmpty {
        if doc.lowercased().contains(path.lowercased()) {
            score += 100
        }
    }

    // 2. 标题精确匹配项目名（高优先级：50分）
    if let title = windowTitle, let name = projectName, !title.isEmpty, !name.isEmpty {
        let titleLower = title.lowercased()
        let nameLower = name.lowercased()
        if titleLower == nameLower {
            score += 50
        } else if titleLower.contains(nameLower) || nameLower.contains(titleLower) {
            score += 25
        }
    }

    // 3. 窗口名是项目路径的父目录（中优先级：30分）
    // 例如：窗口 ".claude" 包含项目 "/Users/xxx/.claude/repos/project"
    if let title = windowTitle, let path = projectPath, !title.isEmpty, !path.isEmpty {
        if isWindowParentOfProject(windowTitle: title, projectPath: path) {
            score += 30
        }
    }

    return score
}

private func focusWindow(pid: pid_t, projectPath: String?, projectName: String?) -> Bool {
    fputs("[DEBUG] focusWindow: pid=\(pid), path=\(projectPath ?? "nil"), name=\(projectName ?? "nil")\n", stderr)

    let hasHint = (projectName?.isEmpty == false) || (projectPath?.isEmpty == false)
    guard hasHint else {
        fputs("[DEBUG] focusWindow: no hint\n", stderr)
        return false
    }

    let appElement = AXUIElementCreateApplication(pid)
    let windows = axWindows(for: appElement)
    fputs("[DEBUG] focusWindow: found \(windows.count) windows\n", stderr)

    guard !windows.isEmpty else {
        fputs("[DEBUG] focusWindow: no windows found\n", stderr)
        return false
    }

    // 使用加权匹配：计算每个窗口的匹配分数，选择最高分的窗口
    var bestMatch: (window: AXUIElement, score: Int, index: Int)? = nil

    for (index, window) in windows.enumerated() {
        let title = axStringAttribute(window, kAXTitleAttribute as CFString)
        let document = axStringAttribute(window, kAXDocumentAttribute as CFString)
        let score = calculateMatchScore(windowTitle: title, document: document, projectPath: projectPath, projectName: projectName)

        fputs("[DEBUG] focusWindow: window[\(index)] title=\(title ?? "nil"), document=\(document ?? "nil"), score=\(score)\n", stderr)

        if score > 0 && (bestMatch == nil || score > bestMatch!.score) {
            bestMatch = (window, score, index)
        }
    }

    // 选择最佳匹配的窗口
    if let best = bestMatch {
        fputs("[DEBUG] focusWindow: best match is window[\(best.index)] with score=\(best.score), raising...\n", stderr)
        let raiseResult = AXUIElementPerformAction(best.window, kAXRaiseAction as CFString)
        fputs("[DEBUG] focusWindow: AXRaiseAction result=\(raiseResult.rawValue)\n", stderr)
        if raiseResult != .success {
            fputs("[DEBUG] focusWindow: AXRaiseAction failed: \(raiseResult.rawValue)\n", stderr)
        }
        return raiseResult == .success
    }

    // 没有找到匹配的窗口，返回 false 让调用方尝试其他方法
    fputs("[DEBUG] focusWindow: no matching window found, returning false to try other methods\n", stderr)
    return false
}

/// 从 bundle ID 获取应用名称
private func getAppName(fromBundleId bundleId: String) -> String? {
    if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
        return app.localizedName
    }
    // 常见映射
    let knownApps: [String: String] = [
        "dev.zed.Zed": "Zed",
        "com.microsoft.VSCode": "Code",
        "com.apple.Terminal": "Terminal",
        "com.googlecode.iterm2": "iTerm2",
    ]
    return knownApps[bundleId]
}

/// 使用 AppleScript 通过 System Events 聚焦窗口
private func focusWindowViaAppleScript(bundleId: String, projectPath: String?, projectName: String?) -> Bool {
    fputs("[DEBUG] focusWindowViaAppleScript: bundleId=\(bundleId), path=\(projectPath ?? "nil"), name=\(projectName ?? "nil")\n", stderr)

    guard let appName = getAppName(fromBundleId: bundleId) else {
        fputs("[DEBUG] focusWindowViaAppleScript: could not get app name for \(bundleId)\n", stderr)
        return false
    }
    fputs("[DEBUG] focusWindowViaAppleScript: appName=\(appName)\n", stderr)

    // 构建匹配条件
    var matchConditions: [String] = []
    if let name = projectName, !name.isEmpty {
        matchConditions.append("name of w contains \"\(name)\"")
    }
    if let path = projectPath, !path.isEmpty {
        // 提取路径组件用于匹配
        let components = extractPathComponents(path)
        for comp in components {
            matchConditions.append("name of w contains \"\(comp)\"")
        }
    }

    let matchCondition = matchConditions.isEmpty ? "true" : matchConditions.joined(separator: " or ")

    let script = """
    tell application "System Events"
        tell process "\(appName)"
            set frontmost to true
            set windowList to every window
            repeat with w in windowList
                if \(matchCondition) then
                    perform action "AXRaise" of w
                    return "matched"
                end if
            end repeat
            -- 没有匹配，raise 第一个窗口
            if (count of windowList) > 0 then
                perform action "AXRaise" of item 1 of windowList
                return "fallback"
            end if
        end tell
    end tell
    return "no_windows"
    """

    fputs("[DEBUG] focusWindowViaAppleScript: executing script...\n", stderr)

    var error: NSDictionary?
    if let appleScript = NSAppleScript(source: script) {
        let result = appleScript.executeAndReturnError(&error)
        if let error = error {
            fputs("[DEBUG] focusWindowViaAppleScript: error=\(error)\n", stderr)
            return false
        }
        let resultStr = result.stringValue ?? "unknown"
        fputs("[DEBUG] focusWindowViaAppleScript: result=\(resultStr)\n", stderr)
        return resultStr == "matched" || resultStr == "fallback"
    }
    return false
}

/// 使用 CG API 获取窗口列表并通过匹配找到目标窗口名
private func findBestWindowNameViaCGAPI(pid: pid_t, projectPath: String?, projectName: String?) -> String? {
    fputs("[DEBUG] findBestWindowNameViaCGAPI: pid=\(pid)\n", stderr)

    guard let windowList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
        fputs("[DEBUG] findBestWindowNameViaCGAPI: failed to get window list\n", stderr)
        return nil
    }

    var candidates: [(windowName: String, score: Int)] = []

    for window in windowList {
        guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int32, ownerPID == pid else {
            continue
        }

        let windowName = window[kCGWindowName as String] as? String ?? ""
        guard !windowName.isEmpty else { continue }

        // 计算匹配分数
        let score = calculateMatchScore(windowTitle: windowName, document: nil, projectPath: projectPath, projectName: projectName)

        fputs("[DEBUG] findBestWindowNameViaCGAPI: window '\(windowName)' score=\(score)\n", stderr)

        if score > 0 {
            candidates.append((windowName, score))
        }
    }

    // 返回分数最高的窗口名
    if let best = candidates.max(by: { $0.score < $1.score }) {
        fputs("[DEBUG] findBestWindowNameViaCGAPI: best match '\(best.windowName)' score=\(best.score)\n", stderr)
        return best.windowName
    }

    return nil
}

/// 检查是否存在精确匹配项目的窗口（用于决定是否使用 CLI）
/// 返回最高匹配分数，只有分数 >= 50 才认为是精确匹配
/// 分数 30（父目录匹配）不足以触发 CLI，因为可能打开错误的目录
private func windowExistsForProject(pid: pid_t, projectPath: String?, projectName: String?) -> Bool {
    guard let windowList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
        return false
    }

    var bestScore = 0
    var bestWindow = ""

    for window in windowList {
        guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int32, ownerPID == pid else {
            continue
        }

        let windowName = window[kCGWindowName as String] as? String ?? ""
        guard !windowName.isEmpty else { continue }

        let score = calculateMatchScore(windowTitle: windowName, document: nil, projectPath: projectPath, projectName: projectName)
        if score > bestScore {
            bestScore = score
            bestWindow = windowName
        }
    }

    // 只有分数 >= 50 才认为是精确匹配（标题精确匹配或包含项目名）
    // 分数 30（父目录匹配）不足以触发 CLI，避免打开错误目录
    let threshold = 50
    if bestScore >= threshold {
        fputs("[DEBUG] windowExistsForProject: found matching window '\(bestWindow)' with score=\(bestScore) (>= \(threshold))\n", stderr)
        return true
    }

    fputs("[DEBUG] windowExistsForProject: best score=\(bestScore) < \(threshold), not precise enough for CLI\n", stderr)
    return false
}

/// 通过 AppleScript 使用窗口名 raise 指定窗口
private func raiseWindowByName(appName: String, windowName: String) -> Bool {
    fputs("[DEBUG] raiseWindowByName: app=\(appName), window=\(windowName)\n", stderr)

    let script = """
    tell application "System Events"
        tell process "\(appName)"
            set frontmost to true
            set windowList to every window
            repeat with w in windowList
                if name of w is "\(windowName)" then
                    perform action "AXRaise" of w
                    return "matched"
                end if
            end repeat
        end tell
    end tell
    return "not_found"
    """

    var error: NSDictionary?
    if let appleScript = NSAppleScript(source: script) {
        let result = appleScript.executeAndReturnError(&error)
        if let error = error {
            fputs("[DEBUG] raiseWindowByName: error=\(error)\n", stderr)
            return false
        }
        let resultStr = result.stringValue ?? "unknown"
        fputs("[DEBUG] raiseWindowByName: result=\(resultStr)\n", stderr)
        return resultStr == "matched"
    }
    return false
}

/// 获取 Zed 当前焦点窗口标题
private func getZedFocusedWindowTitle(pid: pid_t) -> String? {
    let appElement = AXUIElementCreateApplication(pid)
    var focused: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focused)
    guard result == .success, focused != nil else { return nil }

    let fw = focused as AnyObject
    var title: CFTypeRef?
    AXUIElementCopyAttributeValue(fw as! AXUIElement, kAXTitleAttribute as CFString, &title)
    return title as? String
}

/// 使用应用自身的 CLI 切换窗口（跨 Space 场景）
/// 配置文件: ~/.claude/notifier-app-commands.json
/// 格式: { "bundleId": "open command with {path} placeholder" }
/// 例如: { "dev.zed.Zed": "zed {path}" }
private func focusWindowViaCLI(bundleId: String, projectPath: String) -> Bool {
    fputs("[DEBUG] focusWindowViaCLI: bundleId=\(bundleId), path=\(projectPath)\n", stderr)

    // 读取配置文件
    let configPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/notifier-app-commands.json")

    guard FileManager.default.fileExists(atPath: configPath.path),
          let data = try? Data(contentsOf: configPath),
          let config = try? JSONSerialization.jsonObject(with: data) as? [String: String],
          let commandTemplate = config[bundleId] else {
        fputs("[DEBUG] focusWindowViaCLI: no config for \(bundleId)\n", stderr)
        return false
    }

    // 替换 {path} 占位符
    let command = commandTemplate.replacingOccurrences(of: "{path}", with: projectPath)
    fputs("[DEBUG] focusWindowViaCLI: executing '\(command)'\n", stderr)

    // 执行命令
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", command]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
        process.waitUntilExit()
        let success = process.terminationStatus == 0
        fputs("[DEBUG] focusWindowViaCLI: exit code=\(process.terminationStatus)\n", stderr)
        return success
    } catch {
        fputs("[DEBUG] focusWindowViaCLI: error=\(error)\n", stderr)
        return false
    }
}

private func focusHostApp(hostBundleId: String, projectPath: String?, projectName: String?) {
    fputs("[DEBUG] focusHostApp: bundleId=\(hostBundleId)\n", stderr)

    guard let app = activateHostApp(bundleId: hostBundleId) else {
        fputs("[DEBUG] focusHostApp: activateHostApp returned nil\n", stderr)
        return
    }
    fputs("[DEBUG] focusHostApp: app activated, pid=\(app.processIdentifier)\n", stderr)

    let hasHint = (projectName?.isEmpty == false) || (projectPath?.isEmpty == false)
    guard hasHint else {
        fputs("[DEBUG] focusHostApp: no project hint, skipping window focus\n", stderr)
        return
    }

    guard ensureAccessibilityPermission() else {
        fputs("[DEBUG] focusHostApp: accessibility permission denied\n", stderr)
        return
    }
    fputs("[DEBUG] focusHostApp: accessibility permission granted\n", stderr)

    // 方法 1: 尝试 AX API（对同一 Space 的窗口有效）
    for attempt in 1...2 {
        let result = focusWindow(pid: app.processIdentifier, projectPath: projectPath, projectName: projectName)
        if result {
            fputs("[DEBUG] focusHostApp: AX API succeeded on attempt \(attempt)\n", stderr)
            return
        }
        if attempt < 2 {
            Thread.sleep(forTimeInterval: 0.15)
        }
    }

    // 方法 2: 使用应用 CLI 命令（跨 Space 场景，需配置）
    // 配置文件: ~/.claude/notifier-app-commands.json
    // 重要：只有当窗口确实存在（但在其他 Space）时才使用 CLI
    // 避免打开不存在的项目窗口
    if let path = projectPath, !path.isEmpty {
        // 先检查是否存在匹配的窗口
        if windowExistsForProject(pid: app.processIdentifier, projectPath: projectPath, projectName: projectName) {
            fputs("[DEBUG] focusHostApp: window exists, trying CLI command...\n", stderr)
            if focusWindowViaCLI(bundleId: hostBundleId, projectPath: path) {
                fputs("[DEBUG] focusHostApp: CLI command succeeded\n", stderr)
                return
            }
        } else {
            fputs("[DEBUG] focusHostApp: no matching window exists, skipping CLI to avoid opening new window\n", stderr)
        }
    }

    // 方法 3: 使用 CG API 找到窗口名，然后通过 AppleScript raise
    fputs("[DEBUG] focusHostApp: trying CG API + AppleScript...\n", stderr)
    if let windowName = findBestWindowNameViaCGAPI(pid: app.processIdentifier, projectPath: projectPath, projectName: projectName),
       let appName = getAppName(fromBundleId: hostBundleId) {
        if raiseWindowByName(appName: appName, windowName: windowName) {
            fputs("[DEBUG] focusHostApp: CG API + AppleScript succeeded\n", stderr)
            return
        }
    }

    // 方法 4: 尝试通用 AppleScript
    fputs("[DEBUG] focusHostApp: trying generic AppleScript...\n", stderr)
    if focusWindowViaAppleScript(bundleId: hostBundleId, projectPath: projectPath, projectName: projectName) {
        fputs("[DEBUG] focusHostApp: AppleScript succeeded\n", stderr)
        return
    }

    fputs("[DEBUG] focusHostApp: all methods failed, app is activated but window focus failed\n", stderr)
}

/// 安装自定义音效到 ~/Library/Sounds/
func installCustomSound(from path: String) -> String? {
    let fileManager = FileManager.default
    let sourceURL = URL(fileURLWithPath: path)

    // 验证文件存在
    guard fileManager.fileExists(atPath: path) else {
        fputs("Sound file not found: \(path)\n", stderr)
        return nil
    }

    // 验证文件格式
    let ext = sourceURL.pathExtension.lowercased()
    guard ["aiff", "aif", "wav", "caf", "m4a"].contains(ext) else {
        fputs("Unsupported sound format: \(ext). Use .aiff, .wav, .caf, or .m4a\n", stderr)
        return nil
    }

    // 创建 ~/Library/Sounds/ 目录
    let soundsDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Sounds")

    do {
        try fileManager.createDirectory(at: soundsDir, withIntermediateDirectories: true)
    } catch {
        fputs("Failed to create Sounds directory: \(error.localizedDescription)\n", stderr)
        return nil
    }

    // 复制音效文件
    let destURL = soundsDir.appendingPathComponent(sourceURL.lastPathComponent)

    // 如果已存在则删除
    if fileManager.fileExists(atPath: destURL.path) {
        try? fileManager.removeItem(at: destURL)
    }

    do {
        try fileManager.copyItem(at: sourceURL, to: destURL)
        fputs("Installed sound: \(destURL.path)\n", stderr)
    } catch {
        fputs("Failed to copy sound file: \(error.localizedDescription)\n", stderr)
        return nil
    }

    // 返回不带扩展名的文件名
    return sourceURL.deletingPathExtension().lastPathComponent
}

func sendNotification(title: String, message: String, sound: String?, soundFile: String?, userInfo: [AnyHashable: Any]) {
    let center = UNUserNotificationCenter.current()

    let semaphore = DispatchSemaphore(value: 0)

    // 处理自定义音效文件
    var soundName = sound ?? "Glass"
    if let file = soundFile {
        if let installed = installCustomSound(from: file) {
            soundName = installed
        }
    }

    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
        if let error = error {
            fputs("Authorization error: \(error.localizedDescription)\n", stderr)
            semaphore.signal()
            return
        }

        if !granted {
            fputs("Notification permission denied\n", stderr)
            semaphore.signal()
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.userInfo = userInfo
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                fputs("Failed to send notification: \(error.localizedDescription)\n", stderr)
            }
            semaphore.signal()
        }
    }

    _ = semaphore.wait(timeout: .now() + 5)
}

// 写入固定日志文件，追踪所有实例
let logFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/notifier-all.log")
func logToFile(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(message)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logFile.path) {
            if let handle = try? FileHandle(forWritingTo: logFile) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: logFile)
        }
    }
}

logToFile("=== ClaudeNotifier starting ===")
logToFile("PID: \(ProcessInfo.processInfo.processIdentifier)")
logToFile("Args: \(CommandLine.arguments)")

fputs("[DEBUG] === ClaudeNotifier starting ===\n", stderr)
fputs("[DEBUG] Args: \(CommandLine.arguments)\n", stderr)

let center = UNUserNotificationCenter.current()
center.delegate = notificationDelegate

let recognizedOptions: Set<String> = [
    "-t", "--title",
    "-m", "--message",
    "-s", "--sound",
    "-f", "--sound-file",
    "--no-sound",
    "-h", "--help",
    "--project-path",
    "--project-name",
    "--host-bundle-id",
    "--tty",
]

let rawArgs = Array(CommandLine.arguments.dropFirst())
let isLaunchServicesLaunch = rawArgs.contains(where: { $0.hasPrefix("-psn_") })
let hasRecognizedArgs = rawArgs.contains(where: { recognizedOptions.contains($0) })

// 关键修复：如果没有任何有效参数，不发送通知
// 这防止了点击通知后系统重新激活应用时发送默认通知
if !hasRecognizedArgs {
    logToFile("No recognized args, exiting without notification")
    fputs("[DEBUG] No recognized args, exiting without notification\n", stderr)
    if isLaunchServicesLaunch {
        // LaunchServices 启动，等待一会儿再退出
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
    }
    exit(0)
}

// Parse arguments
var title = "Claude Code"
var message = "Task completed"
var sound: String? = "Glass"
var soundFile: String? = nil
var projectPath: String? = nil
var projectName: String? = nil
var hostBundleId: String? = nil
var tty: String? = nil

var args = ArraySlice(rawArgs)
while let arg = args.popFirst() {
    if arg.hasPrefix("-psn_") {
        continue
    }

    switch arg {
    case "-t", "--title":
        if let val = args.popFirst() { title = val }
    case "-m", "--message":
        if let val = args.popFirst() { message = val }
    case "-s", "--sound":
        if let val = args.popFirst() { sound = val }
    case "-f", "--sound-file":
        if let val = args.popFirst() { soundFile = val }
    case "--no-sound":
        sound = nil
    case "--project-path":
        if let val = args.popFirst() { projectPath = val }
    case "--project-name":
        if let val = args.popFirst() { projectName = val }
    case "--host-bundle-id":
        if let val = args.popFirst() { hostBundleId = val }
    case "--tty":
        if let val = args.popFirst() { tty = val }
    case "-h", "--help":
        print("""
        ClaudeNotifier - Send macOS notifications with Claude icon

        Usage: ClaudeNotifier [options]

        Options:
          -t, --title <text>       Notification title (default: "Claude Code")
          -m, --message <text>     Notification message (default: "Task completed")
          -s, --sound <name>       System sound name (default: "Glass")
          -f, --sound-file <path>  Custom sound file (.aiff, .wav, .caf, .m4a)
          --project-path <path>    Full project path
          --project-name <name>    Project folder name
          --host-bundle-id <id>    Host app bundle ID (e.g., dev.zed.Zed)
          --tty <tty>              Terminal tty path (e.g., /dev/ttys003)
          --no-sound               Disable notification sound
          -h, --help               Show this help

        System sounds: Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse,
                       Ping, Pop, Purr, Sosumi, Submarine, Tink

        Custom sounds: Files are copied to ~/Library/Sounds/ automatically.
                       Sound files must be < 30 seconds.

        Examples:
          ClaudeNotifier -t "Done" -m "Build completed"
          ClaudeNotifier -s Hero
          ClaudeNotifier -f ~/Music/notification.aiff
          ClaudeNotifier -t "Done" -m "Build completed" --host-bundle-id dev.zed.Zed --project-name myproj --project-path /path/to/myproj
        """)
        exit(0)
    default:
        break
    }
}

var userInfo: [AnyHashable: Any] = [:]
if let projectPath, !projectPath.isEmpty { userInfo[NotificationUserInfoKey.projectPath] = projectPath }
if let projectName, !projectName.isEmpty { userInfo[NotificationUserInfoKey.projectName] = projectName }
if let hostBundleId, !hostBundleId.isEmpty { userInfo[NotificationUserInfoKey.hostBundleId] = hostBundleId }
if let tty, !tty.isEmpty { userInfo[NotificationUserInfoKey.tty] = tty }

sendNotification(title: title, message: message, sound: sound, soundFile: soundFile, userInfo: userInfo)

// 如果有焦点跳转参数，使用 NSApplication 事件循环等待用户点击
// 只有 NSApplication.run() 才能正确接收通知点击回调
// 用户点击后 didReceive 会调用 exit(0)
if hostBundleId != nil && !hostBundleId!.isEmpty {
    let app = NSApplication.shared
    // 设置为 accessory 类型，不在 Dock 显示图标
    app.setActivationPolicy(.accessory)

    // 设置超时定时器，60秒后自动退出
    DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
        fputs("[DEBUG] Timeout reached, exiting...\n", stderr)
        exit(0)
    }

    fputs("[DEBUG] Starting NSApplication run loop, waiting for notification click...\n", stderr)
    app.run()
} else {
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
}
