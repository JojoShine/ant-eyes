#!/bin/bash

################################################################################
# ant-eyes - 磁盘分区挂载工具模块
# 功能：MBR/GPT分区识别、创建、格式化、挂载、配置自启等完整磁盘管理
################################################################################

# 加载共享函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

manage_disk_mount() {
    print_header "磁盘分区挂载工具"

    # 显示主线流程说明（仅进入时显示一次）
    print_subheader "完整工作流程指南"
    cat << 'EOF'
磁盘挂载的完整流程：

【新磁盘挂载流程】
1️⃣  查看磁盘信息 → 了解当前磁盘状态
2️⃣  查看分区类型 → 识别是MBR还是GPT
3️⃣  创建新分区   → 用fdisk/gdisk划分空间
4️⃣  格式化分区   → 选择ext4/xfs等文件系统
5️⃣  挂载分区     → 临时挂载到指定目录
6️⃣  配置自启     → 编辑/etc/fstab永久挂载

【已有分区挂载流程】
1️⃣  查看磁盘信息 → 找到目标分区
2️⃣  挂载分区     → 临时挂载到目录
3️⃣  配置自启     → 编辑/etc/fstab永久挂载

【常见情况】
✓ 新硬盘未分区: 走流程 3→4→5→6
✓ 新硬盘已分区: 走流程 4→5→6
✓ 已分区已格式化: 走流程 5→6

EOF

    while true; do
        echo ""
        # 显示当前磁盘分区信息
        print_subheader "系统磁盘设备"
        if command_exists lsblk; then
            lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
        elif command_exists fdisk; then
            fdisk -l | grep -E "^Disk /dev|^  /dev"
        else
            print_warning "无法获取磁盘信息（缺失lsblk/fdisk）"
        fi

        echo ""
        print_subheader "磁盘管理选项"
        echo "1. 查看磁盘和分区信息"
        echo "2. 查看分区类型（MBR/GPT）"
        echo "3. 创建新分区"
        echo "4. 格式化分区"
        echo "5. 挂载分区"
        echo "6. 卸载分区"
        echo "7. 创建挂载点"
        echo "8. 配置开机自动挂载"
        echo "9. 查看分区挂载指南"
        echo "0. 返回主菜单"
        echo ""

        read -p "请选择操作 (0-9): " disk_choice

        case $disk_choice in
            1)
                show_partition_details
                ;;
            2)
                show_partition_type
                ;;
            3)
                create_partition
                ;;
            4)
                format_partition
                ;;
            5)
                mount_partition
                ;;
            6)
                umount_partition
                ;;
            7)
                create_mount_point
                ;;
            8)
                configure_auto_mount
                ;;
            9)
                show_mount_guide
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

# 显示分区详细信息
show_partition_details() {
    print_subheader "分区详细信息"

    if command_exists fdisk; then
        print_info "选择磁盘查看详细分区信息:"
        local disk_list=$(lsblk -d -o NAME | grep -E "^(sd|hd|nvme|vd)" | head -10)

        local disk_num=1
        local -a disk_array
        while IFS= read -r disk; do
            disk_array+=("$disk")
            echo "$disk_num. /dev/$disk"
            ((disk_num++))
        done <<< "$disk_list"

        read -p "请选择磁盘编号: " disk_select

        if [[ "$disk_select" =~ ^[0-9]+$ ]]; then
            local selected_disk="/dev/${disk_array[$((disk_select-1))]}"
            if [ -n "$selected_disk" ] && [ -b "$selected_disk" ]; then
                if [ "$EUID" -ne 0 ]; then
                    print_warning "需要root权限查看完整的分区信息"
                    print_info "可以使用: sudo fdisk -l $selected_disk"
                else
                    fdisk -l "$selected_disk"
                fi
            fi
        fi
    else
        print_error "fdisk命令不可用"
    fi
}

# 显示分区类型
show_partition_type() {
    print_subheader "分区类型检测（MBR/GPT）"

    if [ "$EUID" -ne 0 ]; then
        print_warning "需要root权限来检测分区类型"
        return 1
    fi

    local disk_list=$(lsblk -d -o NAME | grep -E "^(sd|hd|nvme|vd)" | head -10)

    echo "$disk_list" | while read -r disk; do
        local full_path="/dev/$disk"
        local size=$(lsblk -d -o SIZE "$full_path" | tail -1)

        # 检测是MBR还是GPT
        if parted "$full_path" print 2>/dev/null | grep -q "Partition Table: gpt"; then
            print_success "$full_path (${size}): GPT分区表"
        elif parted "$full_path" print 2>/dev/null | grep -q "Partition Table: msdos"; then
            print_info "$full_path (${size}): MBR分区表"
        else
            # 尝试用fdisk检测
            if fdisk -l "$full_path" 2>/dev/null | grep -q "GPT"; then
                print_success "$full_path (${size}): GPT分区表"
            else
                print_info "$full_path (${size}): 分区表类型未确定"
            fi
        fi
    done
}

# 创建新分区
create_partition() {
    print_subheader "创建新分区"

    if [ "$EUID" -ne 0 ]; then
        print_error "需要root权限来创建分区"
        return 1
    fi

    # 显示可用的磁盘
    print_info "可用的磁盘设备:"
    local disk_list=$(lsblk -d -o NAME | grep -E "^(sd|hd|nvme|vd)" | head -10)

    local disk_num=1
    local -a disk_array
    while IFS= read -r disk; do
        disk_array+=("$disk")
        local size=$(lsblk -d -o SIZE "/dev/$disk" 2>/dev/null | tail -1)
        echo "$disk_num. /dev/$disk ($size)"
        ((disk_num++))
    done <<< "$disk_list"

    read -p "请选择磁盘编号: " disk_select

    if ! [[ "$disk_select" =~ ^[0-9]+$ ]]; then
        print_error "请输入有效的磁盘编号"
        return 1
    fi

    local selected_disk="/dev/${disk_array[$((disk_select-1))]}"

    if [ -z "$selected_disk" ] || [ ! -b "$selected_disk" ]; then
        print_error "磁盘不存在: $selected_disk"
        return 1
    fi

    # 检测分区表类型
    print_info "正在检测分区表类型..."
    local partition_type="unknown"

    if parted "$selected_disk" print 2>/dev/null | grep -q "Partition Table: gpt"; then
        partition_type="gpt"
        print_success "检测到GPT分区表"
    elif parted "$selected_disk" print 2>/dev/null | grep -q "Partition Table: msdos"; then
        partition_type="mbr"
        print_info "检测到MBR分区表"
    elif fdisk -l "$selected_disk" 2>/dev/null | grep -q "GPT"; then
        partition_type="gpt"
        print_success "检测到GPT分区表"
    else
        partition_type="mbr"
        print_info "检测到MBR分区表（或未初始化）"
    fi

    echo ""
    print_info "分区创建指南："
    if [ "$partition_type" = "gpt" ]; then
        cat << 'EOF'

【GPT分区（使用gdisk）】

如果已安装gdisk，可以使用以下命令：
  $ sudo gdisk /dev/sdX

gdisk交互命令：
  n - 创建新分区
  d - 删除分区
  l - 显示所有分区类型
  w - 写入更改并退出
  q - 不保存退出

快速步骤：
  1. 输入: sudo gdisk /dev/sdX
  2. 输入: n (创建新分区)
  3. 按提示输入分区号、起始扇区、大小等
  4. 输入: w (保存)

或者使用parted命令：
  $ sudo parted /dev/sdX
  (parted) mkpart primary 1MiB 100%
  (parted) quit

EOF
    else
        cat << 'EOF'

【MBR分区（使用fdisk）】

使用fdisk创建新分区：
  $ sudo fdisk /dev/sdX

fdisk交互命令：
  n - 创建新分区
  d - 删除分区
  t - 修改分区类型
  l - 显示所有分区类型
  w - 写入更改并退出
  q - 不保存退出

快速步骤：
  1. 输入: sudo fdisk /dev/sdX
  2. 输入: n (创建新分区)
  3. 选择: p (主分区) 或 e (扩展分区)
  4. 输入分区号 (1-4)
  5. 按提示输入起始和大小
  6. 输入: w (保存)

EOF
    fi

    echo ""
    read -p "是否立即启动分区工具? (y/n): " launch_choice
    if [[ "$launch_choice" =~ ^[Yy]$ ]]; then
        if [ "$partition_type" = "gpt" ]; then
            if command_exists gdisk; then
                gdisk "$selected_disk"
            else
                if command_exists parted; then
                    parted "$selected_disk"
                else
                    print_error "gdisk和parted命令均不可用"
                    print_info "请使用: sudo gdisk $selected_disk (需要安装gdisk)"
                fi
            fi
        else
            if command_exists fdisk; then
                fdisk "$selected_disk"
            else
                print_error "fdisk命令不可用"
            fi
        fi
        print_success "分区创建完成（如果有修改），请再次查看分区信息以确认"
    else
        print_info "您可以手动执行以下命令创建分区："
        if [ "$partition_type" = "gpt" ]; then
            print_info "  sudo gdisk $selected_disk"
        else
            print_info "  sudo fdisk $selected_disk"
        fi
    fi
}

# 格式化分区
format_partition() {
    print_subheader "格式化分区"

    if [ "$EUID" -ne 0 ]; then
        print_error "需要root权限来格式化分区"
        return 1
    fi

    # 显示可用的未格式化分区
    print_info "可用的分区设备:"
    local partitions=$(lsblk -p -o NAME,SIZE,TYPE,FSTYPE | grep "part" | awk '{print $1, $2, $4}')

    echo "$partitions" | nl

    read -p "请输入要格式化的分区设备 (如: /dev/sda1): " partition

    if [ ! -b "$partition" ]; then
        print_error "分区设备不存在: $partition"
        return 1
    fi

    # 检查分区是否已挂载
    if mountpoint -q "$partition" 2>/dev/null; then
        print_error "分区已挂载，无法格式化"
        print_info "请先卸载分区: sudo umount $partition"
        return 1
    fi

    # 获取分区当前信息
    local current_fstype=$(blkid -s TYPE -o value "$partition" 2>/dev/null)
    local partition_size=$(lsblk -o SIZE "$partition" 2>/dev/null | tail -1)

    if [ -n "$current_fstype" ]; then
        print_warning "当前文件系统类型: $current_fstype"
    fi

    echo ""
    echo "支持的文件系统类型："
    echo "  1. ext4       - Linux标准文件系统（推荐）"
    echo "  2. xfs        - 高性能文件系统"
    echo "  3. btrfs      - 新一代文件系统"
    echo "  4. ntfs       - Windows文件系统（跨平台）"
    echo "  5. exfat      - 便携式存储（USB等）"
    echo "  6. vfat       - FAT32文件系统"
    echo ""

    read -p "请选择文件系统类型 (1-6 或输入类型名): " fs_choice

    local fstype=""
    case $fs_choice in
        1) fstype="ext4" ;;
        2) fstype="xfs" ;;
        3) fstype="btrfs" ;;
        4) fstype="ntfs" ;;
        5) fstype="exfat" ;;
        6) fstype="vfat" ;;
        *) fstype="$fs_choice" ;;
    esac

    if [ -z "$fstype" ]; then
        print_error "无效的文件系统类型"
        return 1
    fi

    # 确认警告
    echo ""
    print_error "⚠️  警告：即将格式化分区 $partition"
    print_warning "分区大小: $partition_size"
    print_warning "目标文件系统: $fstype"
    print_error "此操作将导致分区上的所有数据丢失！"
    echo ""

    read -p "请确认操作。输入分区设备名 (如: sda1) 来确认: " confirm_input

    if [ "$confirm_input" != "${partition##*/}" ]; then
        print_error "确认失败，操作已取消"
        return 1
    fi

    # 执行格式化
    echo ""
    print_info "正在格式化分区..."

    case $fstype in
        ext4)
            if mkfs.ext4 -F "$partition"; then
                print_success "分区已成功格式化为ext4"
            else
                print_error "格式化失败"
                return 1
            fi
            ;;
        xfs)
            if command_exists mkfs.xfs; then
                if mkfs.xfs -f "$partition"; then
                    print_success "分区已成功格式化为xfs"
                else
                    print_error "格式化失败"
                    return 1
                fi
            else
                print_error "mkfs.xfs命令不可用，请安装xfsprogs包"
                return 1
            fi
            ;;
        btrfs)
            if command_exists mkfs.btrfs; then
                if mkfs.btrfs -f "$partition"; then
                    print_success "分区已成功格式化为btrfs"
                else
                    print_error "格式化失败"
                    return 1
                fi
            else
                print_error "mkfs.btrfs命令不可用，请安装btrfs-progs包"
                return 1
            fi
            ;;
        ntfs)
            if command_exists mkfs.ntfs; then
                if mkfs.ntfs -F "$partition"; then
                    print_success "分区已成功格式化为ntfs"
                else
                    print_error "格式化失败"
                    return 1
                fi
            else
                print_error "mkfs.ntfs命令不可用，请安装ntfs-3g包"
                return 1
            fi
            ;;
        exfat)
            if command_exists mkfs.exfat; then
                if mkfs.exfat "$partition"; then
                    print_success "分区已成功格式化为exfat"
                else
                    print_error "格式化失败"
                    return 1
                fi
            else
                print_error "mkfs.exfat命令不可用，请安装exfat-utils包"
                return 1
            fi
            ;;
        vfat)
            if mkfs.vfat "$partition"; then
                print_success "分区已成功格式化为vfat"
            else
                print_error "格式化失败"
                return 1
            fi
            ;;
        *)
            print_error "不支持的文件系统类型: $fstype"
            return 1
            ;;
    esac

    echo ""
    print_info "格式化完成，分区可以挂载使用"
}

# 挂载分区
mount_partition() {
    print_subheader "挂载分区"

    if [ "$EUID" -ne 0 ]; then
        print_error "需要root权限来挂载分区"
        return 1
    fi

    # 显示可用的分区
    print_info "可用的分区设备:"
    local partitions=$(lsblk -p -o NAME,SIZE,TYPE | grep "part" | awk '{print $1, $2}')

    echo "$partitions" | nl

    read -p "请输入要挂载的分区设备 (如: /dev/sda1): " partition

    if [ ! -b "$partition" ]; then
        print_error "分区设备不存在: $partition"
        return 1
    fi

    # 检查分区是否已挂载
    if mountpoint -q "$partition" 2>/dev/null; then
        print_warning "分区已挂载在: $(mount | grep $partition | awk '{print $3}')"
        return 1
    fi

    # 获取分区信息
    local fstype=$(blkid -s TYPE -o value "$partition" 2>/dev/null)
    print_info "分区文件系统类型: ${fstype:-未知}"

    # 输入挂载点
    read -p "请输入挂载点路径 (如: /mnt/data): " mountpoint

    if [ -z "$mountpoint" ]; then
        print_error "挂载点不能为空"
        return 1
    fi

    # 检查并创建挂载点
    if [ ! -d "$mountpoint" ]; then
        read -p "挂载点不存在，是否创建? (y/n): " create_choice
        if [[ "$create_choice" =~ ^[Yy]$ ]]; then
            mkdir -p "$mountpoint" || {
                print_error "无法创建挂载点: $mountpoint"
                return 1
            }
            print_success "挂载点已创建: $mountpoint"
        else
            print_error "挂载点不存在，操作已取消"
            return 1
        fi
    fi

    # 执行挂载
    print_info "正在挂载分区..."
    if mount "$partition" "$mountpoint"; then
        print_success "分区挂载成功: $partition -> $mountpoint"

        # 显示挂载结果
        mount | grep "$mountpoint"
    else
        print_error "分区挂载失败"
    fi
}

# 卸载分区
umount_partition() {
    print_subheader "卸载分区"

    if [ "$EUID" -ne 0 ]; then
        print_error "需要root权限来卸载分区"
        return 1
    fi

    # 显示已挂载的分区
    print_info "已挂载的分区:"
    mount | grep "/dev/" | grep -v "tmpfs\|devtmpfs\|cgroup\|proc\|sys" | nl

    read -p "请输入要卸载的分区设备或挂载点 (如: /dev/sda1): " device

    if [ -z "$device" ]; then
        print_error "设备不能为空"
        return 1
    fi

    print_info "正在卸载分区..."
    if umount "$device"; then
        print_success "分区卸载成功: $device"
    else
        print_error "分区卸载失败，可能正被使用"
        read -p "是否强制卸载? (y/n): " force_choice
        if [[ "$force_choice" =~ ^[Yy]$ ]]; then
            if umount -f "$device"; then
                print_success "分区已强制卸载: $device"
            else
                print_error "强制卸载失败"
            fi
        fi
    fi
}

# 创建挂载点
create_mount_point() {
    print_subheader "创建挂载点"

    if [ "$EUID" -ne 0 ]; then
        print_error "需要root权限来创建挂载点"
        return 1
    fi

    read -p "请输入挂载点路径 (如: /mnt/data): " mountpoint

    if [ -z "$mountpoint" ]; then
        print_error "路径不能为空"
        return 1
    fi

    if [ -d "$mountpoint" ]; then
        print_warning "目录已存在: $mountpoint"
    else
        mkdir -p "$mountpoint" || {
            print_error "无法创建目录: $mountpoint"
            return 1
        }
        print_success "挂载点已创建: $mountpoint"
    fi

    # 设置权限
    read -p "是否修改目录权限? (y/n): " perm_choice
    if [[ "$perm_choice" =~ ^[Yy]$ ]]; then
        read -p "请输入权限 (如: 755): " permissions
        if [[ "$permissions" =~ ^[0-7]{3}$ ]]; then
            chmod "$permissions" "$mountpoint"
            print_success "权限已设置: $mountpoint ($permissions)"
        else
            print_error "无效的权限格式"
        fi
    fi
}

# 配置开机自动挂载
configure_auto_mount() {
    print_subheader "配置开机自动挂载（/etc/fstab）"

    if [ "$EUID" -ne 0 ]; then
        print_error "需要root权限来修改/etc/fstab"
        return 1
    fi

    print_info "/etc/fstab 当前内容:"
    cat /etc/fstab | grep -v "^#" | grep -v "^$"

    echo ""
    echo "添加新的自动挂载条目:"
    read -p "请输入分区设备 (如: /dev/sda1): " partition
    read -p "请输入挂载点 (如: /mnt/data): " mountpoint
    read -p "请输入文件系统类型 (如: ext4, xfs, ntfs): " fstype
    read -p "请输入挂载选项 (默认: defaults): " mount_opts
    mount_opts="${mount_opts:-defaults}"

    if [ -z "$partition" ] || [ -z "$mountpoint" ] || [ -z "$fstype" ]; then
        print_error "参数不完整"
        return 1
    fi

    # 创建fstab条目
    local fstab_entry="$partition $mountpoint $fstype $mount_opts 0 0"

    print_info "将添加以下条目到/etc/fstab:"
    print_info "$fstab_entry"

    read -p "确认添加? (y/n): " confirm_choice
    if [[ "$confirm_choice" =~ ^[Yy]$ ]]; then
        # 备份fstab
        cp /etc/fstab /etc/fstab.bak
        print_success "已备份/etc/fstab到/etc/fstab.bak"

        # 添加条目
        echo "$fstab_entry" >> /etc/fstab
        print_success "条目已添加到/etc/fstab"

        # 验证fstab (兼容多种Linux系统)
        local fstab_valid=1

        # 检查fstab语法和格式（不检查挂载点是否存在）
        if grep -E "^[^#[:space:]]" /etc/fstab | awk '{if(NF<4) exit 1}' >/dev/null 2>&1; then
            # 使用findmnt进行额外验证（如果可用）
            if command_exists findmnt; then
                # 只检查语法，不强制验证挂载点存在
                if ! findmnt --verify -q 2>/dev/null; then
                    # 忽略某些非致命错误，只有严重错误才标记为无效
                    if findmnt --verify 2>&1 | grep -qE "unknown.*column|parse error"; then
                        fstab_valid=0
                    fi
                fi
            fi
        else
            fstab_valid=0
        fi

        if [ $fstab_valid -eq 1 ]; then
            print_success "/etc/fstab验证通过"
        else
            print_error "/etc/fstab验证失败，已恢复备份"
            cp /etc/fstab.bak /etc/fstab
        fi
    fi
}

# 显示挂载指南
show_mount_guide() {
    print_subheader "磁盘分区挂载完整指南"

    cat << 'EOF'

【MBR和GPT分区简介】

1. MBR (Master Boot Record)
   - 传统分区方案，最多支持4个主分区
   - 磁盘容量限制: 2TB
   - 兼容性最好，支持所有操作系统
   - 启动文件位置: 磁盘第一个扇区

2. GPT (GUID Partition Table)
   - 现代分区方案，理论上支持无限分区
   - 磁盘容量支持: 2TB以上
   - 更加安全可靠
   - 需要支持UEFI的系统

【分区挂载完整流程】

步骤1: 识别磁盘
  $ lsblk                    # 查看所有块设备
  $ fdisk -l                 # 查看磁盘详细信息
  $ parted /dev/sda print    # 查看分区表类型（MBR/GPT）

步骤2: 创建分区（如需要）
  MBR分区:
  $ fdisk /dev/sda           # 进入fdisk交互界面
  $ parted /dev/sda          # 或使用parted

  GPT分区:
  $ gdisk /dev/sda           # 使用gdisk工具
  $ parted /dev/sda          # 或使用parted

步骤3: 格式化分区
  $ mkfs.ext4 /dev/sda1      # 创建ext4文件系统
  $ mkfs.xfs /dev/sda1       # 创建xfs文件系统
  $ mkfs.ntfs /dev/sda1      # 创建ntfs文件系统（Windows兼容）

步骤4: 创建挂载点
  $ sudo mkdir -p /mnt/data  # 创建挂载目录

步骤5: 临时挂载
  $ sudo mount /dev/sda1 /mnt/data

步骤6: 验证挂载
  $ mount | grep /mnt/data
  $ df -h                    # 查看挂载情况

步骤7: 配置开机自动挂载（/etc/fstab）
  编辑/etc/fstab文件，添加以下行:
  /dev/sda1  /mnt/data  ext4  defaults  0  0

  参数说明:
  - 设备路径: /dev/sda1
  - 挂载点: /mnt/data
  - 文件系统: ext4, xfs, ntfs等
  - 挂载选项: defaults, ro(只读), noexec(禁止执行)等
  - dump标志: 0(不备份) 或 1(每日备份)
  - 检查顺序: 0(不检查) 1(根分区) 2+(其他分区)

步骤8: 验证fstab配置
  $ sudo mount -a --dry-run  # 验证语法

【常用挂载选项】

defaults   - 默认选项 (rw, suid, dev, exec, auto, nouser, async)
ro         - 只读挂载
rw         - 读写挂载
noexec     - 禁止执行可执行文件
nouser     - 禁止普通用户挂载
async      - 异步I/O（性能好，安全性低）
sync       - 同步I/O（安全，性能相对低）
nofail     - 开机时挂载失败不影响启动

【常见问题】

问题1: 提示"Device busy"无法卸载
解决: sudo umount -f /mnt/data  (强制卸载)

问题2: 分区无法识别或无文件系统
解决: mkfs -t ext4 /dev/sda1    (重新格式化)

问题3: 修改fstab后无法启动
解决: 进入单用户模式或使用Live USB修复

# ============================================================================
# 主函数
# ============================================================================

main() {
    if [ "$QUIET" -eq 1 ]; then
        # 非交互模式，仅显示磁盘信息
        show_partition_details
        return
    fi

    # 交互模式，进入菜单
    manage_disk_mount
}

main "$@"
exit 0
