#!/bin/bash

################################################################################
# ant-eyes - 常用组件运行状态检测模块
# 检查：Oracle、MySQL、Redis、Kafka等应用运行状态
################################################################################

# 加载共享函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# ============================================================================
# 常用组件检测
# ============================================================================

check_component() {
    local component=$1
    local process=$2
    
    if pgrep -x "$process" > /dev/null; then
        print_success "$component 正在运行"
        return 0
    else
        print_warning "$component 未运行"
        return 1
    fi
}

show_component_status() {
    print_header "常用组件运行状态检测"

    local components=(
        "MySQL:mysqld"
        "PostgreSQL:postgres"
        "Redis:redis-server"
        "MongoDB:mongod"
        "Kafka:kafka"
        "Nginx:nginx"
        "Apache:httpd"
        "Docker:docker"
        "Elasticsearch:elasticsearch"
        "Zookeeper:zkServer"
    )

    print_subheader "应用运行状态"

    local running_count=0
    local total_count=${#components[@]}

    for item in "${components[@]}"; do
        IFS=':' read -r name process <<< "$item"
        if pgrep -x "$process" > /dev/null; then
            print_success "$name"
            ((running_count++))
        else
            print_warning "$name"
        fi
    done

    print_info "运行中的组件: $running_count/$total_count"

    # 使用 systemctl 检查服务状态（如果可用）
    if command_exists systemctl; then
        print_subheader "系统服务状态"

        local services=("mysql" "postgresql" "redis" "mongodb" "nginx" "docker" "elasticsearch")
        local enabled_count=0

        for service in "${services[@]}"; do
            if systemctl is-enabled "$service" 2>/dev/null | grep -q enabled; then
                print_info "$service: 已启用"
                ((enabled_count++))
            fi
        done

        [ $enabled_count -gt 0 ] && print_info "已启用的服务: $enabled_count 个"
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

    show_component_status
}

# 执行主函数
main "$@"
