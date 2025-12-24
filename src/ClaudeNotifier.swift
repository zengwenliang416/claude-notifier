import Foundation
import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

func sendNotification(title: String, message: String, sound: String) {
    let center = UNUserNotificationCenter.current()
    let delegate = NotificationDelegate()
    center.delegate = delegate

    let semaphore = DispatchSemaphore(value: 0)

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
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: sound))

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

// Parse arguments
var title = "Claude Code"
var message = "Task completed"
var sound = "Glass"

var args = CommandLine.arguments.dropFirst()
while let arg = args.popFirst() {
    switch arg {
    case "-t", "--title":
        if let val = args.popFirst() { title = val }
    case "-m", "--message":
        if let val = args.popFirst() { message = val }
    case "-s", "--sound":
        if let val = args.popFirst() { sound = val }
    case "-h", "--help":
        print("""
        ClaudeNotifier - Send macOS notifications with Claude icon

        Usage: ClaudeNotifier [options]

        Options:
          -t, --title <text>    Notification title (default: "Claude Code")
          -m, --message <text>  Notification message (default: "Task completed")
          -s, --sound <name>    Sound name (default: "Glass")
          -h, --help            Show this help
        """)
        exit(0)
    default:
        break
    }
}

sendNotification(title: title, message: message, sound: sound)
RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
