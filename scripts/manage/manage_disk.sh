#!/bin/bash

################################################################################
# ant-eyes - 磁盘分区挂载工具模块
# 功能：MBR/GPT分区识别、挂载、文件系统管理
################################################################################

# 加载共享函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# ============================================================================
# 磁盘分区管理
# ============================================================================

show_partition_info() {
    print_header "磁盘分区信息"

    print_subheader "物理磁盘"
    local disk_count=0
    if command_exists lsblk; then
        lsblk -d -o NAME,SIZE,TYPE 2>/dev/null | tail -n +2 | while read -r line; do
            print_info "  $line"
        done
        disk_count=$(lsblk -d -o NAME 2>/dev/null | tail -n +2 | wc -l)
        print_info "物理磁盘总数: $disk_count"
    fi

    print_subheader "磁盘分区"
    if command_exists lsblk; then
        lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null | grep part | while read -r line; do
            print_info "  $line"
        done
    fi

    print_subheader "磁盘使用情况"
    print_info "文件系统使用情况:"
    if command_exists df; then
        df -h 2>/dev/null | grep -vE '^Filesystem|tmpfs|cdrom|loop' | while read -r line; do
            local usage=$(echo "$line" | awk '{print $5}' | tr -d '%')
            if [ -n "$usage" ] && [ "$usage" -gt 80 ] 2>/dev/null; then
                print_warning "$line"
            else
                print_info "  $line"
            fi
        done
    fi
}

mount_disk() {
    print_header "挂载磁盘分区"
    
    if [ $(id -u) -ne 0 ]; then
        print_error "需要root权限执行此操作"
        return 1
    fi
    
    read -p "请输入分区设备名 (如: /dev/sdb1): " device
    read -p "请输入挂载点 (如: /mnt/data): " mount_point
    
    if [ ! -e "$device" ]; then
        print_error "设备不存在: $device"
        return 1
    fi
    
    if [ ! -d "$mount_point" ]; then
        mkdir -p "$mount_point"
        print_success "已创建挂载点: $mount_point"
    fi
    
    mount "$device" "$mount_point"
    
    if [ $? -eq 0 ]; then
        print_success "挂载成功"
    else
        print_error "挂载失败"
    fi
}

show_menu() {
    print_header "磁盘分区管理"
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}请选择操作:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}) 查看磁盘分区信息"
    echo -e "  ${GREEN}2${NC}) 挂载磁盘分区"
    echo -e "  ${RED}0${NC}) 返回"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

main() {
    if [ "$QUIET" -eq 1 ]; then
        show_partition_info
        return
    fi
    
    show_menu
    
    read -p "请选择 [0-2]: " choice
    
    case $choice in
        1) show_partition_info ;;
        2) mount_disk ;;
        0) print_info "返回主菜单" ;;
        *) print_error "无效选择" ;;
    esac
}

main "$@"
