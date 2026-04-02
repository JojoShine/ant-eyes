#!/bin/bash

################################################################################
# MinIO 自动安装脚本 v2.0.0
# 支持系统: CentOS/RHEL 7+, Ubuntu 18.04+, Kylin Linux
# 功能: 系统检测、二进制安装、systemd 服务、鉴权配置、网络检查、安装存档
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

OS_TYPE=""
PKG_MGR=""
MINIO_API_PORT="9000"
MINIO_CONSOLE_PORT="9001"
MINIO_ROOT_USER=""
MINIO_ROOT_PASSWORD=""
MINIO_DATA_DIR="/data/minio"
MINIO_USER="minio-user"

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         MinIO 自动安装脚本 v2.0.0                        ║"
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
    for host in "mirrors.aliyun.com" "dl.min.io" "8.8.8.8"; do
        if ping -c 1 -W 3 "$host" &>/dev/null 2>&1; then
            connected=1; break
        fi
    done
    if [[ $connected -eq 0 ]]; then
        log_warn "网络连通性检测失败，MinIO 二进制下载可能受影响"
        read -p "是否仍然继续安装? (y/n): " -n 1 -r; echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    else
        log_success "网络连通性正常"
    fi
}

install_deps() {
    log_info "安装前置依赖..."
    if [[ "$PKG_MGR" == "apt" ]]; then
        apt-get update -qq
        apt-get install -y curl wget 2>/dev/null || true
    else
        yum install -y curl wget 2>/dev/null || true
    fi
    log_success "前置依赖检查完成"
}

prompt_config() {
    log_info "配置 MinIO 安装参数..."
    echo ""

    read -p "请输入 MinIO API 端口 [默认: 9000]: " input_port
    [[ -n "$input_port" ]] && MINIO_API_PORT="$input_port"

    read -p "请输入 MinIO 控制台端口 [默认: 9001]: " input_cport
    [[ -n "$input_cport" ]] && MINIO_CONSOLE_PORT="$input_cport"

    read -p "请输入 MinIO 数据目录 [默认: /data/minio]: " input_dir
    [[ -n "$input_dir" ]] && MINIO_DATA_DIR="$input_dir"

    while true; do
        read -p "请输入 MinIO Root 用户名（必填，不少于3位）: " input_user
        if [[ ${#input_user} -ge 3 ]]; then
            MINIO_ROOT_USER="$input_user"; break
        else
            log_warn "用户名不能少于 3 位，请重新输入"
        fi
    done

    while true; do
        read -s -p "请输入 MinIO Root 密码（必填，不少于8位）: " input_pass; echo
        if [[ ${#input_pass} -ge 8 ]]; then
            read -s -p "请再次输入密码确认: " input_pass2; echo
            if [[ "$input_pass" == "$input_pass2" ]]; then
                MINIO_ROOT_PASSWORD="$input_pass"; break
            else
                log_warn "两次输入的密码不一致，请重新输入"
            fi
        else
            log_warn "密码不能少于 8 位，请重新输入"
        fi
    done

    log_success "配置参数已确认: API端口=$MINIO_API_PORT, 控制台端口=$MINIO_CONSOLE_PORT"
    echo ""
}

install_minio() {
    log_info "下载并安装 MinIO..."

    if command -v minio &>/dev/null; then
        log_warn "MinIO 已安装，跳过安装步骤"
        return 0
    fi

    # 下载 MinIO 二进制（多个镜像源）
    local MINIO_URLS=(
        "https://mirrors.aliyun.com/minio/minio-binaries/latest/linux-amd64/minio"
        "https://dl.min.io/server/minio/release/linux-amd64/minio"
    )

    local download_success=0
    for url in "${MINIO_URLS[@]}"; do
        log_info "尝试从 $url 下载..."
        if curl -fsSL -o /usr/local/bin/minio "$url" 2>/dev/null; then
            download_success=1
            log_success "MinIO 下载成功"
            break
        fi
    done

    if [[ $download_success -eq 0 ]]; then
        log_error "无法下载 MinIO，请检查网络连接"
        exit 1
    fi

    chmod +x /usr/local/bin/minio
    log_success "MinIO 安装至 /usr/local/bin/minio"
}

configure_minio() {
    log_info "配置 MinIO 运行环境..."

    # 创建系统用户
    if ! id "$MINIO_USER" &>/dev/null; then
        useradd -r -s /sbin/nologin "$MINIO_USER"
        log_info "已创建系统用户: $MINIO_USER"
    fi

    # 创建数据目录
    mkdir -p "$MINIO_DATA_DIR"
    chown -R "$MINIO_USER:$MINIO_USER" "$MINIO_DATA_DIR"

    # 创建配置目录
    mkdir -p /etc/minio

    # 写入环境变量文件
    cat > /etc/minio/minio.env <<EOF
# MinIO 环境变量配置
MINIO_ROOT_USER=$MINIO_ROOT_USER
MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD
MINIO_VOLUMES=$MINIO_DATA_DIR
MINIO_OPTS="--console-address :$MINIO_CONSOLE_PORT"
EOF
    chmod 600 /etc/minio/minio.env

    # 创建 systemd service 文件
    cat > /etc/systemd/system/minio.service <<EOF
[Unit]
Description=MinIO Object Storage
Documentation=https://min.io/docs/minio/linux/index.html
Wants=network-online.target
After=network-online.target
AssertFileIsExecutable=/usr/local/bin/minio

[Service]
WorkingDirectory=/usr/local

User=$MINIO_USER
Group=$MINIO_USER
ProtectProc=invisible

EnvironmentFile=-/etc/minio/minio.env

ExecStartPre=/bin/bash -c "if [ -z \"\${MINIO_VOLUMES}\" ]; then echo \"Variable MINIO_VOLUMES not set in /etc/minio/minio.env\"; exit 1; fi"

ExecStart=/usr/local/bin/minio server \$MINIO_VOLUMES \$MINIO_OPTS --address :$MINIO_API_PORT

Restart=always
LimitNOFILE=65536
TasksMax=infinity
TimeoutStopSec=infinity
SendSIGKILL=no

[Install]
WantedBy=multi-user.target
EOF

    log_success "MinIO systemd 服务配置完成"
}

configure_firewall() {
    log_info "配置防火墙规则..."

    if command -v firewall-cmd &>/dev/null && systemctl is-active --quiet firewalld 2>/dev/null; then
        firewall-cmd --permanent --add-port="$MINIO_API_PORT/tcp" 2>/dev/null || true
        firewall-cmd --permanent --add-port="$MINIO_CONSOLE_PORT/tcp" 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
        log_success "firewalld 规则已添加 ($MINIO_API_PORT, $MINIO_CONSOLE_PORT)"
    fi

    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "active"; then
        ufw allow "$MINIO_API_PORT/tcp" 2>/dev/null || true
        ufw allow "$MINIO_CONSOLE_PORT/tcp" 2>/dev/null || true
        log_success "UFW 规则已添加"
    fi
}

start_service() {
    log_info "启动 MinIO 服务..."
    systemctl daemon-reload
    systemctl enable minio
    systemctl start minio
    sleep 5

    if systemctl is-active --quiet minio; then
        log_success "MinIO 服务启动成功"
    else
        log_error "MinIO 服务启动失败"
        systemctl status minio --no-pager
        exit 1
    fi
}

verify() {
    log_info "验证 MinIO 安装..."
    local MINIO_VERSION
    MINIO_VERSION=$(minio --version 2>/dev/null | awk '{print $3}' || echo "unknown")
    log_success "MinIO 版本: $MINIO_VERSION"

    sleep 3
    if curl -sf "http://localhost:$MINIO_API_PORT/minio/health/live" &>/dev/null; then
        log_success "MinIO API 健康检查通过"
    else
        log_warn "MinIO API 健康检查失败，服务可能尚未完全启动"
    fi
}

save_config() {
    log_info "保存安装配置存档..."
    mkdir -p /etc/ant-eyes
    local OS_NAME
    OS_NAME=$(grep "^PRETTY_NAME" /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "$OS_TYPE")
    local MINIO_VERSION
    MINIO_VERSION=$(minio --version 2>/dev/null | awk '{print $3}' || echo "unknown")

    cat > /etc/ant-eyes/minio.conf <<EOF
# MinIO 安装信息
# 安装时间: $(date '+%Y-%m-%d %H:%M:%S')
# 安装系统: $OS_NAME
# ----------------------------------------
SERVICE_VERSION=$MINIO_VERSION
API_PORT=$MINIO_API_PORT
CONSOLE_PORT=$MINIO_CONSOLE_PORT
ROOT_USER=$MINIO_ROOT_USER
ROOT_PASS=$MINIO_ROOT_PASSWORD
DATA_DIR=$MINIO_DATA_DIR
ENV_FILE=/etc/minio/minio.env
SERVICE_NAME=minio
EOF

    chmod 600 /etc/ant-eyes/minio.conf
    log_success "配置存档已保存至: /etc/ant-eyes/minio.conf"
}

main() {
    print_header
    check_root
    detect_os
    check_network
    install_deps
    prompt_config
    install_minio
    configure_minio
    configure_firewall
    start_service
    verify
    save_config

    local HOST_IP
    HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "your-server-ip")

    echo ""
    log_success "MinIO 安装完成！"
    echo ""
    echo -e "${YELLOW}访问信息:${NC}"
    echo "  API 端点:  http://$HOST_IP:$MINIO_API_PORT"
    echo "  控制台:    http://$HOST_IP:$MINIO_CONSOLE_PORT"
    echo "  用户名:    $MINIO_ROOT_USER"
    echo ""
    echo -e "${YELLOW}配置存档:${NC} /etc/ant-eyes/minio.conf"
    echo ""
}

main
