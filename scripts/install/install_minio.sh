#!/bin/bash

################################################################################
# MinIO 自动安装脚本 v2.3.0 (镜像源优化版)
# 支持系统: CentOS/RHEL 7+, Ubuntu 18.04+, Kylin Linux
# 功能: 系统检测、二进制安装、systemd 服务、鉴权配置、网络检查、安装存档
# 优化: 使用有效的镜像源、完整离线安装支持、网络诊断
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
OFFLINE_MODE=0
OFFLINE_FILE=""

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         MinIO 自动安装脚本 v2.3.0 (镜像源优化版)        ║"
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

diagnose_network() {
    log_info "执行网络诊断..."
    echo ""

    # 1. DNS 解析测试
    echo -e "${BLUE}[诊断 1/4]${NC} DNS 解析测试"
    local dns_ok=0
    for host in dl.minio.org.cn dl.min.io mirrors.aliyun.com; do
        if nslookup $host &>/dev/null || host $host &>/dev/null; then
            echo "  ✓ $host - 解析成功"
            dns_ok=1
        else
            echo "  ✗ $host - 解析失败"
        fi
    done
    echo ""

    # 2. 网络连通性测试
    echo -e "${BLUE}[诊断 2/4]${NC} 网络连通性测试"
    local ping_ok=0
    for host in dl.minio.org.cn mirrors.aliyun.com 114.114.114.114; do
        if ping -c 1 -W 2 $host &>/dev/null; then
            echo "  ✓ $host - 可达"
            ping_ok=1
        else
            echo "  ✗ $host - 不可达"
        fi
    done
    echo ""

    # 3. HTTPS 连接测试
    echo -e "${BLUE}[诊断 3/4]${NC} HTTPS 连接测试"
    local https_ok=0
    for url in https://dl.minio.org.cn https://dl.min.io; do
        if curl -I --connect-timeout 5 --max-time 10 "$url" &>/dev/null; then
            echo "  ✓ $url - 连接成功"
            https_ok=1
        else
            echo "  ✗ $url - 连接失败"
        fi
    done
    echo ""

    # 4. MinIO 下载链接测试
    echo -e "${BLUE}[诊断 4/4]${NC} MinIO 下载链接测试"
    local ARCH=$(uname -m)
    local MINIO_ARCH="amd64"
    [[ "$ARCH" == "aarch64" ]] && MINIO_ARCH="arm64"

    local test_urls=(
        "https://dl.minio.org.cn/server/minio/release/linux-${MINIO_ARCH}/minio"
        "https://dl.min.io/server/minio/release/linux-${MINIO_ARCH}/minio"
    )

    for url in "${test_urls[@]}"; do
        if curl -I --connect-timeout 10 "$url" 2>&1 | grep -q "200"; then
            echo "  ✓ $url - 可用"
        else
            echo "  ✗ $url - 不可用"
        fi
    done
    echo ""

    # 综合判断
    if [[ $dns_ok -eq 0 ]] || [[ $ping_ok -eq 0 ]] || [[ $https_ok -eq 0 ]]; then
        log_warn "网络诊断发现问题，建议使用离线安装模式"
        return 1
    fi

    log_success "网络诊断通过"
    return 0
}

check_network() {
    log_info "检测网络连通性..."
    local connected=0
    for host in "dl.minio.org.cn" "mirrors.aliyun.com" "114.114.114.114"; do
        if ping -c 1 -W 3 "$host" &>/dev/null 2>&1; then
            connected=1
            log_success "网络连通性正常 (测试主机: $host)"
            break
        fi
    done

    if [[ $connected -eq 0 ]]; then
        log_warn "网络连通性检测失败"
        echo ""
        read -p "是否执行详细网络诊断? (y/n): " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            diagnose_network
        fi

        echo ""
        log_warn "建议使用离线安装模式"
        read -p "是否切换到离线安装模式? (y/n): " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            OFFLINE_MODE=1
            return 0
        fi

        read -p "是否仍然尝试在线安装? (y/n): " -n 1 -r; echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    fi
}

install_deps() {
    log_info "安装前置依赖..."
    if [[ "$PKG_MGR" == "apt" ]]; then
        apt-get update -qq 2>/dev/null || log_warn "apt update 失败"
        apt-get install -y curl wget ca-certificates 2>/dev/null || log_warn "部分依赖安装失败"
        update-ca-certificates 2>/dev/null || true
    else
        yum install -y curl wget ca-certificates 2>/dev/null || log_warn "部分依赖安装失败"
        update-ca-trust 2>/dev/null || true
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

show_offline_guide() {
    echo ""
    echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║              离线安装指南                                 ║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}步骤 1: 在有网络的机器上下载 MinIO${NC}"
    echo ""

    local ARCH=$(uname -m)
    if [[ "$ARCH" == "aarch64" ]]; then
        echo "  # ARM64 架构"
        echo "  wget https://dl.minio.org.cn/server/minio/release/linux-arm64/minio"
    else
        echo "  # AMD64 架构 (x86_64)"
        echo "  wget https://dl.minio.org.cn/server/minio/release/linux-amd64/minio"
    fi

    echo ""
    echo -e "${GREEN}步骤 2: 传输到本服务器${NC}"
    echo ""
    echo "  方法 A: 使用 scp"
    echo "    scp minio root@$(hostname -I | awk '{print $1}'):/tmp/"
    echo ""
    echo "  方法 B: 使用 U 盘"
    echo "    将 minio 文件复制到 U 盘，然后插入服务器"
    echo "    mount /dev/sdb1 /mnt && cp /mnt/minio /tmp/"
    echo ""
    echo "  方法 C: 使用 HTTP 服务器"
    echo "    # 在源机器上: python3 -m http.server 8000"
    echo "    # 在本机上: wget http://source-ip:8000/minio -O /tmp/minio"
    echo ""
    echo -e "${GREEN}步骤 3: 重新运行此脚本，选择离线模式${NC}"
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

prompt_offline_mode() {
    if [[ $OFFLINE_MODE -eq 1 ]]; then
        log_info "离线安装模式"
        echo ""

        # 自动搜索可能的文件位置
        local search_paths=(
            "/tmp/minio"
            "/root/minio"
            "./minio"
            "$(pwd)/minio"
            "/opt/minio"
            "/usr/local/src/minio"
        )

        local found_file=""
        for path in "${search_paths[@]}"; do
            if [[ -f "$path" ]]; then
                found_file="$path"
                log_success "自动发现 MinIO 文件: $found_file"
                local file_size=$(stat -c%s "$found_file" 2>/dev/null || stat -f%z "$found_file" 2>/dev/null)
                echo "  文件大小: $((file_size/1024/1024))MB"

                if [[ $file_size -lt 10000000 ]]; then
                    log_warn "  文件大小异常，可能不完整"
                fi

                read -p "是否使用此文件? (y/n): " use_found
                if [[ $use_found =~ ^[Yy]$ ]]; then
                    OFFLINE_FILE="$found_file"
                    return 0
                fi
            fi
        done

        if [[ -z "$found_file" ]]; then
            log_warn "未找到 MinIO 文件"
            show_offline_guide
        fi

        while true; do
            echo ""
            read -p "请输入 MinIO 文件路径 (或输入 'help' 查看帮助): " input_path

            if [[ "$input_path" == "help" ]]; then
                show_offline_guide
                continue
            fi

            if [[ -f "$input_path" ]]; then
                OFFLINE_FILE="$input_path"
                local file_size=$(stat -c%s "$OFFLINE_FILE" 2>/dev/null || stat -f%z "$OFFLINE_FILE" 2>/dev/null)

                if [[ $file_size -lt 10000000 ]]; then
                    log_warn "文件大小只有 $((file_size/1024/1024))MB，可能不完整"
                    read -p "是否仍然使用此文件? (y/n): " use_anyway
                    [[ ! $use_anyway =~ ^[Yy]$ ]] && continue
                fi

                log_success "找到离线文件: $OFFLINE_FILE (大小: $((file_size/1024/1024))MB)"
                break
            else
                log_error "文件不存在: $input_path"
                read -p "是否重新输入路径? (y/n): " retry
                if [[ ! $retry =~ ^[Yy]$ ]]; then
                    log_error "无法继续安装，退出"
                    exit 1
                fi
            fi
        done
    fi
}

install_minio() {
    log_info "下载并安装 MinIO..."

    if command -v minio &>/dev/null; then
        log_warn "MinIO 已安装，跳过安装步骤"
        return 0
    fi

    # 离线安装模式
    if [[ $OFFLINE_MODE -eq 1 ]]; then
        log_info "使用离线安装: $OFFLINE_FILE"
        cp "$OFFLINE_FILE" /usr/local/bin/minio
        chmod +x /usr/local/bin/minio

        # 验证文件
        if /usr/local/bin/minio --version &>/dev/null; then
            local version=$(/usr/local/bin/minio --version | head -1)
            log_success "MinIO 离线安装完成: $version"
            return 0
        else
            log_error "MinIO 文件无效或损坏，请检查文件完整性"
            rm -f /usr/local/bin/minio
            exit 1
        fi
    fi

    # 在线安装模式
    local ARCH=$(uname -m)
    local MINIO_ARCH="amd64"
    if [[ "$ARCH" == "aarch64" ]]; then
        MINIO_ARCH="arm64"
        log_info "检测到 ARM64 架构"
    fi

    # 使用有效的镜像源（根据诊断结果优化）
    local MINIO_URLS=(
        # MinIO 中国官方镜像（优先）
        "https://dl.minio.org.cn/server/minio/release/linux-${MINIO_ARCH}/minio"
        # MinIO 国际官方源
        "https://dl.min.io/server/minio/release/linux-${MINIO_ARCH}/minio"
        # GitHub 官方发布（备用）
        "https://github.com/minio/minio/releases/latest/download/minio.linux-${MINIO_ARCH}"
        # Gitee 镜像（国内加速）
        "https://gitee.com/mirrors/minio/releases/download/latest/minio.linux-${MINIO_ARCH}"
    )

    local download_success=0
    local temp_file="/tmp/minio_download_$$"

    for url in "${MINIO_URLS[@]}"; do
        log_info "尝试从 $url 下载..."

        # 先测试链接是否可达
        if ! curl -I -L --connect-timeout 5 --max-time 10 "$url" 2>&1 | grep -q "200\|302"; then
            log_warn "  链接不可达，跳过"
            continue
        fi

        log_info "  链接可达，开始下载..."

        # 方法1: 使用 wget（优先）
        if command -v wget &>/dev/null; then
            log_info "  使用 wget 下载..."

            if wget --timeout=180 \
                    --tries=2 \
                    --show-progress \
                    -O "$temp_file" \
                    "$url" 2>&1; then

                if [[ -s "$temp_file" ]]; then
                    local file_size=$(stat -c%s "$temp_file" 2>/dev/null || stat -f%z "$temp_file" 2>/dev/null)
                    log_info "  下载完成，文件大小: $((file_size/1024/1024))MB"

                    # MinIO 二进制文件应该至少 50MB
                    if [[ $file_size -gt 50000000 ]]; then
                        mv "$temp_file" /usr/local/bin/minio
                        download_success=1
                        log_success "MinIO 下载成功 (大小: $((file_size/1024/1024))MB)"
                        break
                    else
                        log_warn "  下载的文件太小 ($((file_size/1024))KB)，可能是错误页面"
                        # 显示文件内容前几行用于调试
                        if [[ $file_size -lt 10000 ]]; then
                            log_info "  文件内容:"
                            head -10 "$temp_file" | sed 's/^/    /'
                        fi
                    fi
                fi
            fi
        fi

        # 方法2: 使用 curl（备用）
        if [[ $download_success -eq 0 ]] && command -v curl &>/dev/null; then
            log_info "  使用 curl 下载..."
            rm -f "$temp_file"

            if curl -L \
                    --connect-timeout 30 \
                    --max-time 300 \
                    --progress-bar \
                    -o "$temp_file" \
                    "$url" 2>&1; then

                if [[ -s "$temp_file" ]]; then
                    local file_size=$(stat -c%s "$temp_file" 2>/dev/null || stat -f%z "$temp_file" 2>/dev/null)
                    log_info "  下载完成，文件大小: $((file_size/1024/1024))MB"

                    if [[ $file_size -gt 50000000 ]]; then
                        mv "$temp_file" /usr/local/bin/minio
                        download_success=1
                        log_success "MinIO 下载成功 (大小: $((file_size/1024/1024))MB)"
                        break
                    else
                        log_warn "  下载的文件太小 ($((file_size/1024))KB)，可能是错误页面"
                    fi
                fi
            fi
        fi

        rm -f "$temp_file"
        log_warn "  从此镜像下载失败，尝试下一个..."
        sleep 2
    done

    # 清理临时文件
    rm -f "$temp_file"

    if [[ $download_success -eq 0 ]]; then
        log_error "所有镜像源均下载失败"
        echo ""
        log_info "手动下载命令（请在有网络的机器上执行）："
        echo ""
        echo "  wget https://dl.minio.org.cn/server/minio/release/linux-${MINIO_ARCH}/minio"
        echo ""
        log_info "然后传输到本机 /tmp/minio，重新运行脚本选择离线模式"
        echo ""

        read -p "是否切换到离线安装模式? (y/n): " switch_offline
        if [[ $switch_offline =~ ^[Yy]$ ]]; then
            OFFLINE_MODE=1
            show_offline_guide
            echo ""
            read -p "准备好文件后按回车继续..."
            prompt_offline_mode
            install_minio
            return
        else
            exit 1
        fi
    fi

    chmod +x /usr/local/bin/minio

    # 验证安装
    if /usr/local/bin/minio --version &>/dev/null; then
        local version=$(/usr/local/bin/minio --version | head -1)
        log_success "MinIO 安装成功: $version"
    else
        log_error "MinIO 安装失败，文件可能损坏"
        rm -f /usr/local/bin/minio
        exit 1
    fi
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
    log_info "数据目录: $MINIO_DATA_DIR"

    # 创建配置目录
    mkdir -p /etc/minio

    # 写入环境变量文件
    cat > /etc/minio/minio.env <<EOF
# MinIO 环境变量配置
MINIO_ROOT_USER=$MINIO_ROOT_USER
MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD
MINIO_VOLUMES=$MINIO_DATA_DIR
MINIO_OPTS=--console-address :$MINIO_CONSOLE_PORT
EOF
    chmod 600 /etc/minio/minio.env
    log_info "配置文件: /etc/minio/minio.env"

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
ExecStartPre=/bin/bash -c "chown -R $MINIO_USER:$MINIO_USER \${MINIO_VOLUMES} 2>/dev/null || true"

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
        log_success "firewalld 规则已添加 (端口: $MINIO_API_PORT, $MINIO_CONSOLE_PORT)"
    elif command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "active"; then
        ufw allow "$MINIO_API_PORT/tcp" 2>/dev/null || true
        ufw allow "$MINIO_CONSOLE_PORT/tcp" 2>/dev/null || true
        log_success "UFW 规则已添加"
    else
        log_warn "未检测到防火墙，跳过配置"
    fi
}

start_service() {
    log_info "启动 MinIO 服务..."
    systemctl daemon-reload
    systemctl enable minio
    systemctl start minio

    log_info "等待服务启动..."
    sleep 5

    if systemctl is-active --quiet minio; then
        log_success "MinIO 服务启动成功"
    else
        log_error "MinIO 服务启动失败"
        echo ""
        log_error "查看详细日志:"
        systemctl status minio --no-pager
        echo ""
        journalctl -u minio -n 50 --no-pager
        exit 1
    fi
}

verify() {
    log_info "验证 MinIO 安装..."

    # 检查版本
    local MINIO_VERSION
    MINIO_VERSION=$(minio --version 2>/dev/null | head -1 || echo "unknown")
    log_success "MinIO 版本: $MINIO_VERSION"

    # 健康检查
    log_info "执行健康检查..."
    sleep 3

    if curl -sf "http://localhost:$MINIO_API_PORT/minio/health/live" &>/dev/null; then
        log_success "MinIO API 健康检查通过"
    else
        log_warn "MinIO API 健康检查失败，服务可能尚未完全启动"
        log_info "请稍后手动访问控制台验证"
    fi
}

save_config() {
    log_info "保存安装配置存档..."
    mkdir -p /etc/ant-eyes

    local OS_NAME
    OS_NAME=$(grep "^PRETTY_NAME" /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "$OS_TYPE")
    local MINIO_VERSION
    MINIO_VERSION=$(minio --version 2>/dev/null | head -1 || echo "unknown")
    local INSTALL_MODE
    [[ $OFFLINE_MODE -eq 1 ]] && INSTALL_MODE="离线安装" || INSTALL_MODE="在线安装"

    cat > /etc/ant-eyes/minio.conf <<EOF
# MinIO 安装信息
# 安装时间: $(date '+%Y-%m-%d %H:%M:%S')
# 安装系统: $OS_NAME
# 安装模式: $INSTALL_MODE
# ----------------------------------------
SERVICE_VERSION=$MINIO_VERSION
API_PORT=$MINIO_API_PORT
CONSOLE_PORT=$MINIO_CONSOLE_PORT
ROOT_USER=$MINIO_ROOT_USER
ROOT_PASS=$MINIO_ROOT_PASSWORD
DATA_DIR=$MINIO_DATA_DIR
ENV_FILE=/etc/minio/minio.env
SERVICE_NAME=minio
MINIO_USER=$MINIO_USER
EOF

    chmod 600 /etc/ant-eyes/minio.conf
    log_success "配置存档已保存至: /etc/ant-eyes/minio.conf"
}

print_summary() {
    local HOST_IP
    HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "your-server-ip")

    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              MinIO 安装完成！                             ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}访问信息:${NC}"
    echo "  ┌─────────────────────────────────────────────────────────"
    echo "  │ API 端点:   http://$HOST_IP:$MINIO_API_PORT"
    echo "  │ 控制台:     http://$HOST_IP:$MINIO_CONSOLE_PORT"
    echo "  │ 用户名:     $MINIO_ROOT_USER"
    echo "  │ 密码:       (已保存在配置文件中)"
    echo "  └─────────────────────────────────────────────────────────"
    echo ""
    echo -e "${YELLOW}配置文件:${NC}"
    echo "  ┌─────────────────────────────────────────────────────────"
    echo "  │ 环境配置:   /etc/minio/minio.env"
    echo "  │ 服务配置:   /etc/systemd/system/minio.service"
    echo "  │ 数据目录:   $MINIO_DATA_DIR"
    echo "  │ 安装存档:   /etc/ant-eyes/minio.conf"
    echo "  └─────────────────────────────────────────────────────────"
    echo ""
    echo -e "${YELLOW}服务管理:${NC}"
    echo "  ┌─────────────────────────────────────────────────────────"
    echo "  │ 查看状态:   systemctl status minio"
    echo "  │ 启动服务:   systemctl start minio"
    echo "  │ 停止服务:   systemctl stop minio"
    echo "  │ 重启服务:   systemctl restart minio"
    echo "  │ 查看日志:   journalctl -u minio -f"
    echo "  └─────────────────────────────────────────────────────────"
    echo ""
    echo -e "${BLUE}提示: 首次访问控制台请使用上述用户名和密码登录${NC}"
    echo ""
}

main() {
    print_header
    check_root
    detect_os
    check_network
    install_deps
    prompt_config
    prompt_offline_mode
    install_minio
    configure_minio
    configure_firewall
    start_service
    verify
    save_config
    print_summary
}

main
