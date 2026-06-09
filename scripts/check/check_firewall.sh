#!/bin/bash

################################################################################
# ant-eyes - 系统安全检查模块
# 检查：防火墙、SELinux、用户权限、文件安全等
################################################################################

# 加载共享函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# ============================================================================
# 系统安全检查
# ============================================================================

show_security_info() {
    print_header "系统安全情况检查"

    # 防火墙状态
    print_subheader "防火墙状态"
    local fw_status="未检测"
    if command_exists firewall-cmd; then
        fw_status=$(firewall-cmd --state 2>/dev/null)
        if [ "$fw_status" = "running" ]; then
            print_success "防火墙已启用 (firewalld)"
        else
            print_warning "防火墙未运行"
        fi
    elif command_exists ufw; then
        fw_status=$(ufw status | head -1)
        print_info "防火墙状态: $fw_status"
    elif command_exists iptables; then
        print_info "防火墙: iptables"
    else
        print_info "防火墙: 未检测到"
    fi

    # SELinux状态
    print_subheader "SELinux状态"
    local selinux_status="未安装"
    if command_exists getenforce; then
        selinux_status=$(getenforce 2>/dev/null || echo "未安装")
        print_info "SELinux: $selinux_status"
    else
        print_info "SELinux: 未安装"
    fi

    # 系统安全摘要
    print_subheader "安全配置摘要"
    local user_count=$(grep -c ":" /etc/passwd 2>/dev/null || echo "0")
    print_table_two_col "属性" "值" \
        "系统用户总数" "$user_count" \
        "防火墙" "$fw_status" \
        "SELinux" "$selinux_status"

    # 检查是否存在空密码账户
    print_subheader "空密码账户检查"
    local empty_passwd=$(awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null)
    if [ -z "$empty_passwd" ]; then
        print_success "未发现空密码账户"
    else
        print_warning "发现空密码账户: $empty_passwd"
    fi

    # 检查root用户是否可远程登录
    print_subheader "SSH安全配置"
    if [ -f /etc/ssh/sshd_config ]; then
        local permit_root=$(grep -i "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}')
        local passwd_auth=$(grep -i "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}')

        print_table_two_col "配置项" "值" \
            "PermitRootLogin" "${permit_root:-未配置}" \
            "PasswordAuthentication" "${passwd_auth:-未配置}"

        [ "$permit_root" = "no" ] || [ "$permit_root" = "without-password" ] && print_success "✓ root远程登录已限制"
        [ "$passwd_auth" = "no" ] && print_success "✓ 密码认证已禁用"
    fi

    # 检查SUID文件
    print_subheader "SUID文件检查（前10个）"
    local suid_count=$(find / -perm -4000 2>/dev/null | wc -l)
    print_info "系统中的SUID文件总数: $suid_count"
    print_info "前10个SUID文件:"
    find / -perm -4000 2>/dev/null | head -10 | while read -r file; do
        print_info "  $file"
    done

    # ========== 防火墙规则展示 ==========
    print_subheader "防火墙规则"

    if command_exists firewall-cmd; then
        # Firewalld 规则展示
        print_info "Firewalld 配置："

        # 默认区域
        local default_zone=$(firewall-cmd --get-default-zone 2>/dev/null)
        print_info "  默认区域: ${default_zone:-未知}"

        # 开放的端口
        local open_ports=$(firewall-cmd --list-ports 2>/dev/null)
        if [ -n "$open_ports" ]; then
            print_info "  开放端口: $open_ports"
        else
            print_info "  开放端口: 无"
        fi

        # 允许的服务
        local services=$(firewall-cmd --list-services 2>/dev/null)
        if [ -n "$services" ]; then
            print_info "  允许的服务: $services"
        else
            print_info "  允许的服务: 无"
        fi

    elif command_exists ufw; then
        # UFW 规则展示
        print_info "UFW 配置："
        ufw status | while read -r line; do
            print_info "  $line"
        done

    elif command_exists iptables; then
        # iptables 规则展示
        print_info "iptables 配置："
        local rule_count=$(iptables -L 2>/dev/null | grep -c "^Chain\|^target" || echo "0")
        print_info "  规则总数: $rule_count"

        print_info "  INPUT 链规则（前5条）:"
        iptables -L INPUT -n 2>/dev/null | tail -n +3 | head -5 | while read -r line; do
            print_info "    $line"
        done

    else
        print_warning "未检测到防火墙"
    fi
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

    show_security_info
}

# 执行主函数
main "$@"
exit 0
