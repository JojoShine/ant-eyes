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
    DATA_DIR="/data/mongodb"
    LOG_DIR="/data/mongodb/log"
    mkdir -p "$DATA_DIR" "$LOG_DIR"
    chown -R mongodb:mongodb "$DATA_DIR" "$LOG_DIR"
    chmod 750 "$DATA_DIR"

    # 配置 MongoDB
    if [[ -f /etc/mongodb.conf ]]; then
        cp /etc/mongodb.conf /etc/mongodb.conf.bak.$(date +%Y%m%d_%H%M%S)

        # 修改数据目录和日志目录
        sed -i "s|dbpath=.*|dbpath=$DATA_DIR|" /etc/mongodb.conf
        sed -i "s|logpath=.*|logpath=$LOG_DIR/mongodb.log|" /etc/mongodb.conf

        # 配置 bind_ip 允许远程访问
        sed -i 's/bind_ip = 127.0.0.1/bind_ip = 0.0.0.0/' /etc/mongodb.conf
    fi

    log_success "MongoDB 配置完成"
}

configure_firewall() {
    log_info "配置防火墙..."

    # 检查 ufw 是否安装
    if command -v ufw &> /dev/null; then
        ufw allow 27017/tcp
        log_success "防火墙规则已添加（端口 27017）"
    else
        log_warn "ufw 未安装，跳过防火墙配置"
    fi
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
    configure_firewall
    start_service
    verify

    echo ""
    log_success "MongoDB 安装完成！"
    log_info "数据目录: /data/mongodb"
    log_info "远程访问已启用，端口: 27017"
}

main