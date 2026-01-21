#!/bin/bash

################################################################################
# MongoDB 自动安装脚本 - Kylin Linux
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
    echo "║     MongoDB 自动安装脚本 v1.0.0 (Kylin Linux)          ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        exit 1
    fi
}

install_mongodb() {
    log_info "安装 MongoDB..."
    apt-get update -qq
    apt-get install -y mongodb-server mongodb
    log_success "MongoDB 安装完成"
}

configure_mongodb() {
    log_info "配置 MongoDB..."
    mkdir -p /var/lib/mongodb /var/log/mongodb
    chown -R mongodb:mongodb /var/lib/mongodb /var/log/mongodb
    log_success "MongoDB 配置完成"
}

start_service() {
    log_info "启动 MongoDB 服务..."
    systemctl daemon-reload
    systemctl enable mongodb
    systemctl start mongodb

    sleep 2

    if systemctl is-active --quiet mongodb; then
        log_success "MongoDB 服务启动成功"
    else
        log_error "MongoDB 服务启动失败"
        exit 1
    fi
}

verify() {
    log_info "验证 MongoDB 安装..."
    MONGO_VERSION=$(mongod --version | grep "db version" | awk '{print $3}')
    log_success "MongoDB 版本: $MONGO_VERSION"

    if mongo --eval "db.adminCommand('ping')" &>/dev/null; then
        log_success "MongoDB 连接测试通过"
    else
        log_warn "MongoDB 连接测试失败"
    fi
}

main() {
    print_header
    check_root
    install_mongodb
    configure_mongodb
    start_service
    verify

    echo ""
    log_success "MongoDB 安装完成！"
}

main