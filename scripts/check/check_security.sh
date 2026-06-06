#!/bin/bash

################################################################################
# ant-eyes - 系统异常访问检查模块
# 检查：SSH登录失败、暴力破解、可疑连接等安全事件
################################################################################

# 加载共享函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# ============================================================================
# 系统异常访问检查模块
# ============================================================================

show_access_info() {
    print_header "系统异常访问信息"

    # 确定日志文件路径（不同系统可能不同）
    local auth_log=""
    if [ -f /var/log/secure ]; then
        auth_log="/var/log/secure"
    elif [ -f /var/log/auth.log ]; then
        auth_log="/var/log/auth.log"
    fi

    if [ -z "$auth_log" ] || [ ! -r "$auth_log" ]; then
        print_warning "无法读取认证日志文件，需要root权限"
        return
    fi

    # SSH登录失败记录统计
    print_subheader "SSH登录失败记录统计"
    if [ -f "$auth_log" ]; then
        local failed_logins=$(grep -i "failed password\|authentication failure" "$auth_log" | tail -20)
        if [ -n "$failed_logins" ]; then
            local fail_count=$(echo "$failed_logins" | wc -l)
            print_warning "发现 $fail_count 条失败登录记录"
            echo "$failed_logins" | awk '{print $1,$2,$3}' | while read -r line; do
                print_info "  $line"
            done
        else
            print_success "未发现失败登录记录"
        fi
    fi

    # 可疑访问检查（端口扫描等）
    print_subheader "异常SSH连接检查"
    if [ -f "$auth_log" ]; then
        local suspicious_ssh=$(grep -i "invalid user\|accepted publickey\|disconnected" "$auth_log" | tail -10)
        if [ -n "$suspicious_ssh" ]; then
            print_warning "检测到 $(echo "$suspicious_ssh" | wc -l) 条异常SSH连接记录"
            echo "$suspicious_ssh" | while read -r line; do
                print_info "  $(echo $line | awk '{print $1,$2,$3}')"
            done
        else
            print_success "未检测到异常SSH连接"
        fi
    fi

    # 检查sudo日志
    print_subheader "Sudo执行记录（最近5条）"
    if [ -f /var/log/auth.log ]; then
        local sudo_logs=$(grep sudo /var/log/auth.log | grep "COMMAND=" | tail -5)
        if [ -n "$sudo_logs" ]; then
            echo "$sudo_logs" | awk '{print $1,$2,$3}' | while read -r line; do
                print_info "  $line"
            done
        else
            print_info "未找到sudo执行记录"
        fi
    elif [ -f /var/log/secure ]; then
        local sudo_logs=$(grep sudo /var/log/secure | grep "COMMAND=" | tail -5)
        if [ -n "$sudo_logs" ]; then
            echo "$sudo_logs" | awk '{print $1,$2,$3}' | while read -r line; do
                print_info "  $line"
            done
        fi
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

    show_access_info
}

# 执行主函数
main "$@"
