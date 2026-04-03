#!/bin/bash

################################################################################
# 监控任务配置管理脚本 v1.0.0
# 功能: 交互式添加/删除/查看/测试监控任务，管理 crontab 定时任务
################################################################################

MONITOR_DIR="/etc/ant-eyes/monitor"
MONITOR_CONF="$MONITOR_DIR/monitors.conf"
EMAIL_CONF="$MONITOR_DIR/email.conf"
MONITOR_SCRIPT="$MONITOR_DIR/monitor.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

check_init() {
    if [[ ! -f "$MONITOR_CONF" ]]; then
        log_error "监控系统未初始化，请先运行: bash install_monitor.sh"
        exit 1
    fi
}

load_conf() {
    # shellcheck source=/dev/null
    source "$MONITOR_CONF"
    MONITOR_COUNT="${MONITOR_COUNT:-0}"
}

save_monitor() {
    local id="$1"
    shift
    local name="$1" url="$2" method="$3" body="$4" headers="$5"
    local expect="$6" timeout="$7" interval="$8" email="$9" retry="${10}" enabled="${11}"

    # 更新对应 ID 的配置行（先删除旧的，再追加新的）
    local tmp
    tmp=$(mktemp)
    grep -v "^MONITOR_${id}_" "$MONITOR_CONF" > "$tmp" || true
    cat >> "$tmp" <<EOF
MONITOR_${id}_NAME=$name
MONITOR_${id}_URL=$url
MONITOR_${id}_METHOD=$method
MONITOR_${id}_BODY=$body
MONITOR_${id}_HEADERS=$headers
MONITOR_${id}_EXPECT=$expect
MONITOR_${id}_TIMEOUT=$timeout
MONITOR_${id}_INTERVAL=$interval
MONITOR_${id}_EMAIL=$email
MONITOR_${id}_RETRY=$retry
MONITOR_${id}_ENABLED=$enabled
EOF
    mv "$tmp" "$MONITOR_CONF"
    chmod 600 "$MONITOR_CONF"
}

update_count() {
    local count="$1"
    local tmp
    tmp=$(mktemp)
    grep -v "^MONITOR_COUNT=" "$MONITOR_CONF" > "$tmp" || true
    echo "MONITOR_COUNT=$count" >> "$tmp"
    mv "$tmp" "$MONITOR_CONF"
    chmod 600 "$MONITOR_CONF"
}

# 添加 crontab 定时任务
add_crontab() {
    local id="$1"
    local interval="$2"
    local cron_comment="ant-eyes-monitor-${id}"

    # 先删除旧的同 ID crontab
    remove_crontab "$id"

    local cron_expr
    if [[ "$interval" -eq 1 ]]; then
        cron_expr="* * * * *"
    else
        cron_expr="*/${interval} * * * *"
    fi

    (crontab -l 2>/dev/null; echo "${cron_expr} bash $MONITOR_SCRIPT $id >> $MONITOR_DIR/monitor.log 2>&1 # $cron_comment") | crontab -
    log_success "定时任务已添加（每 ${interval} 分钟执行一次）"
}

# 删除 crontab 定时任务
remove_crontab() {
    local id="$1"
    local cron_comment="ant-eyes-monitor-${id}"
    local tmp
    tmp=$(mktemp)
    crontab -l 2>/dev/null | grep -v "# $cron_comment" > "$tmp" || true
    crontab "$tmp"
    rm -f "$tmp"
}

# 添加监控任务
add_monitor() {
    load_conf
    echo ""
    echo -e "${CYAN}=== 添加监控任务 ===${NC}"
    echo ""

    read -p "监控名称（如: 用户登录接口）: " name
    while [[ -z "$name" ]]; do
        log_error "名称不能为空"; read -p "监控名称: " name
    done

    read -p "监控 URL（如: https://api.example.com/health）: " url
    while [[ -z "$url" ]]; do
        log_error "URL 不能为空"; read -p "监控 URL: " url
    done

    echo "HTTP 方法 [1] GET  [2] POST  [3] PUT  [4] DELETE"
    read -p "请选择 [1]: " method_choice
    case "$method_choice" in
        2) method="POST" ;;
        3) method="PUT" ;;
        4) method="DELETE" ;;
        *) method="GET" ;;
    esac

    body=""
    headers=""
    if [[ "$method" == "POST" || "$method" == "PUT" ]]; then
        echo ""
        echo -e "${YELLOW}请求体配置（POST/PUT）${NC}"
        read -p "请求体类型 [1] JSON  [2] Form表单: " body_type
        read -p "请求体内容（如: {\"username\":\"admin\",\"password\":\"123\"}）: " body

        # 自动补充 Content-Type header
        if [[ "$body_type" == "2" ]]; then
            headers="Content-Type: application/x-www-form-urlencoded"
        fi
        # JSON 时 monitor.sh 会自动识别并添加 Content-Type: application/json
    fi

    echo ""
    read -p "自定义请求头（多个用 || 分隔，如: Authorization: Bearer xxx||X-App-Id: 1，留空跳过）: " extra_headers
    if [[ -n "$extra_headers" ]]; then
        [[ -n "$headers" ]] && headers="${headers}||${extra_headers}" || headers="$extra_headers"
    fi

    read -p "期望 HTTP 状态码 [200]: " expect
    expect="${expect:-200}"

    read -p "超时时间（秒）[10]: " timeout
    timeout="${timeout:-10}"

    read -p "监控间隔（分钟）[5]: " interval
    interval="${interval:-5}"

    read -p "预警邮箱（多个用逗号分隔）: " email
    while [[ -z "$email" ]]; do
        log_error "预警邮箱不能为空"; read -p "预警邮箱: " email
    done

    read -p "连续失败几次后发预警 [2]: " retry
    retry="${retry:-2}"

    echo ""
    echo -e "${YELLOW}请确认配置:${NC}"
    echo "  名称: $name"
    echo "  URL:  $url"
    echo "  方法: $method"
    [[ -n "$body" ]] && echo "  请求体: $body"
    [[ -n "$headers" ]] && echo "  请求头: $headers"
    echo "  期望状态码: $expect"
    echo "  超时: ${timeout}s"
    echo "  监控间隔: ${interval}分钟"
    echo "  预警邮箱: $email"
    echo "  失败阈值: ${retry}次"
    echo ""

    read -p "确认保存？(y/n): " -n 1 -r; echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && log_warn "已取消" && return

    local new_id=$(( MONITOR_COUNT + 1 ))
    save_monitor "$new_id" "$name" "$url" "$method" "$body" "$headers" \
        "$expect" "$timeout" "$interval" "$email" "$retry" "true"
    update_count "$new_id"
    add_crontab "$new_id" "$interval"

    log_success "监控任务 [$name] 已添加（ID: $new_id）"
}

# 列出所有监控任务
list_monitors() {
    load_conf
    echo ""
    echo -e "${CYAN}=== 监控任务列表 ===${NC}"
    echo ""

    if [[ "$MONITOR_COUNT" -eq 0 ]]; then
        log_warn "暂无监控任务"
        return
    fi

    printf "%-4s %-20s %-8s %-8s %-40s %-8s\n" "ID" "名称" "方法" "状态" "URL" "间隔"
    echo "────────────────────────────────────────────────────────────────────────────────"
    for (( i=1; i<=MONITOR_COUNT; i++ )); do
        local name method url enabled interval
        eval "name=\$MONITOR_${i}_NAME"
        eval "method=\$MONITOR_${i}_METHOD"
        eval "url=\$MONITOR_${i}_URL"
        eval "enabled=\$MONITOR_${i}_ENABLED"
        eval "interval=\$MONITOR_${i}_INTERVAL"
        [[ -z "$name" ]] && continue

        method="${method:-GET}"
        local status_str
        [[ "$enabled" == "true" ]] && status_str="${GREEN}启用${NC}" || status_str="${RED}禁用${NC}"

        # URL 截断显示
        local url_short="${url:0:40}"
        [[ ${#url} -gt 40 ]] && url_short="${url_short}..."

        printf "%-4s %-20s %-8s " "$i" "$name" "$method"
        echo -e "${status_str}  $(printf '%-40s %-8s' "$url_short" "${interval}分钟")"
    done
    echo ""
}

# 测试监控任务
test_monitor() {
    load_conf
    list_monitors

    read -p "请输入要测试的监控 ID: " id
    if [[ -z "$id" || $id -lt 1 || $id -gt $MONITOR_COUNT ]]; then
        log_error "无效的 ID"; return 1
    fi

    local name; eval "name=\$MONITOR_${id}_NAME"
    log_info "立即测试: [$name]"
    bash "$MONITOR_SCRIPT" "$id"
}

# 启用/禁用监控任务
toggle_monitor() {
    load_conf
    list_monitors

    read -p "请输入要操作的监控 ID: " id
    if [[ -z "$id" || $id -lt 1 || $id -gt $MONITOR_COUNT ]]; then
        log_error "无效的 ID"; return 1
    fi

    local name enabled interval
    eval "name=\$MONITOR_${id}_NAME"
    eval "enabled=\$MONITOR_${id}_ENABLED"
    eval "interval=\$MONITOR_${id}_INTERVAL"

    if [[ "$enabled" == "true" ]]; then
        # 禁用：更新配置 + 删除 crontab
        local tmp; tmp=$(mktemp)
        sed "s/^MONITOR_${id}_ENABLED=.*/MONITOR_${id}_ENABLED=false/" "$MONITOR_CONF" > "$tmp"
        mv "$tmp" "$MONITOR_CONF"; chmod 600 "$MONITOR_CONF"
        remove_crontab "$id"
        log_success "[$name] 已禁用"
    else
        # 启用：更新配置 + 添加 crontab
        local tmp; tmp=$(mktemp)
        sed "s/^MONITOR_${id}_ENABLED=.*/MONITOR_${id}_ENABLED=true/" "$MONITOR_CONF" > "$tmp"
        mv "$tmp" "$MONITOR_CONF"; chmod 600 "$MONITOR_CONF"
        add_crontab "$id" "${interval:-5}"
        log_success "[$name] 已启用"
    fi
}

# 删除监控任务
delete_monitor() {
    load_conf
    list_monitors

    read -p "请输入要删除的监控 ID: " id
    if [[ -z "$id" || $id -lt 1 || $id -gt $MONITOR_COUNT ]]; then
        log_error "无效的 ID"; return 1
    fi

    local name; eval "name=\$MONITOR_${id}_NAME"
    read -p "确认删除 [$name]？(y/n): " -n 1 -r; echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && log_warn "已取消" && return

    # 删除配置行
    local tmp; tmp=$(mktemp)
    grep -v "^MONITOR_${id}_" "$MONITOR_CONF" > "$tmp" || true
    mv "$tmp" "$MONITOR_CONF"; chmod 600 "$MONITOR_CONF"

    # 删除 crontab
    remove_crontab "$id"

    # 清理状态文件
    rm -f "$MONITOR_DIR/state/fail_${id}" "$MONITOR_DIR/state/cooldown_${id}"

    log_success "监控任务 [$name] 已删除"
}

# 查看监控日志
view_log() {
    if [[ ! -f "$MONITOR_DIR/monitor.log" ]]; then
        log_warn "暂无日志"
        return
    fi
    echo ""
    echo -e "${CYAN}=== 最近 50 条监控日志 ===${NC}"
    tail -50 "$MONITOR_DIR/monitor.log"
    echo ""
}

# 更新邮件配置
update_email() {
    echo ""
    echo -e "${CYAN}=== 当前邮件配置 ===${NC}"
    if [[ -f "$EMAIL_CONF" ]]; then
        grep -v "^#\|^$\|PASSWORD" "$EMAIL_CONF" || true
        echo "  SMTP_PASSWORD=******"
    else
        log_warn "邮件配置文件不存在"
    fi
    echo ""
    read -p "是否重新配置邮件？(y/n): " -n 1 -r; echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && return

    read -p "SMTP 服务器 [smtp.163.com]: " smtp_host
    smtp_host="${smtp_host:-smtp.163.com}"
    read -p "SMTP 端口 [465]: " smtp_port
    smtp_port="${smtp_port:-465}"
    read -p "发件人邮箱: " smtp_user
    read -s -p "邮箱授权码: " smtp_password; echo
    read -p "发件人名称 [ant-eyes监控]: " smtp_from_name
    smtp_from_name="${smtp_from_name:-ant-eyes监控}"

    cat > "$EMAIL_CONF" <<EOF
SMTP_HOST=$smtp_host
SMTP_PORT=$smtp_port
SMTP_SECURE=true
SMTP_USER=$smtp_user
SMTP_PASSWORD=$smtp_password
SMTP_FROM_NAME=$smtp_from_name
SMTP_FROM_EMAIL=$smtp_user
EOF
    chmod 600 "$EMAIL_CONF"
    log_success "邮件配置已更新"
}

# 主菜单
main_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}╔══════════════════════════════════╗${NC}"
        echo -e "${CYAN}║      ant-eyes 监控管理           ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════╝${NC}"
        echo ""
        echo "  [1] 查看所有监控任务"
        echo "  [2] 添加监控任务"
        echo "  [3] 测试监控任务（立即执行一次）"
        echo "  [4] 启用/禁用监控任务"
        echo "  [5] 删除监控任务"
        echo "  [6] 查看监控日志"
        echo "  [7] 修改邮件配置"
        echo "  [0] 退出"
        echo ""
        read -p "请选择 [0-7]: " choice

        case "$choice" in
            1) list_monitors ;;
            2) add_monitor ;;
            3) test_monitor ;;
            4) toggle_monitor ;;
            5) delete_monitor ;;
            6) view_log ;;
            7) update_email ;;
            0) log_info "再见！"; exit 0 ;;
            *) log_warn "无效选项" ;;
        esac
    done
}

check_init
main_menu