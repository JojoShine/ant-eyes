#!/bin/bash

################################################################################
# Redis 自动安装脚本
# 支持 CentOS/RHEL 7+, Ubuntu 18.04+, Kylin, UOS
# 功能:
#   - 安装 Redis 7.x 或 6.x
#   - 强制设置密码 (requirepass)
#   - 密码复杂度验证
#   - 配置持久化 (RDB + AOF)
#   - 优化内存参数
#   - 禁用危险命令
#   - 配置开机自启
#
# 使用方法:
#   sudo bash install_redis.sh
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
REDIS_PORT=6379
REDIS_PASSWORD=""
REDIS_VERSION="7.2"

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 打印标题
print_header() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║           Redis 自动安装脚本 v1.0.0                      ║"
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
    local weak_passwords=("password123456" "admin123456" "redis123456" "123456789012")
    for weak in "${weak_passwords[@]}"; do
        if [[ "$password" == "$weak" ]]; then
            log_error "不允许使用常见弱密码"
            return 1
        fi
    done

    return 0
}

# 交互式设置密码
set_redis_password() {
    echo ""
    log_info "Redis 安全配置"
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
        read -s -p "请输入 Redis 密码: " password1
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

        REDIS_PASSWORD="$password1"
        log_success "密码设置成功"
        return 0
    done

    log_error "密码设置失败次数过多"
    exit 1
}

# 检查是否已安装
check_installed() {
    if command -v redis-server &> /dev/null; then
        CURRENT_VERSION=$(redis-server --version | awk '{print $3}' | cut -d'=' -f2)
        log_warn "检测到已安装 Redis: $CURRENT_VERSION"
        read -p "是否继续安装? (y/n): " -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

# 安装 Redis (CentOS/RHEL)
install_redis_yum() {
    log_info "安装 Redis..."

    # 麒麟系统特殊处理
    if [[ "$OS" == "kylin" ]]; then
        log_info "检测到麒麟系统,使用系统自带仓库..."

        # 尝试直接安装系统自带的Redis
        log_info "从系统仓库安装 Redis..."
        if yum install -y redis 2>/dev/null; then
            log_success "Redis 安装成功 (系统版本)"
            REDIS_VERSION=$(redis-server --version 2>/dev/null | awk '{print $3}' | cut -d'=' -f2 || echo "unknown")
            log_info "实际安装版本: Redis $REDIS_VERSION"
            return 0
        else
            log_error "系统仓库安装失败,请检查yum源配置"
            log_info "可用的Redis包:"
            yum search redis 2>/dev/null | grep "^redis"
            exit 1
        fi
    fi

    # 标准CentOS/RHEL系统,使用EPEL和Remi仓库
    log_info "使用EPEL和Remi仓库..."

    # 启用 EPEL 和 Remi 仓库
    if ! yum install -y epel-release 2>/dev/null; then
        log_warn "EPEL仓库安装失败,尝试使用系统仓库..."
        if yum install -y redis 2>/dev/null; then
            log_success "Redis 安装成功 (系统版本)"
            REDIS_VERSION=$(redis-server --version 2>/dev/null | awk '{print $3}' | cut -d'=' -f2 || echo "unknown")
            log_info "实际安装版本: Redis $REDIS_VERSION"
            return 0
        else
            log_error "无法安装Redis,请检查yum源配置"
            exit 1
        fi
    fi

    yum install -y https://rpms.remirepo.net/enterprise/remi-release-$(rpm -E %rhel).rpm 2>/dev/null || true

    # 安装 Redis
    if [[ -n "$(yum module list redis 2>/dev/null)" ]]; then
        yum module reset redis -y
        yum module enable redis:remi-7.2 -y 2>/dev/null || yum module enable redis:remi-7.0 -y
    fi

    yum install -y redis

    log_success "Redis 安装完成"
}

# 安装 Redis (Ubuntu/Debian)
install_redis_apt() {
    log_info "安装 Redis..."

    apt-get update -qq
    apt-get install -y redis-server

    log_success "Redis 安装完成"
}

# 配置 Redis
configure_redis() {
    log_info "配置 Redis..."

    local REDIS_CONF="/etc/redis/redis.conf"
    if [[ ! -f "$REDIS_CONF" ]]; then
        REDIS_CONF="/etc/redis.conf"
    fi

    if [[ ! -f "$REDIS_CONF" ]]; then
        log_error "找不到 Redis 配置文件"
        exit 1
    fi

    # 备份原配置
    cp "$REDIS_CONF" "${REDIS_CONF}.bak.$(date +%Y%m%d_%H%M%S)"

    # 修改配置
    # 1. 监听地址 (默认仅本地，生产环境可改为 0.0.0.0)
    sed -i "s/^bind 127.0.0.1 -::1/bind 0.0.0.0/" "$REDIS_CONF"
    sed -i "s/^bind 127.0.0.1/bind 0.0.0.0/" "$REDIS_CONF"

    # 2. 保护模式
    sed -i "s/^protected-mode yes/protected-mode yes/" "$REDIS_CONF"

    # 3. 端口
    sed -i "s/^port 6379/port $REDIS_PORT/" "$REDIS_CONF"

    # 4. 守护进程模式
    sed -i "s/^supervised no/supervised systemd/" "$REDIS_CONF"

    # 5. 设置密码
    if grep -q "^requirepass" "$REDIS_CONF"; then
        sed -i "s/^requirepass .*/requirepass $REDIS_PASSWORD/" "$REDIS_CONF"
    else
        echo "requirepass $REDIS_PASSWORD" >> "$REDIS_CONF"
    fi

    # 6. 持久化配置 - RDB
    sed -i "s/^save 900 1/save 900 1/" "$REDIS_CONF"
    sed -i "s/^save 300 10/save 300 10/" "$REDIS_CONF"
    sed -i "s/^save 60 10000/save 60 10000/" "$REDIS_CONF"

    # 7. AOF 持久化
    sed -i "s/^appendonly no/appendonly yes/" "$REDIS_CONF"
    sed -i "s/^appendfsync everysec/appendfsync everysec/" "$REDIS_CONF"

    # 8. 内存管理
    echo "" >> "$REDIS_CONF"
    echo "# Memory Management" >> "$REDIS_CONF"
    echo "maxmemory 512mb" >> "$REDIS_CONF"
    echo "maxmemory-policy allkeys-lru" >> "$REDIS_CONF"

    # 9. 禁用危险命令
    echo "" >> "$REDIS_CONF"
    echo "# Disable Dangerous Commands" >> "$REDIS_CONF"
    echo "rename-command FLUSHDB \"\"" >> "$REDIS_CONF"
    echo "rename-command FLUSHALL \"\"" >> "$REDIS_CONF"
    echo "rename-command KEYS \"\"" >> "$REDIS_CONF"
    echo "rename-command CONFIG \"REDIS_CONFIG_$(openssl rand -hex 8)\"" >> "$REDIS_CONF"

    # 10. 日志
    sed -i "s|^logfile .*|logfile /var/log/redis/redis.log|" "$REDIS_CONF"
    mkdir -p /var/log/redis
    chown redis:redis /var/log/redis

    log_success "Redis 配置完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."

    if command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            firewall-cmd --permanent --add-port=$REDIS_PORT/tcp
            firewall-cmd --reload
            log_success "防火墙规则已添加"
        fi
    elif command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            ufw allow $REDIS_PORT/tcp
            log_success "防火墙规则已添加"
        fi
    fi

    log_warn "请注意: Redis 已配置为监听 0.0.0.0，请确保防火墙安全"
}

# 启动服务
start_service() {
    log_info "启动 Redis 服务..."

    systemctl daemon-reload
    systemctl enable redis
    systemctl restart redis

    sleep 2

    if systemctl is-active --quiet redis; then
        log_success "Redis 服务启动成功"
    else
        log_error "Redis 服务启动失败"
        systemctl status redis --no-pager
        exit 1
    fi
}

# 验证安装
verify_installation() {
    log_info "验证 Redis 安装..."

    REDIS_VERSION=$(redis-server --version | awk '{print $3}' | cut -d'=' -f2)
    log_success "Redis 版本: $REDIS_VERSION"

    # 测试连接
    if redis-cli -a "$REDIS_PASSWORD" --no-auth-warning ping | grep -q "PONG"; then
        log_success "Redis 连接测试通过"
    else
        log_error "Redis 连接测试失败"
        exit 1
    fi

    # 测试写入
    if redis-cli -a "$REDIS_PASSWORD" --no-auth-warning set test_key "test_value" | grep -q "OK"; then
        redis-cli -a "$REDIS_PASSWORD" --no-auth-warning del test_key &>/dev/null
        log_success "Redis 读写测试通过"
    else
        log_warn "Redis 读写测试失败"
    fi
}

# 生成安装报告
generate_report() {
    local REPORT_FILE="/tmp/install_redis_report_$(date +%Y%m%d_%H%M%S).txt"
    local SERVER_IP=$(hostname -I | awk '{print $1}')

    cat > "$REPORT_FILE" <<EOF
╔═══════════════════════════════════════════════════════════╗
║           Redis 安装报告                                  ║
╚═══════════════════════════════════════════════════════════╝

安装时间: $(date '+%Y-%m-%d %H:%M:%S')
操作系统: $OS_NAME ($OS_VERSION)

【安装版本】
Redis: $(redis-server --version | awk '{print $3}' | cut -d'=' -f2)

【服务状态】
$(systemctl status redis --no-pager | head -n 3)

【连接信息】
主机: $SERVER_IP
端口: $REDIS_PORT
密码: $REDIS_PASSWORD

【连接命令】
本地连接:
  redis-cli -a '$REDIS_PASSWORD'

远程连接:
  redis-cli -h $SERVER_IP -p $REDIS_PORT -a '$REDIS_PASSWORD'

Python 连接:
  import redis
  r = redis.Redis(host='$SERVER_IP', port=$REDIS_PORT, password='$REDIS_PASSWORD', decode_responses=True)

【配置文件】
主配置: $(find /etc -name redis.conf 2>/dev/null | head -n1)
数据目录: /var/lib/redis
日志文件: /var/log/redis/redis.log

【管理命令】
启动服务:   systemctl start redis
停止服务:   systemctl stop redis
重启服务:   systemctl restart redis
查看状态:   systemctl status redis
查看日志:   tail -f /var/log/redis/redis.log

【Redis 命令】
连接:       redis-cli -a '$REDIS_PASSWORD'
测试连接:   redis-cli -a '$REDIS_PASSWORD' ping
查看信息:   redis-cli -a '$REDIS_PASSWORD' info
查看配置:   redis-cli -a '$REDIS_PASSWORD' config get '*'
监控命令:   redis-cli -a '$REDIS_PASSWORD' monitor

【安全配置】
✓ 已设置密码认证
✓ 已禁用 FLUSHDB 命令
✓ 已禁用 FLUSHALL 命令
✓ 已禁用 KEYS 命令
✓ 已重命名 CONFIG 命令

【持久化配置】
✓ RDB: 已启用 (save 900 1, 300 10, 60 10000)
✓ AOF: 已启用 (appendfsync everysec)

【内存配置】
最大内存: 512MB
淘汰策略: allkeys-lru

【性能优化建议】
1. 根据实际内存调整 maxmemory
2. 选择合适的淘汰策略
3. 监控内存使用: redis-cli -a '$REDIS_PASSWORD' info memory
4. 定期查看慢查询: redis-cli -a '$REDIS_PASSWORD' slowlog get 10

【注意事项】
⚠ Redis 监听 0.0.0.0，请确保防火墙配置正确
⚠ 请妥善保管密码: $REDIS_PASSWORD
⚠ 生产环境建议使用 Redis Sentinel 或 Cluster
⚠ 定期备份 RDB 和 AOF 文件

【安装日志】
$REPORT_FILE

EOF

    log_success "安装报告已生成: $REPORT_FILE"

    # 显示摘要
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           Redis 安装完成!                                 ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Redis 版本:${NC} $(redis-server --version | awk '{print $3}' | cut -d'=' -f2)"
    echo -e "${BLUE}服务状态:${NC} $(systemctl is-active redis)"
    echo -e "${BLUE}连接地址:${NC} $SERVER_IP:$REDIS_PORT"
    echo -e "${BLUE}密    码:${NC} $REDIS_PASSWORD"
    echo ""
    echo -e "${YELLOW}连接测试:${NC} redis-cli -h $SERVER_IP -p $REDIS_PORT -a '$REDIS_PASSWORD' ping"
    echo -e "${YELLOW}报    告:${NC} $REPORT_FILE"
    echo ""
    echo -e "${RED}⚠ 请妥善保管密码，建议将报告内容保存到安全位置${NC}"
    echo ""
}

# 主函数
main() {
    print_header

    # 初始化进度显示（7个主要步骤）
    progress_init "Redis 缓存数据库" 7
    progress_show_tasks \
        "检查root权限" \
        "检测操作系统" \
        "检查现有安装" \
        "设置密码" \
        "安装Redis" \
        "配置参数" \
        "验证安装"

    log_info "开始安装 Redis..."
    echo ""

    # Step 1
    progress_step 1 "检查root权限..."
    check_root
    progress_success "root权限验证通过"
    echo ""

    # Step 2
    progress_step 2 "检测操作系统..."
    detect_os

    # 检查前置依赖
    if command -v check_and_install_dependencies &>/dev/null; then
        log_info "检查前置依赖..."
        check_and_install_dependencies "Redis" "${REDIS_DEPENDENCIES[@]}"
        echo ""
    fi
    progress_success "操作系统检测完成: $OS_NAME"
    echo ""

    # Step 3
    progress_step 3 "检查现有安装..."
    check_installed
    progress_success "安装前检查完成"
    echo ""

    # Step 4
    progress_step 4 "设置Redis密码..."
    set_redis_password
    progress_success "密码设置完成"
    echo ""

    # Step 5
    progress_step 5 "安装Redis..."
    if [[ $PKG_MANAGER == "yum" ]]; then
        progress_status "使用 yum 进行安装..."
        install_redis_yum
    else
        progress_status "使用 apt 进行安装..."
        install_redis_apt
    fi
    progress_success "Redis安装完成"
    echo ""

    # Step 6
    progress_step 6 "配置Redis参数..."
    configure_redis
    configure_firewall
    progress_success "Redis配置完成"
    echo ""

    # Step 7
    progress_step 7 "验证安装..."
    start_service
    verify_installation
    progress_success "安装验证完成"
    echo ""

    progress_complete
    generate_report
}

# 执行主函数
main
