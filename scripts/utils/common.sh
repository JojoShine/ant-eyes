#!/bin/bash

################################################################################
# ant-eyes 共享函数库
# 被所有 check 和 manage 脚本共用
# 包含：颜色定义、打印函数、系统检测、工具检查等
# 要求: bash 4.0+ (Linux系统标配)
################################################################################

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 颜色定义
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 全局变量
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SCRIPT_VERSION="2.0.0"
SCRIPT_RELEASE_DATE="2026-01-04"
REPORT_FILE=""
EXPORT_REPORT=0
VERBOSE=0
QUIET=0

# 检测操作系统类型（在任何脚本加载后立即执行）
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_VERSION="$VERSION"
        OS_ID="$ID"
    elif [ -f /etc/redhat-release ]; then
        OS_NAME=$(cat /etc/redhat-release)
        OS_ID="rhel"
    else
        OS_NAME="Unknown"
        OS_ID="unknown"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 打印函数库
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 打印带颜色的标题
print_header() {
    [ "$QUIET" -eq 1 ] && return
    local title="$1"
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}■ ${title}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 打印子标题
print_subheader() {
    [ "$QUIET" -eq 1 ] && return
    local subtitle="$1"
    echo -e "\n${BLUE}▸ ${subtitle}${NC}"
}

# 打印成功信息
print_success() {
    [ "$QUIET" -eq 1 ] && return
    echo -e "${GREEN}✓${NC} $1"
}

# 打印警告信息
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# 打印错误信息
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# 打印普通信息
print_info() {
    [ "$QUIET" -eq 1 ] && return
    echo -e "${WHITE}  $1${NC}"
}

# 详细输出（仅在 --verbose 时显示）
print_verbose() {
    if [ "$VERBOSE" -eq 1 ]; then
        echo -e "${BLUE}  [DEBUG] $1${NC}"
    fi
}

# 输出到报告文件
log_to_report() {
    if [ "$EXPORT_REPORT" -eq 1 ] && [ -n "$REPORT_FILE" ]; then
        echo "$1" >> "$REPORT_FILE"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 工具和权限检查函数库
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查是否为root用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_warning "部分功能需要root权限才能获取完整信息"
        return 1
    fi
    return 0
}

# 检查是否有执行权限
require_command() {
    local cmd="$1"
    if ! command_exists "$cmd"; then
        print_error "缺少必要命令: $cmd"
        return 1
    fi
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 网络工具检查和安装函数库
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 工具包映射表 (CentOS|Ubuntu) - 使用关联数组 (bash 4.0+)
declare -A TOOL_PACKAGES=(
    [netstat]="net-tools|net-tools"
    [ss]="iproute|iproute2"
    [telnet]="telnet|telnet"
    [nc]="nmap-ncat|netcat-openbsd"
    [traceroute]="traceroute|traceroute"
    [tracepath]="iputils|iputils-tracepath"
    [dig]="bind-utils|dnsutils"
    [nslookup]="bind-utils|dnsutils"
    [host]="bind-utils|dnsutils"
    [arp]="net-tools|net-tools"
)

# 常用端口和服务映射表 - 使用关联数组 (bash 4.0+)
declare -A PORT_SERVICES=(
    [22]="SSH - 远程登录"
    [80]="HTTP - Web服务"
    [443]="HTTPS - Web服务(安全)"
    [3306]="MySQL - 数据库"
    [5432]="PostgreSQL - 数据库"
    [6379]="Redis - 缓存数据库"
    [8080]="HTTP Alt - 备用Web服务"
    [9000]="MinIO - 对象存储"
    [1521]="Oracle - 数据库"
    [27017]="MongoDB - 文档数据库"
    [5672]="RabbitMQ - 消息队列"
    [15672]="RabbitMQ Management - 管理界面"
)

# 获取包管理器类型
get_package_manager() {
    if command -v yum &>/dev/null; then
        echo "yum"
    elif command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    else
        echo "unknown"
    fi
}

# 获取工具对应的包名
get_package_name() {
    local tool="$1"
    local pkg_manager=$(get_package_manager)
    local packages="${TOOL_PACKAGES[$tool]}"

    if [ -z "$packages" ]; then
        return 1
    fi

    if [ "$pkg_manager" = "yum" ] || [ "$pkg_manager" = "dnf" ]; then
        echo "$packages" | cut -d'|' -f1
    elif [ "$pkg_manager" = "apt" ]; then
        echo "$packages" | cut -d'|' -f2
    fi
}

# 建议安装缺失工具
suggest_install_tool() {
    local tool="$1"
    local pkg_name=$(get_package_name "$tool")
    local pkg_manager=$(get_package_manager)

    if [ -z "$pkg_name" ]; then
        return 1
    fi

    print_warning "缺失工具: $tool (来自包: $pkg_name)"

    case "$pkg_manager" in
        yum|dnf)
            print_info "  安装命令: sudo $pkg_manager install -y $pkg_name"
            ;;
        apt)
            print_info "  安装命令: sudo apt-get update && sudo apt-get install -y $pkg_name"
            ;;
        *)
            print_info "  请手动安装 $pkg_name 包"
            ;;
    esac
}

# 检查并报告缺失的关键工具
check_critical_tools() {
    local critical_tools=("ss" "netstat" "telnet" "nc" "traceroute" "dig" "nslookup")
    local missing_tools=()

    for tool in "${critical_tools[@]}"; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_warning "检测到缺失的网络诊断工具："
        for tool in "${missing_tools[@]}"; do
            suggest_install_tool "$tool"
        done
        return 1
    fi
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 表格和格式化输出函数库
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 打印简单表格（两列）
print_table_two_col() {
    local col1_header="$1"
    local col2_header="$2"
    shift 2

    [ "$QUIET" -eq 1 ] && return

    local col1_width=20
    local col2_width=50

    # 打印表头
    printf "${CYAN}%-${col1_width}s%-${col2_width}s${NC}\n" "$col1_header" "$col2_header"
    # 使用蓝色横线作为分隔符
    printf "${BLUE}$(printf '%.0s━' $(seq 1 $((col1_width + col2_width))))${NC}\n"

    # 打印数据行
    while [ $# -ge 2 ]; do
        printf "${WHITE}%-${col1_width}s${NC}%-${col2_width}s\n" "$1" "$2"
        shift 2
    done
}

# 打印进度条
print_progress() {
    local current=$1
    local total=$2
    local label="$3"

    [ "$QUIET" -eq 1 ] && return

    local percent=$((current * 100 / total))
    local filled=$((current * 20 / total))
    local empty=$((20 - filled))

    printf "\r${CYAN}[${GREEN}"
    printf '%*s' "$filled" | tr ' ' '='
    printf "${CYAN}%*s${NC}] %3d%% %s" "$empty" "" "$percent" "$label"
}

# 显示加载动画
show_spinner() {
    local message="$1"
    [ "$QUIET" -eq 1 ] && return

    local spinner=('|' '/' '-' '\')
    local i=0

    while true; do
        printf "\r${CYAN}${spinner[$((i % 4))]} ${message}${NC}"
        i=$((i + 1))
        sleep 0.1
    done
}

# 完成进度条
clear_progress() {
    printf "\r${CYAN}[${GREEN}════════════════════${CYAN}] 100%${NC}\n"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 初始化
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 加载时自动检测操作系统
detect_os
