#!/bin/bash

################################################################################
# Apache Spark 统一安装/修复脚本
# 支持 CentOS/RHEL 7+, Ubuntu 18.04+, Kylin, UOS
#
# ⚠️  重要说明: 本脚本仅支持单机模式安装
#     不支持多机器集群部署，仅用于单节点 Spark Standalone 环境
#
# 功能:
#   - 安装 Apache Spark 3.x (原生安装, 非Docker)
#   - 单机 Standalone 模式
#   - 自动检测或安装 Java 环境
#   - 配置 Spark 参数 (内存、核心数等)
#   - 配置 systemd 服务
#   - 配置开机自启
#   - 修复已安装的 Spark 配置问题（自动检测）
#   - 智能内存配置（根据系统自动计算）
#
# 使用方法:
#   sudo bash install_spark.sh                    # 全新安装
#   sudo bash install_spark.sh --fix-only         # 仅修复已有安装
#   sudo bash install_spark.sh --auto-config      # 自动配置已有安装
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
SPARK_VERSION="3.4.1"
SPARK_HOME="/opt/spark"
SPARK_USER="spark"
SPARK_MEMORY=""
SPARK_CORES=""
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
    echo "║      Apache Spark 自动安装脚本 v1.0.0                    ║"
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

# 检查已安装的 Spark 状态
check_spark_status() {
    if [[ ! -d "$SPARK_HOME" ]]; then
        return 1
    fi

    local status_running=0
    local status_version=""

    # 检查进程运行状态
    if pgrep -f "org.apache.spark" >/dev/null 2>&1; then
        status_running=1
    fi

    # 获取版本信息
    if [[ -f "$SPARK_HOME/bin/spark-submit" ]]; then
        status_version=$("$SPARK_HOME/bin/spark-submit" --version 2>&1 | grep -oP 'Spark \K[0-9.]+' | head -1)
    fi

    return 0
}

# 显示已安装的 Spark 信息
show_installed_status() {
    log_warn "Spark 已安装在 $SPARK_HOME"
    echo ""

    if [[ -f "$SPARK_HOME/bin/spark-submit" ]]; then
        local version=$("$SPARK_HOME/bin/spark-submit" --version 2>&1 | grep -oP 'Spark \K[0-9.]+' | head -1)
        log_info "已安装版本: $version"
    fi

    # 检查运行状态
    if pgrep -f "org.apache.spark" >/dev/null 2>&1; then
        log_success "Spark 状态: 正在运行"
        echo ""
        log_info "运行中的 Spark 进程:"
        ps aux | grep -E "org.apache.spark" | grep -v grep | while read line; do
            log_info "  $line"
        done
    else
        log_warn "Spark 状态: 已停止"
    fi

    # 检查配置
    if [[ -f "$SPARK_HOME/conf/spark-env.sh" ]]; then
        log_info "配置文件: $SPARK_HOME/conf/spark-env.sh"
    fi

    # 检查systemd服务
    if systemctl is-active --quiet spark 2>/dev/null; then
        log_success "Systemd服务: 已启用并运行中"
    elif systemctl is-enabled --quiet spark 2>/dev/null; then
        log_info "Systemd服务: 已启用但未运行"
    else
        log_warn "Systemd服务: 未配置"
    fi

    echo ""
}

# 处理已安装的 Spark
handle_installed_spark() {
    show_installed_status

    echo -e "${BLUE}请选择操作:${NC}"
    echo "  1) 启动/重启 Spark"
    echo "  2) 停止 Spark"
    echo "  3) 查看日志"
    echo "  4) 重新安装（覆盖现有安装）"
    echo "  5) 返回（取消此次安装）"
    read -p "请选择 [1-5, 默认 5]: " -r action
    action=${action:-5}

    case $action in
        1)
            log_info "启动 Spark..."
            systemctl start spark || {
                log_error "启动失败，请检查配置"
                exit 1
            }
            sleep 3
            if systemctl is-active --quiet spark; then
                log_success "Spark 已启动"
                if pgrep -f "Master" >/dev/null 2>&1; then
                    log_info "Master 运行中，访问地址: http://$(hostname -I | awk '{print $1}'):8080/"
                fi
            else
                log_error "Spark 启动失败，请查看日志"
                systemctl status spark
            fi
            exit 0
            ;;
        2)
            log_info "停止 Spark..."
            systemctl stop spark || {
                log_warn "停止失败或服务未运行"
            }
            log_success "Spark 已停止"
            exit 0
            ;;
        3)
            log_info "显示 Spark 日志 (最后 50 行):"
            tail -50 "$SPARK_HOME/logs"/*.log 2>/dev/null || {
                log_warn "未找到日志文件"
            }
            exit 0
            ;;
        4)
            log_warn "将覆盖现有的 Spark 安装，继续安装..."
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
    if [[ -d "$SPARK_HOME" ]]; then
        if check_spark_status; then
            handle_installed_spark
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

# 验证密码复杂度
validate_password() {
    local password="$1"

    # 长度检查 (至少12位)
    if [[ ${#password} -lt 12 ]]; then
        log_error "密码长度至少12位"
        return 1
    fi

    # 复杂度检查: 必须包含大写、小写、数字
    if ! echo "$password" | grep -q '[A-Z]'; then
        log_error "密码必须包含大写字母"
        return 1
    fi

    if ! echo "$password" | grep -q '[a-z]'; then
        log_error "密码必须包含小写字母"
        return 1
    fi

    if ! echo "$password" | grep -q '[0-9]'; then
        log_error "密码必须包含数字"
        return 1
    fi

    return 0
}

# 交互式配置
interactive_config() {
    echo ""
    log_info "Spark 安装配置 (单机模式)"
    echo ""

    # 配置内存
    echo ""
    TOTAL_MEMORY=$(free -m | awk 'NR==2 {print int($2 * 0.6)}')  # 系统内存的60%
    read -p "请输入 Spark 工作内存 (MB) [默认 ${TOTAL_MEMORY}M]: " user_memory
    SPARK_MEMORY="${user_memory:-$TOTAL_MEMORY}m"
    log_info "Spark 工作内存: $SPARK_MEMORY"

    # 配置核心数
    echo ""
    CPU_CORES=$(nproc)
    read -p "请输入 Spark 执行核心数 [默认 $CPU_CORES]: " user_cores
    SPARK_CORES="${user_cores:-$CPU_CORES}"
    log_info "Spark 执行核心数: $SPARK_CORES"
}

# 下载并安装 Spark
install_spark_binary() {
    log_info "下载 Spark ${SPARK_VERSION}..."

    SPARK_DOWNLOAD="https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz"
    SPARK_TEMP="/tmp/spark-${SPARK_VERSION}-bin-hadoop3.tgz"

    # 尝试使用 curl 下载 (优先，因为进度条更简洁)
    if command -v curl &> /dev/null; then
        echo -e "${BLUE}[下载进度]${NC} 正在下载 Spark..."
        if curl -L --progress-bar --max-time 300 -o "$SPARK_TEMP" "$SPARK_DOWNLOAD"; then
            log_success "Spark 下载成功 (curl)"
        else
            # curl 失败，尝试 wget
            log_warn "curl 下载失败，尝试使用 wget..."
            download_with_wget "$SPARK_DOWNLOAD" "$SPARK_TEMP" "Spark" || exit 1
            log_success "Spark 下载成功 (wget)"
        fi
    # 如果没有 curl，使用 wget
    elif command -v wget &> /dev/null; then
        echo -e "${BLUE}[下载进度]${NC} 正在下载 Spark..."
        download_with_wget "$SPARK_DOWNLOAD" "$SPARK_TEMP" "Spark" || exit 1
        log_success "Spark 下载成功 (wget)"
    else
        log_error "没有可用的下载工具 (curl/wget 都不存在)"
        exit 1
    fi

    # 创建 Spark 用户
    log_info "创建 Spark 用户..."
    if ! id "$SPARK_USER" &>/dev/null; then
        useradd -r -s /bin/bash "$SPARK_USER"
        log_success "用户 $SPARK_USER 创建成功"
    else
        log_warn "用户 $SPARK_USER 已存在"
    fi

    # 创建 Spark 目录
    mkdir -p "$SPARK_HOME"
    tar -xzf "$SPARK_TEMP" -C "$SPARK_HOME" --strip-components=1

    # 设置权限
    chown -R "$SPARK_USER:$SPARK_USER" "$SPARK_HOME"
    chmod -R 755 "$SPARK_HOME"

    # 清理临时文件
    rm -f "$SPARK_TEMP"

    log_success "Spark 安装完成: $SPARK_HOME"
}

# 配置 Spark
configure_spark() {
    log_info "配置 Spark..."

    local SPARK_ENV="$SPARK_HOME/conf/spark-env.sh"

    # 创建 spark-env.sh
    cat > "$SPARK_ENV" << EOF
#!/usr/bin/env bash

# Spark 环境配置
export JAVA_HOME=$JAVA_HOME
export SPARK_HOME=$SPARK_HOME
export PATH=\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin

# Spark 内存配置
export SPARK_EXECUTOR_MEMORY=$SPARK_MEMORY
export SPARK_DRIVER_MEMORY=$SPARK_MEMORY

# Spark 核心数配置
export SPARK_EXECUTOR_CORES=$SPARK_CORES

# 日志级别
export SPARK_LOG_DIR=\$SPARK_HOME/logs
export SPARK_PID_DIR=\$SPARK_HOME/pids

# 主机配置
HOSTNAME=\$(hostname)
export SPARK_LOCAL_HOSTNAME=\$HOSTNAME
EOF

    chmod 644 "$SPARK_ENV"
    chown "$SPARK_USER:$SPARK_USER" "$SPARK_ENV"

    log_success "Spark 配置完成"
}

# 配置 systemd 服务
configure_systemd_service() {
    log_info "配置 systemd 服务..."

    local SERVICE_FILE="/etc/systemd/system/spark.service"
    local SPARK_START="$SPARK_HOME/sbin/start-master.sh"

    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Apache Spark
After=network.target

[Service]
Type=forking
User=$SPARK_USER
Group=$SPARK_USER
Environment="JAVA_HOME=$JAVA_HOME"
Environment="SPARK_HOME=$SPARK_HOME"
ExecStart=$SPARK_START
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$SERVICE_FILE"
    systemctl daemon-reload
    systemctl enable spark

    log_success "systemd 服务配置完成"
}

# 启动 Spark 服务
start_spark_service() {
    log_info "启动 Spark 服务..."

    systemctl start spark

    # 等待服务启动
    sleep 3

    if systemctl is-active --quiet spark; then
        log_success "Spark 服务启动成功"
    else
        log_error "Spark 服务启动失败"
        systemctl status spark
        return 1
    fi
}

# 验证安装
verify_installation() {
    log_info "验证 Spark 安装..."

    sleep 2

    if [[ -d "$SPARK_HOME" ]] && [[ -f "$SPARK_HOME/bin/spark-submit" ]]; then
        local SPARK_VERSION=$("$SPARK_HOME/bin/spark-submit" --version 2>&1 | grep -oP 'Spark \K[0-9.]+' | head -1)
        log_success "Spark 版本: $SPARK_VERSION"

        # 检查进程
        if pgrep -f "org.apache.spark" > /dev/null; then
            log_success "Spark 进程正在运行"
        else
            log_warn "Spark 进程未运行，请检查日志"
        fi

        return 0
    else
        log_error "Spark 验证失败"
        return 1
    fi
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."

    if command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL
        firewall-cmd --permanent --add-port=7077/tcp  # Master 通信
        firewall-cmd --permanent --add-port=8080/tcp  # Master Web UI
        firewall-cmd --reload
        log_success "防火墙规则已添加 (yum系统)"
    elif command -v ufw &> /dev/null; then
        # Ubuntu
        ufw allow 7077/tcp
        ufw allow 8080/tcp
        log_success "防火墙规则已添加 (apt系统)"
    fi
}

# 生成安装报告
generate_report() {
    local report_file="/tmp/install_spark_report_$(date +%Y%m%d_%H%M%S).txt"

    cat > "$report_file" << EOF
╔════════════════════════════════════════════════════════════════╗
║         Apache Spark 安装报告                                 ║
╚════════════════════════════════════════════════════════════════╝

【安装信息】
安装时间: $(date '+%Y-%m-%d %H:%M:%S')
Spark 版本: $SPARK_VERSION
安装路径: $SPARK_HOME
Spark 用户: $SPARK_USER
Java 版本: $(java -version 2>&1 | grep -oP 'version "\K[^"]+')

【部署模式】
模式: 单机 Standalone 模式

【性能配置】
工作内存: $SPARK_MEMORY
执行核心数: $SPARK_CORES
系统核心数: $(nproc)
系统总内存: $(free -h | awk 'NR==2 {print $2}')

【常用命令】
1. 启动 Spark:
   systemctl start spark

2. 停止 Spark:
   systemctl stop spark

3. 查看状态:
   systemctl status spark

4. 查看日志:
   tail -f $SPARK_HOME/logs/*

5. 提交任务 (单机模式):
   $SPARK_HOME/bin/spark-submit \\
     --class org.apache.spark.examples.SparkPi \\
     --master local[*] \\
     $SPARK_HOME/examples/jars/spark-examples_2.12-$SPARK_VERSION.jar 10

6. Web UI:
   http://$(hostname -I | awk '{print $1}'):8080/

【配置文件】
- 环境变量: $SPARK_HOME/conf/spark-env.sh
- 日志位置: $SPARK_HOME/logs/

【后续步骤】
1. Spark 单机模式已准备就绪
2. 可直接使用 spark-submit 提交应用

【安全建议】
1. 定期更新 Spark 版本
2. 限制网络访问 Web UI (8080 端口)
3. 监控 Spark 应用的内存使用

【技术支持】
官方文档: https://spark.apache.org/docs/latest/
EOF

    echo ""
    cat "$report_file"
    log_success "安装报告已生成: $report_file"
}

# 主函数
# 修复 Spark 配置
repair_spark_config() {
    local SPARK_CONF_FILE="/opt/spark/conf/spark-defaults.conf"
    local SPARK_HOME="/opt/spark"

    log_info "修复 Spark 配置文件..."

    if [[ -f "$SPARK_CONF_FILE" ]]; then
        cp "$SPARK_CONF_FILE" "${SPARK_CONF_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        log_success "已备份配置文件"
    fi

    # 检测系统内存
    local total_mem=$(free -m | awk 'NR==2 {print $2}')
    local driver_mem=$((total_mem / 4))
    local executor_mem=$((total_mem / 2))

    [[ $driver_mem -lt 512 ]] && driver_mem=512
    [[ $executor_mem -lt 1024 ]] && executor_mem=1024

    cat > "$SPARK_CONF_FILE" << EOF
# Spark 配置文件 (统一脚本修复版本)
spark.driver.memory               ${driver_mem}m
spark.executor.memory             ${executor_mem}m
spark.executor.cores              2
spark.default.parallelism         4
spark.driver.maxResultSize        256m
spark.sql.shuffle.partitions      4
spark.shuffle.compress            true
spark.shuffle.spill.compress      true
spark.eventLog.enabled            false
spark.eventLog.dir                ${SPARK_HOME}/event-logs
spark.master                      spark://localhost:7077
spark.rpc.message.maxSize         128
spark.rpc.askTimeout              120s
spark.sql.broadcastTimeout        300
EOF

    chown spark:spark "$SPARK_CONF_FILE"
    chmod 644 "$SPARK_CONF_FILE"
    log_success "Spark 配置已修复"
}

# 启动并验证 Spark 服务
verify_and_start_spark() {
    log_info "启动 Spark 服务..."

    systemctl stop spark 2>/dev/null || true
    sleep 2

    if systemctl start spark 2>&1; then
        sleep 3

        if systemctl is-active --quiet spark; then
            log_success "✓ Spark 服务已启动"
            return 0
        else
            log_error "✗ Spark 启动失败"
            systemctl status spark --no-pager || true
            return 1
        fi
    else
        log_error "启动命令执行失败"
        return 1
    fi
}

# 仅修复模式
repair_only_mode() {
    log_info "进入 Spark 修复模式..."

    if [[ ! -d "/opt/spark" ]]; then
        log_error "未找到 Spark 安装目录: /opt/spark"
        exit 1
    fi

    check_root
    repair_spark_config

    if verify_and_start_spark; then
        log_success "✅ Spark 修复完成！"
        exit 0
    else
        log_error "❌ Spark 启动失败"
        exit 1
    fi
}

# 自动配置模式
auto_config_mode() {
    log_info "进入 Spark 自动配置模式..."

    if [[ ! -d "/opt/spark" ]]; then
        log_error "未找到 Spark 安装目录: /opt/spark"
        exit 1
    fi

    check_root
    detect_os

    repair_spark_config

    if verify_and_start_spark; then
        log_success "✅ Spark 自动配置完成！"
        exit 0
    else
        log_error "❌ Spark 配置失败"
        exit 1
    fi
}

# 主函数
main() {
    case "${1:-}" in
        --fix-only)
            repair_only_mode
            ;;
        --auto-config)
            auto_config_mode
            ;;
        *)
            print_header
            check_root
            detect_os

            # 检查前置依赖
            if command -v check_and_install_dependencies &>/dev/null; then
                log_info "检查前置依赖..."
                check_and_install_dependencies "Spark" "${SPARK_DEPENDENCIES[@]}"
                echo ""
            fi
            check_installed
            check_java
            interactive_config
            install_spark_binary
            configure_spark
            configure_systemd_service
            configure_firewall
            start_spark_service

            if verify_installation; then
                generate_report
                log_success "Spark 安装完成！"
                exit 0
            else
                log_error "Spark 安装验证失败，请检查日志"
                exit 1
            fi
            ;;
    esac
}

main "$@"
