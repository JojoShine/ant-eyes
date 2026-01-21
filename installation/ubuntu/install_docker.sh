#!/bin/bash

################################################################################
# Docker 自动安装脚本 - Ubuntu 18.04+
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
    echo "║     Docker 自动安装脚本 v1.0.0 (Ubuntu 18.04+)         ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        exit 1
    fi
}

install_dependencies() {
    log_info "安装依赖项..."
    apt-get update -qq
    apt-get install -y ca-certificates curl gnupg lsb-release
    log_success "依赖项安装完成"
}

configure_docker_repo() {
    log_info "配置 Docker 官方仓库..."

    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -qq
    log_success "Docker 仓库配置完成"
}

install_docker() {
    log_info "安装 Docker..."
    apt-get install -y docker-ce docker-ce-cli containerd.io
    log_success "Docker 安装完成"
}

install_compose() {
    log_info "检查 Docker Compose..."

    if docker compose version &> /dev/null; then
        log_success "Docker Compose 已通过 plugin 安装"
        return 0
    fi

    log_info "安装 Docker Compose 独立版本..."
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4 || echo "v2.20.0")

    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose 2>/dev/null || {
        curl -L "https://mirror.ghproxy.com/https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose 2>/dev/null || return 0
    }

    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
    log_success "Docker Compose 安装完成"
}

configure_mirror() {
    log_info "配置 Docker 镜像源..."
    mkdir -p /etc/docker

    cat > /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://dockerhub.azk8s.cn",
    "https://mirror.baidubce.com",
    "https://ccr.ccs.tencentyun.com",
    "https://docker.m.daocloud.io",
    "https://dockerproxy.com",
    "https://mirror.ccs.tencentyun.com",
    "https://reg-mirror.qiniu.com",
    "https://registry.docker-cn.com",
    "https://docker.nju.edu.cn",
    "https://mirror.iscas.ac.cn",
    "https://docker.mirrors.sjtug.sjtu.edu.cn"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true
}
EOF
    log_success "Docker 镜像源配置完成"
}

start_service() {
    log_info "启动 Docker 服务..."
    systemctl daemon-reload
    systemctl enable docker
    systemctl start docker

    sleep 2

    if systemctl is-active --quiet docker; then
        log_success "Docker 服务启动成功"
    else
        log_error "Docker 服务启动失败"
        exit 1
    fi
}

verify() {
    log_info "验证安装..."
    docker --version
    docker compose version 2>/dev/null || docker-compose --version 2>/dev/null || true
    log_success "Docker 安装验证完成"
}

main() {
    print_header
    check_root
    install_dependencies
    configure_docker_repo
    install_docker
    install_compose
    configure_mirror
    start_service
    verify

    echo ""
    log_success "Docker 安装完成！"
}

main
