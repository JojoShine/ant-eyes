#!/bin/bash

################################################################################
# ant-eyes - 网络诊断工具模块
# 检查：Ping、Telnet、DNS解析、端口扫描、网速测试等
################################################################################

# 加载共享函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# ============================================================================
# 网络诊断工具
# ============================================================================

show_network_info() {
    print_header "网络诊断工具"

    # 网络接口信息
    print_subheader "网络接口"
    if command_exists ip; then
        local iface_count=0
        ip addr show | grep "^[0-9]:" | while read -r line; do
            print_info "  $(echo $line | awk '{print $2}' | sed 's/:$//')"
            ((iface_count++))
        done

        # 显示IP地址
        print_info "IP地址:"
        ip addr show | grep "inet " | awk '{print $2, "(" $7 ")"}' | while read -r line; do
            print_info "  $line"
        done
    fi

    # 网络连接状态
    print_subheader "网络连接统计"
    if command_exists ss; then
        local tcp_count=$(($(ss -tan 2>/dev/null | wc -l) - 1))
        local udp_count=$(($(ss -uan 2>/dev/null | wc -l) - 1))
        print_table_two_col "协议" "连接数" \
            "TCP" "$tcp_count" \
            "UDP" "$udp_count"
    fi

    # DNS检查
    print_subheader "DNS配置"
    if [ -f /etc/resolv.conf ]; then
        local dns_count=$(grep "^nameserver" /etc/resolv.conf | wc -l)
        print_info "DNS服务器 ($dns_count 个):"
        grep "^nameserver" /etc/resolv.conf | head -3 | while read -r line; do
            print_info "  $line"
        done
    fi

    # 默认网关
    print_subheader "网络配置"
    if command_exists ip; then
        local gateway=$(ip route | grep default | awk '{print $3}')
        print_table_two_col "属性" "值" \
            "默认网关" "${gateway:-未检测到}"
    fi

    # 网络诊断工具可用性
    print_subheader "网络诊断工具可用性"
    local tools=("ping" "telnet" "traceroute" "dig" "nslookup" "nc")
    local installed=0
    local total=${#tools[@]}

    for tool in "${tools[@]}"; do
        if command_exists "$tool"; then
            print_success "$tool"
            ((installed++))
        else
            print_warning "$tool"
        fi
    done

    print_info "已安装的工具: $installed/$total"
}

# ============================================================================
# 主函数
# ============================================================================

main() {
    # 检查参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -q|--quiet)
                QUIET=1
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    show_network_info
}

# 执行主函数
main "$@"
