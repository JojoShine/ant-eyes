#!/bin/bash

################################################################################
# ant-eyes - NTP/Chrony时间同步管理模块
# 功能：管理时间同步服务，同步系统时间
################################################################################

# 加载共享函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# ============================================================================
# 时间同步管理
# ============================================================================

show_time_status() {
    print_header "系统时间同步状态"

    print_subheader "当前系统时间"
    local current_time=$(date '+%Y-%m-%d %H:%M:%S %Z')
    print_table_two_col "属性" "值" \
        "系统时间" "$current_time"

    print_subheader "时间同步服务"

    # 检查NTP
    if command_exists ntpq; then
        local ntp_status="未运行"
        if systemctl is-active ntp 2>/dev/null | grep -q active; then
            ntp_status="运行中"
            print_success "NTP服务运行中"
            print_info "NTP同步源:"
            ntpq -p 2>/dev/null | head -5 | tail -n +3 | while read -r line; do
                print_info "  $line"
            done
        else
            print_warning "NTP服务未运行"
        fi
    fi

    # 检查Chrony
    if command_exists chronyc; then
        local chrony_status="未运行"
        if systemctl is-active chronyd 2>/dev/null | grep -q active; then
            chrony_status="运行中"
            print_success "Chrony服务运行中"
            print_info "Chrony同步源:"
            chronyc sources 2>/dev/null | head -3 | tail -n +2 | while read -r line; do
                print_info "  $line"
            done
        else
            print_warning "Chrony服务未运行"
        fi
    fi

    # 检查timedatectl
    if command_exists timedatectl; then
        print_subheader "系统时间同步信息"
        timedatectl | while read -r line; do
            print_info "  $line"
        done
    fi
}

sync_time() {
    print_header "同步系统时间"
    
    if [ $(id -u) -ne 0 ]; then
        print_error "需要root权限执行此操作"
        return 1
    fi
    
    if command_exists timedatectl; then
        timedatectl set-ntp true
        print_success "已启用NTP时间同步"
    elif command_exists ntpdate; then
        ntpdate -u pool.ntp.org
        print_success "时间同步完成"
    else
        print_error "无法找到时间同步工具"
    fi
}

show_menu() {
    print_header "时间同步管理"
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}请选择操作:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}) 查看时间同步状态"
    echo -e "  ${GREEN}2${NC}) 同步系统时间"
    echo -e "  ${RED}0${NC}) 返回"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

main() {
    if [ "$QUIET" -eq 1 ]; then
        show_time_status
        return
    fi
    
    show_menu
    
    read -p "请选择 [0-2]: " choice
    
    case $choice in
        1) show_time_status ;;
        2) sync_time ;;
        0) print_info "返回主菜单" ;;
        *) print_error "无效选择" ;;
    esac
}

main "$@"
