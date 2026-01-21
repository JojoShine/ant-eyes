#!/bin/bash

################################################################################
# PostgreSQL 自动安装脚本 - Ubuntu 18.04+
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
    echo "║     PostgreSQL 自动安装脚本 v1.0.0 (Ubuntu 18.04+)     ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        exit 1
    fi
}

install_postgresql() {
    log_info "安装 PostgreSQL..."
    apt-get update -qq
    apt-get install -y postgresql postgresql-contrib
    log_success "PostgreSQL 安装完成"
}

configure_postgresql() {
    log_info "配置 PostgreSQL..."
    mkdir -p /var/lib/postgresql/data
    chown postgres:postgres /var/lib/postgresql/data
    chmod 700 /var/lib/postgresql/data
    log_success "PostgreSQL 配置完成"
}

start_service() {
    log_info "启动 PostgreSQL 服务..."
    systemctl daemon-reload
    systemctl enable postgresql
    systemctl start postgresql

    sleep 2

    if systemctl is-active --quiet postgresql; then
        log_success "PostgreSQL 服务启动成功"
    else
        log_error "PostgreSQL 服务启动失败"
        exit 1
    fi
}

verify() {
    log_info "验证 PostgreSQL 安装..."
    POSTGRES_VERSION=$(postgres --version)
    log_success "$POSTGRES_VERSION"

    if sudo -u postgres psql -c "SELECT 1;" &>/dev/null; then
        log_success "PostgreSQL 连接测试通过"
    else
        log_warn "PostgreSQL 连接测试失败"
    fi
}

main() {
    print_header
    check_root
    install_postgresql
    configure_postgresql
    start_service
    verify

    echo ""
    log_success "PostgreSQL 安装完成！"
}

main