#!/bin/bash

################################################################################
# ant-eyes - 系统服务部署信息模块
# 检查：监听端口、Docker容器状态、运行中的服务
################################################################################

# 加载共享函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# ============================================================================
# 系统服务部署信息
# ============================================================================

show_service_info() {
    print_header "系统服务部署信息"

    # 监听端口统计
    print_subheader "监听端口列表"
    local port_count=0
    if command_exists ss; then
        while read -r line; do
            local addr=$(echo "$line" | awk '{print $4}')
            local port=$(echo "$addr" | cut -d: -f2 | rev | cut -d: -f1 | rev)
            # 简化端口描述（无需关联数组）
            local desc="服务"
            case "$port" in
                22) desc="SSH" ;;
                25|465|587) desc="邮件服务" ;;
                53) desc="DNS" ;;
                80|8080|8000) desc="HTTP Web" ;;
                443|8443) desc="HTTPS Web" ;;
                3306) desc="MySQL" ;;
                5432) desc="PostgreSQL" ;;
                6379) desc="Redis" ;;
                27017) desc="MongoDB" ;;
                *) desc="其他服务" ;;
            esac
            print_info "$addr - $desc"
        done < <(ss -tlnp 2>/dev/null | tail -n +2)
        port_count=$(ss -tln 2>/dev/null | tail -n +2 | wc -l)
    elif command_exists netstat; then
        while read -r line; do
            local addr=$(echo "$line" | awk '{print $4}')
            local port=$(echo "$addr" | rev | cut -d: -f1 | rev)
            # 简化端口描述
            local desc="服务"
            case "$port" in
                22) desc="SSH" ;;
                25|465|587) desc="邮件服务" ;;
                53) desc="DNS" ;;
                80|8080|8000) desc="HTTP Web" ;;
                443|8443) desc="HTTPS Web" ;;
                3306) desc="MySQL" ;;
                5432) desc="PostgreSQL" ;;
                6379) desc="Redis" ;;
                27017) desc="MongoDB" ;;
                *) desc="其他服务" ;;
            esac
            print_info "$addr - $desc"
        done < <(netstat -tln 2>/dev/null | grep LISTEN)
        port_count=$(netstat -tln 2>/dev/null | grep LISTEN | wc -l)
    fi
    [ $port_count -gt 0 ] && print_info "监听中的端口: $port_count 个"

    # Docker容器状态
    print_subheader "Docker容器状态"
    if command_exists docker && [ -S /var/run/docker.sock ]; then
        local running=$(docker ps --filter "status=running" 2>/dev/null | tail -n +2 | wc -l)
        local total=$(docker ps -a 2>/dev/null | tail -n +2 | wc -l)
        print_table_two_col "状态" "数量" \
            "运行中的容器" "$running" \
            "总容器数" "$total"

        if [ $running -gt 0 ]; then
            print_info "运行中的容器："
            docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | tail -n +2 | while read -r line; do
                print_info "  $line"
            done
        fi
    else
        print_info "Docker未安装或无权限访问"
    fi

    # 运行中的服务
    print_subheader "系统服务摘要"
    if command_exists systemctl; then
        local active_services=$(systemctl list-units --type=service --state=running --no-pager 2>/dev/null | grep -c "\.service" || echo "0")
        print_table_two_col "属性" "值" \
            "活跃的系统服务" "$active_services"

        print_info "运行中的服务（前10个）："
        systemctl list-units --type=service --state=running --no-pager 2>/dev/null | \
            grep -E "\.service" | head -10 | awk '{print $1}' | while read -r service; do
            print_info "  $service"
        done
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

    show_service_info
    return 0
}

# 执行主函数
main "$@"
exit 0
