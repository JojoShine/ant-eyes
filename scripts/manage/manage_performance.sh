#!/bin/bash

################################################################################
# ant-eyes - 磁盘I/O性能检查模块
# 功能：iostat监控、fio基准测试、SMART健康检查
################################################################################

# 加载共享函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# 磁盘 I/O 性能检查模块
################################################################################

# 检查 iostat 磁盘 I/O 性能
check_iostat_performance() {
    print_subheader "iostat 磁盘 I/O 性能监控"

    # 尝试自动安装 iostat
    if ! auto_install_tool "iostat" "sysstat"; then
        return 1
    fi

    print_info "正在采集磁盘 I/O 性能数据（3次采样，每次间隔2秒）..."
    echo ""

    # 显示扩展统计信息 (-x: 扩展统计, 2秒间隔, 3次采样)
    iostat -x 2 3

    echo ""
    print_success "I/O 性能监控完成"
}

# 检查 fio 磁盘基准测试
check_fio_benchmark() {
    print_subheader "fio 磁盘性能基准测试"

    # 尝试自动安装 fio
    if ! auto_install_tool "fio" "fio"; then
        return 1
    fi

    # 选择测试场景
    echo "请选择测试场景:"
    echo "1) 顺序读测试 (128K块)"
    echo "2) 顺序写测试 (128K块)"
    echo "3) 随机读测试 (4K块)"
    echo "4) 随机写测试 (4K块)"
    echo "5) 混合读写测试 (70%读/30%写)"
    echo "0) 返回"
    read -p "请选择 [0-5]: " fio_choice

    local test_name=""
    local test_desc=""
    local rw=""
    local bs="4k"
    local rwmixread=""

    case $fio_choice in
        1)
            test_name="sequential_read"
            test_desc="顺序读测试"
            rw="read"
            bs="128k"
            ;;
        2)
            test_name="sequential_write"
            test_desc="顺序写测试"
            rw="write"
            bs="128k"
            ;;
        3)
            test_name="random_read"
            test_desc="随机读测试"
            rw="randread"
            bs="4k"
            ;;
        4)
            test_name="random_write"
            test_desc="随机写测试"
            rw="randwrite"
            bs="4k"
            ;;
        5)
            test_name="mixed_rw"
            test_desc="混合读写测试"
            rw="randrw"
            bs="4k"
            rwmixread=70
            ;;
        0)
            return 0
            ;;
        *)
            print_error "无效选项"
            return 1
            ;;
    esac

    # 选择测试目录
    read -p "请输入测试目录（默认: /tmp）: " test_dir
    test_dir=${test_dir:-/tmp}

    if [ ! -d "$test_dir" ]; then
        print_error "目录不存在: $test_dir"
        return 1
    fi

    # 检查可用空间（至少需要1.5GB）
    local available_space=$(df "$test_dir" | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 1536000 ]; then
        print_error "可用空间不足（需要至少1.5GB，实际: $((available_space/1024))MB）"
        return 1
    fi

    # 测试文件路径
    local test_file="$test_dir/fio_test_$(date +%s).dat"

    print_info "开始 $test_desc..."
    print_warning "测试文件: $test_file"
    print_warning "这可能需要数分钟时间，请耐心等待..."
    echo ""

    # 执行 fio 测试
    if [ -n "$rwmixread" ]; then
        fio --name=$test_name \
            --filename=$test_file \
            --size=1G \
            --rw=$rw \
            --bs=$bs \
            --ioengine=libaio \
            --direct=1 \
            --numjobs=1 \
            --runtime=30 \
            --time_based \
            --rwmixread=$rwmixread \
            --group_reporting 2>&1 || print_error "测试执行失败"
    else
        fio --name=$test_name \
            --filename=$test_file \
            --size=1G \
            --rw=$rw \
            --bs=$bs \
            --ioengine=libaio \
            --direct=1 \
            --numjobs=1 \
            --runtime=30 \
            --time_based \
            --group_reporting 2>&1 || print_error "测试执行失败"
    fi

    # 清理测试文件
    if [ -f "$test_file" ]; then
        rm -f "$test_file"
        print_success "测试文件已清理"
    fi

    echo ""
    print_success "$test_desc 完成"
}

# 检查磁盘 SMART 健康状态
check_disk_health() {
    print_subheader "磁盘 SMART 健康状态检查"

    # 尝试自动安装 smartctl
    if ! auto_install_tool "smartctl" "smartmontools"; then
        return 1
    fi

    if [ "$EUID" -ne 0 ]; then
        print_warning "需要 root 权限来查看 SMART 信息"
        print_info "请使用: sudo smartctl -a /dev/sda 查看具体磁盘信息"
        return 1
    fi

    # 列出所有磁盘
    print_info "检测系统磁盘..."
    local disks=$(lsblk -d -o NAME | grep -E "^(sd|hd|nvme|vd)" | head -10)

    if [ -z "$disks" ]; then
        print_warning "未找到磁盘设备"
        return 1
    fi

    echo "$disks" | while read -r disk; do
        local disk_path="/dev/$disk"

        # 跳过不支持 SMART 的设备
        if ! smartctl -i "$disk_path" >/dev/null 2>&1; then
            print_warning "$disk_path: 不支持 SMART 或无法访问"
            continue
        fi

        print_info ""
        print_success "=== $disk_path SMART 状态 ==="

        # 获取健康状态
        local health=$(smartctl -H "$disk_path" 2>/dev/null | grep "SMART overall" | awk -F': ' '{print $2}')
        if [ -n "$health" ]; then
            if [[ "$health" == *"PASSED"* ]]; then
                print_success "健康状态: $health"
            else
                print_error "健康状态: $health"
            fi
        fi

        # 获取温度
        local temp=$(smartctl -A "$disk_path" 2>/dev/null | grep -i "temperature" | awk '{print $(NF-1)}'  )
        if [ -n "$temp" ]; then
            print_info "磁盘温度: ${temp}°C"
        fi

        # 获取通电时间
        local power_on=$(smartctl -A "$disk_path" 2>/dev/null | grep -i "Power_On_Hours" | awk '{print $10}')
        if [ -n "$power_on" ]; then
            local power_on_days=$((power_on / 24))
            print_info "通电时间: $power_on 小时 ($power_on_days 天)"
        fi

        # 获取错误计数
        local errors=$(smartctl -A "$disk_path" 2>/dev/null | grep -i "error" | grep -v "0$" | wc -l)
        if [ "$errors" -gt 0 ]; then
            print_warning "检测到 $errors 个 SMART 错误计数"
        else
            print_success "无 SMART 错误计数"
        fi
    done

    echo ""
    print_success "SMART 健康检查完成"
}

# 显示 I/O 综合报告
show_disk_io_summary() {
    print_subheader "磁盘 I/O 综合报告"

    # 系统 I/O 统计
    print_info "【系统 I/O 状态】"
    if [ -f /proc/diskstats ]; then
        local read_count=$(awk '{sum+=$1} END {print sum}' /proc/diskstats)
        local write_count=$(awk '{sum+=$5} END {print sum}' /proc/diskstats)
        print_info "总读操作数: $read_count"
        print_info "总写操作数: $write_count"
    fi

    # 当前 I/O 等待
    if [ -f /proc/stat ]; then
        local iowait=$(grep "^cpu " /proc/stat | awk '{print $5}')
        print_info "CPU I/O等待时间: $iowait"
    fi

    echo ""
    print_info "【高 I/O 进程（如果可用）】"

    # 尝试自动安装 iotop
    if auto_install_tool "iotop" "iotop"; then
        print_info "Top 5 I/O 进程:"
        timeout 5 iotop -b -n 1 -o 2>/dev/null | head -10 | tail -5 | while read -r line; do
            print_info "  $line"
        done
    else
        print_info "iotop 可选工具，无法显示高 I/O 进程列表"
    fi

    echo ""
    print_success "I/O 综合报告完成"
}

# 磁盘 I/O 性能检查主菜单
check_disk_io_performance() {
    print_header "磁盘 I/O 性能检查"

    echo ""
    print_info "磁盘 I/O 性能检查工具"
    print_info "1. iostat 实时监控 - 查看当前 I/O 性能指标"
    print_info "2. fio 基准测试 - 测试磁盘最大性能"
    print_info "3. 磁盘健康状态 - 检查 SMART 健康信息"
    print_info "4. I/O 综合报告 - 系统 I/O 负载分析"
    echo ""

    while true; do
        print_subheader "磁盘 I/O 性能检查菜单"
        echo "1) iostat 实时 I/O 监控"
        echo "2) fio 磁盘性能基准测试"
        echo "3) 磁盘 SMART 健康检查"
        echo "4) I/O 综合报告"
        echo "0) 返回主菜单"
        echo ""

        read -p "请选择 [0-4]: " io_choice
        echo ""

        case $io_choice in
            1)
                check_iostat_performance
                ;;
            2)
                check_fio_benchmark
                ;;
            3)
                check_disk_health
                ;;
            4)
                show_disk_io_summary
                ;;
            0)
                break
                ;;
            *)
                print_error "无效选项"
                ;;
        esac

        if [ "$io_choice" != "0" ]; then
            echo ""
            echo -n "按 Enter 继续..."
            read
        fi
    done
}

################################################################################

# ============================================================================
# 主函数
# ============================================================================

main() {
    check_disk_io_performance
}

main "$@"
exit 0
