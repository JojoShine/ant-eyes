#!/bin/bash

################################################################################
# ant-eyes - NTP/Chrony时间同步管理模块
# 功能：检查时间同步状态、配置NTP服务器、调整系统时间
################################################################################

# 加载共享函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# ============================================================================
# 时间同步管理
# ============================================================================

manage_time_sync() {
    print_header "NTP/Chrony时间同步管理"

    # 显示主线流程说明
    print_subheader "时间同步工作流程"
    cat << 'EOF'
系统时间同步的完整流程：

【时间同步设置流程】
1️⃣  检查当前状态 → 了解系统是否已同步时间
2️⃣  选择同步方案 → NTP或Chrony (建议用Chrony)
3️⃣  手动同步时间 → 立即同步至网络时间
4️⃣  启动同步服务 → 让服务后台持续同步
5️⃣  开机自启配置 → 重启后自动启动同步服务

【两种同步方案对比】
┌──────────────────────┬─────────────────────┬─────────────────────┐
│ 功能特性             │ NTP (传统)          │ Chrony (现代推荐)    │
├──────────────────────┼─────────────────────┼─────────────────────┤
│ 启动速度             │ 较慢(10分钟左右)     │ 很快(几分钟)        │
│ 同步精度             │ ±100ms              │ ±1ms                │
│ 离线工作             │ 否                  │ 是(自适应)          │
│ 资源占用             │ 中等                │ 较低                │
│ 虚拟机环境           │ 一般                │ 优秀                │
├──────────────────────┼─────────────────────┼─────────────────────┤
│ 配置文件             │ /etc/ntp.conf       │ /etc/chrony.conf    │
│ 管理命令             │ ntpq, ntpstat       │ chronyc             │
│ 同步命令             │ ntpdate             │ chronyc makestep    │
└──────────────────────┴─────────────────────┴─────────────────────┘

【快速开始】
✓ 查看状态: 选择菜单1或2查看NTP/Chrony状态
✓ 手动同步: 选择菜单3或4手动同步时间
✓ 启动服务: 选择菜单5选择启动NTP或Chrony
✓ 配置方案: 选择菜单6编辑NTP或Chrony配置

EOF

    echo ""
    # 检测当前时间同步服务
    print_subheader "时间同步服务检测"

    local has_ntp=0
    local has_chrony=0
    local ntp_status=""
    local chrony_status=""

    if command_exists ntpd 2>/dev/null || systemctl list-unit-files 2>/dev/null | grep -q ntp; then
        has_ntp=1
        if systemctl is-active ntpd >/dev/null 2>&1; then
            ntp_status="运行中"
            print_success "NTP服务: 已安装且运行中"
        else
            ntp_status="已停止"
            print_warning "NTP服务: 已安装但未运行"
        fi
    fi

    if command_exists chronyd 2>/dev/null || systemctl list-unit-files 2>/dev/null | grep -q chrony; then
        has_chrony=1
        if systemctl is-active chronyd >/dev/null 2>&1; then
            chrony_status="运行中"
            print_success "Chrony服务: 已安装且运行中"
        else
            chrony_status="已停止"
            print_warning "Chrony服务: 已安装但未运行"
        fi
    fi

    if [ "$has_ntp" -eq 0 ] && [ "$has_chrony" -eq 0 ]; then
        print_error "未检测到NTP或Chrony服务"
    fi

    echo ""
    print_subheader "当前系统时间"
    print_info "系统时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    print_info "时区: $(timedatectl show --property=Timezone --value 2>/dev/null || echo '未知')"
    print_info "时间同步状态: $(timedatectl show --property=NTPSynchronized --value 2>/dev/null || echo '未知')"

    echo ""
    print_subheader "时间同步管理选项"
    echo "1. 查看NTP服务状态详情"
    echo "2. 查看Chrony服务状态详情"
    echo "3. 手动同步时间（NTP）"
    echo "4. 手动同步时间（Chrony）"
    echo "5. 启动/停止时间同步服务"
    echo "6. 配置时间同步服务"
    echo "0. 返回主菜单"
    echo ""

    read -p "请选择操作 (0-6): " sync_choice

    case $sync_choice in
        1)
            show_ntp_status
            ;;
        2)
            show_chrony_status
            ;;
        3)
            manual_ntp_sync
            ;;
        4)
            manual_chrony_sync
            ;;
        5)
            manage_sync_service
            ;;
        6)
            configure_time_sync
            ;;
        0)
            return 0
            ;;
        *)
            print_error "无效的选择"
            ;;
    esac
}

# 显示NTP服务状态
show_ntp_status() {
    print_subheader "NTP服务详细状态"
    if command_exists ntpq; then
        ntpq -p
    elif command_exists ntpstat; then
        ntpstat
    elif systemctl is-active ntpd >/dev/null 2>&1; then
        systemctl status ntpd
    else
        print_error "NTP服务未安装或未运行"
    fi
}

# 显示Chrony服务状态
show_chrony_status() {
    print_subheader "Chrony服务详细状态"
    if command_exists chronyc; then
        chronyc tracking
        echo ""
        chronyc sources
    elif systemctl is-active chronyd >/dev/null 2>&1; then
        systemctl status chronyd
    else
        print_error "Chrony服务未安装或未运行"
    fi
}

# 手动同步时间（NTP）
manual_ntp_sync() {
    print_subheader "手动同步时间（NTP）"
    print_info "正在执行NTP时间同步..."

    if [ "$EUID" -ne 0 ]; then
        print_warning "需要root权限才能同步时间"
        read -p "请输入NTP服务器地址 (按Enter跳过): " ntp_server
        if [ -z "$ntp_server" ]; then
            ntp_server="0.cn.pool.ntp.org"
        fi
        print_info "可以使用: sudo ntpdate -u $ntp_server"
    else
        read -p "请输入NTP服务器地址 (默认: 0.cn.pool.ntp.org): " ntp_server
        if [ -z "$ntp_server" ]; then
            ntp_server="0.cn.pool.ntp.org"
        fi

        if command_exists ntpdate; then
            if ntpdate -u "$ntp_server"; then
                print_success "时间同步成功"
            else
                print_error "时间同步失败"
            fi
        else
            print_warning "ntpdate命令不可用，请安装ntp包"
            print_info "CentOS/RHEL: sudo yum install ntp"
            print_info "Ubuntu/Debian: sudo apt-get install ntp"
        fi
    fi
}

# 手动同步时间（Chrony）
manual_chrony_sync() {
    print_subheader "手动同步时间（Chrony）"
    print_info "正在执行Chrony时间同步..."

    if [ "$EUID" -ne 0 ]; then
        print_warning "需要root权限才能同步时间"
        print_info "可以使用: sudo chronyc makestep"
    else
        if command_exists chronyc; then
            if chronyc makestep; then
                print_success "时间同步成功"
            else
                print_error "时间同步失败"
            fi
        else
            print_warning "chronyc命令不可用，请安装chrony包"
            print_info "CentOS/RHEL: sudo yum install chrony"
            print_info "Ubuntu/Debian: sudo apt-get install chrony"
        fi
    fi
}

# 管理时间同步服务
manage_sync_service() {
    print_subheader "管理时间同步服务"

    if [ "$EUID" -ne 0 ]; then
        print_error "需要root权限来管理服务"
        return 1
    fi

    echo "选择要管理的服务:"
    echo "1. 启动/停止NTP"
    echo "2. 启动/停止Chrony"
    echo "3. 启用/禁用开机自启"
    echo ""
    read -p "请选择 (1-3): " service_choice

    case $service_choice in
        1)
            if systemctl is-active ntpd >/dev/null 2>&1; then
                read -p "NTP正在运行，是否停止? (y/n): " stop_choice
                if [[ "$stop_choice" =~ ^[Yy]$ ]]; then
                    systemctl stop ntpd && print_success "NTP已停止"
                fi
            else
                read -p "NTP未运行，是否启动? (y/n): " start_choice
                if [[ "$start_choice" =~ ^[Yy]$ ]]; then
                    systemctl start ntpd && print_success "NTP已启动"
                fi
            fi
            ;;
        2)
            if systemctl is-active chronyd >/dev/null 2>&1; then
                read -p "Chrony正在运行，是否停止? (y/n): " stop_choice
                if [[ "$stop_choice" =~ ^[Yy]$ ]]; then
                    systemctl stop chronyd && print_success "Chrony已停止"
                fi
            else
                read -p "Chrony未运行，是否启动? (y/n): " start_choice
                if [[ "$start_choice" =~ ^[Yy]$ ]]; then
                    systemctl start chronyd && print_success "Chrony已启动"
                fi
            fi
            ;;
        3)
            echo "选择服务:"
            echo "1. NTP"
            echo "2. Chrony"
            read -p "请选择: " service_type

            case $service_type in
                1)
                    if systemctl is-enabled ntpd >/dev/null 2>&1; then
                        read -p "NTP已启用开机自启，是否禁用? (y/n): " disable_choice
                        if [[ "$disable_choice" =~ ^[Yy]$ ]]; then
                            systemctl disable ntpd && print_success "NTP开机自启已禁用"
                        fi
                    else
                        read -p "NTP未启用开机自启，是否启用? (y/n): " enable_choice
                        if [[ "$enable_choice" =~ ^[Yy]$ ]]; then
                            systemctl enable ntpd && print_success "NTP开机自启已启用"
                        fi
                    fi
                    ;;
                2)
                    if systemctl is-enabled chronyd >/dev/null 2>&1; then
                        read -p "Chrony已启用开机自启，是否禁用? (y/n): " disable_choice
                        if [[ "$disable_choice" =~ ^[Yy]$ ]]; then
                            systemctl disable chronyd && print_success "Chrony开机自启已禁用"
                        fi
                    else
                        read -p "Chrony未启用开机自启，是否启用? (y/n): " enable_choice
                        if [[ "$enable_choice" =~ ^[Yy]$ ]]; then
                            systemctl enable chronyd && print_success "Chrony开机自启已启用"
                        fi
                    fi
                    ;;
                *)
                    print_error "无效的选择"
                    ;;
            esac
            ;;
        *)
            print_error "无效的选择"
            ;;
    esac
}

# 配置时间同步服务
configure_time_sync() {
    print_subheader "配置时间同步服务"

    if [ "$EUID" -ne 0 ]; then
        print_error "需要root权限来修改配置"
        return 1
    fi

    echo "选择要配置的服务:"
    echo "1. 配置NTP服务器"
    echo "2. 配置Chrony服务器"
    echo ""
    read -p "请选择 (1-2): " config_choice

    case $config_choice in
        1)
            print_info "NTP配置文件: /etc/ntp.conf"
            read -p "是否打开编辑器? (y/n): " edit_choice
            if [[ "$edit_choice" =~ ^[Yy]$ ]]; then
                ${EDITOR:-nano} /etc/ntp.conf
                systemctl restart ntpd
                print_success "NTP配置已更新并重启"
            fi
            ;;
        2)
            print_info "Chrony配置文件: /etc/chrony.conf"
            read -p "是否打开编辑器? (y/n): " edit_choice
            if [[ "$edit_choice" =~ ^[Yy]$ ]]; then
                ${EDITOR:-nano} /etc/chrony.conf
                systemctl restart chronyd
                print_success "Chrony配置已更新并重启"
            fi
            ;;
        *)
            print_error "无效的选择"
            ;;
    esac
}

# ============================================================================
# 主函数
# ============================================================================

main() {
    manage_time_sync
}

main "$@"
exit 0
