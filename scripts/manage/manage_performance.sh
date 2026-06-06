#!/bin/bash

################################################################################
# ant-eyes - 磁盘I/O性能检查模块
# 功能：iostat实时监控、fio基准测试、SMART健康检查
################################################################################

# 加载共享函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# ============================================================================
# 磁盘性能检查
# ============================================================================

check_iostat() {
    print_header "磁盘I/O性能监控"

    if ! command_exists iostat; then
        print_warning "iostat未安装，请安装sysstat包"
        return 1
    fi

    print_subheader "磁盘I/O统计（3次采样，间隔1秒）"
    print_info "采集中..."
    iostat -x -z 1 3 | tail -n +4 | while read -r line; do
        print_info "  $line"
    done
}

check_fio() {
    print_header "磁盘基准测试"
    
    if ! command_exists fio; then
        print_warning "fio未安装"
        print_info "安装命令: sudo yum install -y fio   # CentOS"
        print_info "或: sudo apt-get install -y fio     # Ubuntu"
        return 1
    fi
    
    read -p "请输入要测试的目录或磁盘 [默认: /]: " test_path
    test_path=${test_path:-.}
    
    print_info "开始运行fio基准测试..."
    fio --name=test --filename=$test_path --rw=randrw --size=1G --iodepth=16 --numjobs=4 --group_reporting
}

check_smart() {
    print_header "磁盘SMART健康状态"
    
    if ! command_exists smartctl; then
        print_warning "smartctl未安装"
        print_info "安装命令: sudo yum install -y smartmontools   # CentOS"
        print_info "或: sudo apt-get install -y smartmontools     # Ubuntu"
        return 1
    fi
    
    print_subheader "可用磁盘列表"
    lsblk -d -o NAME | tail -n +2 | while read -r disk; do
        echo "/dev/$disk"
    done
    
    read -p "请输入要检查的磁盘 (如: /dev/sda): " disk
    
    if [ ! -e "$disk" ]; then
        print_error "磁盘不存在: $disk"
        return 1
    fi
    
    smartctl -H "$disk"
}

show_menu() {
    print_header "磁盘I/O性能检查"
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}请选择操作:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}) iostat 磁盘I/O性能监控"
    echo -e "  ${GREEN}2${NC}) fio 磁盘基准测试"
    echo -e "  ${GREEN}3${NC}) SMART 健康检查"
    echo -e "  ${RED}0${NC}) 返回"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

main() {
    if [ "$QUIET" -eq 1 ]; then
        check_iostat
        return
    fi
    
    show_menu
    
    read -p "请选择 [0-3]: " choice
    
    case $choice in
        1) check_iostat ;;
        2) check_fio ;;
        3) check_smart ;;
        0) print_info "返回主菜单" ;;
        *) print_error "无效选择" ;;
    esac
}

main "$@"
