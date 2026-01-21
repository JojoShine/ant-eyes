#!/bin/bash

################################################################################
# MySQL 自动安装脚本 - Ubuntu 18.04+
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
    echo "║     MySQL 自动安装脚本 v1.0.0 (Ubuntu 18.04+)          ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        exit 1
    fi
}

install_mysql() {
    log_info "安装 MySQL..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y mysql-server mysql-client
    log_success "MySQL 安装完成"
}

configure_mysql() {
    log_info "配置 MySQL..."
    mkdir -p /etc/mysql/conf.d

    cat > /etc/mysql/conf.d/custom.cnf <<'EOF'
[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
init_connect = 'SET NAMES utf8mb4'
bind-address = 127.0.0.1
max_connections = 500

[client]
default-character-set = utf8mb4
EOF

    log_success "MySQL 配置完成"
}

start_service() {
    log_info "启动 MySQL 服务..."
    systemctl daemon-reload
    systemctl enable mysql
    systemctl start mysql

    sleep 2

    if systemctl is-active --quiet mysql; then
        log_success "MySQL 服务启动成功"
    else
        log_error "MySQL 服务启动失败"
        exit 1
    fi
}

verify() {
    log_info "验证 MySQL 安装..."
    MYSQL_VERSION=$(mysql -V | awk '{print $5}' | cut -d',' -f1)
    log_success "MySQL 版本: $MYSQL_VERSION"

    if mysql -e "SELECT 1;" &>/dev/null; then
        log_success "MySQL 连接测试通过"
    else
        log_warn "MySQL 连接测试失败"
    fi
}

main() {
    print_header
    check_root
    install_mysql
    configure_mysql
    start_service
    verify

    echo ""
    log_success "MySQL 安装完成！"
}

main