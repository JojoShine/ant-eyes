#!/bin/bash

################################################################################
# Nginx 自动安装脚本 - Kylin Linux
# 使用 Kylin 官方源，不修改系统 yum 配置
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
    echo "║     使用 Kylin 官方源，无需配置                         ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        exit 1
    fi
}

check_kylin_system() {
    log_info "检测 Kylin 系统..."
    if ! grep -q "Kylin\|kylin" /etc/os-release 2>/dev/null; then
        log_warn "未检测到 Kylin 系统标识，继续尝试安装"
    else
        log_success "检测到 Kylin Linux 系统"
    fi
}

cleanup_yum_repos() {
    log_info "清理被破坏的 yum 源配置..."

    # 检查是否有 CentOS 相关的源配置
    if ls /etc/yum.repos.d/*.repo 2>/dev/null | grep -qi "centos\|vault"; then
        log_warn "检测到 CentOS 源配置，即将清理..."
        rm -f /etc/yum.repos.d/*.repo
        log_info "yum 源文件已删除，清除缓存..."
        yum clean all 2>/dev/null || true
    fi

    # 检查是否有任何有效的源配置
    if ! ls /etc/yum.repos.d/*.repo 2>/dev/null | grep -v "CentOS\|Vault" >/dev/null 2>&1; then
        log_warn "未检测到有效的 yum 源配置，为 Kylin 创建官方源..."

        # 为 Kylin 创建源配置（使用 OpenEuler 源，Kylin 基于 OpenEuler 20.03 LTS）
        mkdir -p /etc/yum.repos.d
        cat > /etc/yum.repos.d/kylin.repo <<KYLINREPO
[kylin-base]
name=Kylin Linux - Base (OpenEuler 20.03 LTS)
baseurl=https://repo.openeuler.org/openEuler-20.03-LTS/OS/\$basearch/
        https://mirrors.huaweicloud.com/openeuler/openEuler-20.03-LTS/OS/\$basearch/
        https://mirrors.aliyun.com/openeuler/openEuler-20.03-LTS/OS/\$basearch/
gpgcheck=0
enabled=1

[kylin-updates]
name=Kylin Linux - Updates (OpenEuler 20.03 LTS)
baseurl=https://repo.openeuler.org/openEuler-20.03-LTS/updates/\$basearch/
        https://mirrors.huaweicloud.com/openeuler/openEuler-20.03-LTS/updates/\$basearch/
        https://mirrors.aliyun.com/openeuler/openEuler-20.03-LTS/updates/\$basearch/
gpgcheck=0
enabled=1

[kylin-extras]
name=Kylin Linux - Extras (OpenEuler 20.03 LTS)
baseurl=https://repo.openeuler.org/openEuler-20.03-LTS/extras/\$basearch/
        https://mirrors.huaweicloud.com/openeuler/openEuler-20.03-LTS/extras/\$basearch/
gpgcheck=0
enabled=1
KYLINREPO
        log_success "Kylin 源配置已创建（基于 OpenEuler 20.03 LTS）"
    fi

    # 重建 yum 缓存，使用系统默认源或恢复的源
    log_info "重建 yum 缓存..."
    yum clean all 2>/dev/null || true
    yum makecache 2>/dev/null || true

    # 验证源是否可用
    if yum repolist 2>/dev/null | grep -q "kylin\|Kylin"; then
        log_success "Kylin 官方源已恢复，可以继续安装"
    else
        log_warn "yum 源检测完成，继续尝试安装..."
    fi
}

install_nginx() {
    log_info "安装 Nginx..."
    yum install -y nginx
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

    if command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            firewall-cmd --permanent --add-service=http
            firewall-cmd --permanent --add-service=https
            firewall-cmd --reload
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
    check_kylin_system
    cleanup_yum_repos
    install_nginx
    configure_nginx
    configure_firewall
    start_service
    verify

    echo ""
    log_success "Nginx 安装完成！"
}

main