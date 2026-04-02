#!/bin/bash

################################################################################
# Redis 自动安装脚本 v2.0.0
# 支持系统: CentOS/RHEL 7+, Ubuntu 18.04+, Kylin Linux
# 功能: 系统检测、鉴权配置、网络检查、安装存档
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 全局变量
OS_TYPE=""
PKG_MGR=""
REDIS_PORT="6379"
REDIS_PASSWORD=""
REDIS_CONF=""
REDIS_SERVICE=""

# 日志函数
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         Redis 自动安装脚本 v2.0.0                        ║"
    echo "║         支持: CentOS / Ubuntu / Kylin                    ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        exit 1
    fi
}

detect_os() {
    log_info "检测操作系统..."
    if grep -qi "kylin" /etc/os-release 2>/dev/null; then
        OS_TYPE="kylin"
        PKG_MGR="yum"
    elif grep -qi "centos\|rhel\|red hat" /etc/os-release 2>/dev/null; then
        OS_TYPE="centos"
        PKG_MGR="yum"
    elif grep -qi "ubuntu\|debian" /etc/os-release 2>/dev/null; then
        OS_TYPE="ubuntu"
        PKG_MGR="apt"
    else
        log_warn "未识别的操作系统，尝试自动探测包管理器..."
        if command -v yum &>/dev/null; then
            OS_TYPE="centos"
            PKG_MGR="yum"
        else
            OS_TYPE="ubuntu"
            PKG_MGR="apt"
        fi
    fi
    log_success "操作系统: $OS_TYPE，包管理器: $PKG_MGR"
}

check_network() {
    log_info "检测网络连通性..."
    local test_hosts=("mirrors.aliyun.com" "mirrors.tuna.tsinghua.edu.cn" "8.8.8.8")
    local connected=0
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 3 "$host" &>/dev/null 2>&1; then
            connected=1
            break
        fi
    done
    if [[ $connected -eq 0 ]]; then
        log_warn "网络连通性检测失败，包下载可能受影响"
        log_warn "请确认服务器网络配置后再继续"
        read -p "是否仍然继续安装? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log_success "网络连通性正常"
    fi
}

configure_pkg_source() {
    if [[ "$PKG_MGR" == "yum" ]]; then
        if [[ "$OS_TYPE" == "kylin" ]]; then
            _setup_kylin_repo
        else
            _setup_centos_repo
        fi
    fi
}

_setup_centos_repo() {
    log_info "配置 CentOS yum 镜像源..."
    mkdir -p /etc/yum.repos.d.bak
    mv /etc/yum.repos.d/*.repo /etc/yum.repos.d.bak/ 2>/dev/null || true
    local OS_VERSION
    OS_VERSION=$(rpm -E %rhel 2>/dev/null || echo "7")
    if [[ "$OS_VERSION" == "7" ]]; then
        cat > /etc/yum.repos.d/CentOS-Base.repo <<'EOF'
[base]
name=CentOS-$releasever - Base - Aliyun Mirror
baseurl=https://mirrors.aliyun.com/centos/$releasever/os/$basearch/
        https://mirrors.tuna.tsinghua.edu.cn/centos/$releasever/os/$basearch/
gpgcheck=0

[updates]
name=CentOS-$releasever - Updates - Aliyun Mirror
baseurl=https://mirrors.aliyun.com/centos/$releasever/updates/$basearch/
        https://mirrors.tuna.tsinghua.edu.cn/centos/$releasever/updates/$basearch/
gpgcheck=0

[extras]
name=CentOS-$releasever - Extras - Aliyun Mirror
baseurl=https://mirrors.aliyun.com/centos/$releasever/extras/$basearch/
        https://mirrors.tuna.tsinghua.edu.cn/centos/$releasever/extras/$basearch/
gpgcheck=0
EOF
    else
        cat > /etc/yum.repos.d/CentOS-Base.repo <<'EOF'
[base]
name=CentOS-$releasever - Base
baseurl=https://mirrors.aliyun.com/centos-vault/$releasever/os/$basearch/
        https://mirrors.tuna.tsinghua.edu.cn/centos-vault/$releasever/os/$basearch/
gpgcheck=0

[updates]
name=CentOS-$releasever - Updates
baseurl=https://mirrors.aliyun.com/centos-vault/$releasever/updates/$basearch/
        https://mirrors.tuna.tsinghua.edu.cn/centos-vault/$releasever/updates/$basearch/
gpgcheck=0
EOF
    fi
    yum clean all 2>/dev/null || true
    yum makecache fast 2>/dev/null || yum makecache 2>/dev/null || true
    log_success "yum 源配置完成"
}

_setup_kylin_repo() {
    log_info "检测 Kylin yum 源配置..."
    if ls /etc/yum.repos.d/*.repo 2>/dev/null | grep -qi "centos\|vault"; then
        log_warn "检测到 CentOS 源配置，清理中..."
        rm -f /etc/yum.repos.d/*.repo
        yum clean all 2>/dev/null || true
    fi
    if ! ls /etc/yum.repos.d/*.repo 2>/dev/null | grep -qiv "centos\|vault"; then
        mkdir -p /etc/yum.repos.d
        cat > /etc/yum.repos.d/kylin.repo <<'EOF'
[kylin-base]
name=Kylin Linux - Base
baseurl=https://repo.openeuler.org/openEuler-20.03-LTS/OS/$basearch/
        https://mirrors.huaweicloud.com/openeuler/openEuler-20.03-LTS/OS/$basearch/
        https://mirrors.aliyun.com/openeuler/openEuler-20.03-LTS/OS/$basearch/
gpgcheck=0
enabled=1

[kylin-updates]
name=Kylin Linux - Updates
baseurl=https://repo.openeuler.org/openEuler-20.03-LTS/updates/$basearch/
        https://mirrors.huaweicloud.com/openeuler/openEuler-20.03-LTS/updates/$basearch/
gpgcheck=0
enabled=1
EOF
        log_success "Kylin 源配置已创建"
    fi
    yum clean all 2>/dev/null || true
    yum makecache 2>/dev/null || true
}

install_deps() {
    log_info "安装前置依赖..."
    if [[ "$PKG_MGR" == "apt" ]]; then
        apt-get update -qq
        apt-get install -y curl 2>/dev/null || true
    else
        yum install -y curl 2>/dev/null || true
    fi
    log_success "前置依赖检查完成"
}

prompt_config() {
    log_info "配置 Redis 安装参数..."
    echo ""

    # 端口
    read -p "请输入 Redis 监听端口 [默认: 6379]: " input_port
    if [[ -n "$input_port" ]]; then
        REDIS_PORT="$input_port"
    fi

    # 密码（强制非空）
    while true; do
        read -s -p "请输入 Redis 认证密码（必填，不少于6位）: " input_pass
        echo
        if [[ ${#input_pass} -ge 6 ]]; then
            read -s -p "请再次输入密码确认: " input_pass2
            echo
            if [[ "$input_pass" == "$input_pass2" ]]; then
                REDIS_PASSWORD="$input_pass"
                break
            else
                log_warn "两次输入的密码不一致，请重新输入"
            fi
        else
            log_warn "密码不能少于 6 位，请重新输入"
        fi
    done

    log_success "配置参数已确认: 端口=$REDIS_PORT"
    echo ""
}

install_redis() {
    log_info "安装 Redis..."
    if command -v redis-server &>/dev/null; then
        log_warn "Redis 已安装，跳过安装步骤"
        return 0
    fi
    if [[ "$PKG_MGR" == "apt" ]]; then
        apt-get update -qq
        apt-get install -y redis-server
    else
        yum install -y redis
    fi
    log_success "Redis 安装完成"
}

configure_redis() {
    log_info "配置 Redis..."

    # 确定配置文件路径
    if [[ -f /etc/redis/redis.conf ]]; then
        REDIS_CONF="/etc/redis/redis.conf"
        REDIS_SERVICE="redis-server"
    elif [[ -f /etc/redis.conf ]]; then
        REDIS_CONF="/etc/redis.conf"
        REDIS_SERVICE="redis"
    else
        log_error "未找到 Redis 配置文件"
        exit 1
    fi

    cp "$REDIS_CONF" "${REDIS_CONF}.bak.$(date +%Y%m%d_%H%M%S)"

    # 设置密码
    if grep -q "^requirepass" "$REDIS_CONF"; then
        sed -i "s|^requirepass .*|requirepass $REDIS_PASSWORD|" "$REDIS_CONF"
    elif grep -q "^# requirepass" "$REDIS_CONF"; then
        sed -i "s|^# requirepass .*|requirepass $REDIS_PASSWORD|" "$REDIS_CONF"
    else
        echo "requirepass $REDIS_PASSWORD" >> "$REDIS_CONF"
    fi

    # 设置端口
    sed -i "s|^port .*|port $REDIS_PORT|" "$REDIS_CONF"

    # 绑定地址（允许所有接口，由密码保护）
    sed -i "s|^bind 127.0.0.1.*|bind 0.0.0.0|" "$REDIS_CONF" || true

    log_success "Redis 配置完成"
}

start_service() {
    log_info "启动 Redis 服务..."
    systemctl daemon-reload
    systemctl enable "$REDIS_SERVICE"
    systemctl start "$REDIS_SERVICE"
    sleep 2
    if systemctl is-active --quiet "$REDIS_SERVICE"; then
        log_success "Redis 服务启动成功"
    else
        log_error "Redis 服务启动失败"
        systemctl status "$REDIS_SERVICE" --no-pager
        exit 1
    fi
}

verify() {
    log_info "验证 Redis 安装..."
    REDIS_VERSION=$(redis-server --version | awk '{print $3}' | cut -d'=' -f2)
    log_success "Redis 版本: $REDIS_VERSION"

    if redis-cli -p "$REDIS_PORT" -a "$REDIS_PASSWORD" ping 2>/dev/null | grep -q "PONG"; then
        log_success "Redis 连接测试通过（带鉴权）"
    else
        log_warn "Redis 连接测试失败，请检查密码和端口配置"
    fi
}

save_config() {
    log_info "保存安装配置存档..."
    mkdir -p /etc/ant-eyes
    local OS_NAME
    OS_NAME=$(grep "^PRETTY_NAME" /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "$OS_TYPE")
    local REDIS_VERSION
    REDIS_VERSION=$(redis-server --version | awk '{print $3}' | cut -d'=' -f2 2>/dev/null || echo "unknown")

    cat > /etc/ant-eyes/redis.conf <<EOF
# Redis 安装信息
# 安装时间: $(date '+%Y-%m-%d %H:%M:%S')
# 安装系统: $OS_NAME
# ----------------------------------------
SERVICE_VERSION=$REDIS_VERSION
SERVICE_PORT=$REDIS_PORT
SERVICE_AUTH_PASS=$REDIS_PASSWORD
CONFIG_FILE=$REDIS_CONF
DATA_DIR=/var/lib/redis
SERVICE_NAME=$REDIS_SERVICE
EOF

    chmod 600 /etc/ant-eyes/redis.conf
    log_success "配置存档已保存至: /etc/ant-eyes/redis.conf"
}

main() {
    print_header
    check_root
    detect_os
    check_network
    install_deps
    configure_pkg_source
    prompt_config
    install_redis
    configure_redis
    start_service
    verify
    save_config

    echo ""
    log_success "Redis 安装完成！"
    echo ""
    echo -e "${YELLOW}连接信息:${NC}"
    echo "  redis-cli -p $REDIS_PORT -a '<密码>'"
    echo ""
    echo -e "${YELLOW}配置存档:${NC} /etc/ant-eyes/redis.conf"
    echo ""
}

main
