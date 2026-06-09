#!/bin/bash

################################################################################
# ant-eyes - Crontab定时任务管理模块
# 功能：查看、添加、删除、编辑定时任务，提供常用模板
################################################################################

# 加载共享函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# ============================================================================
# 定时任务管理
# ============================================================================

manage_crontab() {
    print_header "Crontab定时任务管理"

    # 显示主线流程说明（仅进入时显示一次）
    print_subheader "定时任务工作流程"
    cat << 'EOF'
Crontab定时任务的完整流程：

【添加定时任务流程】
1️⃣  查看现有任务 → 了解当前已有的定时任务
2️⃣  选择合适模板 → 从常用模板或自定义选择
3️⃣  输入任务命令 → 指定要定时执行的脚本/命令
4️⃣  确认任务添加 → 系统会验证并添加到crontab

【常见任务类型】
✓ 每日备份 (凌晨2点)         : 0 2 * * *
✓ 每周清理 (周日凌晨3点)      : 0 3 * * 0
✓ 每月检查 (1号凌晨0点)       : 0 0 1 * *
✓ 每小时执行 (每小时整点)     : 0 * * * *
✓ 自定义频率 (灵活设置)       : 自己指定时间表达式

【编辑和删除】
✓ 编辑任务: 使用编辑器修改crontab
✓ 删除任务: 按编号删除不需要的任务
✓ 查看模板: 参考8个常用的任务模板

EOF

    while true; do
        echo ""
        # 显示当前定时任务
        print_subheader "当前定时任务"
        if [ -f "$HOME/.crontab" ] || command_exists crontab; then
            local current_crontab=$(crontab -l 2>/dev/null)
            if [ -n "$current_crontab" ]; then
                echo "$current_crontab" | while read -r line; do
                    if [[ ! "$line" =~ ^# ]]; then
                        print_info "$line"
                    fi
                done
            else
                print_info "当前用户无定时任务"
            fi
        else
            print_warning "无法访问crontab（需要root权限）"
        fi

        echo ""
        print_subheader "定时任务管理选项"
        echo "1. 查看详细定时任务"
        echo "2. 添加新的定时任务"
        echo "3. 删除定时任务"
        echo "4. 编辑定时任务"
        echo "5. 查看常用模板"
        echo "0. 返回主菜单"
        echo ""

        read -p "请选择操作 (0-5): " cron_choice

        case $cron_choice in
            1)
                print_subheader "详细定时任务列表"
                if crontab -l 2>/dev/null; then
                    :
                else
                    print_error "无法读取定时任务（可能需要root权限）"
                fi
                ;;
            2)
                print_subheader "添加新的定时任务"
                add_crontab_task
                ;;
            3)
                print_subheader "删除定时任务"
                delete_crontab_task
                ;;
            4)
                print_subheader "编辑定时任务"
                crontab -e 2>/dev/null || print_error "无法编辑定时任务"
                ;;
            5)
                print_subheader "常用定时任务模板"
                show_crontab_templates
                ;;
            0)
                return 0
                ;;
            *)
                print_error "无效的选择"
                ;;
        esac
    done
}

# 添加定时任务
add_crontab_task() {
    echo "Crontab格式: 分钟(0-59) 小时(0-23) 日期(1-31) 月份(1-12) 星期(0-6) 命令"
    echo ""
    echo "快速选项:"
    echo "1. 每天备份数据库"
    echo "2. 每周清理日志"
    echo "3. 每月执行更新检查"
    echo "4. 每小时执行监控脚本"
    echo "5. 自定义定时任务"
    echo ""
    read -p "请选择 (1-5): " template_choice

    local cron_expression=""
    local cron_command=""

    case $template_choice in
        1)
            # 每天凌晨2点执行备份
            cron_expression="0 2 * * *"
            read -p "请输入备份命令 (如: /usr/local/bin/backup.sh): " cron_command
            ;;
        2)
            # 每周日凌晨3点清理日志
            cron_expression="0 3 * * 0"
            read -p "请输入日志清理命令 (如: rm /var/log/*.log): " cron_command
            ;;
        3)
            # 每月1号执行检查
            cron_expression="0 0 1 * *"
            read -p "请输入更新检查命令 (如: yum check-update): " cron_command
            ;;
        4)
            # 每小时执行
            cron_expression="0 * * * *"
            read -p "请输入监控命令: " cron_command
            ;;
        5)
            echo ""
            print_info "请输入完整的crontab表达式"
            print_info "格式: 分钟 小时 日期 月份 星期 命令"
            print_info "例如: 0 2 * * * /usr/local/bin/backup.sh"
            read -p "请输入: " full_expression

            # 验证表达式格式
            local parts=$(echo "$full_expression" | awk '{print NF}')
            if [ "$parts" -lt 6 ]; then
                print_error "格式错误：缺少命令部分"
                return 1
            fi

            cron_expression=$(echo "$full_expression" | awk '{print $1, $2, $3, $4, $5}')
            cron_command=$(echo "$full_expression" | cut -d' ' -f6-)
            ;;
        *)
            print_error "无效的选择"
            return 1
            ;;
    esac

    if [ -z "$cron_command" ]; then
        print_error "命令不能为空"
        return 1
    fi

    # 添加到crontab
    local cron_entry="$cron_expression $cron_command"
    (crontab -l 2>/dev/null || echo "") | grep -F "$cron_entry" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_warning "此任务已存在"
        return 1
    fi

    (crontab -l 2>/dev/null || echo "") | { cat; echo "$cron_entry"; } | crontab - 2>/dev/null
    if [ $? -eq 0 ]; then
        print_success "定时任务已添加: $cron_entry"
    else
        print_error "添加定时任务失败（可能需要root权限）"
    fi
}

# 删除定时任务
delete_crontab_task() {
    local crontab_content=$(crontab -l 2>/dev/null)
    if [ -z "$crontab_content" ]; then
        print_info "当前无定时任务"
        return
    fi

    echo "当前定时任务:"
    local line_num=1
    echo "$crontab_content" | while read -r line; do
        if [[ ! "$line" =~ ^# ]] && [ -n "$line" ]; then
            echo "$line_num. $line"
            ((line_num++))
        fi
    done

    read -p "请输入要删除的任务编号: " delete_num

    if ! [[ "$delete_num" =~ ^[0-9]+$ ]]; then
        print_error "请输入有效的编号"
        return 1
    fi

    # 删除指定行
    local counter=1
    (crontab -l 2>/dev/null || echo "") | while read -r line; do
        if [[ "$line" =~ ^# ]]; then
            echo "$line"
        elif [ -n "$line" ]; then
            if [ "$counter" -ne "$delete_num" ]; then
                echo "$line"
            fi
            ((counter++))
        fi
    done | crontab - 2>/dev/null

    print_success "定时任务已删除"
}

# 显示crontab模板
show_crontab_templates() {
    cat << 'EOF'
常用定时任务模板:

1. 每天备份MySQL数据库（凌晨2点）
   0 2 * * * /usr/local/bin/backup_mysql.sh

2. 每周执行文件清理（每周日凌晨3点）
   0 3 * * 0 find /tmp -type f -mtime +7 -delete

3. 每月检查系统更新（每月1号0点）
   0 0 1 * * yum check-update

4. 每小时执行系统监控（每小时整点）
   0 * * * * /usr/local/bin/system_monitor.sh

5. 每天定时同步时间（每天凌晨1点）
   0 1 * * * ntpdate -u ntp.aliyun.com

6. 每30分钟检查服务状态
   */30 * * * * /usr/local/bin/check_service.sh

7. 工作日每小时执行任务（周一到周五）
   0 * * * 1-5 /usr/local/bin/work_task.sh

8. 每天午夜重启应用（凌晨0点）
   0 0 * * * /usr/local/bin/restart_app.sh

Crontab时间表示法:
  分钟: 0-59
  小时: 0-23
  日期: 1-31
  月份: 1-12 (1=1月, 12=12月)
  星期: 0-6 (0=星期日, 1-6=星期一到星期六)

特殊符号:
  *     - 任何时间
  */n   - 每n个单位
  n-m   - 从n到m
  n,m   - n或m
EOF
}

################################################################################
# NTP/Chrony时间同步管理模块
################################################################################

# ============================================================================
# 主函数
# ============================================================================

main() {
    manage_crontab
}

main "$@"
exit 0
