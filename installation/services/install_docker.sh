#!/bin/bash

################################################################################
# Docker 自动安装脚本 v2.0.0
# 支持系统: CentOS/RHEL 7+, Ubuntu 18.04+, Kylin Linux
# 功能: 系统检测、Docker CE 安装、Docker Compose、国内镜像加速、网络检查、安装存档
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
    echo "║         Docker 自动安装脚本 v2.0.0                       ║"
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
    for host in "mirrors.aliyun.com" "download.docker.com" "8.8.8.8"; do
        if ping -c 1 -W 3 "$host" &>/dev/null 2>&1; then
            connected=1; break
        fi
    done
    if [[ $connected -eq 0 ]]; then
        log_warn "网络连通性检测失败，Docker 安装包下载可能受影响"
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
        apt-get install -y ca-certificates curl gnupg lsb-release
    else
        yum install -y curl yum-utils device-mapper-persistent-data lvm2 2>/dev/null || true
    fi
    log_success "前置依赖安装完成"
}

install_docker() {
    log_info "安装 Docker..."

    if command -v docker &>/dev/null; then
        log_warn "Docker 已安装，跳过安装步骤"
        return 0
    fi

    if [[ "$PKG_MGR" == "apt" ]]; then
        _install_docker_apt
    else
        _install_docker_yum
    fi
}

_install_docker_apt() {
    log_info "配置 Docker apt 仓库..."
    mkdir -p /etc/apt/keyrings

    # 尝试官方源，失败则使用阿里云镜像
    if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null; then
        curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg \
            | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
    fi
    chmod a+r /etc/apt/keyrings/docker.gpg

    local UBUNTU_CODENAME
    UBUNTU_CODENAME=$(lsb_release -cs 2>/dev/null || echo "focal")

    # 使用阿里云 Docker 镜像源（国内速度更快）
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $UBUNTU_CODENAME stable" \
        | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -qq
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    log_success "Docker CE 安装完成（apt）"
}

_install_docker_yum() {
    log_info "配置 Docker yum 仓库..."

    # 使用阿里云 Docker 镜像源
    yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo 2>/dev/null || \
    cat > /etc/yum.repos.d/docker-ce.repo <<'EOF'
[docker-ce-stable]
name=Docker CE Stable - $basearch
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/$releasever/$basearch/stable
enabled=1
gpgcheck=0
EOF

    yum makecache fast 2>/dev/null || yum makecache 2>/dev/null || true
    yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || \
        yum install -y docker 2>/dev/null || true
    log_success "Docker CE 安装完成（yum）"
}

install_compose() {
    log_info "检查 Docker Compose..."

    if docker compose version &>/dev/null 2>&1; then
        log_success "Docker Compose plugin 已安装"
        return 0
    fi

    log_info "安装 Docker Compose 独立版本..."
    local COMPOSE_VERSION="v2.24.5"

    local COMPOSE_URLS=(
        "https://mirror.ghproxy.com/https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)"
        "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)"
    )

    local download_success=0
    for url in "${COMPOSE_URLS[@]}"; do
        if curl -fsSL -m 120 -o /usr/local/bin/docker-compose "$url" 2>/dev/null; then
            download_success=1; break
        fi
    done

    if [[ $download_success -eq 1 ]]; then
        chmod +x /usr/local/bin/docker-compose
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
        log_success "Docker Compose $COMPOSE_VERSION 安装完成"
    else
        log_warn "Docker Compose 独立版本下载失败，请手动安装"
    fi
}

configure_mirror() {
    log_info "配置 Docker 国内镜像加速..."
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
    log_success "Docker 镜像加速配置完成（13个国内镜像源）"
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
        systemctl status docker --no-pager
        exit 1
    fi
}

verify() {
    log_info "验证 Docker 安装..."
    local DOCKER_VERSION
    DOCKER_VERSION=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
    log_success "Docker 版本: $DOCKER_VERSION"

    local COMPOSE_VER="未安装"
    if docker compose version &>/dev/null 2>&1; then
        COMPOSE_VER=$(docker compose version 2>/dev/null | awk '{print $NF}')
        log_success "Docker Compose: $COMPOSE_VER"
    elif command -v docker-compose &>/dev/null; then
        COMPOSE_VER=$(docker-compose --version 2>/dev/null | awk '{print $3}' | tr -d ',')
        log_success "Docker Compose (standalone): $COMPOSE_VER"
    fi

    if docker run --rm hello-world &>/dev/null 2>&1; then
        log_success "Docker 运行测试通过"
    else
        log_warn "Docker hello-world 测试跳过（可能需要网络）"
    fi
}

save_config() {
    log_info "保存安装配置存档..."
    mkdir -p /etc/ant-eyes
    local OS_NAME
    OS_NAME=$(grep "^PRETTY_NAME" /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "$OS_TYPE")
    local DOCKER_VERSION
    DOCKER_VERSION=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',' || echo "unknown")
    local COMPOSE_VERSION="unknown"
    if docker compose version &>/dev/null 2>&1; then
        COMPOSE_VERSION=$(docker compose version 2>/dev/null | awk '{print $NF}')
    elif command -v docker-compose &>/dev/null; then
        COMPOSE_VERSION=$(docker-compose --version 2>/dev/null | awk '{print $3}' | tr -d ',')
    fi

    cat > /etc/ant-eyes/docker.conf <<EOF
# Docker 安装信息
# 安装时间: $(date '+%Y-%m-%d %H:%M:%S')
# 安装系统: $OS_NAME
# ----------------------------------------
DOCKER_VERSION=$DOCKER_VERSION
COMPOSE_VERSION=$COMPOSE_VERSION
DAEMON_JSON=/etc/docker/daemon.json
MIRROR_COUNT=13
SERVICE_NAME=docker
EOF

    chmod 644 /etc/ant-eyes/docker.conf
    log_success "配置存档已保存至: /etc/ant-eyes/docker.conf"
}

main() {
    print_header
    check_root
    detect_os
    check_network
    install_deps
    configure_pkg_source
    install_docker
    install_compose
    configure_mirror
    start_service
    verify
    save_config

    echo ""
    log_success "Docker 安装完成！"
    echo ""
    echo -e "${YELLOW}常用命令:${NC}"
    echo "  docker ps                   # 查看运行中的容器"
    echo "  docker images               # 查看本地镜像"
    echo "  docker compose up -d        # 启动 compose 服务"
    echo ""
    echo -e "${YELLOW}配置存档:${NC} /etc/ant-eyes/docker.conf"
    echo ""
}

main
