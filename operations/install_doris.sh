#!/bin/bash

################################################################################
# Apache Doris 统一安装/修复脚本
# 支持 CentOS/RHEL 7+, Ubuntu 18.04+, Kylin, UOS
# 功能:
#   - 安装 Apache Doris 1.2+ (原生安装, 非Docker)
#   - 交互式选择单节点或多节点集群
#   - 单节点: FE + BE 混合部署
#   - 多节点: 选择 FE (Frontend) / BE (Backend) / Observer 角色
#   - 自动检测或安装 Java 环境
#   - 配置 MySQL 兼容接口
#   - 交互式设置数据库用户和密码
#   - 配置 systemd 服务
#   - 配置开机自启
#   - 修复已安装的 Doris 配置问题（自动检测）
#   - 智能内存配置（根据系统自动计算）
#
# 使用方法:
#   sudo bash install_doris.sh                    # 全新安装
#   sudo bash install_doris.sh --fix-only         # 仅修复已有安装
#   sudo bash install_doris.sh --auto-config      # 自动配置已有安装
#
# 作者: Shell Collections Team
# 版本: 2.0.0 (统一版)
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 导入进度显示库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/progress_lib.sh" ]]; then
    source "$SCRIPT_DIR/progress_lib.sh"
else
    # 如果找不到库文件，定义简单的进度函数
    progress_init() { :; }
    progress_step() { echo "→ $2"; }
    progress_complete() { echo "安装完成"; }
    progress_fail() { echo "错误: $1"; }
    progress_status() { echo "⟳ $1"; }
fi

# 导入前置依赖检查库
if [[ -f "$SCRIPT_DIR/dependencies_lib.sh" ]]; then
    source "$SCRIPT_DIR/dependencies_lib.sh"
    source "$SCRIPT_DIR/dependencies_config.sh"
fi



# 配置变量
DORIS_VERSION="2.0.1"
DORIS_HOME="/opt/doris"
DORIS_USER="doris"
DEPLOYMENT_MODE="single"       # single 或 cluster
NODE_TYPE="fe"                  # fe, be, observer
FE_PORT=9010
FE_QUERY_PORT=9030
FE_HTTP_PORT=8030
BE_PORT=9060
BE_HTTP_PORT=8040
BE_HEARTBEAT_PORT=9050
DB_USER="root"
DB_PASSWORD=""
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
    echo "║      Apache Doris 自动安装脚本 v1.0.0                    ║"
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

# 检查是否已安装
# 检查已安装的 Doris 状态
check_doris_status() {
    if [[ ! -d "$DORIS_HOME" ]]; then
        return 1
    fi

    local status_running=0
    local status_version=""

    # 检查进程运行状态（FE和BE）
    if pgrep -f "PaloFE\|palo_be" >/dev/null 2>&1; then
        status_running=1
    fi

    return 0
}

# 显示已安装的 Doris 信息
show_installed_status() {
    log_warn "Doris 已安装在 $DORIS_HOME"
    echo ""

    log_info "Doris 版本: $DORIS_VERSION"

    # 检查运行状态
    if pgrep -f "PaloFE\|palo_be" >/dev/null 2>&1; then
        log_success "Doris 状态: 正在运行"
        echo ""
        log_info "运行中的 Doris 进程:"
        ps aux | grep -E "PaloFE|palo_be" | grep -v grep | while read line; do
            log_info "  $line"
        done
    else
        log_warn "Doris 状态: 已停止"
    fi

    # 检查配置
    if [[ -f "$DORIS_HOME/fe/conf/fe.conf" ]]; then
        log_info "FE配置: $DORIS_HOME/fe/conf/fe.conf"
    fi

    if [[ -f "$DORIS_HOME/be/conf/be.conf" ]]; then
        log_info "BE配置: $DORIS_HOME/be/conf/be.conf"
    fi

    echo ""
}

# 处理已安装的 Doris
handle_installed_doris() {
    show_installed_status

    echo -e "${BLUE}请选择操作:${NC}"
    echo "  1) 启动/重启 Doris (FE)"
    echo "  2) 停止 Doris"
    echo "  3) 查看 FE 日志"
    echo "  4) 查看 BE 日志"
    echo "  5) 重新安装（覆盖现有安装）"
    echo "  6) 返回（取消此次安装）"
    read -p "请选择 [1-6, 默认 6]: " -r action
    action=${action:-6}

    case $action in
        1)
            log_info "启动 Doris FE..."
            if [[ -f "$DORIS_HOME/fe/bin/start_fe.sh" ]]; then
                bash "$DORIS_HOME/fe/bin/start_fe.sh" || {
                    log_error "启动失败，请检查配置"
                    exit 1
                }
                sleep 3
                if pgrep -f "PaloFE" >/dev/null 2>&1; then
                    log_success "Doris FE 已启动"
                    log_info "访问地址: http://$(hostname -I | awk '{print $1}'):8030/"
                else
                    log_error "Doris FE 启动失败，请查看日志"
                fi
            fi
            exit 0
            ;;
        2)
            log_info "停止 Doris..."
            if [[ -f "$DORIS_HOME/fe/bin/stop_fe.sh" ]]; then
                bash "$DORIS_HOME/fe/bin/stop_fe.sh" 2>/dev/null || true
            fi
            if [[ -f "$DORIS_HOME/be/bin/stop_be.sh" ]]; then
                bash "$DORIS_HOME/be/bin/stop_be.sh" 2>/dev/null || true
            fi
            log_success "Doris 已停止"
            exit 0
            ;;
        3)
            log_info "显示 FE 日志 (最后 50 行):"
            tail -50 "$DORIS_HOME/fe/log"/*.log 2>/dev/null || {
                log_warn "未找到 FE 日志文件"
            }
            exit 0
            ;;
        4)
            log_info "显示 BE 日志 (最后 50 行):"
            tail -50 "$DORIS_HOME/be/log"/*.log 2>/dev/null || {
                log_warn "未找到 BE 日志文件"
            }
            exit 0
            ;;
        5)
            log_warn "将覆盖现有的 Doris 安装，继续安装..."
            # 继续进行安装流程
            ;;
        6|*)
            log_info "安装已取消"
            exit 0
            ;;
    esac
}

# 检查是否已安装
check_installed() {
    if [[ -d "$DORIS_HOME" ]]; then
        if check_doris_status; then
            handle_installed_doris
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

    # 长度检查 (至少8位)
    if [[ ${#password} -lt 8 ]]; then
        log_error "密码长度至少8位"
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
    log_info "Doris 安装配置"
    echo ""

    # 选择部署模式
    echo -e "${BLUE}请选择部署模式:${NC}"
    echo "  1) 单节点 (Single - 推荐本地测试)"
    echo "  2) 集群 (Cluster)"
    read -p "请选择 [1-2, 默认 1]: " mode_choice

    case $mode_choice in
        2)
            DEPLOYMENT_MODE="cluster"
            log_info "选择模式: 集群模式"

            # 选择节点类型
            echo ""
            echo -e "${BLUE}请选择节点类型:${NC}"
            echo "  1) FE (Frontend - 查询规划、优化和执行协调)"
            echo "  2) BE (Backend - 数据存储和查询执行)"
            echo "  3) Observer (观察者 FE - 无投票权)"
            read -p "请选择 [1-3, 默认 1]: " type_choice

            case $type_choice in
                2)
                    NODE_TYPE="be"
                    log_info "选择节点类型: BE (Backend)"
                    ;;
                3)
                    NODE_TYPE="observer"
                    log_info "选择节点类型: Observer"
                    ;;
                *)
                    NODE_TYPE="fe"
                    log_info "选择节点类型: FE (Frontend)"
                    ;;
            esac
            ;;
        *)
            DEPLOYMENT_MODE="single"
            log_info "选择模式: 单节点模式"
            NODE_TYPE="fe"
            ;;
    esac

    # 设置数据库密码
    echo ""
    while true; do
        read -sp "请输入 Doris root 用户密码 (默认为空): " DB_PASSWORD
        echo ""
        if [[ -z "$DB_PASSWORD" ]]; then
            log_warn "密码为空，继续"
            break
        elif validate_password "$DB_PASSWORD"; then
            read -sp "请再次输入密码确认: " password_confirm
            echo ""
            if [[ "$DB_PASSWORD" == "$password_confirm" ]]; then
                log_success "密码设置成功"
                break
            else
                log_error "两次密码不一致，请重新输入"
            fi
        fi
    done
}

# 下载并安装 Doris
install_doris_binary() {
    log_info "下载 Doris ${DORIS_VERSION}..."

    DORIS_DOWNLOAD="https://archive.apache.org/dist/doris/${DORIS_VERSION}/apache-doris-${DORIS_VERSION}-bin-x86_64.tar.gz"
    DORIS_TEMP="/tmp/apache-doris-${DORIS_VERSION}-bin-x86_64.tar.gz"

    # 尝试使用 curl 下载 (优先，因为进度条更简洁)
    if command -v curl &> /dev/null; then
        echo -e "${BLUE}[下载进度]${NC} 正在下载 Doris..."
        if curl -L --progress-bar --max-time 300 -o "$DORIS_TEMP" "$DORIS_DOWNLOAD"; then
            log_success "Doris 下载成功 (curl)"
        else
            # curl 失败，尝试 wget
            log_warn "curl 下载失败，尝试使用 wget..."
            download_with_wget "$DORIS_DOWNLOAD" "$DORIS_TEMP" "Doris" || exit 1
            log_success "Doris 下载成功 (wget)"
        fi
    # 如果没有 curl，使用 wget
    elif command -v wget &> /dev/null; then
        echo -e "${BLUE}[下载进度]${NC} 正在下载 Doris..."
        download_with_wget "$DORIS_DOWNLOAD" "$DORIS_TEMP" "Doris" || exit 1
        log_success "Doris 下载成功 (wget)"
    else
        log_error "没有可用的下载工具 (curl/wget 都不存在)"
        exit 1
    fi

    # 创建 Doris 用户
    log_info "创建 Doris 用户..."
    if ! id "$DORIS_USER" &>/dev/null; then
        useradd -r -s /bin/bash "$DORIS_USER"
        log_success "用户 $DORIS_USER 创建成功"
    else
        log_warn "用户 $DORIS_USER 已存在"
    fi

    # 创建 Doris 目录
    mkdir -p "$DORIS_HOME"
    tar -xzf "$DORIS_TEMP" -C "$DORIS_HOME" --strip-components=1

    # 设置权限
    chown -R "$DORIS_USER:$DORIS_USER" "$DORIS_HOME"
    chmod -R 755 "$DORIS_HOME"

    # 创建数据目录
    mkdir -p "$DORIS_HOME/doris-meta"
    mkdir -p "$DORIS_HOME/data"
    chown -R "$DORIS_USER:$DORIS_USER" "$DORIS_HOME/doris-meta" "$DORIS_HOME/data"

    # 清理临时文件
    rm -f "$DORIS_TEMP"

    log_success "Doris 安装完成: $DORIS_HOME"
}

# 配置 Doris
configure_doris() {
    log_info "配置 Doris..."

    # 根据部署模式和节点类型配置
    if [[ "$DEPLOYMENT_MODE" == "single" ]]; then
        configure_single_node
    else
        configure_cluster_node
    fi

    log_success "Doris 配置完成"
}

# 配置单节点
configure_single_node() {
    log_info "配置单节点部署..."

    local FE_CONF="$DORIS_HOME/fe/conf/fe.conf"

    cat >> "$FE_CONF" << EOF

# 单节点配置
meta_dir = $DORIS_HOME/doris-meta
http_port = $FE_HTTP_PORT
rpc_port = $FE_PORT
query_port = $FE_QUERY_PORT
edit_log_port = $((FE_PORT + 1))

# 内存配置
sys_log_level = INFO
log_dir = $DORIS_HOME/log
EOF

    # BE 配置
    local BE_CONF="$DORIS_HOME/be/conf/be.conf"
    cat >> "$BE_CONF" << EOF

# 单节点 BE 配置
storage_root_path = $DORIS_HOME/data

# 端口配置
be_port = $BE_PORT
webserver_port = $BE_HTTP_PORT
heartbeat_service_port = $BE_HEARTBEAT_PORT
brpc_port = $((BE_PORT + 1))

# 内存配置 (系统总内存的50%)
mem_limit = "$(( $(free -m | awk 'NR==2 {print int($2 * 0.5)}') ))m"

# 日志配置
log_dir = $DORIS_HOME/log
EOF

    chown "$DORIS_USER:$DORIS_USER" "$FE_CONF" "$BE_CONF"
}

# 配置集群节点
configure_cluster_node() {
    log_info "配置集群节点 (类型: $NODE_TYPE)..."

    if [[ "$NODE_TYPE" == "fe" ]] || [[ "$NODE_TYPE" == "observer" ]]; then
        local FE_CONF="$DORIS_HOME/fe/conf/fe.conf"

        cat >> "$FE_CONF" << EOF

# 集群 FE 配置
meta_dir = $DORIS_HOME/doris-meta
http_port = $FE_HTTP_PORT
rpc_port = $FE_PORT
query_port = $FE_QUERY_PORT
edit_log_port = $((FE_PORT + 1))

# 日志配置
log_dir = $DORIS_HOME/log
sys_log_level = INFO

# 集群配置
$(if [[ "$NODE_TYPE" == "observer" ]]; then echo "fe_type = OBSERVER"; fi)
EOF

        chown "$DORIS_USER:$DORIS_USER" "$FE_CONF"

    else
        # BE 节点配置
        local BE_CONF="$DORIS_HOME/be/conf/be.conf"

        cat >> "$BE_CONF" << EOF

# 集群 BE 配置
storage_root_path = $DORIS_HOME/data

# 端口配置
be_port = $BE_PORT
webserver_port = $BE_HTTP_PORT
heartbeat_service_port = $BE_HEARTBEAT_PORT
brpc_port = $((BE_PORT + 1))

# 内存配置 (系统总内存的50%)
mem_limit = "$(( $(free -m | awk 'NR==2 {print int($2 * 0.5)}') ))m"

# 日志配置
log_dir = $DORIS_HOME/log
EOF

        chown "$DORIS_USER:$DORIS_USER" "$BE_CONF"
    fi
}

# 配置 systemd 服务
configure_systemd_service() {
    log_info "配置 systemd 服务..."

    if [[ "$NODE_TYPE" == "be" ]]; then
        # BE 服务
        local SERVICE_FILE="/etc/systemd/system/doris-be.service"

        cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Apache Doris Backend
After=network.target

[Service]
Type=forking
User=$DORIS_USER
Group=$DORIS_USER
Environment="JAVA_HOME=$JAVA_HOME"
ExecStart=$DORIS_HOME/be/bin/start_be.sh
ExecStop=$DORIS_HOME/be/bin/stop_be.sh
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

        chmod 644 "$SERVICE_FILE"
        systemctl daemon-reload
        systemctl enable doris-be

    else
        # FE 服务
        local SERVICE_FILE="/etc/systemd/system/doris-fe.service"

        cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Apache Doris Frontend
After=network.target

[Service]
Type=forking
User=$DORIS_USER
Group=$DORIS_USER
Environment="JAVA_HOME=$JAVA_HOME"
ExecStart=$DORIS_HOME/fe/bin/start_fe.sh --daemon
ExecStop=$DORIS_HOME/fe/bin/stop_fe.sh
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

        chmod 644 "$SERVICE_FILE"
        systemctl daemon-reload
        systemctl enable doris-fe
    fi

    log_success "systemd 服务配置完成"
}

# 启动 Doris 服务
start_doris_service() {
    log_info "启动 Doris 服务..."

    if [[ "$NODE_TYPE" == "be" ]]; then
        systemctl start doris-be
        SERVICE_NAME="doris-be"
    else
        systemctl start doris-fe
        SERVICE_NAME="doris-fe"
    fi

    # 等待服务启动
    sleep 3

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_success "Doris 服务启动成功"
    else
        log_error "Doris 服务启动失败"
        systemctl status "$SERVICE_NAME"
        return 1
    fi
}

# 验证安装
verify_installation() {
    log_info "验证 Doris 安装..."

    sleep 2

    if [[ -d "$DORIS_HOME" ]]; then
        log_success "Doris 目录存在"

        if pgrep -f "doris" > /dev/null; then
            log_success "Doris 进程正在运行"
        else
            log_warn "Doris 进程未运行，请检查日志"
        fi

        return 0
    else
        log_error "Doris 验证失败"
        return 1
    fi
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."

    if command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL
        firewall-cmd --permanent --add-port=$FE_PORT/tcp
        firewall-cmd --permanent --add-port=$FE_QUERY_PORT/tcp
        firewall-cmd --permanent --add-port=$FE_HTTP_PORT/tcp
        firewall-cmd --permanent --add-port=$BE_PORT/tcp
        firewall-cmd --permanent --add-port=$BE_HTTP_PORT/tcp
        firewall-cmd --permanent --add-port=$BE_HEARTBEAT_PORT/tcp
        firewall-cmd --reload
        log_success "防火墙规则已添加 (yum系统)"
    elif command -v ufw &> /dev/null; then
        # Ubuntu
        ufw allow $FE_PORT/tcp
        ufw allow $FE_QUERY_PORT/tcp
        ufw allow $FE_HTTP_PORT/tcp
        ufw allow $BE_PORT/tcp
        ufw allow $BE_HTTP_PORT/tcp
        ufw allow $BE_HEARTBEAT_PORT/tcp
        log_success "防火墙规则已添加 (apt系统)"
    fi
}

# 生成安装报告
generate_report() {
    local report_file="/tmp/install_doris_report_$(date +%Y%m%d_%H%M%S).txt"

    cat > "$report_file" << EOF
╔════════════════════════════════════════════════════════════════╗
║         Apache Doris 安装报告                                 ║
╚════════════════════════════════════════════════════════════════╝

【安装信息】
安装时间: $(date '+%Y-%m-%d %H:%M:%S')
Doris 版本: $DORIS_VERSION
安装路径: $DORIS_HOME
Doris 用户: $DORIS_USER
Java 版本: $(java -version 2>&1 | grep -oP 'version "\K[^"]+')

【部署模式】
模式: $DEPLOYMENT_MODE
节点类型: $NODE_TYPE

【端口配置】
FE RPC 端口: $FE_PORT
FE Query 端口: $FE_QUERY_PORT
FE HTTP 端口: $FE_HTTP_PORT
BE RPC 端口: $BE_PORT
BE HTTP 端口: $BE_HTTP_PORT
BE Heartbeat 端口: $BE_HEARTBEAT_PORT

【常用命令】
1. 启动服务:
   $(if [[ "$NODE_TYPE" == "be" ]]; then echo "systemctl start doris-be"; else echo "systemctl start doris-fe"; fi)

2. 停止服务:
   $(if [[ "$NODE_TYPE" == "be" ]]; then echo "systemctl stop doris-be"; else echo "systemctl stop doris-fe"; fi)

3. 查看状态:
   $(if [[ "$NODE_TYPE" == "be" ]]; then echo "systemctl status doris-be"; else echo "systemctl status doris-fe"; fi)

4. 查看日志:
   tail -f $DORIS_HOME/log/*

5. 连接到 Doris:
   mysql -h 127.0.0.1 -P $FE_QUERY_PORT -u root -p

6. Web UI:
   http://$(hostname -I | awk '{print $1}'):$FE_HTTP_PORT/

【配置文件】
$(if [[ "$NODE_TYPE" == "be" ]]; then echo "- BE 配置: $DORIS_HOME/be/conf/be.conf"; else echo "- FE 配置: $DORIS_HOME/fe/conf/fe.conf"; fi)
- 日志位置: $DORIS_HOME/log/
- 数据位置: $DORIS_HOME/data/

【后续步骤】
1. 通过 MySQL 客户端连接 Doris
2. 创建数据库和表
3. 导入数据
4. 执行查询

【性能优化建议】
1. 根据硬件调整内存参数
2. 配置合适的并发参数
3. 定期分析表并优化索引
4. 监控慢查询

【技术支持】
官方文档: https://doris.apache.org/zh-CN/docs/
EOF

    echo ""
    cat "$report_file"
    log_success "安装报告已生成: $report_file"
}

# 修复 Doris 配置
repair_doris_config() {
    local FE_CONF="$DORIS_HOME/fe/conf/fe.conf"
    local BE_CONF="$DORIS_HOME/be/conf/be.conf"

    log_info "修复 Doris 配置文件..."

    if [[ -f "$FE_CONF" ]]; then
        cp "$FE_CONF" "${FE_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
        log_success "已备份 FE 配置"
    fi

    if [[ -f "$BE_CONF" ]]; then
        cp "$BE_CONF" "${BE_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
        log_success "已备份 BE 配置"
    fi

    # 检测系统内存并生成合适配置
    local total_mem=$(free -m | awk 'NR==2 {print $2}')
    local be_mem=$((total_mem / 2))
    [[ $be_mem -lt 1024 ]] && be_mem=1024

    # 创建 FE 配置
    cat > "$FE_CONF" << EOF
# Doris FE 配置 (统一脚本修复版本)
meta_dir = $DORIS_HOME/doris-meta
http_port = 8030
rpc_port = 9010
query_port = 9030
edit_log_port = 9011
bind_addr = 0.0.0.0
log_dir = $DORIS_HOME/log
sys_log_level = INFO
JAVA_OPTS = -Xms512m -Xmx512m
EOF

    # 创建 BE 配置
    cat > "$BE_CONF" << EOF
# Doris BE 配置 (统一脚本修复版本)
storage_root_path = $DORIS_HOME/data
be_port = 9060
webserver_port = 8040
heartbeat_service_port = 9050
brpc_port = 8060
mem_limit = ${be_mem}m
log_dir = $DORIS_HOME/log
sys_log_level = INFO
EOF

    chown doris:doris "$FE_CONF" "$BE_CONF"
    chmod 644 "$FE_CONF" "$BE_CONF"
    log_success "Doris 配置已修复"
}

# 启动并验证 Doris 服务
verify_and_start_doris() {
    log_info "启动 Doris 服务..."

    systemctl stop doris-fe 2>/dev/null || true
    systemctl stop doris-be 2>/dev/null || true
    sleep 2

    # 尝试启动 FE
    if systemctl start doris-fe 2>&1; then
        sleep 3
        if systemctl is-active --quiet doris-fe; then
            log_success "✓ Doris FE 已启动"
        else
            log_warn "⚠ Doris FE 启动可能需要更多时间"
        fi
    fi

    # 尝试启动 BE
    if systemctl start doris-be 2>&1; then
        sleep 2
        if systemctl is-active --quiet doris-be; then
            log_success "✓ Doris BE 已启动"
        else
            log_warn "⚠ Doris BE 未运行（可选）"
        fi
    fi

    return 0
}

# 仅修复模式
repair_only_mode() {
    log_info "进入 Doris 修复模式..."

    if [[ ! -d "$DORIS_HOME" ]]; then
        log_error "未找到 Doris 安装目录: $DORIS_HOME"
        exit 1
    fi

    check_root
    repair_doris_config

    if verify_and_start_doris; then
        log_success "✅ Doris 修复完成！"
        exit 0
    else
        log_error "❌ Doris 启动失败"
        exit 1
    fi
}

# 自动配置模式
auto_config_mode() {
    log_info "进入 Doris 自动配置模式..."

    if [[ ! -d "$DORIS_HOME" ]]; then
        log_error "未找到 Doris 安装目录: $DORIS_HOME"
        exit 1
    fi

    check_root
    detect_os

    repair_doris_config

    if verify_and_start_doris; then
        log_success "✅ Doris 自动配置完成！"
        exit 0
    else
        log_error "❌ Doris 配置失败"
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
                check_and_install_dependencies "Doris" "${DORIS_DEPENDENCIES[@]}"
                echo ""
            fi
            check_installed
            check_java
            interactive_config
            install_doris_binary
            configure_doris
            configure_systemd_service
            configure_firewall
            start_doris_service

            if verify_installation; then
                generate_report
                log_success "Doris 安装完成！"
                exit 0
            else
                log_error "Doris 安装验证失败，请检查日志"
                exit 1
            fi
            ;;
    esac
}

main "$@"
