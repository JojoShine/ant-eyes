#!/bin/bash

################################################################################
# Nginx 自动安装脚本 - Kylin Linux
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
    echo "║     Nginx 自动安装脚本 v1.0.0 (Kylin Linux)            ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        exit 1
    fi
}

install_nginx() {
    log_info "安装 Nginx..."
    apt-get update -qq
    apt-get install -y nginx
    log_success "Nginx 安装完成"
}

configure_nginx() {
    log_info "配置 Nginx..."
    mkdir -p /etc/nginx/conf.d

    # 测试配置
    if nginx -t &> /dev/null; then
        log_success "Nginx 配置验证通过"
    else
        log_error "Nginx 配置验证失败"
        nginx -t
        exit 1
    fi
}

configure_firewall() {
    log_info "配置防火墙规则..."

    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            ufw allow 80/tcp
            ufw allow 443/tcp
            log_success "防火墙规则已添加"
        fi
    fi
}

start_service() {
    log_info "启动 Nginx 服务..."
    systemctl daemon-reload
    systemctl enable nginx
    systemctl start nginx

    sleep 2

    if systemctl is-active --quiet nginx; then
        log_success "Nginx 服务启动成功"
    else
        log_error "Nginx 服务启动失败"
        systemctl status nginx --no-pager
        exit 1
    fi
}

verify() {
    log_info "验证 Nginx 安装..."
    NGINX_VERSION=$(nginx -v 2>&1 | cut -d'/' -f2)
    log_success "Nginx 版本: $NGINX_VERSION"

    if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|301\|302"; then
        log_success "HTTP 服务正常"
    else
        log_warn "HTTP 服务响应异常"
    fi
}

main() {
    print_header
    check_root
    install_nginx
    configure_nginx
    configure_firewall
    start_service
    verify

    echo ""
    log_success "Nginx 安装完成！"
}

main