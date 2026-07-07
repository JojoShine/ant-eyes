#!/bin/bash

################################################################################
# ant-eyes - 防火墙管理模块
# 功能：端口开放/关闭、永久规则、rich规则交互管理
# 支持：firewalld (CentOS/RHEL/Kylin)、ufw (Ubuntu/Debian)
################################################################################

# 加载共享函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# ============================================================================
# 防火墙类型检测
# ============================================================================

detect_firewall() {
    if command_exists firewall-cmd && systemctl is-active --quiet firewalld 2>/dev/null; then
        echo "firewalld"
    elif command_exists ufw && ufw status 2>/dev/null | grep -q "active"; then
        echo "ufw"
    elif command_exists firewall-cmd; then
        echo "firewalld-inactive"
    elif command_exists ufw; then
        echo "ufw-inactive"
    else
        echo "none"
    fi
}

# ============================================================================
# firewalld 管理函数
# ============================================================================

fw_show_status() {
    print_subheader "firewalld 防火墙状态"

    local state=$(firewall-cmd --state 2>/dev/null)
    if [[ "$state" == "running" ]]; then
        print_success "防火墙状态: 已运行"
    else
        print_error "防火墙状态: 未运行 ($state)"
        return 1
    fi

    local default_zone=$(firewall-cmd --get-default-zone 2>/dev/null)
    local active_zone=$(firewall-cmd --get-active-zones 2>/dev/null)

    print_info "默认区域: $default_zone"
    echo ""
    print_info "活跃区域:"
    echo "$active_zone" | while IFS= read -r line; do
        [[ -n "$line" ]] && print_info "  $line"
    done

    echo ""
    print_info "当前开放端口:"
    local ports=$(firewall-cmd --list-ports 2>/dev/null)
    if [[ -n "$ports" ]]; then
        for p in $ports; do
            local port_num=${p%%/*}
            local svc="${PORT_SERVICES[$port_num]:-}"
            if [[ -n "$svc" ]]; then
                print_info "  $p  ($svc)"
            else
                print_info "  $p"
            fi
        done
    else
        print_warning "  无开放端口"
    fi

    echo ""
    print_info "当前允许的服务:"
    local services=$(firewall-cmd --list-services 2>/dev/null)
    if [[ -n "$services" ]]; then
        for svc in $services; do
            print_info "  $svc"
        done
    else
        print_warning "  无允许服务"
    fi

    echo ""
    print_info "当前 Rich 规则:"
    local rich_rules=$(firewall-cmd --list-rich 2>/dev/null)
    if [[ -n "$rich_rules" ]]; then
        echo "$rich_rules" | while IFS= read -r rule; do
            [[ -n "$rule" ]] && print_info "  $rule"
        done
    else
        print_warning "  无 Rich 规则"
    fi
}

fw_open_port() {
    print_subheader "开放端口"

    echo ""
    print_info "常用端口参考:"
    print_info "  22 (SSH)    80 (HTTP)     443 (HTTPS)"
    print_info "  3306 (MySQL)  5432 (PG)   6379 (Redis)"
    print_info "  8080 (Alt HTTP)  9000 (MinIO)  27017 (MongoDB)"
    echo ""

    read -p "请输入要开放的端口 (如: 8080 或 8080-8090): " port_input

    if [[ -z "$port_input" ]]; then
        print_error "端口不能为空"
        return 1
    fi

    # 解析端口和协议
    local port_range=""
    local protocol="tcp"

    # 检查是否包含协议 (如 8080/tcp 或 8080/udp)
    if [[ "$port_input" == *"/"* ]]; then
        port_range="${port_input%%/*}"
        protocol="${port_input##*/}"
    else
        port_range="$port_input"
    fi

    # 验证协议
    if [[ "$protocol" != "tcp" && "$protocol" != "udp" ]]; then
        print_error "协议类型无效，仅支持 tcp 或 udp"
        return 1
    fi

    # 验证端口格式
    if [[ "$port_range" == *-* ]]; then
        local start=${port_range%%-*}
        local end=${port_range##*-}
        if ! [[ "$start" =~ ^[0-9]+$ && "$end" =~ ^[0-9]+$ ]]; then
            print_error "端口格式无效"
            return 1
        fi
        if [[ $start -gt $end || $start -lt 1 || $end -gt 65535 ]]; then
            print_error "端口范围无效 (1-65535)"
            return 1
        fi
    else
        if ! [[ "$port_range" =~ ^[0-9]+$ ]]; then
            print_error "端口格式无效"
            return 1
        fi
        if [[ $port_range -lt 1 || $port_range -gt 65535 ]]; then
            print_error "端口超出范围 (1-65535)"
            return 1
        fi
    fi

    # 检查是否已开放
    if firewall-cmd --query-port="$port_range/$protocol" &>/dev/null; then
        print_warning "端口 $port_range/$protocol 已经开放"
        return 0
    fi

    # 是否永久生效
    echo ""
    read -p "是否永久开放? (y/n) [默认: y]: " permanent_choice
    permanent_choice="${permanent_choice:-y}"

    local port_svc="${PORT_SERVICES[$port_range]:-}"
    echo ""
    print_info "即将执行:"
    print_info "  端口: $port_range/$protocol"
    [[ -n "$port_svc" ]] && print_info "  服务: $port_svc"
    if [[ "$permanent_choice" =~ ^[Yy]$ ]]; then
        print_info "  模式: 永久生效 (--permanent)"
    else
        print_info "  模式: 仅本次运行（重启后失效）"
    fi
    echo ""
    read -p "确认开放? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "已取消"
        return 0
    fi

    # 执行开放端口
    if [[ "$permanent_choice" =~ ^[Yy]$ ]]; then
        if firewall-cmd --permanent --add-port="$port_range/$protocol" 2>/dev/null; then
            print_success "端口 $port_range/$protocol 已永久开放"
            firewall-cmd --reload 2>/dev/null
            print_success "防火墙规则已重载"
        else
            print_error "端口开放失败"
            return 1
        fi
    else
        if firewall-cmd --add-port="$port_range/$protocol" 2>/dev/null; then
            print_success "端口 $port_range/$protocol 已开放（本次运行有效）"
        else
            print_error "端口开放失败"
            return 1
        fi
    fi
}

fw_close_port() {
    print_subheader "关闭端口"

    print_info "当前已开放的端口:"
    local ports=$(firewall-cmd --list-ports 2>/dev/null)
    if [[ -z "$ports" ]]; then
        print_warning "  当前无开放端口"
        return 0
    fi

    local port_num=1
    local -a port_array
    for p in $ports; do
        port_array+=("$p")
        local svc="${PORT_SERVICES[${p%%/*}]:-}"
        if [[ -n "$svc" ]]; then
            echo "  $port_num. $p  ($svc)"
        else
            echo "  $port_num. $p"
        fi
        ((port_num++))
    done

    echo ""
    read -p "请选择要关闭的端口编号 (多个用逗号分隔): " choices

    IFS=',' read -ra selected <<< "$choices"
    for idx in "${selected[@]}"; do
        idx=$(echo "$idx" | tr -d ' ')
        if [[ "$idx" =~ ^[0-9]+$ ]] && [[ $idx -ge 1 && $idx -le ${#port_array[@]} ]]; then
            local target_port="${port_array[$((idx-1))]}"

            read -p "是否同时移除永久规则? (y/n) [默认: y]: " rm_permanent
            rm_permanent="${rm_permanent:-y}"

            if [[ "$rm_permanent" =~ ^[Yy]$ ]]; then
                firewall-cmd --permanent --remove-port="$target_port" 2>/dev/null
            fi
            firewall-cmd --remove-port="$target_port" 2>/dev/null
            print_success "端口 $target_port 已关闭"
        else
            print_warning "无效编号: $idx，跳过"
        fi
    done

    firewall-cmd --reload 2>/dev/null
    print_success "防火墙规则已重载"
}

fw_manage_rich_rules() {
    print_subheader "Rich 规则管理"

    echo ""
    echo "  1. 查看当前 Rich 规则"
    echo "  2. 添加 Rich 规则（交互式构建）"
    echo "  3. 删除 Rich 规则"
    echo "  4. Rich 规则说明"
    echo "  0. 返回"
    echo ""

    read -p "请选择操作 (0-4): " rich_choice

    case $rich_choice in
        1) fw_rich_list ;;
        2) fw_rich_add ;;
        3) fw_rich_remove ;;
        4) fw_rich_help ;;
        0) return 0 ;;
        *) print_error "无效选项" ;;
    esac
}

fw_rich_list() {
    print_subheader "当前 Rich 规则列表"

    local rules=$(firewall-cmd --list-rich 2>/dev/null)
    if [[ -z "$rules" ]]; then
        print_warning "当前无 Rich 规则"
        return 0
    fi

    local rule_num=1
    echo "$rules" | while IFS= read -r rule; do
        if [[ -n "$rule" ]]; then
            echo "  $rule_num. $rule"
            ((rule_num++))
        fi
    done
}

fw_rich_add() {
    print_subheader "交互式构建 Rich 规则"

    echo ""
    print_info "Rich 规则可以精确控制防火墙行为，支持按来源IP、目标IP、端口、协议等组合过滤"
    echo ""
    echo "  规则类型:"
    echo "    1. 允许指定IP访问指定端口"
    echo "    2. 拒绝指定IP访问指定端口"
    echo "    3. 允许指定IP段访问指定端口"
    echo "    4. 拒绝指定IP段访问指定端口"
    echo "    5. 端口转发"
    echo "    6. 限速（rate limit）"
    echo "    7. 自定义 Rich 规则（手动输入）"
    echo ""

    read -p "请选择规则类型 (1-7): " rule_type

    local rule_string=""

    case $rule_type in
        1|2)
            local action="accept"
            [[ "$rule_type" == "2" ]] && action="reject"

            read -p "请输入来源IP (如: 192.168.1.100): " src_ip
            [[ -z "$src_ip" ]] && { print_error "IP不能为空"; return 1; }

            read -p "请输入目标端口: " dst_port
            [[ -z "$dst_port" ]] && { print_error "端口不能为空"; return 1; }

            read -p "请输入协议 (tcp/udp) [默认: tcp]: " proto
            proto="${proto:-tcp}"

            rule_string="rule family=\"ipv4\" source address=\"$src_ip\" port port=\"$dst_port\" protocol=\"$proto\" $action"
            ;;
        3|4)
            local action="accept"
            [[ "$rule_type" == "4" ]] && action="reject"

            read -p "请输入来源IP段 (如: 192.168.1.0/24): " src_net
            [[ -z "$src_net" ]] && { print_error "IP段不能为空"; return 1; }

            read -p "请输入目标端口: " dst_port
            [[ -z "$dst_port" ]] && { print_error "端口不能为空"; return 1; }

            read -p "请输入协议 (tcp/udp) [默认: tcp]: " proto
            proto="${proto:-tcp}"

            rule_string="rule family=\"ipv4\" source address=\"$src_net\" port port=\"$dst_port\" protocol=\"$proto\" $action"
            ;;
        5)
            read -p "请输入源端口: " src_port
            [[ -z "$src_port" ]] && { print_error "源端口不能为空"; return 1; }

            read -p "请输入目标IP: " dst_ip
            [[ -z "$dst_ip" ]] && { print_error "目标IP不能为空"; return 1; }

            read -p "请输入目标端口: " dst_port
            [[ -z "$dst_port" ]] && { print_error "目标端口不能为空"; return 1; }

            read -p "请输入协议 (tcp/udp) [默认: tcp]: " proto
            proto="${proto:-tcp}"

            rule_string="rule family=\"ipv4\" forward-port port=\"$src_port\" protocol=\"$proto\" to-port=\"$dst_port\" to-addr=\"$dst_ip\""
            ;;
        6)
            read -p "请输入目标端口: " dst_port
            [[ -z "$dst_port" ]] && { print_error "端口不能为空"; return 1; }

            read -p "请输入协议 (tcp/udp) [默认: tcp]: " proto
            proto="${proto:-tcp}"

            read -p "请输入速率限制 (如: 10/s 表示每秒10次) [默认: 5/s]: " rate
            rate="${rate:-5/s}"

            rule_string="rule family=\"ipv4\" port port=\"$dst_port\" protocol=\"$proto\" limit value=\"$rate\" accept"
            ;;
        7)
            print_info "请输入完整的 Rich 规则语句"
            print_info "示例: rule family=\"ipv4\" source address=\"10.0.0.0/8\" port port=\"3306\" protocol=\"tcp\" accept"
            echo ""
            read -p "Rich 规则: " rule_string
            [[ -z "$rule_string" ]] && { print_error "规则不能为空"; return 1; }
            ;;
        *)
            print_error "无效选项"
            return 1
            ;;
    esac

    # 显示规则并确认
    echo ""
    print_info "即将添加的 Rich 规则:"
    print_info "  $rule_string"
    echo ""

    read -p "是否永久生效? (y/n) [默认: y]: " permanent_choice
    permanent_choice="${permanent_choice:-y}"

    echo ""
    read -p "确认添加? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "已取消"
        return 0
    fi

    if [[ "$permanent_choice" =~ ^[Yy]$ ]]; then
        if firewall-cmd --permanent --add-rich-rule="$rule_string" 2>/dev/null; then
            print_success "Rich 规则已永久添加"
            firewall-cmd --reload 2>/dev/null
            print_success "防火墙规则已重载"
        else
            print_error "Rich 规则添加失败"
            return 1
        fi
    else
        if firewall-cmd --add-rich-rule="$rule_string" 2>/dev/null; then
            print_success "Rich 规则已添加（本次运行有效）"
        else
            print_error "Rich 规则添加失败"
            return 1
        fi
    fi
}

fw_rich_remove() {
    print_subheader "删除 Rich 规则"

    local rules=$(firewall-cmd --list-rich 2>/dev/null)
    if [[ -z "$rules" ]]; then
        print_warning "当前无 Rich 规则可删除"
        return 0
    fi

    print_info "当前 Rich 规则:"
    local -a rule_array
    local rule_num=1
    while IFS= read -r rule; do
        if [[ -n "$rule" ]]; then
            rule_array+=("$rule")
            echo "  $rule_num. $rule"
            ((rule_num++))
        fi
    done <<< "$rules"

    echo ""
    read -p "请选择要删除的规则编号 (多个用逗号分隔): " choices

    IFS=',' read -ra selected <<< "$choices"
    for idx in "${selected[@]}"; do
        idx=$(echo "$idx" | tr -d ' ')
        if [[ "$idx" =~ ^[0-9]+$ ]] && [[ $idx -ge 1 && $idx -le ${#rule_array[@]} ]]; then
            local target_rule="${rule_array[$((idx-1))]}"

            read -p "是否同时移除永久规则? (y/n) [默认: y]: " rm_permanent
            rm_permanent="${rm_permanent:-y}"

            if [[ "$rm_permanent" =~ ^[Yy]$ ]]; then
                firewall-cmd --permanent --remove-rich-rule="$target_rule" 2>/dev/null
            fi
            firewall-cmd --remove-rich-rule="$target_rule" 2>/dev/null
            print_success "Rich 规则已删除: $target_rule"
        else
            print_warning "无效编号: $idx，跳过"
        fi
    done

    firewall-cmd --reload 2>/dev/null
    print_success "防火墙规则已重载"
}

fw_rich_help() {
    print_subheader "Rich 规则说明"

    cat << 'EOF'

Rich 规则是 firewalld 的高级规则语法，可以精确控制防火墙行为。

【基本语法结构】
  rule [family="ipv4|ipv6"]
       [source address="IP/CIDR"]
       [destination address="IP/CIDR"]
       [port port="端口" protocol="tcp|udp"]
       [accept|reject|drop|mark]

【常用示例】

  1. 允许特定IP访问SSH
     rule family="ipv4" source address="10.0.0.5" port port="22" protocol="tcp" accept

  2. 拒绝特定IP访问数据库
     rule family="ipv4" source address="192.168.1.100" port port="3306" protocol="tcp" reject

  3. 允许整个子网访问Web服务
     rule family="ipv4" source address="192.168.1.0/24" port port="80" protocol="tcp" accept

  4. 端口转发（将9000转发到内网8080）
     rule family="ipv4" forward-port port="9000" protocol="tcp" to-port="8080" to-addr="10.0.0.5"

  5. 限速（防止暴力破解SSH）
     rule family="ipv4" port port="22" protocol="tcp" limit value="3/m" accept

  6. 丢弃来自特定IP的所有流量
     rule family="ipv4" source address="10.0.0.99" drop

【关键字说明】
  accept  - 允许通过
  reject  - 拒绝并返回拒绝消息
  drop    - 静默丢弃（不返回任何消息）
  limit   - 速率限制（如 5/s 每秒5次, 10/m 每分钟10次）

EOF
}

fw_manage_services() {
    print_subheader "服务管理"

    echo ""
    echo "  1. 查看允许的服务"
    echo "  2. 添加服务"
    echo "  3. 移除服务"
    echo "  4. 查看可用服务列表"
    echo "  0. 返回"
    echo ""

    read -p "请选择操作 (0-4): " svc_choice

    case $svc_choice in
        1)
            print_info "当前允许的服务:"
            local services=$(firewall-cmd --list-services 2>/dev/null)
            if [[ -n "$services" ]]; then
                for svc in $services; do
                    print_info "  $svc"
                done
            else
                print_warning "  无允许服务"
            fi
            ;;
        2)
            read -p "请输入服务名称 (如: http, https, ssh, mysql): " svc_name
            [[ -z "$svc_name" ]] && { print_error "服务名不能为空"; return 1; }

            read -p "是否永久生效? (y/n) [默认: y]: " permanent
            permanent="${permanent:-y}"

            if [[ "$permanent" =~ ^[Yy]$ ]]; then
                if firewall-cmd --permanent --add-service="$svc_name" 2>/dev/null; then
                    print_success "服务 $svc_name 已永久允许"
                    firewall-cmd --reload 2>/dev/null
                else
                    print_error "服务添加失败，可能服务名不存在"
                    print_info "使用选项4查看可用服务列表"
                fi
            else
                if firewall-cmd --add-service="$svc_name" 2>/dev/null; then
                    print_success "服务 $svc_name 已允许（本次运行有效）"
                else
                    print_error "服务添加失败"
                fi
            fi
            ;;
        3)
            print_info "当前允许的服务:"
            local services=$(firewall-cmd --list-services 2>/dev/null)
            if [[ -z "$services" ]]; then
                print_warning "  无允许服务"
                return 0
            fi

            local svc_num=1
            local -a svc_array
            for svc in $services; do
                svc_array+=("$svc")
                echo "  $svc_num. $svc"
                ((svc_num++))
            done

            echo ""
            read -p "请选择要移除的服务编号: " svc_idx
            if [[ "$svc_idx" =~ ^[0-9]+$ ]] && [[ $svc_idx -ge 1 && $svc_idx -le ${#svc_array[@]} ]]; then
                local target="${svc_array[$((svc_idx-1))]}"
                firewall-cmd --permanent --remove-service="$target" 2>/dev/null
                firewall-cmd --remove-service="$target" 2>/dev/null
                firewall-cmd --reload 2>/dev/null
                print_success "服务 $target 已移除"
            else
                print_error "无效编号"
            fi
            ;;
        4)
            print_info "firewalld 可用服务列表:"
            firewall-cmd --get-services 2>/dev/null | tr ' ' '\n' | sort | column 2>/dev/null || \
                firewall-cmd --get-services 2>/dev/null
            ;;
        0) return 0 ;;
        *) print_error "无效选项" ;;
    esac
}

fw_reload() {
    print_subheader "重载防火墙规则"

    read -p "确认重载 firewalld 规则? (y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if firewall-cmd --reload 2>/dev/null; then
            print_success "防火墙规则已重载"
        else
            print_error "重载失败"
        fi
    fi
}

# ============================================================================
# ufw 管理函数
# ============================================================================

ufw_show_status() {
    print_subheader "UFW 防火墙状态"

    ufw status verbose 2>/dev/null | while IFS= read -r line; do
        [[ -n "$line" ]] && print_info "$line"
    done

    echo ""
    print_info "编号规则列表:"
    ufw status numbered 2>/dev/null | while IFS= read -r line; do
        [[ -n "$line" ]] && print_info "  $line"
    done
}

ufw_open_port() {
    print_subheader "开放端口 (UFW)"

    echo ""
    print_info "常用端口参考:"
    print_info "  22 (SSH)    80 (HTTP)     443 (HTTPS)"
    print_info "  3306 (MySQL)  5432 (PG)   6379 (Redis)"
    print_info "  8080 (Alt HTTP)  9000 (MinIO)  27017 (MongoDB)"
    echo ""

    read -p "请输入要开放的端口: " port_input
    [[ -z "$port_input" ]] && { print_error "端口不能为空"; return 1; }

    local protocol="tcp"
    if [[ "$port_input" == *"/"* ]]; then
        protocol="${port_input##*/}"
        port_input="${port_input%%/*}"
    fi

    read -p "是否限制来源IP? (y/n) [默认: n]: " limit_ip
    local src_spec=""
    if [[ "$limit_ip" =~ ^[Yy]$ ]]; then
        read -p "请输入来源IP (如: 192.168.1.0/24): " src_ip
        [[ -n "$src_ip" ]] && src_spec="from $src_ip"
    fi

    echo ""
    print_info "即将执行:"
    print_info "  ufw allow $src_spec $port_input/$protocol"
    echo ""
    read -p "确认? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "已取消"
        return 0
    fi

    if ufw allow $src_spec "$port_input/$protocol" 2>/dev/null; then
        print_success "端口 $port_input/$protocol 已开放"
    else
        print_error "端口开放失败"
    fi
}

ufw_close_port() {
    print_subheader "关闭端口 (UFW)"

    print_info "当前规则:"
    ufw status numbered 2>/dev/null | while IFS= read -r line; do
        [[ -n "$line" ]] && print_info "  $line"
    done

    echo ""
    read -p "请输入要删除的规则编号: " rule_num
    [[ -z "$rule_num" ]] && { print_error "编号不能为空"; return 1; }

    read -p "确认删除规则 #$rule_num? (y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if ufw --force delete "$rule_num" 2>/dev/null; then
            print_success "规则 #$rule_num 已删除"
        else
            print_error "删除失败"
        fi
    fi
}

# ============================================================================
# 主菜单
# ============================================================================

manage_firewall() {
    print_header "防火墙管理工具"

    local fw_type=$(detect_firewall)

    case $fw_type in
        firewalld)
            print_success "检测到防火墙: firewalld (已启用)"
            ;;
        firewalld-inactive)
            print_warning "检测到 firewalld 但未运行"
            echo ""
            read -p "是否启动 firewalld? (y/n): " start_fw
            if [[ "$start_fw" =~ ^[Yy]$ ]]; then
                if [ "$EUID" -ne 0 ]; then
                    print_error "需要 root 权限启动防火墙"
                    return 1
                fi
                systemctl start firewalld
                systemctl enable firewalld 2>/dev/null
                print_success "firewalld 已启动并设为开机自启"
            else
                return 0
            fi
            ;;
        ufw)
            print_success "检测到防火墙: ufw (已启用)"
            ;;
        ufw-inactive)
            print_warning "检测到 ufw 但未启用"
            echo ""
            read -p "是否启用 ufw? (y/n): " enable_ufw
            if [[ "$enable_ufw" =~ ^[Yy]$ ]]; then
                if [ "$EUID" -ne 0 ]; then
                    print_error "需要 root 权限启用防火墙"
                    return 1
                fi
                ufw enable
                print_success "ufw 已启用"
            else
                return 0
            fi
            ;;
        none)
            print_error "未检测到防火墙 (firewalld / ufw)"
            print_info "请先安装防火墙:"
            print_info "  CentOS/RHEL: sudo yum install firewalld"
            print_info "  Ubuntu/Debian: sudo apt install ufw"
            return 1
            ;;
    esac

    echo ""

    while true; do
        print_subheader "防火墙管理菜单"

        if [[ "$fw_type" == "firewalld" || "$fw_type" == "firewalld-inactive" ]]; then
            echo "  1. 查看防火墙状态和规则"
            echo "  2. 开放端口"
            echo "  3. 关闭端口"
            echo "  4. Rich 规则管理"
            echo "  5. 服务管理 (允许/禁止)"
            echo "  6. 重载防火墙规则"
            echo "  0. 返回主菜单"
            echo ""

            read -p "请选择操作 (0-6): " choice

            case $choice in
                1) fw_show_status ;;
                2) fw_open_port ;;
                3) fw_close_port ;;
                4) fw_manage_rich_rules ;;
                5) fw_manage_services ;;
                6) fw_reload ;;
                0) return 0 ;;
                *) print_error "无效选项" ;;
            esac

        elif [[ "$fw_type" == "ufw" || "$fw_type" == "ufw-inactive" ]]; then
            echo "  1. 查看防火墙状态和规则"
            echo "  2. 开放端口"
            echo "  3. 关闭/删除规则"
            echo "  0. 返回主菜单"
            echo ""

            read -p "请选择操作 (0-3): " choice

            case $choice in
                1) ufw_show_status ;;
                2) ufw_open_port ;;
                3) ufw_close_port ;;
                0) return 0 ;;
                *) print_error "无效选项" ;;
            esac
        fi

        echo ""
    done
}

# ============================================================================
# 主函数
# ============================================================================

main() {
    manage_firewall
}

main "$@"
exit 0

