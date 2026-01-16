#!/bin/bash

################################################################################
# RabbitMQ 自动安装脚本
# 支持 CentOS/RHEL 7+, Ubuntu 18.04+, Kylin, UOS
# 功能:
#   - 安装 RabbitMQ 3.x 和 Erlang
#   - 强制创建管理员用户和密码
#   - 密码复杂度验证 (12+ 字符)
#   - 启用 rabbitmq_management 插件
#   - 配置虚拟主机 (vhost)
#   - 优化内存和连接参数
#   - 配置双端口 (5672 AMQP, 15672 Management)
#   - 配置开机自启
#
# 使用方法:
#   sudo bash install_rabbitmq.sh
#
# 作者: Shell Collections Team
# 版本: 1.0.0
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
RABBITMQ_VERSION="3.12"
AMQP_PORT=5672
MANAGEMENT_PORT=15672
ADMIN_USER=""
ADMIN_PASSWORD=""
VHOST="/"

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 打印标题
print_header() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         RabbitMQ 自动安装脚本 v1.0.0                     ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
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

# 验证密码复杂度
validate_password() {
    local password="$1"

    # 长度检查 (至少12位)
    if [[ ${#password} -lt 12 ]]; then
        log_error "密码长度至少12位"
        return 1
    fi

    # 复杂度检查
    local has_upper=$(echo "$password" | grep -q '[A-Z]' && echo 1 || echo 0)
    local has_lower=$(echo "$password" | grep -q '[a-z]' && echo 1 || echo 0)
    local has_digit=$(echo "$password" | grep -q '[0-9]' && echo 1 || echo 0)
    local has_special=$(echo "$password" | grep -q '[!@#$%^&*()_+=-]' && echo 1 || echo 0)

    local complexity=$((has_upper + has_lower + has_digit + has_special))

    if [[ $complexity -lt 3 ]]; then
        log_error "密码必须包含以下至少3种: 大写字母、小写字母、数字、特殊字符"
        return 1
    fi

    # 弱密码检查
    local weak_passwords=("rabbitmq123456" "admin123456" "password123456" "123456789012")
    for weak in "${weak_passwords[@]}"; do
        if [[ "$password" == "$weak" ]]; then
            log_error "不允许使用常见弱密码"
            return 1
        fi
    done

    return 0
}

# 交互式配置
interactive_config() {
    echo ""
    log_info "RabbitMQ 安装配置"
    echo ""

    # 设置管理员用户名 (MANDATORY)
    echo -e "${BLUE}设置管理员用户名:${NC}"
    read -p "请输入管理员用户名 [默认: admin]: " custom_admin_user
    if [[ -n "$custom_admin_user" ]]; then
        ADMIN_USER="$custom_admin_user"
    else
        ADMIN_USER="admin"
    fi
    log_info "管理员用户名: $ADMIN_USER"

    # 设置管理员密码 (MANDATORY)
    echo ""
    log_info "设置管理员密码"
    echo -e "${YELLOW}密码要求:${NC}"
    echo "  - 至少12位长度"
    echo "  - 包含大写字母、小写字母、数字、特殊字符中的至少3种"
    echo "  - 不能使用常见弱密码"
    echo ""

    local password1=""
    local password2=""
    local attempts=0
    local max_attempts=3

    while [[ $attempts -lt $max_attempts ]]; do
        read -s -p "请输入管理员密码: " password1
        echo ""

        if ! validate_password "$password1"; then
            ((attempts++))
            if [[ $attempts -lt $max_attempts ]]; then
                log_warn "还有 $((max_attempts - attempts)) 次机会"
            fi
            continue
        fi

        read -s -p "请再次输入密码: " password2
        echo ""

        if [[ "$password1" != "$password2" ]]; then
            log_error "两次密码不一致"
            ((attempts++))
            if [[ $attempts -lt $max_attempts ]]; then
                log_warn "还有 $((max_attempts - attempts)) 次机会"
            fi
            continue
        fi

        ADMIN_PASSWORD="$password1"
        log_success "管理员密码设置成功"
        break
    done

    if [[ -z "$ADMIN_PASSWORD" ]]; then
        log_error "管理员密码设置失败"
        exit 1
    fi

    # 配置虚拟主机
    echo ""
    read -p "请输入虚拟主机名称 (vhost) [默认: /]: " custom_vhost
    if [[ -n "$custom_vhost" ]]; then
        VHOST="$custom_vhost"
    fi
    log_info "虚拟主机: $VHOST"

    # 端口配置
    echo ""
    read -p "AMQP 端口 [默认: 5672]: " custom_amqp_port
    if [[ -n "$custom_amqp_port" ]]; then
        AMQP_PORT="$custom_amqp_port"
    fi

    read -p "Management 端口 [默认: 15672]: " custom_mgmt_port
    if [[ -n "$custom_mgmt_port" ]]; then
        MANAGEMENT_PORT="$custom_mgmt_port"
    fi

    log_info "AMQP 端口: $AMQP_PORT, Management 端口: $MANAGEMENT_PORT"
}

# 检查是否已安装
check_installed() {
    if command -v rabbitmq-server &> /dev/null; then
        CURRENT_VERSION=$(rabbitmq-server --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1)
        log_warn "检测到已安装 RabbitMQ: $CURRENT_VERSION"
        read -p "是否继续安装? (y/n): " -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

# 安装 Erlang (CentOS/RHEL)
install_erlang_yum() {
    log_info "安装 Erlang..."

    # 麒麟系统特殊处理
    if [[ "$OS" == "kylin" ]]; then
        log_info "检测到麒麟系统,使用系统自带仓库..."
        if yum install -y erlang 2>/dev/null; then
            log_success "Erlang 安装成功 (系统版本)"
            return 0
        else
            log_error "系统仓库安装Erlang失败,请检查yum源配置"
            exit 1
        fi
    fi

    # 标准CentOS/RHEL系统,使用官方仓库
    log_info "使用Erlang官方仓库..."

    # 添加 Erlang 仓库
    if ! curl -s https://packagecloud.io/install/repositories/rabbitmq/erlang/script.rpm.sh | bash 2>/dev/null; then
        log_warn "官方仓库添加失败,尝试使用系统仓库..."
        if yum install -y erlang 2>/dev/null; then
            log_success "Erlang 安装成功 (系统版本)"
            return 0
        else
            log_error "无法安装Erlang,请检查yum源配置"
            exit 1
        fi
    fi

    # 安装 Erlang
    yum install -y erlang

    log_success "Erlang 安装完成: $(erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell)"
}

# 安装 Erlang (Ubuntu/Debian)
install_erlang_apt() {
    log_info "安装 Erlang..."

    # 添加 Erlang 仓库
    wget -O- https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc | apt-key add -
    echo "deb https://packages.erlang-solutions.com/ubuntu $(lsb_release -cs) contrib" | tee /etc/apt/sources.list.d/erlang.list

    # 更新并安装
    apt-get update -qq
    apt-get install -y erlang

    log_success "Erlang 安装完成"
}

# 安装 RabbitMQ (CentOS/RHEL)
install_rabbitmq_yum() {
    log_info "安装 RabbitMQ..."

    # 麒麟系统特殊处理
    if [[ "$OS" == "kylin" ]]; then
        log_info "检测到麒麟系统,使用系统自带仓库..."
        if yum install -y rabbitmq-server 2>/dev/null; then
            log_success "RabbitMQ 安装成功 (系统版本)"
            return 0
        else
            log_error "系统仓库安装RabbitMQ失败,请检查yum源配置"
            exit 1
        fi
    fi

    # 标准CentOS/RHEL系统,使用官方仓库
    log_info "使用RabbitMQ官方仓库..."

    # 添加 RabbitMQ 仓库
    if ! curl -s https://packagecloud.io/install/repositories/rabbitmq/rabbitmq-server/script.rpm.sh | bash 2>/dev/null; then
        log_warn "官方仓库添加失败,尝试使用系统仓库..."
        if yum install -y rabbitmq-server 2>/dev/null; then
            log_success "RabbitMQ 安装成功 (系统版本)"
            return 0
        else
            log_error "无法安装RabbitMQ,请检查yum源配置"
            exit 1
        fi
    fi

    # 安装 RabbitMQ
    yum install -y rabbitmq-server

    log_success "RabbitMQ 安装完成"
}

# 安装 RabbitMQ (Ubuntu/Debian)
install_rabbitmq_apt() {
    log_info "安装 RabbitMQ..."

    # 添加 RabbitMQ 仓库
    curl -fsSL https://github.com/rabbitmq/signing-keys/releases/download/2.0/rabbitmq-release-signing-key.asc | apt-key add -

    # 添加 apt 仓库
    echo "deb https://dl.bintray.com/rabbitmq/debian $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/rabbitmq.list

    # 更新并安装
    apt-get update -qq
    apt-get install -y rabbitmq-server

    log_success "RabbitMQ 安装完成"
}

# 配置 RabbitMQ
configure_rabbitmq() {
    log_info "配置 RabbitMQ..."

    # 创建配置文件
    mkdir -p /etc/rabbitmq

    # 计算最大内存 (系统内存的40%)
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    MAX_MEM=$(echo "scale=2; $TOTAL_MEM * 0.4" | bc)
    MAX_MEM_INT=$(printf "%.0f" $MAX_MEM)

    cat > /etc/rabbitmq/rabbitmq.conf <<EOF
# RabbitMQ Configuration

# Network
listeners.tcp.default = $AMQP_PORT
management.tcp.port = $MANAGEMENT_PORT

# Memory
vm_memory_high_watermark.relative = 0.4
vm_memory_high_watermark_paging_ratio = 0.5
total_memory_available_override_value = ${TOTAL_MEM}MB

# Disk
disk_free_limit.absolute = 2GB

# Connections
num_acceptors.tcp = 10
max_connections = 1000

# Channels
channel_max = 128

# Heartbeat
heartbeat = 60

# Default User (will be deleted after creating admin)
default_user = guest
default_pass = guest
loopback_users.guest = false
EOF

    # 创建高级配置文件
    cat > /etc/rabbitmq/advanced.config <<'EOF'
[
  {rabbit, [
    {tcp_listen_options, [
      {backlog, 128},
      {nodelay, true},
      {exit_on_close, false},
      {keepalive, true}
    ]}
  ]}
].
EOF

    log_success "RabbitMQ 配置完成"
}

# 启动服务并启用插件
start_and_enable_plugins() {
    log_info "启动 RabbitMQ 服务..."

    systemctl daemon-reload
    systemctl enable rabbitmq-server
    systemctl start rabbitmq-server

    sleep 5

    if systemctl is-active --quiet rabbitmq-server; then
        log_success "RabbitMQ 服务启动成功"
    else
        log_error "RabbitMQ 服务启动失败"
        systemctl status rabbitmq-server --no-pager
        exit 1
    fi

    # 启用管理插件
    log_info "启用 Management 插件..."
    rabbitmq-plugins enable rabbitmq_management
    log_success "Management 插件已启用"

    # 其他常用插件
    log_info "启用其他插件..."
    rabbitmq-plugins enable rabbitmq_shovel rabbitmq_shovel_management
    rabbitmq-plugins enable rabbitmq_federation rabbitmq_federation_management
    log_success "额外插件已启用"
}

# 创建管理员用户
create_admin_user() {
    log_info "创建管理员用户..."

    # 创建虚拟主机
    if [[ "$VHOST" != "/" ]]; then
        rabbitmqctl add_vhost "$VHOST"
        log_success "已创建虚拟主机: $VHOST"
    fi

    # 创建管理员用户
    rabbitmqctl add_user "$ADMIN_USER" "$ADMIN_PASSWORD"
    rabbitmqctl set_user_tags "$ADMIN_USER" administrator

    # 授权
    rabbitmqctl set_permissions -p "$VHOST" "$ADMIN_USER" ".*" ".*" ".*"

    log_success "已创建管理员用户: $ADMIN_USER"

    # 删除默认 guest 用户 (安全考虑)
    rabbitmqctl delete_user guest 2>/dev/null || true
    log_success "已删除默认 guest 用户"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."

    if command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            firewall-cmd --permanent --add-port=$AMQP_PORT/tcp
            firewall-cmd --permanent --add-port=$MANAGEMENT_PORT/tcp
            firewall-cmd --permanent --add-port=25672/tcp  # Erlang distribution
            firewall-cmd --reload
            log_success "防火墙规则已添加"
        fi
    elif command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            ufw allow $AMQP_PORT/tcp
            ufw allow $MANAGEMENT_PORT/tcp
            ufw allow 25672/tcp
            log_success "防火墙规则已添加"
        fi
    fi
}

# 验证安装
verify_installation() {
    log_info "验证 RabbitMQ 安装..."

    RABBITMQ_VER=$(rabbitmq-server --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1)
    log_success "RabbitMQ 版本: $RABBITMQ_VER"

    # 测试端口
    if timeout 5 bash -c "echo > /dev/tcp/127.0.0.1/$AMQP_PORT" 2>/dev/null; then
        log_success "AMQP 端口 ($AMQP_PORT) 监听正常"
    else
        log_warn "AMQP 端口 ($AMQP_PORT) 未监听"
    fi

    if timeout 5 bash -c "echo > /dev/tcp/127.0.0.1/$MANAGEMENT_PORT" 2>/dev/null; then
        log_success "Management 端口 ($MANAGEMENT_PORT) 监听正常"
    else
        log_warn "Management 端口 ($MANAGEMENT_PORT) 未监听"
    fi

    # 查看集群状态
    rabbitmqctl cluster_status | head -n 10
}

# 生成安装报告
generate_report() {
    local REPORT_FILE="/tmp/install_rabbitmq_report_$(date +%Y%m%d_%H%M%S).txt"
    local SERVER_IP=$(hostname -I | awk '{print $1}')

    cat > "$REPORT_FILE" <<EOF
╔═══════════════════════════════════════════════════════════╗
║         RabbitMQ 安装报告                                 ║
╚═══════════════════════════════════════════════════════════╝

安装时间: $(date '+%Y-%m-%d %H:%M:%S')
操作系统: $OS_NAME ($OS_VERSION)

【安装版本】
RabbitMQ: $(rabbitmq-server --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1)
Erlang: $(erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell 2>&1)

【服务状态】
$(systemctl status rabbitmq-server --no-pager | head -n 3)

【连接信息】
主机: $SERVER_IP
AMQP 端口: $AMQP_PORT
Management 端口: $MANAGEMENT_PORT
管理员用户: $ADMIN_USER
管理员密码: $ADMIN_PASSWORD
虚拟主机: $VHOST

【访问地址】
Management Web UI:
  http://$SERVER_IP:$MANAGEMENT_PORT

登录凭证:
  用户名: $ADMIN_USER
  密码: $ADMIN_PASSWORD

AMQP 连接:
  amqp://$ADMIN_USER:$ADMIN_PASSWORD@$SERVER_IP:$AMQP_PORT/$VHOST

【配置文件】
主配置: /etc/rabbitmq/rabbitmq.conf
高级配置: /etc/rabbitmq/advanced.config
数据目录: /var/lib/rabbitmq
日志目录: /var/log/rabbitmq

【管理命令】
启动服务:   systemctl start rabbitmq-server
停止服务:   systemctl stop rabbitmq-server
重启服务:   systemctl restart rabbitmq-server
查看状态:   systemctl status rabbitmq-server
查看日志:   tail -f /var/log/rabbitmq/rabbit@*.log

【RabbitMQ 管理命令】
集群状态:   rabbitmqctl cluster_status
列出用户:   rabbitmqctl list_users
列出vhost:  rabbitmqctl list_vhosts
列出队列:   rabbitmqctl list_queues
列出交换机: rabbitmqctl list_exchanges
查看连接:   rabbitmqctl list_connections

【插件管理】
列出插件:   rabbitmq-plugins list
启用插件:   rabbitmq-plugins enable <plugin>
禁用插件:   rabbitmq-plugins disable <plugin>

已启用插件:
$(rabbitmq-plugins list -e | grep -E '\[E\]')

【创建用户和虚拟主机】
创建用户:
  rabbitmqctl add_user myuser mypassword
  rabbitmqctl set_user_tags myuser monitoring

创建虚拟主机:
  rabbitmqctl add_vhost myvhost

授权:
  rabbitmqctl set_permissions -p myvhost myuser ".*" ".*" ".*"

【Python 示例】
import pika

credentials = pika.PlainCredentials('$ADMIN_USER', '$ADMIN_PASSWORD')
parameters = pika.ConnectionParameters(
    host='$SERVER_IP',
    port=$AMQP_PORT,
    virtual_host='$VHOST',
    credentials=credentials
)

connection = pika.BlockingConnection(parameters)
channel = connection.channel()

# 声明队列
channel.queue_declare(queue='hello')

# 发送消息
channel.basic_publish(exchange='', routing_key='hello', body='Hello World!')

【性能优化】
内存限制: ${MAX_MEM_INT}MB (系统内存的40%)
最大连接数: 1000
磁盘空闲限制: 2GB

优化建议:
- 根据实际负载调整内存限制
- 启用消息持久化以防数据丢失
- 配置集群以提高可用性
- 监控队列长度和消息积压
- 使用 TTL 清理过期消息

【监控指标】
查看队列:
  rabbitmqctl list_queues name messages consumers

查看内存使用:
  rabbitmqctl status | grep memory

【安全建议】
1. 已删除默认 guest 用户
2. 定期修改管理员密码
3. 为不同应用创建专用用户
4. 配置 SSL/TLS 加密连接 (生产环境)
5. 限制 Management UI 访问 IP
6. 定期备份配置和数据

【集群配置 (可选)】
在其他节点执行:
  rabbitmqctl stop_app
  rabbitmqctl join_cluster rabbit@$SERVER_IP
  rabbitmqctl start_app

【注意事项】
⚠ 请妥善保管管理员密码: $ADMIN_PASSWORD
⚠ Management UI: http://$SERVER_IP:$MANAGEMENT_PORT
⚠ 生产环境建议配置集群
⚠ 定期备份数据和配置
⚠ 监控内存和磁盘使用率

【安装日志】
$REPORT_FILE

EOF

    log_success "安装报告已生成: $REPORT_FILE"

    # 显示摘要
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         RabbitMQ 安装完成!                                ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}RabbitMQ 版本:${NC} $(rabbitmq-server --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1)"
    echo -e "${BLUE}服务状态:${NC} $(systemctl is-active rabbitmq-server)"
    echo -e "${BLUE}AMQP 端口:${NC} $SERVER_IP:$AMQP_PORT"
    echo -e "${BLUE}Management:${NC} http://$SERVER_IP:$MANAGEMENT_PORT"
    echo -e "${BLUE}管理员:${NC} $ADMIN_USER"
    echo -e "${BLUE}密    码:${NC} $ADMIN_PASSWORD"
    echo ""
    echo -e "${YELLOW}浏览器访问:${NC} http://$SERVER_IP:$MANAGEMENT_PORT"
    echo -e "${YELLOW}报    告:${NC} $REPORT_FILE"
    echo ""
    echo -e "${RED}⚠ 请妥善保管密码，建议将报告内容保存到安全位置${NC}"
    echo ""
}

# 主函数
main() {
    print_header

    log_info "开始安装 RabbitMQ..."
    echo ""

    check_root
    detect_os

    # 检查前置依赖
    if command -v check_and_install_dependencies &>/dev/null; then
        log_info "检查前置依赖..."
        check_and_install_dependencies "RabbitMQ" "${RABBITMQ_DEPENDENCIES[@]}"
        echo ""
    fi
    check_installed
    interactive_config

    # 安装 Erlang
    if [[ $PKG_MANAGER == "yum" ]]; then
        install_erlang_yum
    else
        install_erlang_apt
    fi

    # 安装 RabbitMQ
    if [[ $PKG_MANAGER == "yum" ]]; then
        install_rabbitmq_yum
    else
        install_rabbitmq_apt
    fi

    configure_rabbitmq
    start_and_enable_plugins
    create_admin_user
    configure_firewall
    verify_installation

    echo ""
    generate_report
}

# 执行主函数
main
