#!/bin/bash

################################################################################
# ant-eyes - 系统安全审计检查模块
# 检查：SSH登录、暴力破解、用户账户、文件权限、可疑进程、系统更新等
################################################################################

# 加载共享函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# ============================================================================
# 系统安全审计检查
# ============================================================================

show_security_info() {
    print_header "系统安全审计检查"

    # 确定日志文件路径
    local auth_log=""
    if [ -f /var/log/secure ]; then
        auth_log="/var/log/secure"
    elif [ -f /var/log/auth.log ]; then
        auth_log="/var/log/auth.log"
    fi

    # ========== SSH登录安全检查 ==========
    print_subheader "SSH登录安全检查"

    if [ -f /etc/ssh/sshd_config ]; then
        local permit_root=$(grep "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}')
        local password_auth=$(grep "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}')
        local ssh_port=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}')

        print_table_two_col "配置项" "值" \
            "PermitRootLogin" "${permit_root:-默认}" \
            "PasswordAuthentication" "${password_auth:-默认}" \
            "SSH端口" "${ssh_port:-22}"

        [[ "$permit_root" == "no" ]] && print_success "Root直接登录已禁用" || print_warning "允许Root直接登录（不安全）"
        [[ "$password_auth" == "no" ]] && print_success "已禁用密码认证" || print_warning "密码认证已启用"
        [[ "$ssh_port" != "22" && -n "$ssh_port" ]] && print_success "SSH端口已修改" || print_info "SSH使用默认端口22"
    else
        print_warning "SSH配置文件不存在"
    fi

    # ========== SSH登录失败记录 ==========
    print_subheader "SSH登录失败统计"

    if [ -z "$auth_log" ] || [ ! -r "$auth_log" ]; then
        print_warning "无法读取认证日志（需要root权限）"
    else
        local fail_count=$(grep -i "failed password\|authentication failure" "$auth_log" 2>/dev/null | wc -l)
        if [ "$fail_count" -gt 0 ]; then
            print_warning "最近 $fail_count 条登录失败记录"
            grep -i "failed password\|authentication failure" "$auth_log" 2>/dev/null | tail -5 | while read -r line; do
                print_info "  $(echo $line | awk '{print $1,$2,$3}')"
            done
        else
            print_success "未发现SSH登录失败记录"
        fi
    fi

    # ========== 暴力破解攻击检测 ==========
    print_subheader "暴力破解攻击检测"

    if [ -n "$auth_log" ] && [ -r "$auth_log" ]; then
        # 统计每个IP的失败次数
        local brute_force=$(grep -i "failed password" "$auth_log" 2>/dev/null | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort | uniq -c | sort -rn | head -5)
        if [ -n "$brute_force" ]; then
            print_warning "检测到可疑的登录尝试："
            echo "$brute_force" | while read -r count ip; do
                if [ "$count" -gt 5 ]; then
                    print_error "  IP: $ip ($count 次失败)"
                else
                    print_warning "  IP: $ip ($count 次失败)"
                fi
            done
        else
            print_success "未检测到暴力破解迹象"
        fi
    fi

    # ========== 用户账户安全检查 ==========
    print_subheader "用户账户安全检查"

    # 检查空密码账户
    if [ -r /etc/shadow ]; then
        local empty_pass=$(awk -F: '($2 == "" || $2 == "!") {print $1}' /etc/shadow 2>/dev/null)
        if [ -n "$empty_pass" ]; then
            print_error "发现空密码或锁定账户："
            echo "$empty_pass" | while read -r user; do
                print_info "  - $user"
            done
        else
            print_success "未发现空密码账户"
        fi
    fi

    # 检查UID为0的账户（root权限）
    if [ -r /etc/passwd ]; then
        local uid_zero=$(awk -F: '($3 == 0) {print $1}' /etc/passwd)
        local uid_zero_count=$(echo "$uid_zero" | wc -l)
        if [ "$uid_zero_count" -gt 1 ]; then
            print_warning "发现多个UID=0的账户（root权限）："
            echo "$uid_zero" | while read -r user; do
                print_info "  - $user"
            done
        else
            print_success "仅有root账户拥有UID=0"
        fi

        # 系统用户总数
        local total_users=$(grep -c ":" /etc/passwd)
        print_info "系统用户总数：$total_users 个"
    fi

    # ========== 文件权限安全检查 ==========
    print_subheader "关键文件权限检查"

    local critical_files=(
        "/etc/passwd"
        "/etc/shadow"
        "/etc/sudoers"
        "/etc/ssh/sshd_config"
    )

    for file in "${critical_files[@]}"; do
        if [ -e "$file" ]; then
            local perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%p" "$file" 2>/dev/null | grep -o '..$')
            if [[ "$file" == *"shadow"* ]]; then
                if [[ "$perms" == "640" || "$perms" == "000" ]]; then
                    print_success "$file: $perms ✓"
                else
                    print_warning "$file: $perms (权限可能不安全)"
                fi
            elif [[ "$file" == *"sudoers"* ]]; then
                if [[ "$perms" == "440" ]]; then
                    print_success "$file: $perms ✓"
                else
                    print_warning "$file: $perms (权限可能不安全)"
                fi
            else
                print_info "$file: $perms"
            fi
        fi
    done

    # ========== Sudo执行记录 ==========
    print_subheader "Sudo执行记录（最近5条）"

    if [ -n "$auth_log" ] && [ -r "$auth_log" ]; then
        local sudo_logs=$(grep sudo "$auth_log" 2>/dev/null | grep "COMMAND=" | tail -5)
        if [ -n "$sudo_logs" ]; then
            echo "$sudo_logs" | while read -r line; do
                print_info "  $(echo $line | awk '{print $1,$2,$3}')"
            done
        else
            print_info "未找到sudo执行记录"
        fi
    fi

    # ========== 可疑进程检查 ==========
    print_subheader "可疑进程检查"

    if command_exists ps; then
        # 检查常见挖矿程序
        local suspicious_procs=$(ps aux 2>/dev/null | grep -iE "xmrig|minerd|ccminer|cgminer|bitminer|nanopool" | grep -v grep)
        if [ -n "$suspicious_procs" ]; then
            print_error "检测到可疑挖矿进程："
            echo "$suspicious_procs" | while read -r line; do
                print_error "  $line"
            done
        else
            print_success "未发现可疑挖矿进程"
        fi
    fi

    # ========== 防火墙状态 ==========
    print_subheader "防火墙状态"

    local fw_status="未检测"
    if command_exists firewall-cmd; then
        if systemctl is-active firewalld >/dev/null 2>&1; then
            print_success "firewalld 正在运行"
            fw_status="firewalld已启用"
        else
            print_warning "firewalld 未运行"
            fw_status="firewalld未运行"
        fi
    elif command_exists ufw; then
        local ufw_status=$(ufw status 2>/dev/null | head -1)
        if [[ "$ufw_status" == *"active"* ]]; then
            print_success "ufw 正在运行"
            fw_status="ufw已启用"
        else
            print_warning "ufw 未运行"
            fw_status="ufw未运行"
        fi
    else
        print_warning "未检测到防火墙"
        fw_status="未检测到防火墙"
    fi

    # ========== SELinux状态 ==========
    print_subheader "SELinux状态"

    if command_exists getenforce; then
        local selinux_status=$(getenforce 2>/dev/null)
        case "$selinux_status" in
            Enforcing)
                print_success "SELinux: Enforcing（强制模式）"
                ;;
            Permissive)
                print_warning "SELinux: Permissive（宽容模式）"
                ;;
            Disabled)
                print_warning "SELinux: Disabled（已禁用）"
                ;;
            *)
                print_info "SELinux: 状态未知"
                ;;
        esac
    else
        print_info "SELinux 未安装或不支持"
    fi

    # ========== 系统更新状态 ==========
    print_subheader "系统更新状态"

    if command_exists yum; then
        local updates=$(yum check-update 2>/dev/null | tail -1 | awk '{print $1}')
        if [[ "$updates" =~ ^[0-9]+$ ]] && [ "$updates" -gt 0 ]; then
            print_warning "有 $updates 个可用更新（建议立即更新）"
        else
            print_success "系统已是最新"
        fi
    elif command_exists apt; then
        local updates=$(apt list --upgradable 2>/dev/null | grep upgradable | wc -l)
        if [ "$updates" -gt 0 ]; then
            print_warning "有 $updates 个可用更新"
        else
            print_success "系统已是最新"
        fi
    else
        print_info "无法检测系统更新（包管理器不可用）"
    fi

    # ========== 异常登录检查 ==========
    print_subheader "异常登录检查"

    if [ -n "$auth_log" ] && [ -r "$auth_log" ]; then
        local invalid_users=$(grep -i "invalid user" "$auth_log" 2>/dev/null | tail -5 | wc -l)
        if [ "$invalid_users" -gt 0 ]; then
            print_warning "检测到 $invalid_users 条异常登录尝试"
        else
            print_success "未检测到异常登录尝试"
        fi
    fi

    # ========== SUID文件检查 ==========
    print_subheader "SUID文件检查（前5个）"

    local suid_count=$(find / -perm -4000 2>/dev/null | wc -l)
    if [ "$suid_count" -gt 0 ]; then
        print_info "系统中的SUID文件总数：$suid_count 个"
        print_info "前5个SUID文件："
        find / -perm -4000 2>/dev/null | head -5 | while read -r file; do
            print_info "  $file"
        done
    else
        print_info "未发现SUID文件"
    fi

    # ========== 安全摘要 ==========
    echo ""
    print_subheader "安全状态摘要"
    print_table_two_col "检查项" "状态" \
        "防火墙" "$fw_status" \
        "SSH配置" "已检查" \
        "用户账户" "已检查" \
        "文件权限" "已检查" \
        "系统更新" "已检查"
}

# ============================================================================
# 异常行为检测
# ============================================================================

check_suspicious_behavior() {
    print_header "异常行为检测"

    # ========== 异常文件上传检查 ==========
    print_subheader "异常文件上传检查"

    # 检查tmp目录中的可执行文件
    if [ -d /tmp ]; then
        local suspicious_files=$(find /tmp -type f \( -name "*.sh" -o -name "*.py" -o -name "*.pl" \) -mtime -1 2>/dev/null)
        if [ -n "$suspicious_files" ]; then
            print_warning "检测到最近24小时内在 /tmp 上传的脚本文件："
            echo "$suspicious_files" | while read -r file; do
                print_warning "  $file ($(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1,2 || stat -f %Sm "$file" 2>/dev/null))"
            done
        else
            print_success "未检测到可疑的临时脚本文件"
        fi
    fi

    # 检查home目录中的隐藏脚本
    local home_suspicious=$(find /home /root -name ".*" -type f \( -name "*.sh" -o -name "*.py" \) 2>/dev/null | head -5)
    if [ -n "$home_suspicious" ]; then
        print_warning "检测到home目录中的隐藏脚本文件："
        echo "$home_suspicious" | while read -r file; do
            print_warning "  $file"
        done
    else
        print_success "未检测到可疑的隐藏脚本"
    fi

    # ========== 异常网络连接检查 ==========
    print_subheader "异常网络连接检查"

    if command_exists netstat; then
        local listening_ports=$(netstat -tlnp 2>/dev/null | grep LISTEN | awk '{print $4}' | cut -d: -f2 | sort -u)
        local unknown_ports=""

        # 检查非常见端口的监听
        for port in $listening_ports; do
            case "$port" in
                22|25|53|80|110|143|443|465|587|993|995|3306|5432|6379|8080|27017)
                    # 这些是常见端口，跳过
                    ;;
                *)
                    if [[ "$port" =~ ^[0-9]+$ ]]; then
                        unknown_ports="$unknown_ports $port"
                    fi
                    ;;
            esac
        done

        if [ -n "$unknown_ports" ]; then
            print_warning "检测到非常见端口的监听："
            echo "$unknown_ports" | tr ' ' '\n' | while read -r port; do
                [ -n "$port" ] && print_warning "  端口 $port"
            done
        else
            print_success "未检测到非常见端口的异常监听"
        fi
    fi

    # ========== 异常进程检查 ==========
    print_subheader "异常进程行为检查"

    if command_exists ps; then
        # 检查从tmp目录运行的进程
        local tmp_processes=$(ps aux 2>/dev/null | grep -E "/tmp/|/var/tmp/" | grep -v grep | grep -v "^root")
        if [ -n "$tmp_processes" ]; then
            print_warning "检测到从临时目录运行的进程："
            echo "$tmp_processes" | while read -r line; do
                print_warning "  $(echo $line | awk '{print $11}')"
            done
        else
            print_success "未检测到从临时目录运行的可疑进程"
        fi

        # 检查没有关联进程的网络连接
        local orphan_connections=$(netstat -tulnp 2>/dev/null | grep "ESTABLISHED" | grep -E "\(no name\)|\(-\)" | wc -l)
        if [ "$orphan_connections" -gt 0 ]; then
            print_warning "检测到 $orphan_connections 个孤立的网络连接"
        else
            print_success "未检测到孤立的网络连接"
        fi
    fi

    # ========== 文件系统异常检查 ==========
    print_subheader "文件系统异常检查"

    # 检查最近修改的重要文件
    local modified_critical=$(find /etc /boot /usr/bin /usr/sbin -type f -mtime -1 2>/dev/null | grep -E "^/etc/(passwd|shadow|sudoers|ssh)" | head -10)
    if [ -n "$modified_critical" ]; then
        print_warning "检测到最近24小时内修改的关键文件："
        echo "$modified_critical" | while read -r file; do
            print_warning "  $file ($(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1,2 || stat -f %Sm "$file" 2>/dev/null))"
        done
    else
        print_success "关键文件未被最近修改"
    fi

    # ========== 环境变量异常检查 ==========
    print_subheader "系统环境变量检查"

    # 检查LD_PRELOAD和其他注入风险的变量
    local suspicious_env=$(env 2>/dev/null | grep -E "^LD_PRELOAD=|^LD_LIBRARY_PATH=|^LD_AUDIT=|^PROMPT_COMMAND=")
    if [ -n "$suspicious_env" ]; then
        print_warning "检测到可疑的环境变量设置："
        echo "$suspicious_env" | while read -r var; do
            print_warning "  $var"
        done
    else
        print_success "未检测到可疑的环境变量"
    fi

    # ========== Cron任务异常检查 ==========
    print_subheader "定时任务异常检查"

    if [ -d /var/spool/cron ] || [ -d /var/spool/cron/crontabs ]; then
        local cron_dir="/var/spool/cron"
        [ -d /var/spool/cron/crontabs ] && cron_dir="/var/spool/cron/crontabs"

        local suspicious_cron=$(find "$cron_dir" -type f 2>/dev/null | while read -r file; do
            grep -E "\(/tmp/\|nc \|bash -i\|/dev/tcp\|wget\|curl" "$file" 2>/dev/null
        done)

        if [ -n "$suspicious_cron" ]; then
            print_warning "检测到可疑的定时任务："
            echo "$suspicious_cron" | while read -r line; do
                print_warning "  $line"
            done
        else
            print_success "未检测到可疑的定时任务"
        fi
    fi

    # ========== 日志篡改检查 ==========
    print_subheader "日志完整性检查"

    local log_anomalies=0
    for logfile in /var/log/auth.log /var/log/secure /var/log/messages; do
        if [ -f "$logfile" ]; then
            # 检查日志是否有非预期的间隙
            local log_entries=$(grep -c "." "$logfile" 2>/dev/null || echo "0")
            if [ "$log_entries" -lt 10 ]; then
                print_warning "$logfile 日志条目过少（$log_entries 条）- 可能被篡改或清理"
                ((log_anomalies++))
            fi
        fi
    done

    if [ "$log_anomalies" -eq 0 ]; then
        print_success "日志完整性检查正常"
    fi

    # ========== SSH密钥异常检查 ==========
    print_subheader "SSH密钥安全检查"

    local suspicious_keys=0
    for user_dir in /home/* /root; do
        if [ -d "$user_dir/.ssh" ]; then
            local auth_keys="$user_dir/.ssh/authorized_keys"
            if [ -f "$auth_keys" ]; then
                local key_count=$(grep -c "^ssh-" "$auth_keys" 2>/dev/null || echo "0")
                if [ "$key_count" -eq 0 ]; then
                    print_info "$(basename $user_dir): 无SSH公钥"
                else
                    # 检查是否有非标准格式的密钥
                    local odd_keys=$(grep -v "^ssh-" "$auth_keys" | grep -v "^#" | grep -v "^$" | wc -l)
                    if [ "$odd_keys" -gt 0 ]; then
                        print_warning "$(basename $user_dir): 检测到 $odd_keys 个非标准格式的SSH密钥"
                        ((suspicious_keys++))
                    else
                        print_success "$(basename $user_dir): SSH密钥正常（$key_count 个）"
                    fi
                fi
            fi
        fi
    done
}

# ============================================================================
# 安全摘要和建议
# ============================================================================

show_security_summary() {
    print_subheader "安全状态摘要"

    print_table_two_col "检查项" "状态" \
        "防火墙" "已检查" \
        "SSH配置" "已检查" \
        "用户账户" "已检查" \
        "异常行为" "已检查" \
        "文件完整性" "已检查"

    echo ""
    print_info "📌 安全建议："
    print_info "1. 定期检查SSH配置，禁用密码认证"
    print_info "2. 监视日志文件，检测异常活动"
    print_info "3. 定期审查用户权限和SUID文件"
    print_info "4. 启用防火墙并配置适当的规则"
    print_info "5. 及时安装系统补丁和安全更新"
    print_info "6. 监视网络连接和异常进程"
    print_info "7. 定期备份重要文件和配置"
    echo ""
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
            --basic)
                # 仅显示基本信息
                show_security_info
                return 0
                ;;
            --behavior)
                # 仅显示异常行为检测
                check_suspicious_behavior
                return 0
                ;;
            *)
                shift
                ;;
        esac
    done

    # 默认运行所有检查
    show_security_info
    echo ""
    check_suspicious_behavior
    echo ""
    show_security_summary
}

# 执行主函数
main "$@"
exit 0
