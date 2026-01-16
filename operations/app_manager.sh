#!/bin/bash

################################################################################
# Shell Collections 应用管理工具
# 支持查看、启动、停止、重启已安装的应用
# 支持应用: Flink, Spark, Doris, MongoDB, MySQL, PostgreSQL, Redis,
#          RabbitMQ, Nginx, Minio 等
#
# 使用方法:
#   sudo bash app_manager.sh [应用名称]
#   sudo bash app_manager.sh                 # 交互模式
#
# 作者: Shell Collections Team
# 版本: 1.0.0
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 应用配置
declare -A APP_COMMANDS=(
    [flink]="systemctl"
    [spark]="systemctl"
    [doris]="custom"
    [mongodb]="systemctl"
    [mysql]="systemctl"
    [postgresql]="systemctl"
    [redis]="systemctl"
    [rabbitmq]="systemctl"
    [nginx]="systemctl"
    [docker]="systemctl"
    [minio]="systemctl"
)

declare -A APP_PORTS=(
    [flink]="8081"
    [spark]="8080"
    [doris]="8030"
    [mongodb]="27017"
    [mysql]="3306"
    [postgresql]="5432"
    [redis]="6379"
    [rabbitmq]="5672,15672"
    [nginx]="80,443"
    [docker]="N/A"
    [minio]="9000,9001"
)

declare -A APP_PROCESSES=(
    [flink]="JobManager|TaskManager"
    [spark]="org.apache.spark"
    [doris]="PaloFE|palo_be"
    [mongodb]="mongod"
    [mysql]="mysqld"
    [postgresql]="postgres"
    [redis]="redis-server"
    [rabbitmq]="beam"
    [nginx]="nginx"
    [docker]="dockerd"
    [minio]="minio"
)

# 显示标题
print_header() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║        Shell Collections 应用管理工具 v1.0.0             ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 显示支持的应用列表
show_supported_apps() {
    echo -e "${BLUE}支持的应用:${NC}"
    local i=1
    local -a apps=()

    # 获取所有应用名称并排序
    for app in "${!APP_COMMANDS[@]}"; do
        apps+=("$app")
    done

    # 排序应用名称
    IFS=$'\n' sorted_apps=($(sort <<<"${apps[*]}"))
    unset IFS

    for app in "${sorted_apps[@]}"; do
        printf "  %2d) %-15s (端口: %s)\n" $i "$app" "${APP_PORTS[$app]}"
        ((i++))
    done
}

# 检查应用是否运行
check_app_running() {
    local app=$1
    local process_pattern="${APP_PROCESSES[$app]}"

    if pgrep -f "$process_pattern" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 显示应用状态
show_app_status() {
    local app=$1

    echo ""
    log_info "$app 应用状态:"
    echo ""

    if check_app_running "$app"; then
        log_success "$app: 运行中 ✅"

        # 显示运行进程
        echo ""
        log_info "运行中的进程:"
        ps aux | grep -E "${APP_PROCESSES[$app]}" | grep -v grep | while read line; do
            echo "  $line"
        done | head -3

    else
        log_warn "$app: 已停止 ⚠️"
    fi

    # 显示端口信息
    echo ""
    log_info "配置端口: ${APP_PORTS[$app]}"

    # 检查 systemd 服务
    if systemctl is-active --quiet "$app" 2>/dev/null; then
        log_success "Systemd服务: 已启用并运行中"
    elif systemctl is-enabled --quiet "$app" 2>/dev/null; then
        log_info "Systemd服务: 已启用但未运行"
    fi

    echo ""
}

# 启动应用
start_app() {
    local app=$1

    log_info "启动 $app..."

    if systemctl start "$app" 2>/dev/null; then
        sleep 2
        if check_app_running "$app"; then
            log_success "$app 已启动 ✅"
            return 0
        else
            log_error "$app 启动失败"
            return 1
        fi
    else
        log_error "无法通过 systemctl 启动 $app"
        return 1
    fi
}

# 停止应用
stop_app() {
    local app=$1

    log_info "停止 $app..."

    if systemctl stop "$app" 2>/dev/null; then
        log_success "$app 已停止 ✅"
        return 0
    else
        log_warn "停止 $app 失败或服务未运行"
        return 1
    fi
}

# 重启应用
restart_app() {
    local app=$1

    log_info "重启 $app..."

    if systemctl restart "$app" 2>/dev/null; then
        sleep 2
        if check_app_running "$app"; then
            log_success "$app 已重启 ✅"
            return 0
        else
            log_error "$app 重启失败"
            return 1
        fi
    else
        log_error "重启 $app 失败"
        return 1
    fi
}

# 查看日志
view_logs() {
    local app=$1

    log_info "显示 $app 日志 (最后 50 行):"
    echo ""

    # 尝试查看 systemd 日志
    if command -v journalctl &>/dev/null; then
        journalctl -u "$app" -n 50 --no-pager 2>/dev/null || {
            log_warn "无法通过 journalctl 获取日志"
        }
    else
        log_warn "journalctl 命令不可用"
    fi
}

# 应用管理菜单
manage_app() {
    local app=$1

    while true; do
        echo ""
        log_info "$app 管理菜单"
        echo ""
        echo -e "  ${GREEN}1${NC}) 查看状态"
        echo -e "  ${GREEN}2${NC}) 启动"
        echo -e "  ${GREEN}3${NC}) 停止"
        echo -e "  ${GREEN}4${NC}) 重启"
        echo -e "  ${GREEN}5${NC}) 查看日志"
        echo -e "  ${RED}0${NC}) 返回"
        echo ""

        read -p "请选择操作 [0-5]: " choice

        case $choice in
            1)
                show_app_status "$app"
                ;;
            2)
                start_app "$app"
                ;;
            3)
                stop_app "$app"
                ;;
            4)
                restart_app "$app"
                ;;
            5)
                view_logs "$app"
                ;;
            0)
                break
                ;;
            *)
                log_error "无效的选择"
                ;;
        esac
    done
}

# 交互模式
interactive_mode() {
    while true; do
        clear
        print_header

        echo -e "${BLUE}请选择要管理的应用:${NC}"
        echo ""

        local i=1
        local -a app_list
        local -a apps=()

        # 获取所有应用名称并排序
        for app in "${!APP_COMMANDS[@]}"; do
            apps+=("$app")
        done

        # 排序应用名称
        IFS=$'\n' sorted_apps=($(sort <<<"${apps[*]}"))
        unset IFS

        for app in "${sorted_apps[@]}"; do
            app_list+=("$app")
            printf "  %2d) %-15s (端口: %s)\n" $i "$app" "${APP_PORTS[$app]}"
            ((i++))
        done

        echo -e "  ${RED}0${NC}) 退出"
        echo ""

        read -p "请选择 [0-$((${#app_list[@]}))]: " choice

        if [ "$choice" = "0" ]; then
            break
        fi

        if [ "$choice" -ge 1 ] && [ "$choice" -le "${#app_list[@]}" ]; then
            local selected_app="${app_list[$((choice - 1))]}"
            manage_app "$selected_app"
        else
            log_error "无效的选择"
            read -p "按 Enter 继续..."
        fi
    done
}

# 主函数
main() {
    # 检查 root 权限
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        exit 1
    fi

    print_header

    if [ -z "$1" ]; then
        # 交互模式
        interactive_mode
    else
        # 命令行模式
        local app="$1"
        local app_lower=$(echo "$app" | tr '[:upper:]' '[:lower:]')

        if [ -z "${APP_COMMANDS[$app_lower]}" ]; then
            log_error "不支持的应用: $app"
            echo ""
            show_supported_apps
            exit 1
        fi

        # 如果指定了操作，执行该操作
        case "${2:-status}" in
            start)
                start_app "$app_lower"
                ;;
            stop)
                stop_app "$app_lower"
                ;;
            restart)
                restart_app "$app_lower"
                ;;
            status)
                show_app_status "$app_lower"
                ;;
            logs)
                view_logs "$app_lower"
                ;;
            *)
                log_error "无效的操作: $2"
                echo "支持的操作: start, stop, restart, status, logs"
                exit 1
                ;;
        esac
    fi
}

main "$@"