#!/bin/bash

################################################################################
# Apache Flink 统一安装/修复脚本
# 支持 CentOS/RHEL 7+, Ubuntu 18.04+, Kylin, UOS
#
# ⚠️  重要说明: 本脚本仅支持单机模式安装
#     不支持多机器集群部署，仅用于单节点 Flink 本地环境
#
# 功能:
#   - 安装 Apache Flink 1.18+ (原生安装, 非Docker)
#   - 单机本地模式
#   - 自动检测或安装 Java 环境
#   - 配置 flink-conf.yaml 参数
#   - 配置 systemd 服务
#   - 配置开机自启
#   - 修复已安装的 Flink 配置问题（自动检测）
#   - 智能内存配置（根据系统自动计算）
#
# 使用方法:
#   sudo bash install_flink.sh                    # 全新安装
#   sudo bash install_flink.sh --fix-only         # 仅修复已有安装
#   sudo bash install_flink.sh --auto-config      # 自动配置已有安装
#
# 作者: Shell Collections Team
# 版本: 2.1.0 (单机版)
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'



# 配置变量
FLINK_VERSION="1.18.1"
FLINK_HOME="/opt/flink"
FLINK_USER="flink"
TASKMANAGER_SLOTS="4"
TASKMANAGER_MEMORY="2g"
JAVA_HOME=""

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 打印标题
print_header() {
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║      Apache Flink 自动安装脚本 v1.0.0                    ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        exit 1
    fi
}

# 检测操作系统
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        OS_NAME=$NAME
    else
        log_error "无法检测操作系统类型"
        exit 1
    fi

    log_info "检测到操作系统: $OS_NAME ($OS_VERSION)"

    case $OS in
        centos|rhel|kylin|rocky|almalinux)
            PKG_MANAGER="yum"
            OS_MAJOR_VERSION=$(echo $OS_VERSION | cut -d. -f1)
            ;;
        ubuntu|debian|uos)
            PKG_MANAGER="apt"
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
}

# 自动修复 yum 镜像源 (针对 CentOS 7 官方源停止维护问题)
fix_yum_mirrors() {
    log_info "检查并修复 yum 镜像源..."

    # 检查网络连接
    if ! ping -c 1 8.8.8.8 &>/dev/null; then
        log_warn "网络连接可能不稳定，尝试修复镜像源..."
    fi

    if [[ "$OS" == "centos" ]] && [[ "$OS_MAJOR_VERSION" == "7" ]]; then
        log_warn "检测到 CentOS 7，官方镜像已停止维护，正在切换到国内镜像..."

        # 备份原始配置
        if [[ -f /etc/yum.repos.d/CentOS-Base.repo ]]; then
            cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak.$(date +%s)
            log_info "已备份原始 yum 配置"
        fi

        # 方案1: 尝试阿里云镜像 (最快)
        log_info "尝试使用阿里云镜像源..."
        if curl -s -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo 2>/dev/null; then
            log_success "已切换到阿里云镜像源"
        else
            # 方案2: 本地配置 (备用)
            log_warn "在线下载失败，使用本地镜像配置..."
            cat > /etc/yum.repos.d/CentOS-Base.repo << 'MIRROR_EOF'
[base]
name=CentOS-$releasever - Base
baseurl=http://mirrors.aliyun.com/centos/$releasever/os/$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

[updates]
name=CentOS-$releasever - Updates
baseurl=http://mirrors.aliyun.com/centos/$releasever/updates/$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

[extras]
name=CentOS-$releasever - Extras
baseurl=http://mirrors.aliyun.com/centos/$releasever/extras/$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

[centosplus]
name=CentOS-$releasever - Plus
baseurl=http://mirrors.aliyun.com/centos/$releasever/centosplus/$basearch/
gpgcheck=1
enabled=0
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
MIRROR_EOF
            log_success "已配置本地镜像源"
        fi

        # 清除缓存
        log_info "清除 yum 缓存..."
        yum clean all > /dev/null 2>&1
        yum makecache > /dev/null 2>&1
        log_success "yum 镜像源修复完成"

    elif [[ "$PKG_MANAGER" == "apt" ]]; then
        log_info "Ubuntu/Debian 系统，检查 apt 源..."
        apt-get update -qq > /dev/null 2>&1 || {
            log_warn "apt 更新失败，尝试修复..."
            sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list
            apt-get update -qq
        }
    fi
}

# 更新包管理器
update_package_manager() {
    log_info "更新包管理器..."

    if [[ "$PKG_MANAGER" == "yum" ]]; then
        yum update -y > /dev/null 2>&1 || {
            log_error "yum 更新失败"
            return 1
        }
    else
        apt-get update -qq > /dev/null 2>&1 || {
            log_error "apt 更新失败"
            return 1
        }
    fi

    log_success "包管理器更新完成"
}

# 检查并安装必要的工具
check_and_install_tools() {
    log_info "检查并安装必要的工具..."

    local tools_needed=()
    local tools_name=""

    # 检查 wget
    if ! command -v wget &> /dev/null; then
        tools_needed+=("wget")
        tools_name="wget "
    fi

    # 检查 curl
    if ! command -v curl &> /dev/null; then
        tools_needed+=("curl")
        tools_name="${tools_name}curl "
    fi

    # 如果需要安装工具
    if [[ ${#tools_needed[@]} -gt 0 ]]; then
        log_warn "缺少必要工具: $tools_name，正在安装..."

        if [[ "$PKG_MANAGER" == "yum" ]]; then
            yum install -y "${tools_needed[@]}" > /dev/null 2>&1 || {
                log_error "无法安装工具: $tools_name"
                return 1
            }
        else
            apt-get install -y "${tools_needed[@]}" > /dev/null 2>&1 || {
                log_error "无法安装工具: $tools_name"
                return 1
            }
        fi

        log_success "已安装工具: $tools_name"
    else
        log_success "所有必要工具已就绪"
    fi
}

# 检查已安装的 Flink 状态
check_flink_status() {
    if [[ ! -d "$FLINK_HOME" ]]; then
        return 1
    fi

    local status_running=0
    local status_version=""

    # 检查进程运行状态
    if pgrep -f "TaskManager\|JobManager" >/dev/null 2>&1; then
        status_running=1
    fi

    # 获取版本信息
    if [[ -f "$FLINK_HOME/bin/flink" ]]; then
        status_version=$("$FLINK_HOME/bin/flink" --version 2>&1 | grep -oP 'flink-\K[0-9.]+' | head -1)
    fi

    return 0
}

# 显示已安装的 Flink 信息
show_installed_status() {
    log_warn "Flink 已安装在 $FLINK_HOME"
    echo ""

    if [[ -f "$FLINK_HOME/bin/flink" ]]; then
        local version=$("$FLINK_HOME/bin/flink" --version 2>&1 | grep -oP 'flink-\K[0-9.]+' | head -1)
        log_info "已安装版本: $version"
    fi

    # 检查运行状态
    if pgrep -f "TaskManager\|JobManager" >/dev/null 2>&1; then
        log_success "Flink 状态: 正在运行"
        echo ""
        log_info "运行中的 Flink 进程:"
        ps aux | grep -E "TaskManager|JobManager" | grep -v grep | while read line; do
            log_info "  $line"
        done
    else
        log_warn "Flink 状态: 已停止"
    fi

    # 检查配置
    if [[ -f "$FLINK_HOME/conf/flink-conf.yaml" ]]; then
        log_info "配置文件: $FLINK_HOME/conf/flink-conf.yaml"
    fi

    # 检查systemd服务
    if systemctl is-active --quiet flink 2>/dev/null; then
        log_success "Systemd服务: 已启用并运行中"
    elif systemctl is-enabled --quiet flink 2>/dev/null; then
        log_info "Systemd服务: 已启用但未运行"
    else
        log_warn "Systemd服务: 未配置"
    fi

    echo ""
}

# 处理已安装的 Flink
handle_installed_flink() {
    show_installed_status

    echo -e "${BLUE}请选择操作:${NC}"
    echo "  1) 启动/重启 Flink"
    echo "  2) 停止 Flink"
    echo "  3) 查看日志"
    echo "  4) 重新安装（覆盖现有安装）"
    echo "  5) 返回（取消此次安装）"
    read -p "请选择 [1-5, 默认 5]: " -r action
    action=${action:-5}

    case $action in
        1)
            log_info "启动 Flink..."
            systemctl start flink || {
                log_error "启动失败，请检查配置"
                exit 1
            }
            sleep 3
            if systemctl is-active --quiet flink; then
                log_success "Flink 已启动"
                if pgrep -f "JobManager" >/dev/null 2>&1; then
                    log_info "JobManager 运行中，访问地址: http://$(hostname -I | awk '{print $1}'):8081/"
                fi
            else
                log_error "Flink 启动失败，请查看日志"
                systemctl status flink
            fi
            exit 0
            ;;
        2)
            log_info "停止 Flink..."
            systemctl stop flink || {
                log_warn "停止失败或服务未运行"
            }
            log_success "Flink 已停止"
            exit 0
            ;;
        3)
            log_info "显示 Flink 日志 (最后 50 行):"
            tail -50 "$FLINK_HOME/logs"/*.log 2>/dev/null || {
                log_warn "未找到日志文件"
            }
            exit 0
            ;;
        4)
            log_warn "将覆盖现有的 Flink 安装，继续安装..."
            # 继续进行安装流程
            ;;
        5|*)
            log_info "安装已取消"
            exit 0
            ;;
    esac
}

# 检查是否已安装
check_installed() {
    if [[ -d "$FLINK_HOME" ]]; then
        if check_flink_status; then
            handle_installed_flink
        fi
    fi
}

# wget 下载函数，带进度条显示
download_with_wget() {
    local url=$1
    local output=$2
    local name=$3
    local temp_output="${output}.tmp"

    # 策略 1: 尝试 --show-progress 选项 (wget 1.16+)
    if wget --show-progress --progress=bar --timeout=300 -O "$temp_output" "$url" 2>/dev/null; then
        mv "$temp_output" "$output"
        return 0
    fi

    # 策略 2: 尝试 --progress=bar:force 选项
    if wget --progress=bar:force --timeout=300 -O "$temp_output" "$url" 2>/dev/null; then
        mv "$temp_output" "$output"
        return 0
    fi

    # 策略 3: 尝试 --progress=dot:mega 选项
    if wget --progress=dot:mega --timeout=300 -O "$temp_output" "$url" 2>/dev/null; then
        mv "$temp_output" "$output"
        return 0
    fi

    # 策略 4: 降级方案 - 使用 -q (静默模式)
    if wget -q --timeout=300 -O "$temp_output" "$url" 2>/dev/null; then
        mv "$temp_output" "$output"
        return 0
    fi

    # 所有策略都失败
    rm -f "$temp_output"
    return 1
}

# 检查 Java 环境
check_java() {
    log_info "检查 Java 环境..."

    if command -v java &> /dev/null; then
        JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
        JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
        log_success "找到 Java: $JAVA_VERSION (JAVA_HOME=$JAVA_HOME)"
        return 0
    else
        log_warn "未找到 Java, 需要安装"
        install_java
    fi
}

# 安装 Java
install_java() {
    log_info "安装 Java 环境..."

    if [[ "$PKG_MANAGER" == "yum" ]]; then
        yum install -y java-11-openjdk java-11-openjdk-devel
    else
        apt-get update -qq
        apt-get install -y openjdk-11-jdk
    fi

    JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
    log_success "Java 安装成功: $JAVA_HOME"
}

# 交互式配置
interactive_config() {
    echo ""
    log_info "Flink 安装配置 (本地模式)"
    echo ""

    # 配置 TaskManager 参数
    echo ""
    read -p "请输入 TaskManager Slot 数量 [默认 4]: " user_slots
    TASKMANAGER_SLOTS="${user_slots:-4}"
    log_info "TaskManager Slot 数: $TASKMANAGER_SLOTS"

    # 配置内存
    echo ""
    TOTAL_MEMORY=$(free -m | awk 'NR==2 {print int($2 * 0.5)}')  # 系统内存的50%
    read -p "请输入 TaskManager 内存 (GB) [默认 2]: " user_memory
    TASKMANAGER_MEMORY="${user_memory:-2}g"
    log_info "TaskManager 内存: $TASKMANAGER_MEMORY"
}

# 下载并安装 Flink
install_flink_binary() {
    log_info "下载 Flink ${FLINK_VERSION}..."

    FLINK_DOWNLOAD="https://archive.apache.org/dist/flink/flink-${FLINK_VERSION}/flink-${FLINK_VERSION}-bin-scala_2.12.tgz"
    FLINK_TEMP="/tmp/flink-${FLINK_VERSION}-bin-scala_2.12.tgz"

    # 尝试使用 curl 下载 (优先，因为进度条更简洁)
    if command -v curl &> /dev/null; then
        echo -e "${BLUE}[下载进度]${NC} 正在下载 Flink..."
        if curl -L --progress-bar --max-time 300 -o "$FLINK_TEMP" "$FLINK_DOWNLOAD"; then
            log_success "Flink 下载成功 (curl)"
        else
            # curl 失败，尝试 wget
            log_warn "curl 下载失败，尝试使用 wget..."
            download_with_wget "$FLINK_DOWNLOAD" "$FLINK_TEMP" "Flink" || exit 1
            log_success "Flink 下载成功 (wget)"
        fi
    # 如果没有 curl，使用 wget
    elif command -v wget &> /dev/null; then
        echo -e "${BLUE}[下载进度]${NC} 正在下载 Flink..."
        download_with_wget "$FLINK_DOWNLOAD" "$FLINK_TEMP" "Flink" || exit 1
        log_success "Flink 下载成功 (wget)"
    else
        log_error "没有可用的下载工具 (curl/wget 都不存在)"
        exit 1
    fi

    # 创建 Flink 用户
    log_info "创建 Flink 用户..."
    if ! id "$FLINK_USER" &>/dev/null; then
        useradd -r -s /bin/bash "$FLINK_USER"
        log_success "用户 $FLINK_USER 创建成功"
    else
        log_warn "用户 $FLINK_USER 已存在"
    fi

    # 创建 Flink 目录
    mkdir -p "$FLINK_HOME"
    tar -xzf "$FLINK_TEMP" -C "$FLINK_HOME" --strip-components=1

    # 设置权限
    chown -R "$FLINK_USER:$FLINK_USER" "$FLINK_HOME"
    chmod -R 755 "$FLINK_HOME"

    # 创建日志目录
    mkdir -p "$FLINK_HOME/logs"
    chown -R "$FLINK_USER:$FLINK_USER" "$FLINK_HOME/logs"

    # 清理临时文件
    rm -f "$FLINK_TEMP"

    log_success "Flink 安装完成: $FLINK_HOME"
}

# 配置 Flink
configure_flink() {
    log_info "配置 Flink..."

    local FLINK_CONF="$FLINK_HOME/conf/flink-conf.yaml"

    # 备份原配置
    if [[ -f "$FLINK_CONF" ]]; then
        cp "$FLINK_CONF" "${FLINK_CONF}.bak"
    fi

    # 创建新配置
    cat > "$FLINK_CONF" << EOF
# Flink 配置文件

# 主机名和端口
jobmanager.rpc.address: localhost
jobmanager.rpc.port: 6123
jobmanager.bind-host: 0.0.0.0

# JobManager 内存配置（Flink 1.18+ 需要显式配置）
jobmanager.memory.process.size: 1024m

# TaskManager 配置
taskmanager.numberOfTaskSlots: $TASKMANAGER_SLOTS
taskmanager.memory.process.size: $TASKMANAGER_MEMORY

# Web UI 配置
rest.port: 8081
rest.bind-address: 0.0.0.0

# 并行度配置
parallelism.default: $(( TASKMANAGER_SLOTS * 4 ))

# 检查点和状态后端
state.backend: filesystem
state.checkpoints.dir: file://$FLINK_HOME/checkpoints
state.savepoints.dir: file://$FLINK_HOME/savepoints

# 日志配置
logger.level: INFO
logger.org.apache.flink: INFO
logger.org.apache.hadoop: INFO
logger.akka: WARN

# IO 配置
akka.framesize: 104857600

# RPC 配置
akka.tcp.timeout: 60s
EOF

    chown "$FLINK_USER:$FLINK_USER" "$FLINK_CONF"
    chmod 644 "$FLINK_CONF"

    log_success "Flink 配置完成"
}

# 配置 systemd 服务
configure_systemd_service() {
    log_info "配置 systemd 服务..."

    local SERVICE_FILE="/etc/systemd/system/flink.service"
    local EXEC_START="$FLINK_HOME/bin/start-cluster.sh"

    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Apache Flink
After=network.target

[Service]
Type=forking
User=$FLINK_USER
Group=$FLINK_USER
Environment="JAVA_HOME=$JAVA_HOME"
Environment="FLINK_HOME=$FLINK_HOME"
ExecStart=$EXEC_START
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$SERVICE_FILE"
    systemctl daemon-reload
    systemctl enable flink

    log_success "systemd 服务配置完成"
}

# 启动 Flink 服务
start_flink_service() {
    log_info "启动 Flink 服务..."

    systemctl start flink

    # 等待服务启动
    sleep 3

    if systemctl is-active --quiet flink; then
        log_success "Flink 服务启动成功"
    else
        log_error "Flink 服务启动失败"
        systemctl status flink
        return 1
    fi
}

# 验证安装
verify_installation() {
    log_info "验证 Flink 安装..."

    sleep 2

    if [[ -d "$FLINK_HOME" ]] && [[ -f "$FLINK_HOME/bin/flink" ]]; then
        local FLINK_VERSION=$("$FLINK_HOME/bin/flink" --version 2>&1 | grep -oP 'flink-\K[0-9.]+' | head -1)
        log_success "Flink 版本: $FLINK_VERSION"

        # 检查进程
        if pgrep -f "TaskManager\|JobManager" > /dev/null; then
            log_success "Flink 进程正在运行"
        else
            log_warn "Flink 进程未运行，请检查日志"
        fi

        return 0
    else
        log_error "Flink 验证失败"
        return 1
    fi
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."

    if command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL
        firewall-cmd --permanent --add-port=6123/tcp  # RPC 端口
        firewall-cmd --permanent --add-port=8081/tcp  # Web UI
        firewall-cmd --reload
        log_success "防火墙规则已添加 (yum系统)"
    elif command -v ufw &> /dev/null; then
        # Ubuntu
        ufw allow 6123/tcp
        ufw allow 8081/tcp
        log_success "防火墙规则已添加 (apt系统)"
    fi
}

# 生成安装报告
generate_report() {
    local report_file="/tmp/install_flink_report_$(date +%Y%m%d_%H%M%S).txt"

    cat > "$report_file" << EOF
╔════════════════════════════════════════════════════════════════╗
║         Apache Flink 安装报告                                 ║
╚════════════════════════════════════════════════════════════════╝

【安装信息】
安装时间: $(date '+%Y-%m-%d %H:%M:%S')
Flink 版本: $FLINK_VERSION
安装路径: $FLINK_HOME
Flink 用户: $FLINK_USER
Java 版本: $(java -version 2>&1 | grep -oP 'version "\K[^"]+')

【部署模式】
模式: 本地单机模式

【性能配置】
TaskManager Slot 数: $TASKMANAGER_SLOTS
TaskManager 内存: $TASKMANAGER_MEMORY
并行度: $(( TASKMANAGER_SLOTS * 4 ))

【常用命令】
1. 启动 Flink:
   systemctl start flink

2. 停止 Flink:
   systemctl stop flink

3. 查看状态:
   systemctl status flink

4. 查看日志:
   tail -f $FLINK_HOME/logs/*

5. 提交任务:
   $FLINK_HOME/bin/flink run -p 4 \\
     examples/streaming/WordCount.jar --input /path/to/file

6. Web UI:
   http://$(hostname -I | awk '{print $1}'):8081/

【配置文件】
- 主配置: $FLINK_HOME/conf/flink-conf.yaml
- 日志位置: $FLINK_HOME/logs/

【后续步骤】
1. Flink 本地模式已准备就绪
2. 可直接使用 flink run 提交应用

【性能优化建议】
1. 根据硬件调整 TaskManager 内存和 Slot 数
2. 配置合适的 state.backend (filesystem/rocksdb)
3. 定期监控任务运行状态
4. 配置合理的 Checkpoint 间隔

【安全建议】
1. 限制网络访问 Web UI (8081 端口)
2. 定期更新 Flink 版本
3. 配置身份验证 (可选)
4. 监控磁盘空间 (checkpoints/savepoints)

【技术支持】
官方文档: https://nightlies.apache.org/flink/flink-docs-stable/
EOF

    echo ""
    cat "$report_file"
    log_success "安装报告已生成: $report_file"
}

# 检测系统内存并建议配置
detect_system_memory() {
    local total_mem=$(free -m | awk 'NR==2 {print $2}')
    local recommended_jm=$((total_mem / 4))
    local recommended_tm=$((total_mem / 2))

    log_info "系统总内存: ${total_mem}MB"
    log_info "建议 JobManager 内存: ${recommended_jm}m"
    log_info "建议 TaskManager 内存: ${recommended_tm}m"

    if [[ $recommended_jm -lt 512 ]]; then
        recommended_jm=512
        log_warn "系统内存较小，JobManager 内存设置为最小值: 512m"
    fi

    if [[ $recommended_tm -lt 1024 ]]; then
        recommended_tm=1024
        log_warn "系统内存较小，TaskManager 内存设置为最小值: 1024m"
    fi

    FLINK_JM_MEMORY="${recommended_jm}m"
    FLINK_TM_MEMORY="${recommended_tm}m"
}

# 修复已安装的 Flink 配置
repair_flink_config() {
    local FLINK_CONF="$FLINK_HOME/conf/flink-conf.yaml"

    log_info "修复 Flink 配置文件..."

    if [[ ! -f "$FLINK_CONF" ]]; then
        log_warn "配置文件不存在，将创建新配置"
    else
        # 备份原配置
        cp "$FLINK_CONF" "${FLINK_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
        log_success "已备份原配置文件"
    fi

    # 检查系统内存并自动配置
    detect_system_memory

    # 创建修复后的配置
    cat > "$FLINK_CONF" << EOF
# Flink 配置文件 (统一脚本修复版本)
# 修复日期: $(date '+%Y-%m-%d %H:%M:%S')

# 主机名和端口
jobmanager.rpc.address: localhost
jobmanager.rpc.port: 6123
jobmanager.bind-host: 0.0.0.0

# ========== 关键配置: 内存设置 (Flink 1.18+ 必需) ==========
jobmanager.memory.process.size: ${FLINK_JM_MEMORY}
taskmanager.memory.process.size: ${FLINK_TM_MEMORY}

# TaskManager 配置
taskmanager.numberOfTaskSlots: 4

# Web UI 配置
rest.port: 8081
rest.bind-address: 0.0.0.0

# 并行度配置
parallelism.default: 4

# 检查点和状态后端
state.backend: filesystem
state.checkpoints.dir: file://${FLINK_HOME}/checkpoints
state.savepoints.dir: file://${FLINK_HOME}/savepoints

# 日志配置
logger.level: INFO
logger.org.apache.flink: INFO
logger.org.apache.hadoop: INFO
logger.akka: WARN

# IO 配置
akka.framesize: 104857600

# RPC 配置
akka.tcp.timeout: 60s
EOF

    chown flink:flink "$FLINK_CONF"
    chmod 644 "$FLINK_CONF"

    log_success "Flink 配置已修复"
}

# 启动并验证 Flink 服务
verify_and_start_flink() {
    log_info "启动 Flink 服务..."

    # 停止现有服务
    systemctl stop flink 2>/dev/null || true
    sleep 2

    # 启动服务
    if systemctl start flink 2>&1; then
        sleep 3

        if systemctl is-active --quiet flink; then
            log_success "Flink 服务已启动"

            # 检查进程
            if pgrep -f "JobManager" > /dev/null 2>&1; then
                log_success "✓ JobManager 进程运行中"
            else
                log_warn "⚠ JobManager 进程未运行"
            fi

            if pgrep -f "TaskManager" > /dev/null 2>&1; then
                log_success "✓ TaskManager 进程运行中"
            else
                log_warn "⚠ TaskManager 进程未运行"
            fi

            return 0
        else
            log_error "Flink 启动失败，显示状态:"
            systemctl status flink --no-pager || true
            return 1
        fi
    else
        log_error "启动命令执行失败"
        return 1
    fi
}

# 仅修复模式（针对已有安装）
repair_only_mode() {
    log_info "进入修复模式..."

    if [[ ! -d "$FLINK_HOME" ]]; then
        log_error "未找到 Flink 安装目录: $FLINK_HOME"
        log_info "请先安装 Flink，或直接运行: sudo bash $0"
        exit 1
    fi

    check_root
    repair_flink_config

    if verify_and_start_flink; then
        echo ""
        log_success "✅ Flink 修复完成！"
        local ip=$(hostname -I | awk '{print $1}')
        log_info "访问地址: http://${ip}:8081/"
        exit 0
    else
        log_error "❌ Flink 启动失败，请检查日志"
        tail -20 "$FLINK_HOME/logs/flink-*.log" 2>/dev/null || true
        exit 1
    fi
}

# 自动配置模式（结合 check_installed 逻辑）
auto_config_mode() {
    log_info "进入自动配置模式..."

    if [[ ! -d "$FLINK_HOME" ]]; then
        log_error "未找到 Flink 安装目录: $FLINK_HOME"
        exit 1
    fi

    check_root
    detect_os

    log_info "Flink 已安装，正在自动配置..."
    repair_flink_config

    if verify_and_start_flink; then
        log_success "✅ Flink 自动配置完成！"
        exit 0
    else
        log_error "❌ Flink 配置失败"
        exit 1
    fi
}

# 主函数
main() {
    # 处理命令行参数
    case "${1:-}" in
        --fix-only)
            repair_only_mode
            ;;
        --auto-config)
            auto_config_mode
            ;;
        *)
            # 常规安装流程
            print_header
            check_root
            detect_os
            fix_yum_mirrors           # 自动修复镜像源
            update_package_manager    # 更新包管理器
            check_and_install_tools   # 检查并安装必要工具

            # 检查前置依赖
            if command -v check_and_install_dependencies &>/dev/null; then
                log_info "检查前置依赖..."
                check_and_install_dependencies "Flink" "${FLINK_DEPENDENCIES[@]}"
                echo ""
            fi

            check_installed
            check_java
            interactive_config
            install_flink_binary
            configure_flink
            configure_systemd_service
            configure_firewall
            start_flink_service

            if verify_installation; then
                generate_report
                log_success "Flink 安装完成！"
                exit 0
            else
                log_error "Flink 安装验证失败，请检查日志"
                exit 1
            fi
            ;;
    esac
}

main "$@"
