#!/bin/bash

################################################################################
# MinIO 自动安装脚本
# 支持 CentOS/RHEL 7+, Ubuntu 18.04+, Kylin, UOS
# 功能:
#   - 安装最新版 MinIO
#   - 强制设置访问密钥 (MINIO_ROOT_USER/PASSWORD)
#   - 密钥复杂度验证 (用户名8+字符, 密码12+字符)
#   - 配置存储路径
#   - 配置双端口 (9000 API, 9001 Console)
#   - 创建 systemd 服务
#   - 配置开机自启
#
# 使用方法:
#   sudo bash install_minio.sh
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
NC='\033[0m'

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


# 配置变量
MINIO_API_PORT=9000
MINIO_CONSOLE_PORT=9001
MINIO_ROOT_USER=""
MINIO_ROOT_PASSWORD=""
MINIO_DATA_DIR="/data/minio"
MINIO_USER="minio-user"

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 打印标题
print_header() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║           MinIO 自动安装脚本 v1.0.0                      ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
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
        centos|rhel|kylin|rocky|almalinux)
            PKG_MANAGER="yum"
            ;;
        ubuntu|debian|uos)
            PKG_MANAGER="apt"
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
}

# 验证用户名复杂度
validate_username() {
    local username="$1"

    # 长度检查 (至少8位)
    if [[ ${#username} -lt 8 ]]; then
        log_error "用户名长度至少8位"
        return 1
    fi

    # 复杂度检查: 必须包含字母和数字
    if ! echo "$username" | grep -q '[a-zA-Z]'; then
        log_error "用户名必须包含字母"
        return 1
    fi

    if ! echo "$username" | grep -q '[0-9]'; then
        log_error "用户名必须包含数字"
        return 1
    fi

    # 弱用户名检查
    local weak_usernames=("admin123" "minio123" "root1234")
    for weak in "${weak_usernames[@]}"; do
        if [[ "$username" == "$weak" ]]; then
            log_error "不允许使用常见弱用户名"
            return 1
        fi
    done

    return 0
}

# 验证密码复杂度
validate_password() {
    local password="$1"

    # 长度检查 (至少12位)
    if [[ ${#password} -lt 12 ]]; then
        log_error "密码长度至少12位"
        return 1
    fi

    # 复杂度检查: 必须包含大写、小写、数字
    if ! echo "$password" | grep -q '[A-Z]'; then
        log_error "密码必须包含大写字母"
        return 1
    fi

    if ! echo "$password" | grep -q '[a-z]'; then
        log_error "密码必须包含小写字母"
        return 1
    fi

    if ! echo "$password" | grep -q '[0-9]'; then
        log_error "密码必须包含数字"
        return 1
    fi

    # 弱密码检查
    local weak_passwords=("minioadmin123" "Admin123456" "Password123")
    for weak in "${weak_passwords[@]}"; do
        if [[ "$password" == "$weak" ]]; then
            log_error "不允许使用常见弱密码"
            return 1
        fi
    done

    return 0
}

# 交互式配置
interactive_config() {
    echo ""
    log_info "MinIO 安装配置"
    echo ""

    # 设置存储路径
    read -p "请输入 MinIO 数据存储路径 [默认: /data/minio]: " custom_data_dir
    if [[ -n "$custom_data_dir" ]]; then
        MINIO_DATA_DIR="$custom_data_dir"
    fi
    log_info "数据存储路径: $MINIO_DATA_DIR"

    # 设置 MINIO_ROOT_USER (MANDATORY)
    echo ""
    log_info "设置 MinIO Root User"
    echo -e "${YELLOW}要求:${NC}"
    echo "  - 至少8位长度"
    echo "  - 必须包含字母和数字"
    echo ""

    local attempts=0
    local max_attempts=3

    while [[ $attempts -lt $max_attempts ]]; do
        read -p "请输入 MINIO_ROOT_USER: " MINIO_ROOT_USER

        if ! validate_username "$MINIO_ROOT_USER"; then
            ((attempts++))
            if [[ $attempts -lt $max_attempts ]]; then
                log_warn "还有 $((max_attempts - attempts)) 次机会"
            fi
            continue
        fi

        log_success "MINIO_ROOT_USER 设置成功"
        break
    done

    if [[ -z "$MINIO_ROOT_USER" ]]; then
        log_error "MINIO_ROOT_USER 设置失败"
        exit 1
    fi

    # 设置 MINIO_ROOT_PASSWORD (MANDATORY)
    echo ""
    log_info "设置 MinIO Root Password"
    echo -e "${YELLOW}要求:${NC}"
    echo "  - 至少12位长度"
    echo "  - 必须包含大写字母、小写字母、数字"
    echo ""

    local password1=""
    local password2=""
    attempts=0

    while [[ $attempts -lt $max_attempts ]]; do
        read -s -p "请输入 MINIO_ROOT_PASSWORD: " password1
        echo ""

        if ! validate_password "$password1"; then
            ((attempts++))
            if [[ $attempts -lt $max_attempts ]]; then
                log_warn "还有 $((max_attempts - attempts)) 次机会"
            fi
            continue
        fi

        read -s -p "请再次输入密码: " password2
        echo ""

        if [[ "$password1" != "$password2" ]]; then
            log_error "两次密码不一致"
            ((attempts++))
            if [[ $attempts -lt $max_attempts ]]; then
                log_warn "还有 $((max_attempts - attempts)) 次机会"
            fi
            continue
        fi

        MINIO_ROOT_PASSWORD="$password1"
        log_success "MINIO_ROOT_PASSWORD 设置成功"
        break
    done

    if [[ -z "$MINIO_ROOT_PASSWORD" ]]; then
        log_error "MINIO_ROOT_PASSWORD 设置失败"
        exit 1
    fi

    # 端口配置
    echo ""
    read -p "MinIO API 端口 [默认: 9000]: " custom_api_port
    if [[ -n "$custom_api_port" ]]; then
        MINIO_API_PORT="$custom_api_port"
    fi

    read -p "MinIO Console 端口 [默认: 9001]: " custom_console_port
    if [[ -n "$custom_console_port" ]]; then
        MINIO_CONSOLE_PORT="$custom_console_port"
    fi

    log_info "API 端口: $MINIO_API_PORT, Console 端口: $MINIO_CONSOLE_PORT"
}

# 检查是否已安装
check_installed() {
    if command -v minio &> /dev/null; then
        CURRENT_VERSION=$(minio --version 2>&1 | head -n1 | awk '{print $3}')
        log_warn "检测到已安装 MinIO: $CURRENT_VERSION"
        read -p "是否继续安装? (y/n): " -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

# 创建系统用户
create_minio_user() {
    log_info "创建 MinIO 系统用户..."

    if ! id -u $MINIO_USER &>/dev/null; then
        useradd -r -s /sbin/nologin -M $MINIO_USER
        log_success "已创建用户 $MINIO_USER"
    else
        log_info "用户 $MINIO_USER 已存在"
    fi
}

# 安装 MinIO
install_minio() {
    log_info "安装 MinIO..."

    # 检查 wget 或 curl
    if command -v wget &> /dev/null; then
        DOWNLOAD_CMD="wget --timeout=60 --tries=2 --show-progress"
    elif command -v curl &> /dev/null; then
        DOWNLOAD_CMD="curl -# -L --connect-timeout 60 --max-time 300"
    else
        log_error "未找到 wget 或 curl 工具"
        exit 1
    fi

    # 下载 MinIO 二进制文件
    cd /tmp
    log_info "正在下载 MinIO 服务器 (约100MB，请稍候)..."

    if command -v wget &> /dev/null; then
        if ! wget --timeout=300 --tries=3 --show-progress https://dl.min.io/server/minio/release/linux-amd64/minio -O minio; then
            log_error "MinIO 下载失败，请检查网络连接"
            log_info "手动下载地址: https://dl.min.io/server/minio/release/linux-amd64/minio"
            exit 1
        fi
    else
        if ! curl -# -L --connect-timeout 300 --max-time 600 https://dl.min.io/server/minio/release/linux-amd64/minio -o minio; then
            log_error "MinIO 下载失败，请检查网络连接"
            log_info "手动下载地址: https://dl.min.io/server/minio/release/linux-amd64/minio"
            exit 1
        fi
    fi

    # 安装到系统路径
    chmod +x minio
    mv minio /usr/local/bin/

    # 验证安装
    if command -v minio &> /dev/null; then
        log_success "MinIO 安装完成: $(minio --version | head -n1)"
    else
        log_error "MinIO 安装失败"
        exit 1
    fi

    # 下载 MinIO Client (mc)
    log_info "正在下载 MinIO Client (约20MB)..."

    if command -v wget &> /dev/null; then
        if ! wget --timeout=300 --tries=3 --show-progress https://dl.min.io/client/mc/release/linux-amd64/mc -O mc; then
            log_warn "MinIO Client 下载失败，跳过（不影响主服务）"
            log_info "可手动下载: https://dl.min.io/client/mc/release/linux-amd64/mc"
        else
            chmod +x mc
            mv mc /usr/local/bin/
            log_success "MinIO Client 安装完成"
        fi
    else
        if ! curl -# -L --connect-timeout 300 --max-time 600 https://dl.min.io/client/mc/release/linux-amd64/mc -o mc; then
            log_warn "MinIO Client 下载失败，跳过（不影响主服务）"
            log_info "可手动下载: https://dl.min.io/client/mc/release/linux-amd64/mc"
        else
            chmod +x mc
            mv mc /usr/local/bin/
            log_success "MinIO Client 安装完成"
        fi
    fi
}

# 配置 MinIO
configure_minio() {
    log_info "配置 MinIO..."

    # 创建数据目录
    mkdir -p $MINIO_DATA_DIR
    chown -R $MINIO_USER:$MINIO_USER $MINIO_DATA_DIR

    # 创建环境变量文件
    cat > /etc/default/minio <<EOF
# MinIO Configuration

# Root credentials
MINIO_ROOT_USER="$MINIO_ROOT_USER"
MINIO_ROOT_PASSWORD="$MINIO_ROOT_PASSWORD"

# Storage
MINIO_VOLUMES="$MINIO_DATA_DIR"

# Network
MINIO_ADDRESS=":$MINIO_API_PORT"
MINIO_CONSOLE_ADDRESS=":$MINIO_CONSOLE_PORT"

# Other options
MINIO_OPTS="--certs-dir /etc/minio/certs"
EOF

    chmod 600 /etc/default/minio

    # 创建证书目录 (用于未来的 HTTPS 配置)
    mkdir -p /etc/minio/certs
    chown -R $MINIO_USER:$MINIO_USER /etc/minio

    log_success "MinIO 配置完成"
}

# 创建 systemd 服务
create_systemd_service() {
    log_info "创建 systemd 服务..."

    cat > /etc/systemd/system/minio.service <<'EOF'
[Unit]
Description=MinIO Object Storage
Documentation=https://min.io/docs/minio/linux/index.html
Wants=network-online.target
After=network-online.target
AssertFileIsExecutable=/usr/local/bin/minio

[Service]
WorkingDirectory=/usr/local

User=minio-user
Group=minio-user
ProtectProc=invisible

EnvironmentFile=-/etc/default/minio
ExecStartPre=/bin/bash -c "if [ -z \"${MINIO_VOLUMES}\" ]; then echo \"Variable MINIO_VOLUMES not set in /etc/default/minio\"; exit 1; fi"
ExecStart=/usr/local/bin/minio server $MINIO_OPTS $MINIO_VOLUMES

# MinIO RELEASE.2023-05-04T21-44-30Z adds support for Type=notify (sd_notify)
Type=notify
Restart=always
RestartSec=5s

# Specifies the maximum file descriptor number that can be opened by this process
LimitNOFILE=65536

# Specifies the maximum number of threads this process can create
TasksMax=infinity

# Disable timeout logic and wait until process is stopped
TimeoutStopSec=infinity
SendSIGKILL=no

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    log_success "systemd 服务创建完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."

    if command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            firewall-cmd --permanent --add-port=$MINIO_API_PORT/tcp
            firewall-cmd --permanent --add-port=$MINIO_CONSOLE_PORT/tcp
            firewall-cmd --reload
            log_success "防火墙规则已添加"
        fi
    elif command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            ufw allow $MINIO_API_PORT/tcp
            ufw allow $MINIO_CONSOLE_PORT/tcp
            log_success "防火墙规则已添加"
        fi
    fi
}

# 启动服务
start_service() {
    log_info "启动 MinIO 服务..."

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

# 验证安装
verify_installation() {
    log_info "验证 MinIO 安装..."

    MINIO_VER=$(minio --version | head -n1 | awk '{print $3}')
    log_success "MinIO 版本: $MINIO_VER"

    # 测试 API 端口
    if timeout 5 bash -c "echo > /dev/tcp/127.0.0.1/$MINIO_API_PORT" 2>/dev/null; then
        log_success "MinIO API 端口 ($MINIO_API_PORT) 监听正常"
    else
        log_warn "MinIO API 端口 ($MINIO_API_PORT) 未监听"
    fi

    # 测试 Console 端口
    if timeout 5 bash -c "echo > /dev/tcp/127.0.0.1/$MINIO_CONSOLE_PORT" 2>/dev/null; then
        log_success "MinIO Console 端口 ($MINIO_CONSOLE_PORT) 监听正常"
    else
        log_warn "MinIO Console 端口 ($MINIO_CONSOLE_PORT) 未监听"
    fi
}

# 生成安装报告
generate_report() {
    local REPORT_FILE="/tmp/install_minio_report_$(date +%Y%m%d_%H%M%S).txt"
    local SERVER_IP=$(hostname -I | awk '{print $1}')

    cat > "$REPORT_FILE" <<EOF
╔═══════════════════════════════════════════════════════════╗
║           MinIO 安装报告                                  ║
╚═══════════════════════════════════════════════════════════╝

安装时间: $(date '+%Y-%m-%d %H:%M:%S')
操作系统: $OS_NAME ($OS_VERSION)

【安装版本】
MinIO: $(minio --version | head -n1 | awk '{print $3}')
MinIO Client: $(mc --version | head -n1 | awk '{print $3}')

【服务状态】
$(systemctl status minio --no-pager | head -n 3)

【连接信息】
主机: $SERVER_IP
API 端口: $MINIO_API_PORT
Console 端口: $MINIO_CONSOLE_PORT
Root User: $MINIO_ROOT_USER
Root Password: $MINIO_ROOT_PASSWORD

【访问地址】
API 地址:
  http://$SERVER_IP:$MINIO_API_PORT

Web Console 地址:
  http://$SERVER_IP:$MINIO_CONSOLE_PORT

登录凭证:
  用户名: $MINIO_ROOT_USER
  密码: $MINIO_ROOT_PASSWORD

【配置文件】
环境配置: /etc/default/minio
数据目录: $MINIO_DATA_DIR
证书目录: /etc/minio/certs
二进制文件: /usr/local/bin/minio
客户端工具: /usr/local/bin/mc

【管理命令】
启动服务:   systemctl start minio
停止服务:   systemctl stop minio
重启服务:   systemctl restart minio
查看状态:   systemctl status minio
查看日志:   journalctl -u minio -f

【MinIO Client 配置】
配置别名:
  mc alias set myminio http://localhost:$MINIO_API_PORT $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD

常用命令:
  列出存储桶:   mc ls myminio
  创建存储桶:   mc mb myminio/mybucket
  上传文件:     mc cp file.txt myminio/mybucket/
  下载文件:     mc cp myminio/mybucket/file.txt ./
  查看信息:     mc admin info myminio

【Python SDK 示例】
from minio import Minio

client = Minio(
    "$SERVER_IP:$MINIO_API_PORT",
    access_key="$MINIO_ROOT_USER",
    secret_key="$MINIO_ROOT_PASSWORD",
    secure=False
)

# 列出存储桶
buckets = client.list_buckets()

【安全建议】
1. 生产环境请配置 HTTPS (将证书放到 /etc/minio/certs/)
2. 定期修改 Root 密码
3. 创建专用 IAM 用户而非直接使用 Root
4. 配置访问策略 (Bucket Policy)
5. 启用版本控制和生命周期管理
6. 定期备份重要数据

【性能优化】
- 数据目录建议使用独立磁盘或 RAID
- 大文件上传建议使用 multipart upload
- 配置对象过期策略节省空间
- 监控磁盘使用率

【HTTPS 配置 (可选)】
将 SSL 证书放到以下位置:
- 公钥: /etc/minio/certs/public.crt
- 私钥: /etc/minio/certs/private.key

然后重启服务:
  systemctl restart minio

【注意事项】
⚠ 请妥善保管 Root 凭证
⚠ Root User: $MINIO_ROOT_USER
⚠ Root Password: $MINIO_ROOT_PASSWORD
⚠ 生产环境强烈建议配置 HTTPS
⚠ 定期检查磁盘空间
⚠ 建议配置对象过期策略

【安装日志】
$REPORT_FILE

EOF

    log_success "安装报告已生成: $REPORT_FILE"

    # 显示摘要
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           MinIO 安装完成!                                 ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}MinIO 版本:${NC} $(minio --version | head -n1 | awk '{print $3}')"
    echo -e "${BLUE}服务状态:${NC} $(systemctl is-active minio)"
    echo -e "${BLUE}API 地址:${NC} http://$SERVER_IP:$MINIO_API_PORT"
    echo -e "${BLUE}Console:${NC} http://$SERVER_IP:$MINIO_CONSOLE_PORT"
    echo -e "${BLUE}Root User:${NC} $MINIO_ROOT_USER"
    echo -e "${BLUE}Root Pass:${NC} $MINIO_ROOT_PASSWORD"
    echo ""
    echo -e "${YELLOW}浏览器访问:${NC} http://$SERVER_IP:$MINIO_CONSOLE_PORT"
    echo -e "${YELLOW}报    告:${NC} $REPORT_FILE"
    echo ""
    echo -e "${RED}⚠ 请妥善保管凭证，建议将报告内容保存到安全位置${NC}"
    echo ""
}

# 主函数
main() {
    print_header

    log_info "开始安装 MinIO..."
    echo ""

    check_root
    detect_os

    # 检查前置依赖
    if command -v check_and_install_dependencies &>/dev/null; then
        log_info "检查前置依赖..."
        check_and_install_dependencies "MinIO" "${MINIO_DEPENDENCIES[@]}"
        echo ""
    fi
    check_installed
    interactive_config

    create_minio_user
    install_minio
    configure_minio
    create_systemd_service
    configure_firewall
    start_service
    verify_installation

    echo ""
    generate_report
}

# 执行主函数
main
