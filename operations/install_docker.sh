#!/bin/bash

################################################################################
# Docker 自动安装脚本
# 支持 CentOS/RHEL 7+, Ubuntu 18.04+, Rocky, AlmaLinux, UOS
# 功能:
#   - 卸载旧版本 Docker
#   - 安装 Docker CE 最新版
#   - 配置国内镜像加速
#   - 安装 Docker Compose
#   - 配置开机自启
#   - 验证安装
#
# 注意: 麒麟系统请使用 install_docker_kylin.sh
#
# 使用方法:
#   sudo bash install_docker.sh
#
# 作者: Shell Collections Team
# 版本: 1.0.0
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 导入进度显示库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/progress_lib.sh" ]]; then
    source "$SCRIPT_DIR/progress_lib.sh"
else
    # 如果找不到库文件，定义简单的进度函数
    progress_init() { :; }
    progress_step() { echo "→ $2"; }
    progress_complete() { echo "安装完成"; }
    progress_fail() { echo "错误: $1"; }
    progress_status() { echo "⟳ $1"; }
fi

# 导入前置依赖检查库
if [[ -f "$SCRIPT_DIR/dependencies_lib.sh" ]]; then
    source "$SCRIPT_DIR/dependencies_lib.sh"
    source "$SCRIPT_DIR/dependencies_config.sh"
fi



# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 打印标题
print_header() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║           Docker 自动安装脚本 v1.0.0                     ║"
    echo "║   Docker CE + Docker Compose 一键安装                     ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        log_info "请使用: sudo bash $0"
        exit 1
    fi
}

# 检测操作系统
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        OS_NAME=$NAME
    else
        log_error "无法检测操作系统类型"
        exit 1
    fi

    log_info "检测到操作系统: $OS_NAME ($OS_VERSION)"

    case $OS in
        centos|rhel|rocky|almalinux)
            PKG_MANAGER="yum"
            ;;
        ubuntu|debian|uos)
            PKG_MANAGER="apt"
            ;;
        kylin)
            log_error "检测到麒麟系统，请使用专用安装脚本: install_docker_kylin.sh"
            exit 1
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
}

# 检查是否已安装 Docker
check_docker_installed() {
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version 2>/dev/null || echo "unknown")
        log_warn "检测到已安装 Docker: $DOCKER_VERSION"
        read -p "是否卸载并重新安装? (y/n): " -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            return 1
        else
            log_info "保留现有 Docker 安装"
            exit 0
        fi
    fi
    return 0
}

# 卸载旧版本 Docker
remove_old_docker() {
    log_info "卸载旧版本 Docker..."

    if [[ $PKG_MANAGER == "yum" ]]; then
        yum remove -y docker \
            docker-client \
            docker-client-latest \
            docker-common \
            docker-latest \
            docker-latest-logrotate \
            docker-logrotate \
            docker-engine \
            podman \
            runc 2>/dev/null || true
    else
        apt-get remove -y docker \
            docker-engine \
            docker.io \
            containerd \
            runc 2>/dev/null || true
    fi

    log_success "旧版本 Docker 已卸载"
}

# 安装依赖包
install_dependencies() {
    log_info "安装依赖包..."

    if [[ $PKG_MANAGER == "yum" ]]; then
        # 麒麟系统可能没有yum-utils包,但yum-config-manager已内置
        # 尝试安装yum-utils,如果失败则检查yum-config-manager是否存在
        if ! yum install -y yum-utils 2>/dev/null; then
            log_warn "yum-utils包不可用,检查yum-config-manager..."
            if ! command -v yum-config-manager &> /dev/null; then
                log_error "yum-config-manager命令不可用,无法继续"
                exit 1
            else
                log_info "yum-config-manager已存在,跳过yum-utils安装"
            fi
        fi
        yum install -y device-mapper-persistent-data lvm2 curl wget
    else
        apt-get update -qq
        apt-get install -y ca-certificates curl gnupg lsb-release wget
    fi

    log_success "依赖包安装完成"
}

# 添加 Docker 官方仓库
add_docker_repo() {
    log_info "添加 Docker 官方仓库..."

    if [[ $PKG_MANAGER == "yum" ]]; then
        # 使用阿里云镜像源
        yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
        sed -i 's+download.docker.com+mirrors.aliyun.com/docker-ce+' /etc/yum.repos.d/docker-ce.repo
    else
        # 使用阿里云镜像源
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg

        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu \
          $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

        apt-get update -qq
    fi

    log_success "Docker 仓库添加完成"
}

# 安装 Docker CE
install_docker() {
    log_info "安装 Docker CE..."

    if [[ $PKG_MANAGER == "yum" ]]; then
        # 尝试安装最新版本
        if ! yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null; then
            log_warn "最新版本安装失败,可能是GLIBC版本不兼容"
            log_info "尝试安装兼容版本..."

            # 查询所有可用的Docker版本
            log_info "查询可用的Docker版本..."
            AVAILABLE_VERSIONS=$(yum list docker-ce --showduplicates 2>/dev/null | grep docker-ce | awk '{print $2}' | sort -V)

            if [[ -z "$AVAILABLE_VERSIONS" ]]; then
                log_error "无法查询到可用的Docker版本"
                log_error "请检查网络连接和yum源配置"
                exit 1
            fi

            # 显示可用版本
            echo "$AVAILABLE_VERSIONS" | head -10

            # 尝试按顺序安装兼容版本
            # 优先尝试: 20.10.x -> 19.03.x -> 18.09.x -> 任意可用版本
            INSTALLED=false

            for VERSION_PREFIX in "20.10" "19.03" "18.09" ""; do
                if [[ -n "$VERSION_PREFIX" ]]; then
                    TARGET_VERSION=$(echo "$AVAILABLE_VERSIONS" | grep "^${VERSION_PREFIX}" | tail -1)
                    if [[ -n "$TARGET_VERSION" ]]; then
                        log_info "尝试安装 Docker CE ${TARGET_VERSION}..."
                        if yum install -y docker-ce-${TARGET_VERSION} docker-ce-cli-${TARGET_VERSION} containerd.io --nobest 2>/dev/null; then
                            log_success "Docker CE ${TARGET_VERSION} 安装成功"
                            INSTALLED=true
                            break
                        fi
                    fi
                else
                    # 最后尝试: 安装任意可用的最旧版本
                    OLDEST_VERSION=$(echo "$AVAILABLE_VERSIONS" | head -1)
                    if [[ -n "$OLDEST_VERSION" ]]; then
                        log_warn "尝试安装最旧的可用版本: ${OLDEST_VERSION}..."
                        if yum install -y docker-ce-${OLDEST_VERSION} docker-ce-cli-${OLDEST_VERSION} containerd.io --nobest 2>/dev/null; then
                            log_success "Docker CE ${OLDEST_VERSION} 安装成功"
                            INSTALLED=true
                            break
                        fi
                    fi
                fi
            done

            if [[ "$INSTALLED" != "true" ]]; then
                log_error "无法找到兼容的Docker版本"
                log_error "系统GLIBC版本: $(ldd --version | head -1)"
                log_error "可用Docker版本:"
                echo "$AVAILABLE_VERSIONS" | head -5
                exit 1
            fi
        else
            log_success "Docker CE 最新版本安装完成"
        fi
    else
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        log_success "Docker CE 安装完成"
    fi
}

# 配置 Docker 镜像加速
configure_docker_mirror() {
    log_info "配置 Docker 镜像加速..."

    mkdir -p /etc/docker

    cat > /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com",
    "https://registry.docker-cn.com",
    "https://docker.mirrors.ustc.edu.cn"
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

    log_success "Docker 镜像加速配置完成"
}

# 启动 Docker 服务
start_docker() {
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

# 添加当前用户到 docker 组
add_user_to_docker_group() {
    if [[ -n "$SUDO_USER" ]]; then
        log_info "添加用户 $SUDO_USER 到 docker 组..."
        usermod -aG docker "$SUDO_USER"
        log_success "用户已添加到 docker 组 (需重新登录生效)"
    fi
}

# 安装 Docker Compose (standalone)
install_docker_compose() {
    log_info "检查 Docker Compose..."

    # 检查是否已安装 docker-compose-plugin
    if docker compose version &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version --short)
        log_success "Docker Compose Plugin 已安装: v$COMPOSE_VERSION"
        return 0
    fi

    # 安装 standalone docker-compose
    log_info "安装 Docker Compose standalone..."

    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)

    if [[ -z "$COMPOSE_VERSION" ]]; then
        COMPOSE_VERSION="v2.24.5"
        log_warn "无法获取最新版本，使用默认版本: $COMPOSE_VERSION"
    fi

    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose

    chmod +x /usr/local/bin/docker-compose

    # 创建软链接
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

    log_success "Docker Compose 安装完成: $COMPOSE_VERSION"
}

# 验证安装
verify_installation() {
    log_info "验证 Docker 安装..."

    # 验证 Docker 版本
    DOCKER_VERSION=$(docker --version)
    log_success "Docker 版本: $DOCKER_VERSION"

    # 验证 Docker Compose
    if docker compose version &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version)
        log_success "Docker Compose: $COMPOSE_VERSION"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose --version)
        log_success "Docker Compose: $COMPOSE_VERSION"
    fi

    # 运行测试容器
    log_info "运行测试容器 (hello-world)..."
    if docker run --rm hello-world &> /dev/null; then
        log_success "Docker 运行测试通过"
    else
        log_warn "Docker 测试容器运行失败，但 Docker 已安装"
    fi
}

# 生成安装报告
generate_report() {
    local REPORT_FILE="/tmp/install_docker_report_$(date +%Y%m%d_%H%M%S).txt"

    cat > "$REPORT_FILE" <<EOF
╔═══════════════════════════════════════════════════════════╗
║           Docker 安装报告                                 ║
╚═══════════════════════════════════════════════════════════╝

安装时间: $(date '+%Y-%m-%d %H:%M:%S')
操作系统: $OS_NAME ($OS_VERSION)

【安装版本】
$(docker --version)
$(docker compose version 2>/dev/null || docker-compose --version 2>/dev/null || echo "Docker Compose: 未安装")

【服务状态】
$(systemctl status docker --no-pager | head -n 3)

【配置文件】
- Docker 配置: /etc/docker/daemon.json
- 日志目录: /var/lib/docker

【管理命令】
启动服务:   systemctl start docker
停止服务:   systemctl stop docker
重启服务:   systemctl restart docker
查看状态:   systemctl status docker
查看日志:   journalctl -u docker -f

【常用命令】
查看镜像:   docker images
查看容器:   docker ps -a
拉取镜像:   docker pull <image>
运行容器:   docker run <image>
进入容器:   docker exec -it <container> bash

【Docker Compose 命令】
启动服务:   docker compose up -d
停止服务:   docker compose down
查看日志:   docker compose logs -f

【镜像加速】
已配置以下镜像源:
- 腾讯云: https://mirror.ccs.tencentyun.com
- Docker中国: https://registry.docker-cn.com
- 中科大: https://docker.mirrors.ustc.edu.cn

【注意事项】
1. 非 root 用户需要重新登录才能使用 docker 命令
2. 防火墙可能需要开放相关端口
3. 建议定期清理无用镜像和容器: docker system prune

【安装日志】
$REPORT_FILE

EOF

    log_success "安装报告已生成: $REPORT_FILE"

    # 显示摘要
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           Docker 安装完成!                                ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Docker 版本:${NC} $(docker --version)"
    echo -e "${BLUE}Compose 版本:${NC} $(docker compose version --short 2>/dev/null || docker-compose --version 2>/dev/null)"
    echo -e "${BLUE}服务状态:${NC} $(systemctl is-active docker)"
    echo ""
    echo -e "${YELLOW}提示:${NC} 非 root 用户请重新登录后使用 docker 命令"
    echo -e "${YELLOW}报告:${NC} $REPORT_FILE"
    echo ""
}

# 主函数
main() {
    print_header

    log_info "开始安装 Docker..."
    echo ""

    check_root
    detect_os


    # 检查前置依赖
    if command -v check_and_install_dependencies &>/dev/null; then
        log_info "检查前置依赖..."
        check_and_install_dependencies "Docker" "${DOCKER_DEPENDENCIES[@]}"
        echo ""
    fi
    check_docker_installed || remove_old_docker

    install_dependencies
    add_docker_repo
    install_docker
    configure_docker_mirror
    start_docker
    add_user_to_docker_group
    install_docker_compose
    verify_installation

    echo ""
    generate_report
}

# 执行主函数
main
