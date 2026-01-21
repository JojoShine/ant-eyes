#!/bin/bash

################################################################################
# Redis 自动安装脚本 - Ubuntu 18.04+
# 完全独立，无外部依赖
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║     Redis 自动安装脚本 v1.0.0 (Ubuntu 18.04+)           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        exit 1
    fi
}

install_redis() {
    log_info "安装 Redis..."
    apt-get update -qq
    apt-get install -y redis-server
    log_success "Redis 安装完成"
}

configure_redis() {
    log_info "配置 Redis..."

    if [[ -f /etc/redis/redis.conf ]]; then
        cp /etc/redis/redis.conf /etc/redis/redis.conf.bak.$(date +%Y%m%d_%H%M%S)

        # 配置 requirepass（设置空密码，可以自行修改）
        sed -i 's/^# requirepass foobared/requirepass foobared/' /etc/redis/redis.conf || true
    fi

    log_success "Redis 配置完成"
}

start_service() {
    log_info "启动 Redis 服务..."
    systemctl daemon-reload
    systemctl enable redis-server
    systemctl start redis-server

    sleep 2

    if systemctl is-active --quiet redis-server; then
        log_success "Redis 服务启动成功"
    else
        log_error "Redis 服务启动失败"
        exit 1
    fi
}

verify() {
    log_info "验证 Redis 安装..."
    REDIS_VERSION=$(redis-server --version | awk '{print $3}' | cut -d'=' -f2)
    log_success "Redis 版本: $REDIS_VERSION"

    if redis-cli ping | grep -q "PONG"; then
        log_success "Redis 连接测试通过"
    else
        log_warn "Redis 连接测试失败"
    fi
}

main() {
    print_header
    check_root
    install_redis
    configure_redis
    start_service
    verify

    echo ""
    log_success "Redis 安装完成！"
}

main