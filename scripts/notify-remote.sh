#!/bin/bash
# Claude Notifier - 多渠道远程推送脚本 (Phase 0 MVP)
# 用法: ./notify-remote.sh [-t title] [-m message] [-c config]

set -euo pipefail

# 默认值
TITLE="${TITLE:-Claude Code}"
MESSAGE="${MESSAGE:-任务已完成}"
CONFIG_FILE="${CONFIG_FILE:-$HOME/.config/claude-notifier/notifier.toml}"
TIMEOUT=5

# 解析参数
while getopts "t:m:c:h" opt; do
    case $opt in
        t) TITLE="$OPTARG" ;;
        m) MESSAGE="$OPTARG" ;;
        c) CONFIG_FILE="$OPTARG" ;;
        h)
            echo "用法: $0 [-t title] [-m message] [-c config]"
            echo "  -t  通知标题 (默认: Claude Code)"
            echo "  -m  通知消息 (默认: 任务已完成)"
            echo "  -c  配置文件路径 (默认: ~/.config/claude-notifier/notifier.toml)"
            exit 0
            ;;
        *) exit 1 ;;
    esac
done

# 辅助函数：从 TOML 读取配置值
get_config() {
    local section=$1
    local key=$2
    local default=${3:-}

    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "$default"
        return
    fi

    # 简单的 TOML 解析（仅支持基本格式）
    local value
    value=$(awk -v section="$section" -v key="$key" '
        /^\[.*\]$/ { current_section = substr($0, 2, length($0)-2) }
        current_section == section && $0 ~ "^"key" *=" {
            gsub(/^[^=]*= *"?/, "")
            gsub(/"? *$/, "")
            gsub(/#.*$/, "")
            print
            exit
        }
    ' "$CONFIG_FILE" 2>/dev/null || echo "")

    # 展开环境变量 (将 ${VAR} 转换为 $VAR 供 envsubst 处理)
    if [[ -n "$value" ]]; then
        value=$(echo "$value" | sed 's/\${\([^}]*\)}/$\1/g' | envsubst)
        echo "$value"
    else
        echo "$default"
    fi
}

# 检查配置节是否启用
is_enabled() {
    local section=$1
    local enabled
    enabled=$(get_config "$section" "enabled" "false")
    [[ "$enabled" == "true" ]]
}

# ============================================================
# ntfy.sh 推送
# ============================================================
send_ntfy() {
    local server topic token priority
    server=$(get_config "ntfy" "server" "https://ntfy.sh")
    topic=$(get_config "ntfy" "topic" "claude-notify")
    token=$(get_config "ntfy" "token" "")
    priority=$(get_config "ntfy" "priority" "3")

    local headers=(-H "Title: $TITLE" -H "Priority: $priority")
    [[ -n "$token" ]] && headers+=(-H "Authorization: Bearer $token")

    curl -s -m "$TIMEOUT" \
        "${headers[@]}" \
        -d "$MESSAGE" \
        "${server}/${topic}" >/dev/null 2>&1 && echo "[ntfy] ✓" || echo "[ntfy] ✗"
}

# ============================================================
# Telegram Bot 推送
# ============================================================
send_telegram() {
    local bot_token chat_id
    bot_token=$(get_config "telegram" "bot_token" "")
    chat_id=$(get_config "telegram" "chat_id" "")

    if [[ -z "$bot_token" || -z "$chat_id" ]]; then
        echo "[telegram] ✗ (missing token or chat_id)"
        return
    fi

    local text="*${TITLE}*"$'\n'"${MESSAGE}"

    curl -s -m "$TIMEOUT" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\":\"$chat_id\",\"text\":\"$text\",\"parse_mode\":\"Markdown\"}" \
        "https://api.telegram.org/bot${bot_token}/sendMessage" >/dev/null 2>&1 && echo "[telegram] ✓" || echo "[telegram] ✗"
}

# ============================================================
# Bark 推送 (iOS)
# ============================================================
send_bark() {
    local server device_key group sound
    server=$(get_config "bark" "server" "https://api.day.app")
    device_key=$(get_config "bark" "device_key" "")
    group=$(get_config "bark" "group" "Claude")
    sound=$(get_config "bark" "sound" "")

    if [[ -z "$device_key" ]]; then
        echo "[bark] ✗ (missing device_key)"
        return
    fi

    # 使用 POST JSON 方式，避免 URL 编码问题
    local payload="{\"title\":\"${TITLE}\",\"body\":\"${MESSAGE}\",\"group\":\"${group}\""
    [[ -n "$sound" ]] && payload="${payload},\"sound\":\"${sound}\""
    payload="${payload}}"

    curl -s -m "$TIMEOUT" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "${server}/${device_key}" >/dev/null 2>&1 && echo "[bark] ✓" || echo "[bark] ✗"
}

# ============================================================
# 飞书 Webhook 推送
# ============================================================
send_feishu() {
    local webhook_url secret
    webhook_url=$(get_config "feishu" "webhook_url" "")
    secret=$(get_config "feishu" "secret" "")

    if [[ -z "$webhook_url" ]]; then
        echo "[feishu] ✗ (missing webhook_url)"
        return
    fi

    local payload
    if [[ -n "$secret" ]]; then
        # 带签名的请求
        local timestamp
        timestamp=$(date +%s)
        local sign_string="${timestamp}\n${secret}"
        local sign
        sign=$(echo -ne "$sign_string" | openssl dgst -sha256 -hmac "$secret" -binary | base64)
        payload="{\"timestamp\":\"$timestamp\",\"sign\":\"$sign\",\"msg_type\":\"text\",\"content\":{\"text\":\"${TITLE}: ${MESSAGE}\"}}"
    else
        payload="{\"msg_type\":\"text\",\"content\":{\"text\":\"${TITLE}: ${MESSAGE}\"}}"
    fi

    curl -s -m "$TIMEOUT" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$webhook_url" >/dev/null 2>&1 && echo "[feishu] ✓" || echo "[feishu] ✗"
}

# ============================================================
# 钉钉 Webhook 推送
# ============================================================
send_dingtalk() {
    local webhook_url secret
    webhook_url=$(get_config "dingtalk" "webhook_url" "")
    secret=$(get_config "dingtalk" "secret" "")

    if [[ -z "$webhook_url" ]]; then
        echo "[dingtalk] ✗ (missing webhook_url)"
        return
    fi

    if [[ -n "$secret" ]]; then
        local timestamp
        timestamp=$(($(date +%s) * 1000))
        local sign_string="${timestamp}\n${secret}"
        local sign
        sign=$(echo -ne "$sign_string" | openssl dgst -sha256 -hmac "$secret" -binary | base64 | sed 's/+/%2B/g; s/\//%2F/g; s/=/%3D/g')
        webhook_url="${webhook_url}&timestamp=${timestamp}&sign=${sign}"
    fi

    curl -s -m "$TIMEOUT" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"msgtype\":\"text\",\"text\":{\"content\":\"${TITLE}: ${MESSAGE}\"}}" \
        "$webhook_url" >/dev/null 2>&1 && echo "[dingtalk] ✓" || echo "[dingtalk] ✗"
}

# ============================================================
# 企业微信 Webhook 推送
# ============================================================
send_wecom() {
    local webhook_url
    webhook_url=$(get_config "wecom" "webhook_url" "")

    if [[ -z "$webhook_url" ]]; then
        echo "[wecom] ✗ (missing webhook_url)"
        return
    fi

    curl -s -m "$TIMEOUT" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"msgtype\":\"text\",\"text\":{\"content\":\"${TITLE}: ${MESSAGE}\"}}" \
        "$webhook_url" >/dev/null 2>&1 && echo "[wecom] ✓" || echo "[wecom] ✗"
}

# ============================================================
# 主逻辑
# ============================================================
main() {
    local sent=0

    # 检查配置文件
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "配置文件不存在: $CONFIG_FILE"
        echo "请运行: mkdir -p ~/.config/claude-notifier && cp config/notifier.example.toml ~/.config/claude-notifier/notifier.toml"
        exit 1
    fi

    echo "📤 发送通知: $TITLE - $MESSAGE"

    # 并行发送所有启用的渠道
    local pids=()

    if is_enabled "ntfy"; then
        send_ntfy &
        pids+=($!)
        ((sent++)) || true
    fi

    if is_enabled "telegram"; then
        send_telegram &
        pids+=($!)
        ((sent++)) || true
    fi

    if is_enabled "bark"; then
        send_bark &
        pids+=($!)
        ((sent++)) || true
    fi

    if is_enabled "feishu"; then
        send_feishu &
        pids+=($!)
        ((sent++)) || true
    fi

    if is_enabled "dingtalk"; then
        send_dingtalk &
        pids+=($!)
        ((sent++)) || true
    fi

    if is_enabled "wecom"; then
        send_wecom &
        pids+=($!)
        ((sent++)) || true
    fi

    # 等待所有后台任务完成
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    if [[ $sent -eq 0 ]]; then
        echo "⚠️  没有启用任何推送渠道，请编辑 $CONFIG_FILE"
    fi
}

main
