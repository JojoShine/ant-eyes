#!/bin/bash

################################################################################
# ant-eyes - 网络诊断工具模块
# 检查：接口、DNS、公网IP、ARP表、交互式网络诊断（ping、telnet、traceroute等）
################################################################################

# 加载共享函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# ============================================================================
# 网络信息展示
# ============================================================================

show_network_info() {
    print_header "网络诊断工具"

    # ========== 网络接口信息 ==========
    print_subheader "网络接口信息"

    if command_exists ip; then
        ip -br addr show | while read -r line; do
            print_info "  $line"
        done
    elif command_exists ifconfig; then
        ifconfig | grep -E "^[a-z]|inet " | while read -r line; do
            print_info "  $line"
        done
    fi

    # ========== 网卡流量统计 ==========
    print_subheader "网卡流量统计"

    if command_exists ip; then
        ip -s link show | grep -E "^[0-9]+:|RX:|TX:" | head -20 | while read -r line; do
            if [[ "$line" =~ ^[0-9]+: ]]; then
                print_info "$(echo $line | cut -d: -f2-)"
            else
                print_info "  $line"
            fi
        done
    else
        print_info "ip命令不可用"
    fi

    # ========== 公网IP地址 ==========
    print_subheader "公网IP地址"

    local public_ip=""
    if command_exists curl; then
        public_ip=$(curl -s --max-time 3 ifconfig.me 2>/dev/null || \
                   curl -s --max-time 3 ipinfo.io/ip 2>/dev/null || \
                   curl -s --max-time 3 icanhazip.com 2>/dev/null)
    elif command_exists wget; then
        public_ip=$(wget -qO- --timeout=3 ifconfig.me 2>/dev/null || \
                   wget -qO- --timeout=3 ipinfo.io/ip 2>/dev/null || \
                   wget -qO- --timeout=3 icanhazip.com 2>/dev/null)
    fi

    if [ -n "$public_ip" ]; then
        print_success "公网IP: $public_ip"
    else
        print_warning "无法获取公网IP（网络连接失败或curl/wget不可用）"
    fi

    # ========== 默认网关 ==========
    print_subheader "默认网关"

    if command_exists ip; then
        local gateway=$(ip route | grep default | awk '{print $3}')
        if [ -n "$gateway" ]; then
            print_info "默认网关: $gateway"
        else
            print_warning "未找到默认网关"
        fi
    fi

    # ========== DNS配置 ==========
    print_subheader "DNS配置"

    if [ -f /etc/resolv.conf ]; then
        local dns_servers=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}')
        local dns_count=$(echo "$dns_servers" | wc -l)
        print_info "DNS服务器（$dns_count 个）："
        echo "$dns_servers" | head -3 | while read -r dns; do
            print_info "  $dns"
        done
    else
        print_warning "resolv.conf 文件不存在"
    fi

    # ========== 网络连接统计 ==========
    print_subheader "网络连接统计"

    if command_exists ss; then
        local tcp_estab=$(ss -tan 2>/dev/null | grep -c ESTAB || echo "0")
        local tcp_total=$(ss -tan 2>/dev/null | tail -n +2 | wc -l || echo "0")
        local udp_total=$(ss -uan 2>/dev/null | tail -n +2 | wc -l || echo "0")
        print_table_two_col "类型" "连接数" \
            "TCP已建立" "$tcp_estab" \
            "TCP总连接" "$tcp_total" \
            "UDP连接" "$udp_total"
    elif command_exists netstat; then
        local tcp_estab=$(netstat -tan 2>/dev/null | grep -c ESTABLISHED || echo "0")
        print_info "TCP已建立连接: $tcp_estab 个"
    fi

    # ========== ARP缓存表 ==========
    print_subheader "ARP缓存表（前10个）"

    if command_exists arp; then
        local arp_entries=$(arp -an 2>/dev/null | grep -v "incomplete" | wc -l)
        if [ "$arp_entries" -gt 0 ]; then
            print_info "ARP缓存条目数: $arp_entries"
            arp -an 2>/dev/null | grep -v "incomplete" | head -10 | while read -r line; do
                print_info "  $line"
            done
        else
            print_info "ARP缓存为空"
        fi
    elif command_exists ip; then
        local arp_entries=$(ip neigh show 2>/dev/null | grep -v "FAILED" | wc -l)
        if [ "$arp_entries" -gt 0 ]; then
            print_info "ARP缓存条目数: $arp_entries"
            ip neigh show 2>/dev/null | grep -v "FAILED" | head -10 | while read -r line; do
                print_info "  $line"
            done
        else
            print_info "ARP缓存为空"
        fi
    else
        print_warning "arp和ip命令均不可用"
    fi

    # ========== 网络诊断工具可用性 ==========
    print_subheader "网络诊断工具可用性"

    local tools=("ping" "telnet" "traceroute" "dig" "nslookup" "nc" "curl" "wget")
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

    # ========== 交互式诊断 ==========
    echo ""
    print_subheader "交互式网络诊断"
    print_info "1. Ping 测试 - 测试主机连通性"
    print_info "2. Telnet 测试 - 测试TCP端口"
    print_info "3. Traceroute - 追踪路由路径"
    print_info "4. DNS 解析 - 测试域名解析"
    print_info "5. Nslookup - DNS查询"
    print_info "6. ARP 查询 - 查询MAC地址"
    print_info "7. 延迟测试 - 查看网络延迟"
    print_info "8. 端口扫描 - 扫描常用端口"
    print_info "0. 不执行测试"
    echo ""

    # 交互式测试
    if [ -t 0 ]; then
        read -p "选择操作 [0-8]: " test_choice

        case $test_choice in
            1)
                read -p "请输入目标主机: " target_host
                if [ -n "$target_host" ]; then
                    print_subheader "Ping 测试: $target_host"
                    if command_exists ping; then
                        ping -c 4 "$target_host" 2>&1 || true
                    else
                        print_error "ping 命令不可用"
                    fi
                fi
                ;;
            2)
                read -p "请输入目标主机: " target_host
                read -p "请输入端口号: " target_port
                if [ -n "$target_host" ] && [ -n "$target_port" ]; then
                    print_subheader "Telnet 测试: $target_host:$target_port"
                    if command_exists telnet; then
                        timeout 3 telnet "$target_host" "$target_port" 2>&1 || true
                    elif command_exists nc; then
                        nc -zv -w 3 "$target_host" "$target_port" 2>&1 || true
                    else
                        print_error "telnet 和 nc 命令均不可用"
                    fi
                fi
                ;;
            3)
                read -p "请输入目标主机: " target_host
                if [ -n "$target_host" ]; then
                    print_subheader "Traceroute: $target_host"
                    if command_exists traceroute; then
                        traceroute "$target_host" 2>&1 || true
                    elif command_exists tracepath; then
                        tracepath "$target_host" 2>&1 || true
                    else
                        print_error "traceroute 和 tracepath 命令均不可用"
                    fi
                fi
                ;;
            4)
                read -p "请输入域名: " domain_name
                if [ -n "$domain_name" ]; then
                    print_subheader "DNS 解析: $domain_name"
                    if command_exists dig; then
                        dig "$domain_name" 2>&1 | head -20 || true
                    elif command_exists nslookup; then
                        nslookup "$domain_name" 2>&1 || true
                    else
                        print_error "dig 和 nslookup 命令均不可用"
                    fi
                fi
                ;;
            5)
                read -p "请输入域名: " domain_name
                if [ -n "$domain_name" ]; then
                    print_subheader "Nslookup: $domain_name"
                    if command_exists nslookup; then
                        nslookup "$domain_name" 2>&1 || true
                    else
                        print_error "nslookup 命令不可用"
                    fi
                fi
                ;;
            6)
                read -p "请输入IP地址: " ip_addr
                if [ -n "$ip_addr" ]; then
                    print_subheader "ARP 查询: $ip_addr"
                    if command_exists arp; then
                        arp -n "$ip_addr" 2>&1 || true
                    elif command_exists ip; then
                        ip neigh show "$ip_addr" 2>&1 || true
                    else
                        print_error "arp 和 ip 命令均不可用"
                    fi
                fi
                ;;
            7)
                read -p "请输入目标主机: " target_host
                if [ -n "$target_host" ]; then
                    print_subheader "延迟测试: $target_host"
                    if command_exists ping; then
                        ping -c 1 -W 5 "$target_host" 2>&1 | grep -E "time=|unreachable" || true
                    else
                        print_error "ping 命令不可用"
                    fi
                fi
                ;;
            8)
                read -p "请输入目标主机: " target_host
                if [ -n "$target_host" ]; then
                    print_subheader "常用端口扫描: $target_host"
                    local common_ports=(22 80 443 3306 5432 6379 8080 9000 27017 5672)
                    if command_exists nc; then
                        for port in "${common_ports[@]}"; do
                            timeout 1 nc -zv "$target_host" "$port" 2>&1 | grep -E "succeeded|refused" || true
                        done
                    else
                        print_error "nc 命令不可用，建议使用: nmap -p 22,80,443,3306,5432,6379 $target_host"
                    fi
                fi
                ;;
            0)
                print_info "退出网络诊断"
                ;;
            *)
                print_error "无效选择"
                ;;
        esac
    else
        print_info "非交互模式，跳过诊断工具"
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

    show_network_info
}

# 执行主函数
main "$@"
exit 0
