#!/bin/bash

################################################################################
# 监控预警系统安装脚本 v1.0.0
# 功能: 安装依赖、初始化配置目录、配置邮件服务
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MONITOR_DIR="/etc/ant-eyes/monitor"
MONITOR_CONF="$MONITOR_DIR/monitors.conf"
EMAIL_CONF="$MONITOR_DIR/email.conf"
STATE_DIR="$MONITOR_DIR/state"
LOG_FILE="$MONITOR_DIR/monitor.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         监控预警系统安装 v1.0.0                          ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        exit 1
    fi
}

install_deps() {
    log_info "检查并安装依赖（curl）..."
    if ! command -v curl &>/dev/null; then
        if command -v yum &>/dev/null; then
            yum install -y curl 2>/dev/null || true
        elif command -v apt-get &>/dev/null; then
            apt-get install -y curl 2>/dev/null || true
        fi
    fi
    if ! command -v curl &>/dev/null; then
        log_error "curl 不可用，无法继续"
        exit 1
    fi
    log_success "依赖检查完成"
}

init_dirs() {
    log_info "初始化配置目录..."
    mkdir -p "$MONITOR_DIR" "$STATE_DIR"
    touch "$LOG_FILE"
    chmod 700 "$MONITOR_DIR"
    chmod 600 "$LOG_FILE" 2>/dev/null || true
    log_success "配置目录已创建: $MONITOR_DIR"
}

init_monitors_conf() {
    if [[ ! -f "$MONITOR_CONF" ]]; then
        cat > "$MONITOR_CONF" <<'EOF'
# 监控任务配置文件
# 格式说明：
#   MONITOR_<ID>_NAME       监控名称
#   MONITOR_<ID>_URL        监控 URL
#   MONITOR_<ID>_METHOD     HTTP 方法 (GET/POST/PUT/DELETE)
#   MONITOR_<ID>_BODY       POST 请求体 (JSON 字符串，GET 时留空)
#   MONITOR_<ID>_HEADERS    请求头，多个用||分隔，如: Authorization: Bearer xxx||X-App-Id: 1
#   MONITOR_<ID>_EXPECT     期望状态码（默认 200）
#   MONITOR_<ID>_TIMEOUT    超时秒数（默认 10）
#   MONITOR_<ID>_INTERVAL   监控间隔分钟（默认 5）
#   MONITOR_<ID>_EMAIL      预警收件邮箱，多个用逗号分隔
#   MONITOR_<ID>_RETRY      连续失败几次后发预警（默认 2）
#   MONITOR_<ID>_ENABLED    是否启用 (true/false)
MONITOR_COUNT=0
EOF
        chmod 600 "$MONITOR_CONF"
        log_success "监控配置文件已创建: $MONITOR_CONF"
    else
        log_warn "监控配置文件已存在，跳过"
    fi
}

configure_email() {
    log_info "配置邮件服务..."

    if [[ -f "$EMAIL_CONF" ]]; then
        log_warn "邮件配置已存在: $EMAIL_CONF"
        read -p "是否重新配置？(y/n): " -n 1 -r; echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && return 0
    fi

    echo ""
    log_info "请输入 SMTP 邮件配置（直接回车使用默认值）"
    echo ""

    read -p "SMTP 服务器地址 [smtp.163.com]: " smtp_host
    smtp_host="${smtp_host:-smtp.163.com}"

    read -p "SMTP 端口 [465]: " smtp_port
    smtp_port="${smtp_port:-465}"

    read -p "发件人邮箱: " smtp_user
    while [[ -z "$smtp_user" ]]; do
        log_error "发件人邮箱不能为空"
        read -p "发件人邮箱: " smtp_user
    done

    read -s -p "邮箱授权码（非登录密码）: " smtp_password; echo
    while [[ -z "$smtp_password" ]]; do
        log_error "授权码不能为空"
        read -s -p "邮箱授权码: " smtp_password; echo
    done

    read -p "发件人名称 [ant-eyes监控]: " smtp_from_name
    smtp_from_name="${smtp_from_name:-ant-eyes监控}"

    cat > "$EMAIL_CONF" <<EOF
# 邮件配置
SMTP_HOST=$smtp_host
SMTP_PORT=$smtp_port
SMTP_SECURE=true
SMTP_USER=$smtp_user
SMTP_PASSWORD=$smtp_password
SMTP_FROM_NAME=$smtp_from_name
SMTP_FROM_EMAIL=$smtp_user
EOF
    chmod 600 "$EMAIL_CONF"
    log_success "邮件配置已保存: $EMAIL_CONF"
}

install_scripts() {
    log_info "安装监控脚本..."
    cp "$SCRIPT_DIR/monitor.sh" "$MONITOR_DIR/monitor.sh"
    cp "$SCRIPT_DIR/monitor_config.sh" "$MONITOR_DIR/monitor_config.sh"
    chmod +x "$MONITOR_DIR/monitor.sh"
    chmod +x "$MONITOR_DIR/monitor_config.sh"
    log_success "监控脚本已安装到 $MONITOR_DIR"
}

print_summary() {
    echo ""
    log_success "监控预警系统安装完成！"
    echo ""
    echo -e "${YELLOW}使用方法:${NC}"
    echo "  # 管理监控任务（添加/删除/查看/测试）"
    echo "  bash $MONITOR_DIR/monitor_config.sh"
    echo ""
    echo "  # 手动执行一次监控检查"
    echo "  bash $MONITOR_DIR/monitor.sh"
    echo ""
    echo -e "${YELLOW}配置文件:${NC}"
    echo "  监控任务: $MONITOR_CONF"
    echo "  邮件配置: $EMAIL_CONF"
    echo "  运行日志: $LOG_FILE"
    echo ""
}

main() {
    print_header
    check_root
    install_deps
    init_dirs
    init_monitors_conf
    configure_email
    install_scripts
    print_summary
}

main "$@"
