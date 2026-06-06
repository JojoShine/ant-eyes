#!/bin/bash

################################################################################
# ant-eyes - 系统基本信息检查模块
# 检查：CPU、内存、磁盘、网络、运行时间等系统关键信息
################################################################################

# 加载共享函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# ============================================================================
# 系统基本信息模块
# ============================================================================

show_system_info() {
    print_header "系统基本信息"

    # 操作系统信息
    print_subheader "操作系统"
    print_table_two_col "属性" "值" \
        "系统名称" "$OS_NAME" \
        "系统版本" "$OS_VERSION" \
        "内核版本" "$(uname -r)" \
        "系统架构" "$(uname -m)"

    # 主机名和IP地址
    print_subheader "主机信息"
    local hostname_val=$(hostname)
    local hostname_fqdn=$hostname_val
    if command_exists hostname; then
        hostname_fqdn=$(hostname -f 2>/dev/null || hostname)
    fi

    local ip_addr="未检测到"
    if command_exists ip; then
        ip_addr=$(ip -4 addr show | grep -o 'inet [0-9.]*' | awk '{print $2}' | grep -v '127.0.0.1' | head -1)
        ip_addr=${ip_addr:-未检测到}
    elif command_exists ifconfig; then
        ip_addr=$(ifconfig | grep -o 'inet [0-9.]*' | awk '{print $2}' | grep -v '127.0.0.1' | head -1)
        ip_addr=${ip_addr:-未检测到}
    fi

    print_table_two_col "属性" "值" \
        "主机名" "$hostname_val" \
        "完整域名" "$hostname_fqdn" \
        "主IP地址" "$ip_addr"

    # CPU信息
    print_subheader "CPU信息"
    if [ -f /proc/cpuinfo ]; then
        local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^[ \t]*//')
        local cpu_cores=$(grep -c "^processor" /proc/cpuinfo)
        local cpu_usage="未知"

        if command_exists top; then
            cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
        fi

        print_table_two_col "属性" "值" \
            "CPU型号" "${cpu_model:-未知}" \
            "CPU核心数" "$cpu_cores" \
            "CPU使用率" "$cpu_usage"
    fi

    # 内存信息
    print_subheader "内存信息"
    if [ -f /proc/meminfo ]; then
        local mem_total=$(grep MemTotal /proc/meminfo | awk '{printf "%.2f GB", $2/1024/1024}')
        local mem_free=$(grep MemAvailable /proc/meminfo | awk '{printf "%.2f GB", $2/1024/1024}')
        local mem_used=$(free -h | awk '/^Mem:/ {print $3}')
        local mem_percent=$(free | awk '/^Mem:/ {printf "%.1f%%", $3/$2*100}')

        print_table_two_col "属性" "值" \
            "总内存" "$mem_total" \
            "已用内存" "$mem_used" \
            "可用内存" "$mem_free" \
            "内存使用率" "$mem_percent"
    fi

    # 磁盘信息
    print_subheader "磁盘清单"
    if command_exists lsblk; then
        print_info "物理磁盘设备:"
        lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,MODEL 2>/dev/null | head -20 | while read -r line; do
            print_info "  $line"
        done
    fi

    # 磁盘使用情况
    print_subheader "磁盘使用情况"
    if command_exists df; then
        while IFS= read -r line; do
            local usage=$(echo "$line" | awk '{print $5}' | tr -d '%')
            if [ -n "$usage" ] && [ "$usage" -gt 80 ] 2>/dev/null; then
                print_warning "$line"
            else
                print_info "$line"
            fi
        done < <(df -h | grep -vE '^Filesystem|tmpfs|cdrom|loop' | awk '{printf "%-20s %8s %8s %8s %6s %s\n", $1, $2, $3, $4, $5, $6}')
    fi

    # 系统运行时间
    print_subheader "系统运行时间"
    if command_exists uptime; then
        local uptime_info=$(uptime -p 2>/dev/null || uptime | awk -F'( |,|:)+' '{print $6,$7",",$8,"hours,",$9,"minutes"}')
        local load_avg=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//')

        print_table_two_col "属性" "值" \
            "运行时长" "$uptime_info" \
            "平均负载" "$load_avg"
    fi

    # 登录用户
    print_subheader "当前登录用户"
    if command_exists who; then
        local login_count=$(who | wc -l)
        print_info "登录会话数: $login_count"
        who | while read -r line; do
            print_info "  $line"
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

    show_system_info
}

# 执行主函数
main "$@"
