#!/bin/bash
# Example: Claude Code stop hook with ClaudeNotifier integration
# Place this in ~/.claude/hooks/stop-check.sh

set -euo pipefail

# Send notification using ClaudeNotifier (with osascript fallback)
send_notification() {
    local title="Claude Code"
    local message="Claude 已完成回答"
    local notifier="$HOME/.claude/apps/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier"

    if [[ -x "$notifier" ]]; then
        "$notifier" -t "$title" -m "$message" 2>/dev/null || \
        osascript -e "display notification \"$message\" with title \"$title\" sound name \"Glass\"" 2>/dev/null || true
    else
        osascript -e "display notification \"$message\" with title \"$title\" sound name \"Glass\"" 2>/dev/null || true
    fi
}

# Main logic
main() {
    # Add your stop-check logic here
    # Example: check if todos are completed

    # Send notification when task completes
    send_notification

    # Output decision
    echo '{"decision": "approve"}'
}

main "$@"
