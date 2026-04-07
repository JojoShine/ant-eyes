#!/bin/bash

################################################################################
# Linux服务器信息收集与安全检查工具
# 支持: CentOS, Kylin, UOS等国产操作系统
# 功能: 系统信息、安全检查、异常访问、服务部署、网络诊断
################################################################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 全局变量
SCRIPT_VERSION="2.0.0"
SCRIPT_RELEASE_DATE="2026-01-04"
REPORT_FILE=""
EXPORT_REPORT=0

################################################################################
# 工具函数
################################################################################

# 显示版本和功能信息
show_version_info() {
    print_header "版本和功能介绍"

    echo -e "${BLUE}▸ 工具版本信息${NC}"
    print_info "工具名称: Linux服务器信息收集与安全检查工具"
    print_info "版本号: v$SCRIPT_VERSION"
    print_info "发布日期: $SCRIPT_RELEASE_DATE"
    print_info "支持系统: CentOS, Kylin麒麟, UOS, Ubuntu等"

    echo ""
    echo -e "${BLUE}▸ 核心功能模块${NC}"
    print_info "1. 系统基本信息检查 - 查看CPU、内存、磁盘、网络等系统关键信息"
    print_info "2. 系统异常访问检查 - 监控SSH登录、暴力破解、可疑连接等安全事件"
    print_info "3. 常用组件运行状态检测 - 检测Oracle、MySQL、Redis、Kafka等应用运行状态"
    print_info "4. 系统服务部署信息 - 显示运行中的服务、监听端口、Docker容器状态"
    print_info "5. 系统安全情况检查 - 防火墙、SELinux、用户权限、文件安全等检查"
    print_info "6. 网络诊断工具 - Ping、Telnet、DNS解析、端口扫描、网速测试、防火墙管理等"
    print_info "7. Crontab定时任务管理 - 查看、添加、删除定时任务，支持常用模板"
    print_info "8. NTP/Chrony时间同步 - 管理时间同步服务，同步系统时间"
    print_info "9. 磁盘分区挂载工具 - MBR/GPT分区识别、挂载、文件系统管理"
    print_info "10. 磁盘 I/O 性能检查 - iostat实时监控、fio基准测试、SMART健康检查"

    echo ""
    echo -e "${BLUE}▸ 功能特点${NC}"
    print_success "✓ 支持多种Linux发行版（RedHat系、Debian系、国产操作系统）"
    print_success "✓ 完整的系统安全检查能力"
    print_success "✓ 强大的网络诊断工具集"
    print_success "✓ 交互式菜单，易于使用"
    print_success "✓ 支持报告导出功能"
    print_success "✓ 提供自动化的系统管理工具"

    echo ""
    echo -e "${BLUE}▸ 使用建议${NC}"
    print_info "• 建议以root身份运行以获取完整的系统信息"
    print_info "• 首次运行建议选择\"完整检查\"了解系统全面情况"
    print_info "• 定期运行此工具进行系统健康检查"
    print_info "• 在进行系统管理操作前建议先备份重要数据"

}

# 打印带颜色的标题
print_header() {
    local title="$1"
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}■ ${title}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 打印子标题
print_subheader() {
    local subtitle="$1"
    echo -e "\n${BLUE}▸ ${subtitle}${NC}"
}

# 打印成功信息
print_success() {
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
    echo -e "${WHITE}  $1${NC}"
}

# 输出到报告文件
log_to_report() {
    if [ "$EXPORT_REPORT" -eq 1 ] && [ -n "$REPORT_FILE" ]; then
        echo "$1" >> "$REPORT_FILE"
    fi
}

# 检测操作系统类型
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

################################################################################
# 网络工具检查和安装函数库
################################################################################

# 工具包映射表 (CentOS|Ubuntu)
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

# 常用端口和服务映射表
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

# 端口扫描函数（支持多种工具fallback）
scan_port() {
    local host="$1"
    local port="$2"
    local timeout=2

    # 方法1: 使用 nc (netcat)
    if command_exists nc; then
        if nc -zv -w $timeout "$host" "$port" 2>&1 | grep -q -E "succeeded|Connection succeeded"; then
            return 0  # 端口开放
        fi
    fi

    # 方法2: 使用 telnet
    if command_exists telnet; then
        if timeout $timeout telnet "$host" "$port" 2>&1 | grep -q -E "Connected|Escape"; then
            return 0
        fi
    fi

    # 方法3: 使用 bash 的 /dev/tcp (最后的手段)
    if timeout $timeout bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
        return 0
    fi

    return 1  # 端口关闭或无法访问
}

# DNS 解析函数（支持多种工具fallback）
resolve_dns() {
    local domain="$1"

    # 方法1: 使用 nslookup
    if command_exists nslookup; then
        nslookup "$domain" 2>/dev/null
        return $?
    fi

    # 方法2: 使用 dig
    if command_exists dig; then
        dig "$domain" 2>/dev/null
        return $?
    fi

    # 方法3: 使用 host
    if command_exists host; then
        host "$domain" 2>/dev/null
        return $?
    fi

    # 方法4: 使用 getent
    if command_exists getent; then
        echo "正在解析域名 $domain..."
        getent hosts "$domain" 2>/dev/null || echo "未找到 DNS 记录"
        return $?
    fi

    return 1  # 所有方法都失败
}

# 路由追踪函数（支持多种工具fallback）
trace_route() {
    local host="$1"
    local max_hops=15

    # 方法1: 使用 traceroute
    if command_exists traceroute; then
        traceroute -m $max_hops "$host" 2>/dev/null
        return $?
    fi

    # 方法2: 使用 tracepath
    if command_exists tracepath; then
        tracepath -m $max_hops "$host" 2>/dev/null
        return $?
    fi

    # 方法3: 使用 bash 实现 (简化版)
    if command_exists nc || command_exists timeout; then
        echo "使用基础方法追踪到 $host 的路由（可能不完整）："
        for i in {1..15}; do
            if timeout 2 bash -c "echo >/dev/tcp/$host/80" 2>/dev/null; then
                echo "跳转 $i: 目标 $host 可达"
                return 0
            fi
        done
        echo "无法追踪到目标主机"
        return 1
    fi

    return 1  # 所有方法都失败
}

# 端口连接查询函数（支持多种工具fallback）
query_port_connections() {
    local query_type="$1"  # port 或 ip
    local query_value="$2"

    if [ "$query_type" = "port" ]; then
        echo "正在查询端口 $query_value 的所有连接..."
        echo ""
    elif [ "$query_type" = "ip" ]; then
        echo "正在查询与 $query_value 相关的连接..."
        echo ""
    fi

    # 方法1: 使用 ss (推荐，性能最好)
    if command_exists ss; then
        if [ "$query_type" = "port" ]; then
            # 查询本地端口
            print_subheader "本地监听该端口的连接 (ss)"
            ss -antp 2>/dev/null | grep ":$query_value " | head -20
            echo ""
            print_subheader "与该端口的远程连接 (ss)"
            ss -antp 2>/dev/null | grep -E ":(.*\s|)$query_value\s" | head -20
        elif [ "$query_type" = "ip" ]; then
            # 查询特定IP的连接
            print_subheader "与 $query_value 相关的连接 (ss)"
            ss -antp 2>/dev/null | grep "$query_value" | head -30
        fi
        return 0
    fi

    # 方法2: 使用 netstat (fallback)
    if command_exists netstat; then
        if [ "$query_type" = "port" ]; then
            print_subheader "本地监听该端口的连接 (netstat)"
            # Linux netstat 支持 -p，macOS 不支持
            if [[ "$OSTYPE" == "darwin"* ]]; then
                netstat -an 2>/dev/null | grep ":$query_value " | head -20
            else
                netstat -antp 2>/dev/null | grep ":$query_value " | head -20
            fi
            echo ""
            print_subheader "与该端口的远程连接 (netstat)"
            if [[ "$OSTYPE" == "darwin"* ]]; then
                netstat -an 2>/dev/null | grep -E ":(.*\s|)$query_value\s" | head -20
            else
                netstat -antp 2>/dev/null | grep -E ":(.*\s|)$query_value\s" | head -20
            fi
        elif [ "$query_type" = "ip" ]; then
            print_subheader "与 $query_value 相关的连接 (netstat)"
            if [[ "$OSTYPE" == "darwin"* ]]; then
                netstat -an 2>/dev/null | grep "$query_value" | head -30
            else
                netstat -antp 2>/dev/null | grep "$query_value" | head -30
            fi
        fi
        return 0
    fi

    # 方法3: 使用 /proc 文件系统 (Linux only fallback)
    if [ -f /proc/net/tcp ]; then
        print_subheader "基于 /proc/net/tcp 的查询结果"
        if [ "$query_type" = "port" ]; then
            # 将十进制端口转换为16进制用于查询
            local port_hex=$(printf "%04X" $query_value)
            echo "查询端口 $query_value (hex: $port_hex):"
            grep -E ":(.*\s|)$port_hex\s" /proc/net/tcp 2>/dev/null | head -20
            echo "(注：显示格式为 local_addr:port remote_addr:port state)"
        fi
        return 0
    fi

    print_error "无法查询连接信息，缺失 ss/netstat 命令"
    return 1
}

################################################################################
# 系统基本信息模块
################################################################################
show_system_info() {
    print_header "系统基本信息"

    # 操作系统信息
    print_subheader "操作系统"
    print_info "系统名称: $OS_NAME"
    print_info "系统版本: $OS_VERSION"
    print_info "内核版本: $(uname -r)"
    print_info "系统架构: $(uname -m)"

    # 主机名和IP地址
    print_subheader "主机信息"
    print_info "主机名: $(hostname)"
    if command_exists hostname; then
        local hostname_fqdn=$(hostname -f 2>/dev/null || hostname)
        print_info "完整域名: $hostname_fqdn"
    fi

    # 获取IP地址
    if command_exists ip; then
        local ip_addr=$(ip -4 addr show | grep -o 'inet [0-9.]*' | awk '{print $2}' | grep -v '127.0.0.1' | head -1)
        print_info "主IP地址: ${ip_addr:-未检测到}"
    elif command_exists ifconfig; then
        local ip_addr=$(ifconfig | grep -o 'inet [0-9.]*' | awk '{print $2}' | grep -v '127.0.0.1' | head -1)
        print_info "主IP地址: ${ip_addr:-未检测到}"
    fi

    # CPU信息
    print_subheader "CPU信息"
    if [ -f /proc/cpuinfo ]; then
        local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^[ \t]*//')
        local cpu_cores=$(grep -c "^processor" /proc/cpuinfo)
        print_info "CPU型号: ${cpu_model:-未知}"
        print_info "CPU核心数: $cpu_cores"

        # CPU使用率
        if command_exists top; then
            local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
            print_info "CPU使用率: ${cpu_usage:-未知}"
        fi
    fi

    # 内存信息
    print_subheader "内存信息"
    if [ -f /proc/meminfo ]; then
        local mem_total=$(grep MemTotal /proc/meminfo | awk '{printf "%.2f GB", $2/1024/1024}')
        local mem_free=$(grep MemAvailable /proc/meminfo | awk '{printf "%.2f GB", $2/1024/1024}')
        local mem_used=$(free -h | awk '/^Mem:/ {print $3}')
        print_info "总内存: $mem_total"
        print_info "已用内存: $mem_used"
        print_info "可用内存: $mem_free"

        # 计算内存使用率
        local mem_percent=$(free | awk '/^Mem:/ {printf "%.1f%%", $3/$2*100}')
        if [[ $(echo "$mem_percent" | tr -d '%' | cut -d. -f1) -gt 80 ]]; then
            print_warning "内存使用率: $mem_percent (偏高)"
        else
            print_info "内存使用率: $mem_percent"
        fi
    fi

    # 磁盘信息
    print_subheader "磁盘清单"
    if command_exists lsblk; then
        print_info "物理磁盘设备:"
        lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,MODEL 2>/dev/null | head -20 | while read -r line; do
            print_info "  $line"
        done
    elif [ -f /proc/partitions ]; then
        print_info "磁盘分区:"
        cat /proc/partitions | grep -v "^major" | while read -r line; do
            print_info "  $line"
        done
    fi

    # 挂载情况
    print_subheader "文件系统挂载情况"
    if command_exists mount; then
        mount | grep -vE 'tmpfs|devtmpfs|cgroup|proc|sys' | while read -r line; do
            print_info "$line"
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
        print_info "运行时长: $uptime_info"

        local load_avg=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//')
        print_info "平均负载: $load_avg"
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

################################################################################
# 系统异常访问信息模块
################################################################################
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

    # SSH登录失败记录（最近20条）
    print_subheader "SSH登录失败记录（最近20条）"
    if [ -f "$auth_log" ]; then
        local failed_logins=$(grep -i "failed password\|authentication failure" "$auth_log" | tail -20)
        if [ -n "$failed_logins" ]; then
            local fail_count=$(echo "$failed_logins" | wc -l)
            print_warning "发现 $fail_count 条失败登录记录"
            echo "$failed_logins" | while read -r line; do
                print_info "  $(echo $line | awk '{print $1,$2,$3}') - $(echo $line | grep -oP 'from \S+' || echo 'unknown')"
            done
        else
            print_success "未发现失败登录记录"
        fi
    fi

    # 成功登录记录（最近10条）
    print_subheader "近期成功登录记录（最近10条）"
    if command_exists last; then
        local success_logins=$(last -n 10 -w | grep -v "^$\|^wtmp\|^reboot")
        if [ -n "$success_logins" ]; then
            echo "$success_logins" | while read -r line; do
                print_info "  $line"
            done
        else
            print_info "无登录记录"
        fi
    fi

    # 暴力破解尝试统计（统计失败次数最多的IP）
    print_subheader "暴力破解尝试统计（Top 10 IP）"
    if [ -f "$auth_log" ]; then
        local brute_force=$(grep -i "failed password" "$auth_log" | grep -o 'from [0-9.]*' | awk '{print $2}' | sort | uniq -c | sort -rn | head -10)
        if [ -n "$brute_force" ]; then
            echo "$brute_force" | while read -r count ip; do
                if [ "$count" -gt 10 ]; then
                    print_error "  $ip: $count 次失败尝试 (高危)"
                elif [ "$count" -gt 5 ]; then
                    print_warning "  $ip: $count 次失败尝试"
                else
                    print_info "  $ip: $count 次失败尝试"
                fi
            done
        else
            print_success "未发现暴力破解尝试"
        fi
    fi

    # 当前活动连接
    print_subheader "当前SSH活动连接"
    if command_exists ss; then
        local ssh_connections=$(ss -tn state established '( dport = :22 or sport = :22 )' | grep -v "^State")
        if [ -n "$ssh_connections" ]; then
            local conn_count=$(echo "$ssh_connections" | wc -l)
            print_info "活动SSH连接数: $conn_count"
            echo "$ssh_connections" | while read -r line; do
                print_info "  $line"
            done
        else
            print_info "当前无SSH连接"
        fi
    elif command_exists netstat; then
        local ssh_connections=$(netstat -tn | grep ':22' | grep ESTABLISHED)
        if [ -n "$ssh_connections" ]; then
            local conn_count=$(echo "$ssh_connections" | wc -l)
            print_info "活动SSH连接数: $conn_count"
            echo "$ssh_connections" | while read -r line; do
                print_info "  $line"
            done
        else
            print_info "当前无SSH连接"
        fi
    fi

    # 可疑登录（非常规时间或异常用户）
    print_subheader "Root用户登录记录"
    if command_exists last; then
        local root_logins=$(last -n 20 root | grep -v "^$\|^wtmp\|^reboot")
        if [ -n "$root_logins" ]; then
            local root_count=$(echo "$root_logins" | wc -l)
            print_warning "发现 $root_count 条root登录记录"
            echo "$root_logins" | head -5 | while read -r line; do
                print_info "  $line"
            done
        else
            print_success "未发现root直接登录"
        fi
    fi
}

################################################################################
# 系统服务部署信息模块
################################################################################
show_service_info() {
    print_header "系统服务部署信息"

    # 系统负载情况
    print_subheader "系统负载"
    if [ -f /proc/loadavg ]; then
        local load_avg=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
        local cpu_cores=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo 1)
        print_info "平均负载(1/5/15分钟): $load_avg"
        print_info "CPU核心数: $cpu_cores"

        # 检查负载是否过高
        local load_1min=$(cat /proc/loadavg | awk '{print $1}')
        local load_threshold=$(echo "$cpu_cores * 0.7" | bc 2>/dev/null || echo "$cpu_cores")
        if command_exists bc && [ $(echo "$load_1min > $load_threshold" | bc) -eq 1 ]; then
            print_warning "系统负载较高"
        fi
    fi

    # 正在运行的服务（systemd）
    print_subheader "正在运行的服务 (Top 15)"
    if command_exists systemctl; then
        local running_services=$(systemctl list-units --type=service --state=running --no-pager --no-legend | awk '{print $1}' | head -15)
        if [ -n "$running_services" ]; then
            local service_count=$(systemctl list-units --type=service --state=running --no-pager --no-legend | wc -l)
            print_info "运行中的服务总数: $service_count"
            echo "$running_services" | while read -r service; do
                print_info "  ✓ $service"
            done
        else
            print_info "未发现运行中的服务"
        fi
    elif command_exists service; then
        print_info "使用传统service命令检测服务"
        service --status-all 2>/dev/null | grep '\[ + \]' | head -15 | while read -r line; do
            print_info "  $line"
        done
    fi

    # 开机自启服务
    print_subheader "开机自启服务 (Top 10)"
    if command_exists systemctl; then
        local enabled_services=$(systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend | awk '{print $1}' | head -10)
        if [ -n "$enabled_services" ]; then
            echo "$enabled_services" | while read -r service; do
                print_info "  ☑ $service"
            done
        else
            print_info "未发现自启服务"
        fi
    fi

    # 监听端口及对应进程
    print_subheader "监听端口及对应进程"
    if command_exists ss; then
        local listening_ports=$(ss -tulpn 2>/dev/null | grep LISTEN)
        if [ -n "$listening_ports" ]; then
            local port_count=$(echo "$listening_ports" | wc -l)
            print_info "TCP/UDP监听端口总数: $port_count"
            echo ""
            print_info "详细列表:"
            echo "$listening_ports" | awk 'BEGIN {print "  协议\t本地地址\t\t\t进程信息"}
            {print "  " $1 "\t" $5 "\t\t" $7}' | while read -r line; do
                print_info "$line"
            done
        else
            print_info "无监听端口"
        fi
    elif command_exists netstat; then
        local listening_ports=$(netstat -tulpn 2>/dev/null | grep LISTEN)
        if [ -n "$listening_ports" ]; then
            local port_count=$(echo "$listening_ports" | wc -l)
            print_info "TCP/UDP监听端口总数: $port_count"
            echo ""
            print_info "详细列表:"
            echo "$listening_ports" | awk 'BEGIN {print "  协议\t本地地址\t\t\t进程信息"}
            {print "  " $1 "\t" $4 "\t\t" $7}' | while read -r line; do
                print_info "$line"
            done
        else
            print_info "无监听端口"
        fi
    else
        print_warning "ss和netstat命令均不可用"
    fi

    # Docker容器状态（如果安装了Docker）
    print_subheader "Docker容器状态"
    if command_exists docker; then
        if docker ps >/dev/null 2>&1; then
            local container_count=$(docker ps -q | wc -l)
            local all_container_count=$(docker ps -aq | wc -l)
            print_info "运行中容器: $container_count / 总容器: $all_container_count"

            if [ "$container_count" -gt 0 ]; then
                docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | tail -n +2 | head -10 | while read -r line; do
                    print_info "  $line"
                done
            fi
        else
            print_warning "Docker已安装但无法访问（需要权限）"
        fi
    else
        print_info "Docker未安装"
    fi

    # 进程数统计
    print_subheader "进程统计"
    if [ -d /proc ]; then
        local total_processes=$(ls -d /proc/[0-9]* 2>/dev/null | wc -l)
        print_info "总进程数: $total_processes"

        # Top 5 CPU占用进程
        if command_exists ps; then
            print_info "CPU占用Top 5:"
            ps aux --sort=-%cpu | head -6 | tail -5 | awk '{printf "  %-10s %5s%% %s\n", $1, $3, $11}' | while read -r line; do
                print_info "$line"
            done
        fi

        # Top 5 内存占用进程
        if command_exists ps; then
            print_info "内存占用Top 5:"
            ps aux --sort=-%mem | head -6 | tail -5 | awk '{printf "  %-10s %5s%% %s\n", $1, $4, $11}' | while read -r line; do
                print_info "$line"
            done
        fi
    fi
}

################################################################################
# 常用组件运行状态检测模块
################################################################################
check_component_status() {
    local component_name="$1"
    local port="$2"
    local process_keyword="$3"

    # 检查端口是否监听
    local port_status=0
    if command_exists ss; then
        if ss -tulpn 2>/dev/null | grep -q ":$port "; then
            port_status=1
        fi
    elif command_exists netstat; then
        if netstat -tulpn 2>/dev/null | grep -q ":$port "; then
            port_status=1
        fi
    fi

    # 检查进程
    local process_status=0
    local process_info=""
    if [ -n "$process_keyword" ]; then
        process_info=$(pgrep -f "$process_keyword" 2>/dev/null | head -1)
        if [ -n "$process_info" ]; then
            process_status=1
            # 获取进程详细信息
            process_info=$(ps aux | grep "$process_keyword" | grep -v grep | awk '{print $2, $11}' | head -1)
        fi
    fi

    # 综合判断状态
    if [ "$port_status" -eq 1 ] || [ "$process_status" -eq 1 ]; then
        echo -e "${GREEN}✅${NC} $component_name\t端口:$port\t状态:运行中"
        if [ -n "$process_info" ]; then
            echo -e "  └─ 进程: $process_info"
        fi
    else
        echo -e "${RED}❌${NC} $component_name\t端口:$port\t状态:未运行"
    fi
}

show_component_status() {
    print_header "常用组件运行状态检测"

    echo ""
    print_subheader "数据库应用"
    check_component_status "Oracle Database" "1521" "oracle.*smon"
    check_component_status "MySQL/MariaDB" "3306" "mysqld"
    check_component_status "PostgreSQL" "5432" "postgres"
    check_component_status "MongoDB" "27017" "mongod"

    echo ""
    print_subheader "缓存和队列应用"
    check_component_status "Redis" "6379" "redis-server"
    check_component_status "RabbitMQ" "5672" "rabbitmq"
    check_component_status "Kafka" "9092" "kafka.*server"

    echo ""
    print_subheader "搜索和分析应用"
    check_component_status "Elasticsearch" "9200" "elasticsearch"
    check_component_status "Kibana" "5601" "kibana"

    echo ""
    print_subheader "其他应用"
    check_component_status "Nginx" "80" "nginx"
    check_component_status "Apache" "80" "httpd"

    echo ""
    print_subheader "快速状态总结"
    echo ""

    # 统计运行中的组件
    local running_components=0
    local total_components=11

    local components=(
        "1521:oracle.*smon"
        "3306:mysqld"
        "5432:postgres"
        "27017:mongod"
        "6379:redis-server"
        "5672:rabbitmq"
        "9092:kafka.*server"
        "9200:elasticsearch"
        "5601:kibana"
        "80:nginx"
        "80:httpd"
    )

    for comp in "${components[@]}"; do
        local port="${comp%%:*}"
        local keyword="${comp##*:}"

        if command_exists ss; then
            if ss -tulpn 2>/dev/null | grep -q ":$port "; then
                ((running_components++))
                continue
            fi
        elif command_exists netstat; then
            if netstat -tulpn 2>/dev/null | grep -q ":$port "; then
                ((running_components++))
                continue
            fi
        fi

        if pgrep -f "$keyword" >/dev/null 2>&1; then
            ((running_components++))
        fi
    done

    print_info "检测到 $running_components / 11 个常用组件正在运行"

    if [ "$running_components" -eq 0 ]; then
        print_warning "未发现正在运行的常用组件"
    elif [ "$running_components" -lt 3 ]; then
        print_warning "仅有少数组件在运行，请检查系统配置"
    else
        print_success "系统中有多个组件处于活跃状态"
    fi
}

################################################################################
# 系统安全情况模块
################################################################################
show_security_info() {
    print_header "系统安全情况"

    # 防火墙状态
    print_subheader "防火墙状态"
    if command_exists firewall-cmd; then
        if systemctl is-active firewalld >/dev/null 2>&1; then
            print_success "firewalld 正在运行"
            local default_zone=$(firewall-cmd --get-default-zone 2>/dev/null)
            print_info "默认区域: $default_zone"

            # 显示开放的端口
            local open_ports=$(firewall-cmd --list-ports 2>/dev/null)
            if [ -n "$open_ports" ]; then
                print_info "开放端口: $open_ports"
            fi
        else
            print_warning "firewalld 未运行"
        fi
    elif command_exists iptables; then
        if iptables -L >/dev/null 2>&1; then
            local rule_count=$(iptables -L | grep -c "^Chain\|^target")
            print_success "iptables 已配置 ($rule_count 条规则)"
        else
            print_warning "iptables 无法访问（需要root权限）"
        fi
    else
        print_error "未检测到防火墙（firewalld/iptables）"
    fi

    # SELinux状态
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
                print_error "SELinux: Disabled（已禁用）"
                ;;
            *)
                print_info "SELinux: 状态未知"
                ;;
        esac
    else
        print_info "SELinux 未安装或不支持"
    fi

    # 用户账户安全检查
    print_subheader "用户账户安全"
    if [ -r /etc/passwd ]; then
        # 检查空密码账户
        if [ -r /etc/shadow ]; then
            local empty_pass=$(awk -F: '($2 == "" || $2 == "!") {print $1}' /etc/shadow 2>/dev/null | grep -v "^#")
            if [ -n "$empty_pass" ]; then
                print_error "发现空密码或锁定账户:"
                echo "$empty_pass" | while read -r user; do
                    print_info "  - $user"
                done
            else
                print_success "未发现空密码账户"
            fi
        fi

        # 检查UID为0的账户（root权限）
        local uid_zero=$(awk -F: '($3 == 0) {print $1}' /etc/passwd)
        local uid_zero_count=$(echo "$uid_zero" | wc -l)
        if [ "$uid_zero_count" -gt 1 ]; then
            print_warning "发现多个UID=0的账户（root权限）:"
            echo "$uid_zero" | while read -r user; do
                print_info "  - $user"
            done
        else
            print_success "仅有root账户拥有UID=0"
        fi

        # sudo权限用户
        if [ -r /etc/sudoers ] || [ -d /etc/sudoers.d ]; then
            print_info "具有sudo权限的用户:"
            if command_exists getent; then
                getent group sudo wheel 2>/dev/null | cut -d: -f4 | tr ',' '\n' | while read -r user; do
                    [ -n "$user" ] && print_info "  - $user"
                done
            fi
        fi
    fi

    # 重要文件权限检查
    print_subheader "重要文件权限检查"
    local critical_files=(
        "/etc/passwd"
        "/etc/shadow"
        "/etc/sudoers"
        "/root/.ssh/authorized_keys"
        "/etc/ssh/sshd_config"
    )

    for file in "${critical_files[@]}"; do
        if [ -e "$file" ]; then
            local perms=$(stat -c "%a %U:%G" "$file" 2>/dev/null || stat -f "%p %Su:%Sg" "$file" 2>/dev/null)
            # 检查危险权限
            local file_perm=$(echo $perms | awk '{print $1}' | tail -c 4)
            if [[ "$file" == *"shadow"* ]] || [[ "$file" == *"sudoers"* ]]; then
                if [[ ! "$file_perm" =~ ^[0-4][0-4][0-4]$ ]]; then
                    print_warning "$file: $perms (权限过于宽松)"
                else
                    print_success "$file: $perms"
                fi
            else
                print_info "$file: $perms"
            fi
        fi
    done

    # SSH配置安全检查
    print_subheader "SSH配置安全"
    if [ -f /etc/ssh/sshd_config ]; then
        # Root登录检查
        local permit_root=$(grep "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}')
        if [ "$permit_root" = "yes" ]; then
            print_error "允许Root直接登录 (不安全)"
        elif [ "$permit_root" = "no" ]; then
            print_success "禁止Root直接登录"
        else
            print_info "Root登录配置: ${permit_root:-默认}"
        fi

        # 密码认证检查
        local password_auth=$(grep "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}')
        if [ "$password_auth" = "no" ]; then
            print_success "已禁用密码认证（仅密钥）"
        else
            print_warning "密码认证已启用"
        fi

        # SSH端口检查
        local ssh_port=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}')
        if [ -n "$ssh_port" ] && [ "$ssh_port" != "22" ]; then
            print_success "SSH端口已修改: $ssh_port"
        else
            print_warning "SSH使用默认端口22（建议修改）"
        fi
    fi

    # 可疑进程检查
    print_subheader "可疑进程检查"
    if command_exists ps; then
        # 检查常见挖矿程序
        local suspicious_procs=$(ps aux | grep -iE "xmrig|minerd|ccminer|cgminer|bitminer|nanopool" | grep -v grep)
        if [ -n "$suspicious_procs" ]; then
            print_error "发现可疑挖矿进程:"
            echo "$suspicious_procs" | while read -r line; do
                print_info "  $line"
            done
        else
            print_success "未发现可疑挖矿进程"
        fi
    fi

    # 系统更新状态（针对不同发行版）
    print_subheader "系统更新状态"
    if command_exists yum; then
        local updates=$(yum check-update 2>/dev/null | grep -v "^$\|^Loaded\|^Last" | wc -l)
        if [ "$updates" -gt 0 ]; then
            print_warning "有 $updates 个可用更新"
        else
            print_success "系统已是最新"
        fi
    elif command_exists apt; then
        print_info "使用 'apt list --upgradable' 查看可用更新"
    fi

    # 防火墙管理入口
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "是否进入防火墙管理（查看/修改规则）？(y/N): " fw_enter
    if [[ "$fw_enter" =~ ^[Yy]$ ]]; then
        manage_firewall
    fi
}

################################################################################
# Crontab定时任务管理模块
################################################################################
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
manage_time_sync() {
    print_header "NTP/Chrony时间同步管理"

    # 显示主线流程说明
    print_subheader "时间同步工作流程"
    cat << 'EOF'
系统时间同步的完整流程：

【时间同步设置流程】
1️⃣  检查当前状态 → 了解系统是否已同步时间
2️⃣  选择同步方案 → NTP或Chrony (建议用Chrony)
3️⃣  手动同步时间 → 立即同步至网络时间
4️⃣  启动同步服务 → 让服务后台持续同步
5️⃣  开机自启配置 → 重启后自动启动同步服务

【两种同步方案对比】
┌──────────────────────┬─────────────────────┬─────────────────────┐
│ 功能特性             │ NTP (传统)          │ Chrony (现代推荐)    │
├──────────────────────┼─────────────────────┼─────────────────────┤
│ 启动速度             │ 较慢(10分钟左右)     │ 很快(几分钟)        │
│ 同步精度             │ ±100ms              │ ±1ms                │
│ 离线工作             │ 否                  │ 是(自适应)          │
│ 资源占用             │ 中等                │ 较低                │
│ 虚拟机环境           │ 一般                │ 优秀                │
├──────────────────────┼─────────────────────┼─────────────────────┤
│ 配置文件             │ /etc/ntp.conf       │ /etc/chrony.conf    │
│ 管理命令             │ ntpq, ntpstat       │ chronyc             │
│ 同步命令             │ ntpdate             │ chronyc makestep    │
└──────────────────────┴─────────────────────┴─────────────────────┘

【快速开始】
✓ 查看状态: 选择菜单1或2查看NTP/Chrony状态
✓ 手动同步: 选择菜单3或4手动同步时间
✓ 启动服务: 选择菜单5选择启动NTP或Chrony
✓ 配置方案: 选择菜单6编辑NTP或Chrony配置

EOF

    echo ""
    # 检测当前时间同步服务
    print_subheader "时间同步服务检测"

    local has_ntp=0
    local has_chrony=0
    local ntp_status=""
    local chrony_status=""

    if command_exists ntpd 2>/dev/null || systemctl list-unit-files 2>/dev/null | grep -q ntp; then
        has_ntp=1
        if systemctl is-active ntpd >/dev/null 2>&1; then
            ntp_status="运行中"
            print_success "NTP服务: 已安装且运行中"
        else
            ntp_status="已停止"
            print_warning "NTP服务: 已安装但未运行"
        fi
    fi

    if command_exists chronyd 2>/dev/null || systemctl list-unit-files 2>/dev/null | grep -q chrony; then
        has_chrony=1
        if systemctl is-active chronyd >/dev/null 2>&1; then
            chrony_status="运行中"
            print_success "Chrony服务: 已安装且运行中"
        else
            chrony_status="已停止"
            print_warning "Chrony服务: 已安装但未运行"
        fi
    fi

    if [ "$has_ntp" -eq 0 ] && [ "$has_chrony" -eq 0 ]; then
        print_error "未检测到NTP或Chrony服务"
    fi

    echo ""
    print_subheader "当前系统时间"
    print_info "系统时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    print_info "时区: $(timedatectl show --property=Timezone --value 2>/dev/null || echo '未知')"
    print_info "时间同步状态: $(timedatectl show --property=NTPSynchronized --value 2>/dev/null || echo '未知')"

    echo ""
    print_subheader "时间同步管理选项"
    echo "1. 查看NTP服务状态详情"
    echo "2. 查看Chrony服务状态详情"
    echo "3. 手动同步时间（NTP）"
    echo "4. 手动同步时间（Chrony）"
    echo "5. 启动/停止时间同步服务"
    echo "6. 配置时间同步服务"
    echo "0. 返回主菜单"
    echo ""

    read -p "请选择操作 (0-6): " sync_choice

    case $sync_choice in
        1)
            show_ntp_status
            ;;
        2)
            show_chrony_status
            ;;
        3)
            manual_ntp_sync
            ;;
        4)
            manual_chrony_sync
            ;;
        5)
            manage_sync_service
            ;;
        6)
            configure_time_sync
            ;;
        0)
            return 0
            ;;
        *)
            print_error "无效的选择"
            ;;
    esac
}

# 显示NTP服务状态
show_ntp_status() {
    print_subheader "NTP服务详细状态"
    if command_exists ntpq; then
        ntpq -p
    elif command_exists ntpstat; then
        ntpstat
    elif systemctl is-active ntpd >/dev/null 2>&1; then
        systemctl status ntpd
    else
        print_error "NTP服务未安装或未运行"
    fi
}

# 显示Chrony服务状态
show_chrony_status() {
    print_subheader "Chrony服务详细状态"
    if command_exists chronyc; then
        chronyc tracking
        echo ""
        chronyc sources
    elif systemctl is-active chronyd >/dev/null 2>&1; then
        systemctl status chronyd
    else
        print_error "Chrony服务未安装或未运行"
    fi
}

# 手动同步时间（NTP）
manual_ntp_sync() {
    print_subheader "手动同步时间（NTP）"
    print_info "正在执行NTP时间同步..."

    if [ "$EUID" -ne 0 ]; then
        print_warning "需要root权限才能同步时间"
        read -p "请输入NTP服务器地址 (按Enter跳过): " ntp_server
        if [ -z "$ntp_server" ]; then
            ntp_server="0.cn.pool.ntp.org"
        fi
        print_info "可以使用: sudo ntpdate -u $ntp_server"
    else
        read -p "请输入NTP服务器地址 (默认: 0.cn.pool.ntp.org): " ntp_server
        if [ -z "$ntp_server" ]; then
            ntp_server="0.cn.pool.ntp.org"
        fi

        if command_exists ntpdate; then
            if ntpdate -u "$ntp_server"; then
                print_success "时间同步成功"
            else
                print_error "时间同步失败"
            fi
        else
            print_warning "ntpdate命令不可用，请安装ntp包"
            print_info "CentOS/RHEL: sudo yum install ntp"
            print_info "Ubuntu/Debian: sudo apt-get install ntp"
        fi
    fi
}

# 手动同步时间（Chrony）
manual_chrony_sync() {
    print_subheader "手动同步时间（Chrony）"
    print_info "正在执行Chrony时间同步..."

    if [ "$EUID" -ne 0 ]; then
        print_warning "需要root权限才能同步时间"
        print_info "可以使用: sudo chronyc makestep"
    else
        if command_exists chronyc; then
            if chronyc makestep; then
                print_success "时间同步成功"
            else
                print_error "时间同步失败"
            fi
        else
            print_warning "chronyc命令不可用，请安装chrony包"
            print_info "CentOS/RHEL: sudo yum install chrony"
            print_info "Ubuntu/Debian: sudo apt-get install chrony"
        fi
    fi
}

# 管理时间同步服务
manage_sync_service() {
    print_subheader "管理时间同步服务"

    if [ "$EUID" -ne 0 ]; then
        print_error "需要root权限来管理服务"
        return 1
    fi

    echo "选择要管理的服务:"
    echo "1. 启动/停止NTP"
    echo "2. 启动/停止Chrony"
    echo "3. 启用/禁用开机自启"
    echo ""
    read -p "请选择 (1-3): " service_choice

    case $service_choice in
        1)
            if systemctl is-active ntpd >/dev/null 2>&1; then
                read -p "NTP正在运行，是否停止? (y/n): " stop_choice
                if [[ "$stop_choice" =~ ^[Yy]$ ]]; then
                    systemctl stop ntpd && print_success "NTP已停止"
                fi
            else
                read -p "NTP未运行，是否启动? (y/n): " start_choice
                if [[ "$start_choice" =~ ^[Yy]$ ]]; then
                    systemctl start ntpd && print_success "NTP已启动"
                fi
            fi
            ;;
        2)
            if systemctl is-active chronyd >/dev/null 2>&1; then
                read -p "Chrony正在运行，是否停止? (y/n): " stop_choice
                if [[ "$stop_choice" =~ ^[Yy]$ ]]; then
                    systemctl stop chronyd && print_success "Chrony已停止"
                fi
            else
                read -p "Chrony未运行，是否启动? (y/n): " start_choice
                if [[ "$start_choice" =~ ^[Yy]$ ]]; then
                    systemctl start chronyd && print_success "Chrony已启动"
                fi
            fi
            ;;
        3)
            echo "选择服务:"
            echo "1. NTP"
            echo "2. Chrony"
            read -p "请选择: " service_type

            case $service_type in
                1)
                    if systemctl is-enabled ntpd >/dev/null 2>&1; then
                        read -p "NTP已启用开机自启，是否禁用? (y/n): " disable_choice
                        if [[ "$disable_choice" =~ ^[Yy]$ ]]; then
                            systemctl disable ntpd && print_success "NTP开机自启已禁用"
                        fi
                    else
                        read -p "NTP未启用开机自启，是否启用? (y/n): " enable_choice
                        if [[ "$enable_choice" =~ ^[Yy]$ ]]; then
                            systemctl enable ntpd && print_success "NTP开机自启已启用"
                        fi
                    fi
                    ;;
                2)
                    if systemctl is-enabled chronyd >/dev/null 2>&1; then
                        read -p "Chrony已启用开机自启，是否禁用? (y/n): " disable_choice
                        if [[ "$disable_choice" =~ ^[Yy]$ ]]; then
                            systemctl disable chronyd && print_success "Chrony开机自启已禁用"
                        fi
                    else
                        read -p "Chrony未启用开机自启，是否启用? (y/n): " enable_choice
                        if [[ "$enable_choice" =~ ^[Yy]$ ]]; then
                            systemctl enable chronyd && print_success "Chrony开机自启已启用"
                        fi
                    fi
                    ;;
                *)
                    print_error "无效的选择"
                    ;;
            esac
            ;;
        *)
            print_error "无效的选择"
            ;;
    esac
}

# 配置时间同步服务
configure_time_sync() {
    print_subheader "配置时间同步服务"

    if [ "$EUID" -ne 0 ]; then
        print_error "需要root权限来修改配置"
        return 1
    fi

    echo "选择要配置的服务:"
    echo "1. 配置NTP服务器"
    echo "2. 配置Chrony服务器"
    echo ""
    read -p "请选择 (1-2): " config_choice

    case $config_choice in
        1)
            print_info "NTP配置文件: /etc/ntp.conf"
            read -p "是否打开编辑器? (y/n): " edit_choice
            if [[ "$edit_choice" =~ ^[Yy]$ ]]; then
                ${EDITOR:-nano} /etc/ntp.conf
                systemctl restart ntpd
                print_success "NTP配置已更新并重启"
            fi
            ;;
        2)
            print_info "Chrony配置文件: /etc/chrony.conf"
            read -p "是否打开编辑器? (y/n): " edit_choice
            if [[ "$edit_choice" =~ ^[Yy]$ ]]; then
                ${EDITOR:-nano} /etc/chrony.conf
                systemctl restart chronyd
                print_success "Chrony配置已更新并重启"
            fi
            ;;
        *)
            print_error "无效的选择"
            ;;
    esac
}

################################################################################
# 磁盘分区挂载管理模块
################################################################################
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
      mount -o remount,rw /
      恢复/etc/fstab.bak备份

【使用工具推荐】

查看分区: lsblk, fdisk, parted, gdisk
创建分区: fdisk(MBR), gdisk/parted(GPT)
格式化: mkfs, mkfs.ext4, mkfs.xfs
挂载管理: mount, umount, mountpoint
配置: vim/nano /etc/fstab

EOF
}

################################################################################
# I/O 工具自动安装辅助函数
################################################################################

# 自动安装缺失的 I/O 工具
auto_install_tool() {
    local tool_name="$1"
    local package_name="$2"

    # 如果工具已存在，直接返回成功
    if command_exists "$tool_name"; then
        return 0
    fi

    # 工具不存在，需要安装
    print_warning "检测到 $tool_name 未安装，正在尝试自动安装 ($package_name)..."

    # 检查是否为 root 用户
    if [ "$EUID" -ne 0 ]; then
        print_error "$tool_name 需要 root 权限安装"
        print_info "请使用以下命令手动安装:"

        local pkg_manager=$(get_package_manager)
        case "$pkg_manager" in
            yum|dnf)
                print_info "  sudo $pkg_manager install -y $package_name"
                ;;
            apt)
                print_info "  sudo apt-get update && sudo apt-get install -y $package_name"
                ;;
            *)
                print_info "  请根据系统包管理器安装: $package_name"
                ;;
        esac
        return 1
    fi

    # 获取包管理器
    local pkg_manager=$(get_package_manager)

    case "$pkg_manager" in
        yum)
            print_info "使用 yum 安装 $package_name..."
            if yum install -y "$package_name" > /dev/null 2>&1; then
                print_success "$package_name 安装成功"
                return 0
            else
                print_error "$package_name 安装失败"
                return 1
            fi
            ;;
        dnf)
            print_info "使用 dnf 安装 $package_name..."
            if dnf install -y "$package_name" > /dev/null 2>&1; then
                print_success "$package_name 安装成功"
                return 0
            else
                print_error "$package_name 安装失败"
                return 1
            fi
            ;;
        apt)
            print_info "使用 apt-get 安装 $package_name..."
            if apt-get update -qq > /dev/null 2>&1 && apt-get install -y "$package_name" > /dev/null 2>&1; then
                print_success "$package_name 安装成功"
                return 0
            else
                print_error "$package_name 安装失败"
                return 1
            fi
            ;;
        *)
            print_error "无法识别包管理器，无法自动安装"
            return 1
            ;;
    esac
}

################################################################################
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
# 防火墙管理模块
################################################################################
manage_firewall() {
    print_header "防火墙管理工具"

    # 检查防火墙类型
    local firewall_type=""
    if command_exists firewall-cmd; then
        firewall_type="firewalld"
    elif command_exists ufw; then
        firewall_type="ufw"
    else
        print_error "未发现支持的防火墙工具 (firewalld/ufw)"
        print_info "请先安装防火墙工具:"
        print_info "  CentOS/RHEL: yum install firewalld"
        print_info "  Ubuntu: apt install ufw"
        return 1
    fi

    print_success "检测到防火墙: $firewall_type"
    echo ""

    if [ "$firewall_type" = "firewalld" ]; then
        manage_firewalld
    else
        manage_ufw
    fi
}

manage_firewalld() {
    while true; do
        echo ""
        print_subheader "Firewalld 管理菜单"
        echo -e "  ${GREEN}1${NC}) 查看防火墙状态"
        echo -e "  ${GREEN}2${NC}) 列出所有规则"
        echo -e "  ${GREEN}3${NC}) 查看开放端口"
        echo -e "  ${GREEN}4${NC}) 添加端口规则"
        echo -e "  ${GREEN}5${NC}) 删除端口规则"
        echo -e "  ${GREEN}6${NC}) 添加服务规则"
        echo -e "  ${GREEN}7${NC}) 重新加载配置"
        echo -e "  ${RED}0${NC}) 返回主菜单"
        echo ""

        read -p "请选择操作 [0-7]: " fw_choice
        echo ""

        case $fw_choice in
            1)
                print_subheader "防火墙状态"
                if systemctl is-active --quiet firewalld; then
                    print_success "Firewalld 状态: 运行中"
                else
                    print_warning "Firewalld 状态: 已停止"
                fi
                systemctl status firewalld --no-pager
                ;;
            2)
                print_subheader "所有防火墙规则"
                firewall-cmd --list-all
                ;;
            3)
                print_subheader "开放的端口"
                echo "TCP 端口:"
                firewall-cmd --list-ports | tr ' ' '\n' | grep '/tcp' | sort -V
                echo ""
                echo "UDP 端口:"
                firewall-cmd --list-ports | tr ' ' '\n' | grep '/udp' | sort -V
                echo ""
                echo "允许的服务:"
                firewall-cmd --list-services
                ;;
            4)
                print_subheader "添加端口规则"
                read -p "请输入端口号 (如: 8080): " port
                read -p "请输入协议 (tcp/udp, 默认 tcp): " protocol
                protocol=${protocol:-tcp}

                if [ -n "$port" ] && [[ "$port" =~ ^[0-9]+$ ]]; then
                    print_info "添加规则: 端口 $port/$protocol"
                    firewall-cmd --permanent --add-port="$port/$protocol"
                    firewall-cmd --reload
                    print_success "规则已添加并重新加载"
                else
                    print_error "无效的端口号"
                fi
                ;;
            5)
                print_subheader "删除端口规则"
                read -p "请输入要删除的端口号 (如: 8080): " port
                read -p "请输入协议 (tcp/udp, 默认 tcp): " protocol
                protocol=${protocol:-tcp}

                if [ -n "$port" ] && [[ "$port" =~ ^[0-9]+$ ]]; then
                    print_info "删除规则: 端口 $port/$protocol"
                    firewall-cmd --permanent --remove-port="$port/$protocol"
                    firewall-cmd --reload
                    print_success "规则已删除并重新加载"
                else
                    print_error "无效的端口号"
                fi
                ;;
            6)
                print_subheader "添加服务规则"
                print_info "常用服务: http, https, ssh, ftp, mysql, postgresql, redis, mongodb"
                read -p "请输入服务名称: " service_name

                if [ -n "$service_name" ]; then
                    print_info "添加服务: $service_name"
                    firewall-cmd --permanent --add-service="$service_name"
                    firewall-cmd --reload
                    print_success "服务规则已添加"
                else
                    print_error "服务名称不能为空"
                fi
                ;;
            7)
                print_subheader "重新加载配置"
                firewall-cmd --reload
                print_success "配置已重新加载"
                ;;
            0)
                print_info "返回主菜单..."
                break
                ;;
            *)
                print_error "无效的选项"
                ;;
        esac
    done
}

manage_ufw() {
    while true; do
        echo ""
        print_subheader "UFW 管理菜单"
        echo -e "  ${GREEN}1${NC}) 查看防火墙状态"
        echo -e "  ${GREEN}2${NC}) 列出所有规则"
        echo -e "  ${GREEN}3${NC}) 查看开放端口"
        echo -e "  ${GREEN}4${NC}) 添加端口规则"
        echo -e "  ${GREEN}5${NC}) 删除端口规则"
        echo -e "  ${GREEN}6${NC}) 启用防火墙"
        echo -e "  ${GREEN}7${NC}) 禁用防火墙"
        echo -e "  ${RED}0${NC}) 返回主菜单"
        echo ""

        read -p "请选择操作 [0-7]: " fw_choice
        echo ""

        case $fw_choice in
            1)
                print_subheader "防火墙状态"
                ufw status
                ;;
            2)
                print_subheader "所有防火墙规则"
                ufw show added
                ;;
            3)
                print_subheader "开放的端口"
                ufw status | grep -E "^[0-9]+.*ALLOW"
                ;;
            4)
                print_subheader "添加端口规则"
                read -p "请输入端口号 (如: 8080): " port
                read -p "请输入协议 (tcp/udp, 默认 tcp): " protocol
                protocol=${protocol:-tcp}

                if [ -n "$port" ] && [[ "$port" =~ ^[0-9]+$ ]]; then
                    print_info "添加规则: 端口 $port/$protocol"
                    ufw allow "$port/$protocol"
                    print_success "规则已添加"
                else
                    print_error "无效的端口号"
                fi
                ;;
            5)
                print_subheader "删除端口规则"
                read -p "请输入要删除的端口号 (如: 8080): " port
                read -p "请输入协议 (tcp/udp, 默认 tcp): " protocol
                protocol=${protocol:-tcp}

                if [ -n "$port" ] && [[ "$port" =~ ^[0-9]+$ ]]; then
                    print_info "删除规则: 端口 $port/$protocol"
                    ufw delete allow "$port/$protocol"
                    print_success "规则已删除"
                else
                    print_error "无效的端口号"
                fi
                ;;
            6)
                print_subheader "启用防火墙"
                ufw enable
                print_success "防火墙已启用"
                ;;
            7)
                print_subheader "禁用防火墙"
                read -p "确认要禁用防火墙吗? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    ufw disable
                    print_warning "防火墙已禁用"
                else
                    print_info "操作已取消"
                fi
                ;;
            0)
                print_info "返回主菜单..."
                break
                ;;
            *)
                print_error "无效的选项"
                ;;
        esac
    done
}

################################################################################
# DNS配置管理模块
################################################################################
manage_dns_config() {
    print_header "DNS配置管理"

    while true; do
        echo ""
        print_subheader "当前DNS配置"
        if [ -f /etc/resolv.conf ]; then
            local dns_servers=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}')
            if [ -n "$dns_servers" ]; then
                echo "$dns_servers" | while read -r dns; do
                    print_info "DNS服务器: $dns"
                done
            else
                print_warning "未配置DNS服务器"
            fi
        else
            print_error "/etc/resolv.conf 文件不存在"
        fi

        echo ""
        print_subheader "DNS管理选项"
        echo -e "  ${GREEN}1${NC}) 查看完整DNS配置"
        echo -e "  ${GREEN}2${NC}) 添加DNS服务器"
        echo -e "  ${GREEN}3${NC}) 替换DNS服务器"
        echo -e "  ${GREEN}4${NC}) 使用默认DNS (114.114.114.114)"
        echo -e "  ${GREEN}5${NC}) 测试DNS解析"
        echo -e "  ${RED}0${NC}) 返回上级菜单"
        echo ""

        read -p "请选择操作 [0-5]: " dns_choice
        echo ""

        case $dns_choice in
            1)
                print_subheader "完整DNS配置文件"
                if [ -f /etc/resolv.conf ]; then
                    cat /etc/resolv.conf
                else
                    print_error "/etc/resolv.conf 文件不存在"
                fi
                ;;
            2)
                print_subheader "添加DNS服务器"
                read -p "请输入DNS服务器地址 (如: 8.8.8.8): " new_dns
                if [ -n "$new_dns" ]; then
                    if [[ "$new_dns" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                        echo "nameserver $new_dns" | sudo tee -a /etc/resolv.conf >/dev/null
                        print_success "DNS服务器 $new_dns 已添加"
                    else
                        print_error "无效的IP地址格式"
                    fi
                fi
                ;;
            3)
                print_subheader "替换DNS服务器"
                print_warning "此操作将清空现有DNS配置"
                read -p "请输入新的DNS服务器地址 (如: 8.8.8.8，多个用空格分隔): " new_dns_list
                if [ -n "$new_dns_list" ]; then
                    read -p "确认替换DNS配置? (y/N): " confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        sudo cp /etc/resolv.conf /etc/resolv.conf.backup.$(date +%Y%m%d_%H%M%S)
                        echo "# Generated by server_check.sh" | sudo tee /etc/resolv.conf >/dev/null
                        for dns in $new_dns_list; do
                            if [[ "$dns" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                                echo "nameserver $dns" | sudo tee -a /etc/resolv.conf >/dev/null
                                print_success "已添加DNS: $dns"
                            else
                                print_warning "跳过无效IP: $dns"
                            fi
                        done
                        print_success "DNS配置已更新，旧配置已备份"
                    else
                        print_info "操作已取消"
                    fi
                fi
                ;;
            4)
                print_subheader "使用默认DNS (114.114.114.114)"
                read -p "是否使用 114.114.114.114 作为DNS服务器? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    sudo cp /etc/resolv.conf /etc/resolv.conf.backup.$(date +%Y%m%d_%H%M%S)
                    echo "# Generated by server_check.sh" | sudo tee /etc/resolv.conf >/dev/null
                    echo "nameserver 114.114.114.114" | sudo tee -a /etc/resolv.conf >/dev/null
                    echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf >/dev/null
                    print_success "DNS已配置为 114.114.114.114 (主) 和 8.8.8.8 (备)"
                    print_info "旧配置已备份"
                else
                    print_info "操作已取消"
                fi
                ;;
            5)
                print_subheader "测试DNS解析"
                read -p "请输入要测试的域名 (默认: www.baidu.com): " test_domain
                test_domain=${test_domain:-www.baidu.com}
                print_info "正在解析 $test_domain ..."
                if resolve_dns "$test_domain"; then
                    print_success "DNS解析成功"
                else
                    print_error "DNS解析失败"
                fi
                ;;
            0)
                return 0
                ;;
            *)
                print_error "无效的选项"
                ;;
        esac
    done
}

################################################################################
# 网络诊断工具模块
################################################################################

show_network_tools() {
    print_header "网络诊断工具"

    print_info "网络诊断工具提供交互式测试，请按照提示操作"
    echo ""

    # 网络接口信息
    print_subheader "网络接口信息"
    if command_exists ip; then
        local interfaces=$(ip -br addr show | grep -v "^lo")
        if [ -n "$interfaces" ]; then
            echo "$interfaces" | while read -r line; do
                print_info "$line"
            done
        fi

        # 网卡流量统计
        print_info ""
        print_info "网卡流量统计:"
        ip -s link show | grep -E "^[0-9]+:|RX:|TX:" | while read -r line; do
            if [[ "$line" =~ ^[0-9]+: ]]; then
                print_info "  $line"
            else
                print_info "    $line"
            fi
        done | head -20
    elif command_exists ifconfig; then
        ifconfig | grep -E "^[a-z]|inet " | while read -r line; do
            print_info "$line"
        done
    fi

    # 公网IP地址
    print_subheader "公网IP地址"
    if command_exists curl; then
        local public_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 ipinfo.io/ip 2>/dev/null || curl -s --max-time 5 icanhazip.com 2>/dev/null)
        if [ -n "$public_ip" ]; then
            print_info "公网IP: $public_ip"
        else
            print_warning "无法获取公网IP（网络连接失败）"
        fi
    elif command_exists wget; then
        local public_ip=$(wget -qO- --timeout=5 ifconfig.me 2>/dev/null || wget -qO- --timeout=5 ipinfo.io/ip 2>/dev/null || wget -qO- --timeout=5 icanhazip.com 2>/dev/null)
        if [ -n "$public_ip" ]; then
            print_info "公网IP: $public_ip"
        else
            print_warning "无法获取公网IP（网络连接失败）"
        fi
    else
        print_warning "curl和wget命令均不可用，无法获取公网IP"
    fi

    # 默认网关
    print_subheader "默认网关"
    if command_exists ip; then
        local gateway=$(ip route | grep default | awk '{print $3}')
        if [ -n "$gateway" ]; then
            print_info "默认网关: $gateway"
        else
            print_warning "未找到默认网关"
        fi
    fi

    # DNS配置
    print_subheader "DNS配置"
    if [ -f /etc/resolv.conf ]; then
        local dns_servers=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}')
        if [ -n "$dns_servers" ]; then
            echo "$dns_servers" | while read -r dns; do
                print_info "DNS服务器: $dns"
            done
        fi
    fi

    # 当前网络连接统计
    print_subheader "网络连接统计"
    if command_exists ss; then
        local tcp_count=$(ss -tan | grep -c ESTAB)
        local udp_count=$(ss -uan | wc -l)
        print_info "已建立的TCP连接数: $tcp_count"
        print_info "UDP连接数: $udp_count"
    elif command_exists netstat; then
        local tcp_count=$(netstat -tan | grep -c ESTABLISHED)
        print_info "已建立的TCP连接数: $tcp_count"
    fi

    # ARP表
    print_subheader "ARP缓存表"
    if command_exists arp; then
        local arp_entries=$(arp -an 2>/dev/null | grep -v "incomplete" | wc -l)
        if [ "$arp_entries" -gt 0 ]; then
            print_info "ARP缓存条目数: $arp_entries"
            arp -an 2>/dev/null | grep -v "incomplete" | head -15 | while read -r line; do
                print_info "  $line"
            done
        else
            print_info "ARP缓存为空"
        fi
    elif command_exists ip; then
        local arp_entries=$(ip neigh show 2>/dev/null | grep -v "FAILED" | wc -l)
        if [ "$arp_entries" -gt 0 ]; then
            print_info "ARP缓存条目数: $arp_entries"
            ip neigh show 2>/dev/null | grep -v "FAILED" | head -15 | while read -r line; do
                print_info "  $line"
            done
        else
            print_info "ARP缓存为空"
        fi
    else
        print_warning "arp和ip命令均不可用"
    fi

    # 提供交互式测试选项
    print_subheader "交互式网络测试工具"
    print_info "1. Ping测试 - 测试到目标主机的连通性"
    print_info "2. Telnet测试 - 测试TCP端口是否开放"
    print_info "3. Traceroute - 追踪到目标主机的路由路径"
    print_info "4. DNS解析测试 - 测试域名解析"
    print_info "5. 端口扫描 - 扫描常用端口"
    print_info "6. 网络连接查看 - 查看当前网络连接"
    print_info "7. 网速测试 - 测试网络带宽"
    print_info "8. 端口/连接查询 - 查询特定端口或IP的连接"
    print_info "9. 防火墙管理 - 管理防火墙规则和端口"
    print_info "10. DNS配置管理 - 查看和修改DNS服务器配置"
    echo ""

    # 如果是交互模式，提供工具使用
    if [ -t 0 ]; then
        read -p "是否执行网络测试或管理? (y/N): " do_test
        if [[ "$do_test" =~ ^[Yy]$ ]]; then
            echo ""
            read -p "选择测试类型 (1-10): " test_type

            case $test_type in
                1)
                    read -p "请输入目标主机: " target_host
                    if [ -n "$target_host" ]; then
                        print_subheader "Ping测试: $target_host"
                        if command_exists ping; then
                            ping -c 4 "$target_host"
                        else
                            print_error "ping命令不可用"
                        fi
                    fi
                    ;;
                2)
                    read -p "请输入目标主机: " target_host
                    read -p "请输入端口号: " target_port
                    if [ -n "$target_host" ] && [ -n "$target_port" ]; then
                        print_subheader "Telnet测试: $target_host:$target_port"
                        if command_exists telnet; then
                            timeout 5 telnet "$target_host" "$target_port"
                        elif command_exists nc; then
                            nc -zv "$target_host" "$target_port"
                        else
                            print_error "telnet和nc命令均不可用"
                        fi
                    fi
                    ;;
                3)
                    read -p "请输入目标主机: " target_host
                    if [ -n "$target_host" ]; then
                        print_subheader "Traceroute: $target_host"
                        if ! trace_route "$target_host"; then
                            print_error "无法追踪路由 (缺失 traceroute/tracepath 命令)"
                            suggest_install_tool "traceroute"
                        fi
                    fi
                    ;;
                4)
                    read -p "请输入域名: " domain
                    if [ -n "$domain" ]; then
                        print_subheader "DNS解析测试: $domain"
                        if ! resolve_dns "$domain"; then
                            print_error "DNS解析失败 (缺失 nslookup/dig/host/getent 命令)"
                            suggest_install_tool "dig"
                        fi
                    fi
                    ;;
                5)
                    read -p "请输入目标主机: " target_host
                    if [ -n "$target_host" ]; then
                        print_subheader "常用端口扫描: $target_host"
                        # 扩展的端口列表（包括数据库端口）
                        local common_ports="22 80 443 3306 5432 6379 8080 9000 1521 27017 5672 15672"

                        # 检查是否有任何扫描工具可用
                        if ! command_exists nc && ! command_exists telnet; then
                            print_warning "缺失扫描工具 (nc/telnet)，尝试使用基础方法..."
                        fi

                        echo ""
                        for port in $common_ports; do
                            local service="${PORT_SERVICES[$port]:-未知服务}"
                            if scan_port "$target_host" "$port"; then
                                print_success "端口 $port ($service): 开放"
                            else
                                print_info "端口 $port ($service): 关闭或无法访问"
                            fi
                        done
                        echo ""
                    fi
                    ;;
                6)
                    print_subheader "当前网络连接"
                    if command_exists ss; then
                        ss -tunap | head -30
                    elif command_exists netstat; then
                        # macOS的netstat不支持-p选项，使用兼容的方式
                        if [[ "$OSTYPE" == "darwin"* ]]; then
                            netstat -tuan | head -30
                        else
                            netstat -tunap | head -30
                        fi
                    else
                        print_error "ss和netstat命令均不可用"
                    fi
                    ;;
                7)
                    print_subheader "网速测试"
                    print_info "正在进行网速测试，请稍候..."

                    if command_exists speedtest-cli; then
                        # 使用speedtest-cli（如果已安装）
                        speedtest-cli --simple
                    elif command_exists curl; then
                        # 使用curl下载测试文件
                        print_info "使用curl进行下载速度测试..."
                        local test_url="http://speedtest.tele2.net/10MB.zip"
                        print_info "测试文件: $test_url"

                        local start_time=$(date +%s)
                        curl -o /dev/null -s -w "下载速度: %{speed_download} bytes/sec\n下载时间: %{time_total} 秒\n" "$test_url"

                        print_info ""
                        print_warning "提示: 安装speedtest-cli可获得更准确的测速结果"
                        print_info "安装方法: pip install speedtest-cli 或 apt/yum install speedtest-cli"
                    elif command_exists wget; then
                        # 使用wget下载测试文件
                        print_info "使用wget进行下载速度测试..."
                        local test_url="http://speedtest.tele2.net/10MB.zip"
                        print_info "测试文件: $test_url"

                        wget -O /dev/null "$test_url" 2>&1 | grep -E "saved|/s"

                        print_info ""
                        print_warning "提示: 安装speedtest-cli可获得更准确的测速结果"
                        print_info "安装方法: pip install speedtest-cli 或 apt/yum install speedtest-cli"
                    else
                        print_error "未找到可用的测速工具"
                        print_info "请安装以下工具之一："
                        print_info "  - speedtest-cli (推荐): pip install speedtest-cli"
                        print_info "  - curl: apt/yum install curl"
                        print_info "  - wget: apt/yum install wget"
                    fi
                    ;;
                8)
                    print_subheader "端口/连接查询"
                    echo "查询选项:"
                    echo "1) 按端口号查询 (如: 1521, 5432, 27017)"
                    echo "2) 按IP地址查询 (如: 192.168.1.100)"
                    read -p "请选择查询类型 (1-2): " query_choice

                    if [ "$query_choice" = "1" ]; then
                        read -p "请输入端口号: " port_num
                        if [ -n "$port_num" ] && [ "$port_num" -eq "$port_num" ] 2>/dev/null; then
                            query_port_connections "port" "$port_num"
                        else
                            print_error "请输入有效的端口号"
                        fi
                    elif [ "$query_choice" = "2" ]; then
                        read -p "请输入IP地址: " ip_addr
                        if [ -n "$ip_addr" ]; then
                            query_port_connections "ip" "$ip_addr"
                        else
                            print_error "请输入有效的IP地址"
                        fi
                    else
                        print_error "无效的选择"
                    fi
                    ;;
                9)
                    manage_firewall
                    ;;
                10)
                    manage_dns_config
                    ;;
                *)
                    print_warning "无效的选项"
                    ;;
            esac
        fi
    else
        print_info "非交互模式，跳过网络测试"
        print_info "手动测试示例:"
        print_info "  ping -c 4 <host>          # Ping测试"
        print_info "  telnet <host> <port>      # 端口测试"
        print_info "  traceroute <host>         # 路由追踪"
        print_info "  nslookup <domain>         # DNS解析"
        print_info "  nc -zv <host> <port>      # 端口扫描"
    fi
}

################################################################################
# 交互式菜单
################################################################################
show_menu() {
    clear
    echo -e "${PURPLE}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║   Linux服务器信息收集与安全检查工具                      ║
║   Server Check Tool v2.0.0                                ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    print_info "操作系统: $OS_NAME"
    print_info "检测时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}请选择要执行的功能:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}) 系统基本信息检查"
    echo -e "  ${GREEN}2${NC}) 系统异常访问检查"
    echo -e "  ${GREEN}3${NC}) 常用组件运行状态检测"
    echo -e "  ${GREEN}4${NC}) 系统服务部署信息"
    echo -e "  ${GREEN}5${NC}) 系统安全情况检查"
    echo -e "  ${GREEN}6${NC}) 网络诊断工具"
    echo -e "  ${GREEN}7${NC}) 版本和功能介绍"
    echo -e "  ${GREEN}8${NC}) Crontab定时任务管理"
    echo -e "  ${GREEN}9${NC}) NTP/Chrony时间同步"
    echo -e "  ${GREEN}10${NC}) 磁盘分区挂载工具"
    echo -e "  ${GREEN}11${NC}) 磁盘 I/O 性能检查"
    echo -e "  ${GREEN}12${NC}) 完整检查（所有模块）"
    echo -e "  ${GREEN}13${NC}) 导出报告到文件"
    echo -e "  ${RED}0${NC}) 退出"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 显示完整的欢迎屏幕（版本信息 + 菜单）
show_welcome_screen() {
    print_header "版本和功能介绍"

    echo -e "${BLUE}▸ 工具版本信息${NC}"
    print_info "工具名称: Linux服务器信息收集与安全检查工具"
    print_info "版本号: v$SCRIPT_VERSION"
    print_info "发布日期: $SCRIPT_RELEASE_DATE"
    print_info "支持系统: CentOS, Kylin麒麟, UOS, Ubuntu等"

    echo ""
    echo -e "${BLUE}▸ 核心功能模块${NC}"
    print_info "1. 系统基本信息检查 - 查看CPU、内存、磁盘、网络等系统关键信息"
    print_info "2. 系统异常访问检查 - 监控SSH登录、暴力破解、可疑连接等安全事件"
    print_info "3. 常用组件运行状态检测 - 检测Oracle、MySQL、Redis、Kafka等应用运行状态"
    print_info "4. 系统服务部署信息 - 显示运行中的服务、监听端口、Docker容器状态"
    print_info "5. 系统安全情况检查 - 防火墙、SELinux、用户权限、文件安全等检查"
    print_info "6. 网络诊断工具 - Ping、Telnet、DNS解析、端口扫描、网速测试、防火墙管理等"
    print_info "7. 版本和功能介绍 - 显示工具版本和所有功能说明"
    print_info "8. Crontab定时任务管理 - 查看、添加、删除定时任务，支持常用模板"
    print_info "9. NTP/Chrony时间同步 - 管理时间同步服务，同步系统时间"
    print_info "10. 磁盘分区挂载工具 - MBR/GPT分区识别、挂载、文件系统管理"
    print_info "11. 磁盘 I/O 性能检查 - iostat实时监控、fio基准测试、SMART健康检查"

    echo ""
    echo -e "${BLUE}▸ 功能特点${NC}"
    print_success "✓ 支持多种Linux发行版（RedHat系、Debian系、国产操作系统）"
    print_success "✓ 完整的系统安全检查能力"
    print_success "✓ 强大的网络诊断工具集"
    print_success "✓ 交互式菜单，易于使用"
    print_success "✓ 支持报告导出功能"
    print_success "✓ 提供自动化的系统管理工具"

    echo ""
    echo -e "${BLUE}▸ 使用建议${NC}"
    print_info "• 建议以root身份运行以获取完整的系统信息"
    print_info "• 首次运行建议选择完整检查了解系统全面情况"
    print_info "• 定期运行此工具进行系统健康检查"
    print_info "• 在进行系统管理操作前建议先备份重要数据"
}

# 交互式主循环
interactive_mode() {
    local first_time=1
    while true; do
        # 首次进入时显示欢迎屏幕（版本信息 + 菜单）
        if [ $first_time -eq 1 ]; then
            clear
            echo -e "${PURPLE}"
            cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║   Linux服务器信息收集与安全检查工具                      ║
║   Server Check Tool v2.0.0                                ║
╚═══════════════════════════════════════════════════════════╝
EOF
            echo -e "${NC}"
            print_info "操作系统: $OS_NAME"
            print_info "检测时间: $(date '+%Y-%m-%d %H:%M:%S')"
            echo ""

            # 显示版本介绍
            show_welcome_screen

            first_time=0

            # 显示菜单
            echo ""
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${WHITE}请选择要执行的功能:${NC}"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            echo -e "  ${GREEN}1${NC}) 系统基本信息检查"
            echo -e "  ${GREEN}2${NC}) 系统异常访问检查"
            echo -e "  ${GREEN}3${NC}) 常用组件运行状态检测"
            echo -e "  ${GREEN}4${NC}) 系统服务部署信息"
            echo -e "  ${GREEN}5${NC}) 系统安全情况检查"
            echo -e "  ${GREEN}6${NC}) 网络诊断工具"
            echo -e "  ${GREEN}7${NC}) 版本和功能介绍"
            echo -e "  ${GREEN}8${NC}) Crontab定时任务管理"
            echo -e "  ${GREEN}9${NC}) NTP/Chrony时间同步"
            echo -e "  ${GREEN}10${NC}) 磁盘分区挂载工具"
            echo -e "  ${GREEN}11${NC}) 磁盘 I/O 性能检查"
            echo -e "  ${GREEN}12${NC}) 完整检查（所有模块）"
            echo -e "  ${GREEN}13${NC}) 导出报告到文件"
            echo -e "  ${RED}0${NC}) 退出"
            echo ""
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        else
            show_menu
        fi

        echo -n -e "${WHITE}请输入选项 [0-13]: ${NC}"
        read -r choice
        echo ""

        case $choice in
            1)
                show_system_info
                ;;
            2)
                show_access_info
                ;;
            3)
                show_component_status
                ;;
            4)
                show_service_info
                ;;
            5)
                show_security_info
                ;;
            6)
                show_network_tools
                ;;
            7)
                show_version_info
                ;;
            8)
                manage_crontab
                ;;
            9)
                manage_time_sync
                ;;
            10)
                manage_disk_mount
                ;;
            11)
                check_disk_io_performance
                ;;
            12)
                show_system_info
                show_access_info
                show_component_status
                show_service_info
                show_security_info
                show_network_tools
                ;;
            13)
                echo -n "请输入报告文件名: "
                read -r report_file
                if [ -n "$report_file" ]; then
                    EXPORT_REPORT=1
                    REPORT_FILE="$report_file"
                    echo "Linux服务器检查报告 - $(date '+%Y-%m-%d %H:%M:%S')" > "$REPORT_FILE"
                    print_success "报告将导出到: $REPORT_FILE"
                    echo ""
                    echo "选择要导出的模块:"
                    echo "1) 系统基本信息"
                    echo "2) 异常访问信息"
                    echo "3) 服务部署信息"
                    echo "4) 安全检查信息"
                    echo "5) 网络诊断信息"
                    echo "6) 所有模块"
                    echo -n "请选择 [1-6]: "
                    read -r export_choice
                    echo ""

                    case $export_choice in
                        1) show_system_info >> "$REPORT_FILE" 2>&1 ;;
                        2) show_access_info >> "$REPORT_FILE" 2>&1 ;;
                        3) show_service_info >> "$REPORT_FILE" 2>&1 ;;
                        4) show_security_info >> "$REPORT_FILE" 2>&1 ;;
                        5) show_network_tools >> "$REPORT_FILE" 2>&1 ;;
                        6)
                            show_system_info >> "$REPORT_FILE" 2>&1
                            show_access_info >> "$REPORT_FILE" 2>&1
                            show_service_info >> "$REPORT_FILE" 2>&1
                            show_security_info >> "$REPORT_FILE" 2>&1
                            show_network_tools >> "$REPORT_FILE" 2>&1
                            ;;
                        *) print_error "无效的选项" ;;
                    esac

                    if [ -f "$REPORT_FILE" ]; then
                        print_success "报告已保存到: $REPORT_FILE"
                    fi
                    EXPORT_REPORT=0
                fi
                ;;
            0)
                echo -e "${GREEN}感谢使用！再见！${NC}"
                exit 0
                ;;
            *)
                print_error "无效的选项，请重新选择"
                ;;
        esac

        # 等待用户按键继续
        if [ "$choice" != "0" ]; then
            echo ""
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -n -e "${WHITE}按Enter键继续...${NC}"
            read -r
        fi
    done
}

################################################################################
# 帮助信息
################################################################################
show_help() {
    cat << EOF
Linux服务器信息收集与安全检查工具 v${SCRIPT_VERSION}

使用方法: $0 [选项]

选项:
    -i, --interactive   交互式菜单模式（推荐）
    -a, --all           显示所有信息
    -s, --system        仅显示系统基本信息
    -c, --access        仅显示异常访问信息
    -v, --service       仅显示服务部署信息
    -S, --security      仅显示安全检查信息
    -n, --network       仅显示网络诊断工具
    -e, --export FILE   导出报告到文件
    -h, --help          显示此帮助信息

功能说明:
    系统基本信息检查    - 查看CPU、内存、磁盘、网络等系统信息
    异常访问信息检查    - 监控SSH登录、暴力破解等安全事件
    服务部署信息        - 显示运行中的服务、监听端口、容器状态
    安全情况检查        - 防火墙、SELinux、权限等安全检查
    网络诊断工具        - Ping、DNS、端口扫描、网速测试等
    版本和功能介绍      - 显示工具版本和所有功能说明
    Crontab任务管理     - 查看、添加、删除定时任务（需交互式菜单）
    NTP/Chrony时间同步  - 管理时间同步服务（需交互式菜单）
    磁盘分区挂载工具    - MBR/GPT分区识别和挂载（需交互式菜单）

示例:
    $0                  # 启动交互式菜单（默认）
    $0 -i               # 启动交互式菜单
    $0 -a               # 直接显示所有信息
    $0 -s               # 仅显示系统信息
    $0 -a -e report.txt # 显示所有信息并导出到report.txt

EOF
}

################################################################################
# 主函数
################################################################################
main() {
    local show_all=0
    local show_system=0
    local show_access=0
    local show_service=0
    local show_security=0
    local show_network=0
    local use_interactive=0

    # 检测操作系统
    detect_os

    # 检查权限
    check_root

    # 检查关键网络工具
    check_critical_tools

    # 如果没有任何参数，启动交互式模式
    if [ $# -eq 0 ]; then
        interactive_mode
        exit 0
    fi

    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--interactive)
                use_interactive=1
                shift
                ;;
            -a|--all)
                show_all=1
                shift
                ;;
            -s|--system)
                show_system=1
                shift
                ;;
            -c|--access)
                show_access=1
                shift
                ;;
            -v|--service)
                show_service=1
                shift
                ;;
            -S|--security)
                show_security=1
                shift
                ;;
            -n|--network)
                show_network=1
                shift
                ;;
            -e|--export)
                EXPORT_REPORT=1
                REPORT_FILE="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 如果指定了交互式模式，进入交互模式
    if [ $use_interactive -eq 1 ]; then
        interactive_mode
        exit 0
    fi

    # 初始化报告文件
    if [ "$EXPORT_REPORT" -eq 1 ]; then
        echo "Linux服务器检查报告 - $(date '+%Y-%m-%d %H:%M:%S')" > "$REPORT_FILE"
        print_success "报告将导出到: $REPORT_FILE"
    fi

    # 显示欢迎信息
    echo -e "${PURPLE}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║   Linux服务器信息收集与安全检查工具                      ║
║   Server Check Tool v2.0.0                                ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    print_info "操作系统: $OS_NAME"
    print_info "检测时间: $(date '+%Y-%m-%d %H:%M:%S')"

    # 执行检查模块
    if [ $show_all -eq 1 ]; then
        show_system_info
        show_access_info
        show_service_info
        show_security_info
        show_network_tools
    else
        if [ $show_system -eq 1 ]; then
            show_system_info
        fi

        if [ $show_access -eq 1 ]; then
            show_access_info
        fi

        if [ $show_service -eq 1 ]; then
            show_service_info
        fi

        if [ $show_security -eq 1 ]; then
            show_security_info
        fi

        if [ $show_network -eq 1 ]; then
            show_network_tools
        fi
    fi

    # 结束信息
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_success "检查完成！"

    if [ "$EXPORT_REPORT" -eq 1 ]; then
        print_success "报告已保存到: $REPORT_FILE"
    fi
}

# 执行主函数
main "$@"
