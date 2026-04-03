#!/bin/bash

################################################################################
# 监控预警核心脚本 v1.0.0
# 功能: 读取配置、执行 curl 检查、失败计数、发送邮件预警、恢复通知
# 用法: bash monitor.sh [monitor_id]  （不指定则检查所有）
################################################################################

MONITOR_DIR="/etc/ant-eyes/monitor"
MONITOR_CONF="$MONITOR_DIR/monitors.conf"
EMAIL_CONF="$MONITOR_DIR/email.conf"
STATE_DIR="$MONITOR_DIR/state"
LOG_FILE="$MONITOR_DIR/monitor.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

write_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 加载邮件配置
load_email_conf() {
    if [[ ! -f "$EMAIL_CONF" ]]; then
        log_error "邮件配置不存在: $EMAIL_CONF"
        return 1
    fi
    # shellcheck source=/dev/null
    source "$EMAIL_CONF"
}

# 发送邮件（使用 curl + SMTP）
send_email() {
    local to="$1"
    local subject="$2"
    local body="$3"

    load_email_conf || return 1

    local mail_tmp
    mail_tmp=$(mktemp /tmp/monitor_mail_XXXXXX.txt)

    cat > "$mail_tmp" <<EOF
From: $SMTP_FROM_NAME <$SMTP_FROM_EMAIL>
To: $to
Subject: $subject
Content-Type: text/plain; charset=UTF-8

$body
EOF

    local protocol="smtps"
    [[ "$SMTP_SECURE" != "true" ]] && protocol="smtp"

    local result
    result=$(curl -s --url "${protocol}://${SMTP_HOST}:${SMTP_PORT}" \
        --ssl-reqd \
        --mail-from "$SMTP_FROM_EMAIL" \
        --mail-rcpt "$to" \
        --user "${SMTP_USER}:${SMTP_PASSWORD}" \
        --upload-file "$mail_tmp" \
        2>&1)
    local exit_code=$?

    rm -f "$mail_tmp"

    if [[ $exit_code -eq 0 ]]; then
        write_log "邮件发送成功 -> $to: $subject"
        return 0
    else
        write_log "邮件发送失败 -> $to: $result"
        return 1
    fi
}

# 执行接口检查，返回 HTTP 状态码
check_endpoint() {
    local url="$1"
    local method="$2"
    local body="$3"
    local headers="$4"
    local timeout="$5"

    local curl_args=(-s -o /dev/null -w "%{http_code}" --max-time "$timeout" -X "$method")

    # 添加自定义请求头（多个用 || 分隔）
    if [[ -n "$headers" ]]; then
        IFS='||' read -ra header_list <<< "$headers"
        for h in "${header_list[@]}"; do
            h=$(echo "$h" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [[ -n "$h" ]] && curl_args+=(-H "$h")
        done
    fi

    # POST/PUT 添加请求体
    if [[ "$method" == "POST" || "$method" == "PUT" ]] && [[ -n "$body" ]]; then
        # 自动识别 JSON 格式并设置 Content-Type
        if echo "$body" | grep -q '^\s*{'; then
            curl_args+=(-H "Content-Type: application/json")
        fi
        curl_args+=(--data "$body")
    fi

    curl_args+=("$url")

    curl "${curl_args[@]}" 2>/dev/null || echo "000"
}

# 获取失败计数
get_fail_count() {
    local id="$1"
    local state_file="$STATE_DIR/fail_${id}"
    [[ -f "$state_file" ]] && cat "$state_file" || echo "0"
}

# 设置失败计数
set_fail_count() {
    local id="$1"
    local count="$2"
    echo "$count" > "$STATE_DIR/fail_${id}"
}

# 检查是否处于预警冷却期（1小时内已发送过预警）
in_cooldown() {
    local id="$1"
    local cooldown_file="$STATE_DIR/cooldown_${id}"
    if [[ -f "$cooldown_file" ]]; then
        local last_alert
        last_alert=$(cat "$cooldown_file")
        local now
        now=$(date +%s)
        local diff=$(( now - last_alert ))
        [[ $diff -lt 3600 ]] && return 0
    fi
    return 1
}

# 设置预警冷却时间戳
set_cooldown() {
    local id="$1"
    date +%s > "$STATE_DIR/cooldown_${id}"
}

# 清除冷却标记
clear_cooldown() {
    local id="$1"
    rm -f "$STATE_DIR/cooldown_${id}"
}

# 检查上次是否为异常状态（用于恢复通知）
was_failed() {
    local id="$1"
    local count
    count=$(get_fail_count "$id")
    [[ "$count" -gt 0 ]]
}

# 检查单个监控任务
check_monitor() {
    local id="$1"

    # 读取配置
    local name method url body headers expect timeout retry email enabled
    eval "name=\$MONITOR_${id}_NAME"
    eval "method=\$MONITOR_${id}_METHOD"
    eval "url=\$MONITOR_${id}_URL"
    eval "body=\$MONITOR_${id}_BODY"
    eval "headers=\$MONITOR_${id}_HEADERS"
    eval "expect=\$MONITOR_${id}_EXPECT"
    eval "timeout=\$MONITOR_${id}_TIMEOUT"
    eval "retry=\$MONITOR_${id}_RETRY"
    eval "email=\$MONITOR_${id}_EMAIL"
    eval "enabled=\$MONITOR_${id}_ENABLED"

    # 默认值
    method="${method:-GET}"
    expect="${expect:-200}"
    timeout="${timeout:-10}"
    retry="${retry:-2}"

    [[ "$enabled" != "true" ]] && return 0
    [[ -z "$url" ]] && return 0

    log_info "检查 [$name] $method $url"
    write_log "检查开始: [$name] $method $url"

    local http_code
    http_code=$(check_endpoint "$url" "$method" "$body" "$headers" "$timeout")

    if [[ "$http_code" == "$expect" ]]; then
        # 检查是否从失败状态恢复
        if was_failed "$id"; then
            write_log "[$name] 接口恢复正常 (状态码: $http_code)"
            log_success "[$name] 恢复正常 (状态码: $http_code)"

            # 发送恢复通知
            IFS=',' read -ra email_list <<< "$email"
            for addr in "${email_list[@]}"; do
                addr=$(echo "$addr" | tr -d ' ')
                [[ -z "$addr" ]] && continue
                local recover_body
                recover_body=$(cat <<EOF
【恢复通知】监控项: $name

接口已恢复正常。

接口地址: $url
请求方式: $method
当前状态码: $http_code
期望状态码: $expect
恢复时间: $(date '+%Y-%m-%d %H:%M:%S')

-- ant-eyes 监控系统
EOF
)
                send_email "$addr" "【恢复】$name 接口已恢复" "$recover_body" || true
            done
        else
            log_success "[$name] 正常 (状态码: $http_code)"
            write_log "[$name] 正常 (状态码: $http_code)"
        fi

        # 重置失败计数和冷却标记
        set_fail_count "$id" 0
        clear_cooldown "$id"

    else
        # 接口异常
        local fail_count
        fail_count=$(get_fail_count "$id")
        fail_count=$(( fail_count + 1 ))
        set_fail_count "$id" "$fail_count"

        log_error "[$name] 异常 (状态码: $http_code，期望: $expect，连续失败: ${fail_count}次)"
        write_log "[$name] 异常 (状态码: $http_code，期望: $expect，连续失败: ${fail_count}次)"

        # 达到失败阈值且不在冷却期才发送预警
        if [[ $fail_count -ge $retry ]] && ! in_cooldown "$id"; then
            set_cooldown "$id"
            write_log "[$name] 触发预警，发送邮件..."

            IFS=',' read -ra email_list <<< "$email"
            for addr in "${email_list[@]}"; do
                addr=$(echo "$addr" | tr -d ' ')
                [[ -z "$addr" ]] && continue
                local alert_body
                alert_body=$(cat <<EOF
【预警通知】监控项: $name

接口连续 ${fail_count} 次检测失败，请及时处理！

接口地址: $url
请求方式: $method
当前状态码: $http_code（期望: $expect）
检测时间: $(date '+%Y-%m-%d %H:%M:%S')
连续失败: ${fail_count} 次

-- ant-eyes 监控系统
EOF
)
                if send_email "$addr" "【预警】$name 接口异常" "$alert_body"; then
                    log_warn "预警邮件已发送至 $addr"
                else
                    log_error "预警邮件发送失败 -> $addr"
                fi
            done
        elif in_cooldown "$id"; then
            write_log "[$name] 处于冷却期，跳过发送预警"
        fi
    fi
}

# 主函数
main() {
    if [[ ! -f "$MONITOR_CONF" ]]; then
        log_error "配置文件不存在: $MONITOR_CONF"
        log_info "请先运行: bash install_monitor.sh"
        exit 1
    fi

    mkdir -p "$STATE_DIR"

    # shellcheck source=/dev/null
    source "$MONITOR_CONF"

    local target_id="${1:-}"
    local count="${MONITOR_COUNT:-0}"

    if [[ $count -eq 0 ]]; then
        log_warn "暂无监控任务，请先添加"
        exit 0
    fi

    if [[ -n "$target_id" ]]; then
        check_monitor "$target_id"
    else
        for (( i=1; i<=count; i++ )); do
            check_monitor "$i"
        done
    fi
}

main "$@"
