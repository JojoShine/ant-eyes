#!/bin/bash

################################################################################
# ant-eyes - Crontab定时任务管理模块
# 功能：查看、添加、删除定时任务，支持常用模板
################################################################################

# 加载共享函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# ============================================================================
# Crontab管理功能
# ============================================================================

show_crontab_menu() {
    print_header "Crontab定时任务管理"
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}请选择操作:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}) 查看当前定时任务"
    echo -e "  ${GREEN}2${NC}) 添加新的定时任务"
    echo -e "  ${GREEN}3${NC}) 删除定时任务"
    echo -e "  ${GREEN}4${NC}) 编辑定时任务"
    echo -e "  ${GREEN}5${NC}) 查看常用模板"
    echo -e "  ${RED}0${NC}) 返回"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

show_crontab() {
    print_header "当前定时任务"

    local cron_list=$(crontab -l 2>/dev/null | grep -v "^#\|^$")
    if [ -n "$cron_list" ]; then
        local task_count=$(echo "$cron_list" | wc -l)
        print_info "当前定时任务数: $task_count"
        print_subheader "任务列表"
        echo "$cron_list" | while read -r line; do
            print_info "  $line"
        done
    else
        print_info "当前用户还未设置定时任务"
    fi
}

add_crontab() {
    print_header "添加定时任务"
    
    read -p "请输入crontab表达式 (分 时 日 月 周): " schedule
    read -p "请输入要执行的命令: " command
    
    local new_cron="$schedule $command"
    
    # 添加到crontab
    (crontab -l 2>/dev/null; echo "$new_cron") | crontab -
    
    if [ $? -eq 0 ]; then
        print_success "定时任务添加成功"
    else
        print_error "添加定时任务失败"
    fi
}

remove_crontab() {
    print_header "删除定时任务"
    
    print_warning "功能开发中，请使用 crontab -e 手动编辑"
}

show_templates() {
    print_header "常用Crontab模板"

    print_subheader "时间表达式说明"
    print_table_two_col "字段" "范围说明" \
        "分" "0-59" \
        "时" "0-23" \
        "日" "1-31" \
        "月" "1-12" \
        "周" "0-6 (0=日)"

    print_subheader "常用示例"
    print_info "每天00:00执行:        0 0 * * * /path/to/script"
    print_info "每周一03:00执行:      0 3 * * 1 /path/to/script"
    print_info "每月1号12:00执行:     0 12 1 * * /path/to/script"
    print_info "每小时执行:           0 * * * * /path/to/script"
    print_info "每5分钟执行:          */5 * * * * /path/to/script"
    print_info "工作日每天18:00执行:  0 18 * * 1-5 /path/to/script"
}

main() {
    if [ "$QUIET" -eq 1 ]; then
        show_crontab
        return
    fi
    
    show_crontab_menu
    
    read -p "请选择 [0-5]: " choice
    
    case $choice in
        1) show_crontab ;;
        2) add_crontab ;;
        3) remove_crontab ;;
        4) print_info "已打开crontab编辑器"; crontab -e ;;
        5) show_templates ;;
        0) print_info "返回主菜单" ;;
        *) print_error "无效选择" ;;
    esac
}

main "$@"
