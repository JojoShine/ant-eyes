#!/bin/bash

################################################################################
# Nginx 自动安装脚本 v2.0.0
# 支持系统: CentOS/RHEL 7+, Ubuntu 18.04+, Kylin Linux
# 功能: 系统检测、防火墙配置、网络检查、安装存档
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

OS_TYPE=""
PKG_MGR=""

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         Nginx 自动安装脚本 v2.0.0                        ║"
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
        OS_TYPE="kylin"; PKG_MGR="yum"
    elif grep -qi "centos\|rhel\|red hat" /etc/os-release 2>/dev/null; then
        OS_TYPE="centos"; PKG_MGR="yum"
    elif grep -qi "ubuntu\|debian" /etc/os-release 2>/dev/null; then
        OS_TYPE="ubuntu"; PKG_MGR="apt"
    else
        log_warn "未识别的操作系统，尝试自动探测..."
        if command -v yum &>/dev/null; then
            OS_TYPE="centos"; PKG_MGR="yum"
        else
            OS_TYPE="ubuntu"; PKG_MGR="apt"
        fi
    fi
    log_success "操作系统: $OS_TYPE，包管理器: $PKG_MGR"
}

check_network() {
    log_info "检测网络连通性..."
    local connected=0
    for host in "mirrors.aliyun.com" "mirrors.tuna.tsinghua.edu.cn" "8.8.8.8"; do
        if ping -c 1 -W 3 "$host" &>/dev/null 2>&1; then
            connected=1; break
        fi
    done
    if [[ $connected -eq 0 ]]; then
        log_warn "网络连通性检测失败，包下载可能受影响"
        read -p "是否仍然继续安装? (y/n): " -n 1 -r; echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    else
        log_success "网络连通性正常"
    fi
}

configure_pkg_source() {
    if [[ "$PKG_MGR" == "yum" ]]; then
        [[ "$OS_TYPE" == "kylin" ]] && _setup_kylin_repo || _setup_centos_repo
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

install_nginx() {
    log_info "安装 Nginx..."
    if command -v nginx &>/dev/null; then
        log_warn "Nginx 已安装，跳过安装步骤"
        return 0
    fi

    if [[ "$PKG_MGR" == "apt" ]]; then
        apt-get update -qq
        apt-get install -y nginx
    else
        yum install -y nginx
    fi
    log_success "Nginx 安装完成"
}

configure_nginx() {
    log_info "配置 Nginx..."
    mkdir -p /etc/nginx/conf.d

    if nginx -t &>/dev/null; then
        log_success "Nginx 配置验证通过"
    else
        log_error "Nginx 配置验证失败"
        nginx -t
        exit 1
    fi
}

configure_firewall() {
    log_info "配置防火墙规则..."

    # firewalld（CentOS/Kylin）
    if command -v firewall-cmd &>/dev/null && systemctl is-active --quiet firewalld 2>/dev/null; then
        firewall-cmd --permanent --add-service=http 2>/dev/null || true
        firewall-cmd --permanent --add-service=https 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
        log_success "firewalld 规则已添加 (http/https)"
    fi

    # ufw（Ubuntu）
    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "active"; then
        ufw allow 'Nginx Full' 2>/dev/null || true
        log_success "UFW 规则已添加 (Nginx Full)"
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
    local NGINX_VERSION
    NGINX_VERSION=$(nginx -v 2>&1 | cut -d'/' -f2)
    log_success "Nginx 版本: $NGINX_VERSION"

    if curl -s -o /dev/null -w "%{http_code}" http://localhost 2>/dev/null | grep -q "200\|301\|302"; then
        log_success "HTTP 服务响应正常"
    else
        log_warn "HTTP 服务响应异常，请检查服务状态"
    fi
}

save_config() {
    log_info "保存安装配置存档..."
    mkdir -p /etc/ant-eyes
    local OS_NAME
    OS_NAME=$(grep "^PRETTY_NAME" /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "$OS_TYPE")
    local NGINX_VERSION
    NGINX_VERSION=$(nginx -v 2>&1 | cut -d'/' -f2 || echo "unknown")

    cat > /etc/ant-eyes/nginx.conf <<EOF
# Nginx 安装信息
# 安装时间: $(date '+%Y-%m-%d %H:%M:%S')
# 安装系统: $OS_NAME
# ----------------------------------------
SERVICE_VERSION=$NGINX_VERSION
HTTP_PORT=80
HTTPS_PORT=443
CONFIG_DIR=/etc/nginx
CONF_D_DIR=/etc/nginx/conf.d
LOG_DIR=/var/log/nginx
SERVICE_NAME=nginx
EOF

    chmod 644 /etc/ant-eyes/nginx.conf
    log_success "配置存档已保存至: /etc/ant-eyes/nginx.conf"
}

main() {
    print_header
    check_root
    detect_os
    check_network
    install_deps
    configure_pkg_source
    install_nginx
    configure_nginx
    configure_firewall
    start_service
    verify
    save_config

    echo ""
    log_success "Nginx 安装完成！"
    echo ""
    echo -e "${YELLOW}常用操作:${NC}"
    echo "  systemctl status nginx    # 查看状态"
    echo "  nginx -t                  # 测试配置"
    echo "  nginx -s reload           # 重载配置"
    echo ""
    echo -e "${YELLOW}配置存档:${NC} /etc/ant-eyes/nginx.conf"
    echo ""
}

main
