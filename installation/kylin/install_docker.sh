#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# 检查是否为root用户
check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi
}

# 检查系统版本
check_system() {
    if [ -f /etc/kylin-release ]; then
        KYLIN_VERSION=$(cat /etc/kylin-release | grep -oP 'V\d+' || echo "Unknown")
        log_info "检测到麒麟操作系统: $KYLIN_VERSION"

        ARCH=$(uname -m)
        log_info "系统架构: $ARCH"

        KERNEL_VERSION=$(uname -r)
        log_info "内核版本: $KERNEL_VERSION"
    else
        log_error "未检测到麒麟操作系统"
        exit 1
    fi
}

# 检查系统环境
check_environment() {
    log_info "检查系统环境..."

    # 检查内存
    total_mem=$(free -g | awk '/^Mem:/{print $2}')
    if [ $total_mem -lt 2 ]; then
        log_warn "系统内存小于2GB，可能会影响Docker运行性能"
    fi

    # 检查磁盘空间
    root_free=$(df -h / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ $(echo "$root_free < 10" | bc) -eq 1 ]; then
        log_warn "根目录可用空间小于10GB，建议清理磁盘空间"
    fi
}

# 卸载旧版本Docker
remove_old_docker() {
    log_info "检查并卸载旧版本Docker..."

    # 停止Docker服务
    systemctl stop docker || true

    # 卸载Docker相关包
    yum remove -y docker \
        docker-client \
        docker-client-latest \
        docker-common \
        docker-latest \
        docker-latest-logrotate \
        docker-logrotate \
        docker-engine \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-runc \
        docker-compose

    # 清理Docker相关文件
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
    rm -rf /etc/docker
    rm -rf /run/docker
    rm -rf /var/run/docker
    rm -f /usr/local/bin/docker-compose
    rm -f /usr/bin/docker-compose
}

# 安装依赖包
install_dependencies() {
    log_info "安装依赖包..."
    yum install -y yum-utils \
        device-mapper-persistent-data \
        lvm2 \
        curl \
        wget \
        net-tools \
        python3-pip
}

# 安装Docker
install_docker() {
    log_info "开始安装Docker..."

    # 使用麒麟系统自带的Docker包
    yum install -y docker

    if [ $? -ne 0 ]; then
        log_error "Docker安装失败"
        exit 1
    fi
}

# 配置Docker守护进程
configure_docker() {
    log_info "配置Docker守护进程..."

    # 创建Docker配置目录
    mkdir -p /etc/docker

    # 配置Docker daemon.json
    cat > /etc/docker/daemon.json <<EOF
{
    "registry-mirrors": [
        "https://mirror.ccs.tencentyun.com",
        "https://hub-mirror.c.163.com",
        "https://mirror.baidubce.com"
    ],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    },
    "data-root": "/var/lib/docker",
    "storage-driver": "overlay2"
}
EOF
}

# 启动Docker服务
start_docker() {
    log_info "启动Docker服务..."

    # 重新加载systemd配置
    systemctl daemon-reload

    # 设置开机启动
    systemctl enable docker

    # 启动Docker服务
    systemctl start docker

    if [ $? -ne 0 ]; then
        log_error "Docker服务启动失败"
        exit 1
    fi
}

# 验证Docker安装
verify_installation() {
    log_info "验证Docker安装..."

    # 检查Docker版本
    docker --version
    if [ $? -ne 0 ]; then
        log_error "Docker安装验证失败"
        exit 1
    fi

    # 检查Docker服务状态
    systemctl status docker --no-pager

    log_info "Docker安装成功！"
}

# 安装Docker Compose
install_docker_compose() {
    log_info "开始安装Docker Compose..."

    # 检查是否已安装
    if command -v docker-compose &> /dev/null; then
        log_info "Docker Compose 已安装，版本：$(docker-compose --version)"
        return 0
    fi

    # 设置Docker Compose版本和架构
    COMPOSE_VERSION="2.20.0"
    TARGET_ARCH=$(uname -m)

    # 对于arm架构的特殊处理
    case ${TARGET_ARCH} in
        aarch64) TARGET_ARCH="aarch64" ;;
        armv7l)  TARGET_ARCH="armv7" ;;
        *)       TARGET_ARCH="x86_64" ;;
    esac

    # 创建临时目录
    TMP_DIR=$(mktemp -d)
    cd ${TMP_DIR}

    # 国内镜像源列表
    DOWNLOAD_URLS=(
        "https://mirror.ccs.tencentyun.com/docker-ce/linux/static/stable/${TARGET_ARCH}/docker-compose-linux-${TARGET_ARCH}"
        "https://get.daocloud.io/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-Linux-${TARGET_ARCH}"
        "https://mirror.baidubce.com/docker-ce/linux/static/stable/${TARGET_ARCH}/docker-compose-linux-${TARGET_ARCH}"
        "https://download.fastgit.org/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-Linux-${TARGET_ARCH}"
    )

    # 尝试yum方式安装
    log_info "尝试通过yum安装Docker Compose..."
    if yum install -y docker-compose; then
        log_info "Docker Compose 通过yum安装成功"
        rm -rf ${TMP_DIR}
        return 0
    fi

    log_warn "yum安装失败，尝试二进制安装方式..."

    # 尝试从不同源下载二进制文件
    for url in "${DOWNLOAD_URLS[@]}"; do
        log_info "尝试从 $url 下载..."
        if curl -L "$url" -o docker-compose || wget -q "$url" -O docker-compose; then
            log_info "下载成功"

            # 安装Docker Compose
            chmod +x docker-compose
            mv docker-compose /usr/local/bin/
            ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

            # 验证安装
            if docker-compose --version; then
                log_info "Docker Compose 安装成功"
                rm -rf ${TMP_DIR}
                return 0
            fi
        else
            log_warn "从 $url 下载失败"
        fi
    done

    # 如果上述方法都失败，尝试使用pip安装
    log_info "尝试通过pip安装Docker Compose..."
    if pip install docker-compose; then
        log_info "Docker Compose 通过pip安装成功"
        rm -rf ${TMP_DIR}
        return 0
    fi

    # 如果所有安装方法都失败
    log_error "Docker Compose 安装失败，所有安装方法均不可用"
    rm -rf ${TMP_DIR}
    return 1
}

# 添加当前用户到docker组
add_user_to_docker_group() {
    log_info "将当前用户添加到docker组..."

    # 创建docker组
    groupadd docker || true

    # 获取当前用户
    CURRENT_USER=$(who am i | awk '{print $1}')

    # 将用户添加到docker组
    usermod -aG docker $CURRENT_USER

    log_info "请注销并重新登录以使用户组变更生效"
}

# 显示安装完成信息
show_completion_message() {
    echo -e "\n${GREEN}安装完成！${NC}"
    echo -e "${YELLOW}安装信息：${NC}"
    echo -e "- Docker 版本：$(docker --version)"
    if command -v docker-compose &> /dev/null; then
        echo -e "- Docker Compose 版本：$(docker-compose --version)"
    fi
    echo -e "- Docker 配置文件：/etc/docker/daemon.json"
    echo -e "- Docker 数据目录：/var/lib/docker"

    echo -e "\n${YELLOW}Docker常用命令：${NC}"
    echo "- 启动Docker：systemctl start docker"
    echo "- 停止Docker：systemctl stop docker"
    echo "- 重启Docker：systemctl restart docker"
    echo "- 查看Docker状态：systemctl status docker"

    echo -e "\n${YELLOW}Docker Compose常用命令：${NC}"
    echo "- 启动服务：docker-compose up -d"
    echo "- 停止服务：docker-compose down"
    echo "- 查看服务状态：docker-compose ps"
    echo "- 查看服务日志：docker-compose logs"

    echo -e "\n${YELLOW}注意事项：${NC}"
    echo "1. 请确保在使用Docker之前已经注销并重新登录"
    echo "2. 如果遇到网络问题，请检查防火墙设置"
    echo "3. 建议定期清理未使用的Docker资源：docker system prune"
    echo "4. Docker Compose配置文件默认为当前目录下的docker-compose.yml"

    echo -e "\n${YELLOW}推荐配置：${NC}"
    echo "1. 建议配置Docker镜像加速器（已默认配置国内源）"
    echo "2. 如需自定义存储目录，请修改 /etc/docker/daemon.json 中的 data-root 配置"
    echo "3. 生产环境建议配置Docker日志轮转（已默认配置）"
}

# 主函数
main() {
    clear
    echo -e "${GREEN}开始安装Docker和Docker Compose...${NC}"

    check_root
    check_system
    check_environment
    remove_old_docker
    install_dependencies
    install_docker
    configure_docker
    start_docker
    verify_installation
    install_docker_compose
    add_user_to_docker_group
    show_completion_message
}

# 执行主函数
main
