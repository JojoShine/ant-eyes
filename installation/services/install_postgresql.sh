#!/bin/bash

################################################################################
# PostgreSQL 自动安装脚本 v2.0.0
# 支持系统: CentOS/RHEL 7+, Ubuntu 18.04+, Kylin Linux
# 功能: 系统检测、密码认证配置、网络检查、安装存档
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

OS_TYPE=""
PKG_MGR=""
PG_PORT="5432"
PG_PASSWORD=""
PG_DATA_DIR=""
PG_SERVICE=""

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         PostgreSQL 自动安装脚本 v2.0.0                   ║"
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

prompt_config() {
    log_info "配置 PostgreSQL 安装参数..."
    echo ""

    read -p "请输入 PostgreSQL 监听端口 [默认: 5432]: " input_port
    [[ -n "$input_port" ]] && PG_PORT="$input_port"

    while true; do
        read -s -p "请输入 postgres 用户密码（必填，不少于8位）: " input_pass; echo
        if [[ ${#input_pass} -ge 8 ]]; then
            read -s -p "请再次输入密码确认: " input_pass2; echo
            if [[ "$input_pass" == "$input_pass2" ]]; then
                PG_PASSWORD="$input_pass"; break
            else
                log_warn "两次输入的密码不一致，请重新输入"
            fi
        else
            log_warn "密码不能少于 8 位，请重新输入"
        fi
    done

    log_success "配置参数已确认: 端口=$PG_PORT"
    echo ""
}

install_postgresql() {
    log_info "安装 PostgreSQL..."
    if command -v psql &>/dev/null; then
        log_warn "PostgreSQL 已安装，跳过安装步骤"
        return 0
    fi

    if [[ "$PKG_MGR" == "apt" ]]; then
        apt-get update -qq
        apt-get install -y postgresql postgresql-contrib
        PG_SERVICE="postgresql"
    else
        yum install -y postgresql-server postgresql-contrib
        PG_SERVICE="postgresql"
    fi
    log_success "PostgreSQL 安装完成"
}

init_postgresql() {
    log_info "初始化 PostgreSQL 数据目录..."

    if [[ "$PKG_MGR" == "yum" ]]; then
        # CentOS/Kylin 需要手动初始化
        if command -v postgresql-setup &>/dev/null; then
            postgresql-setup initdb 2>/dev/null || postgresql-setup --initdb 2>/dev/null || true
        fi
    fi

    # 确定数据目录
    if [[ -d /var/lib/postgresql ]]; then
        PG_DATA_DIR=$(find /var/lib/postgresql -name "pg_hba.conf" -exec dirname {} \; 2>/dev/null | head -1)
    fi
    if [[ -z "$PG_DATA_DIR" ]]; then
        PG_DATA_DIR=$(find /var/lib/pgsql -name "pg_hba.conf" -exec dirname {} \; 2>/dev/null | head -1)
    fi
    if [[ -z "$PG_DATA_DIR" ]]; then
        PG_DATA_DIR="/var/lib/postgresql/data"
    fi

    log_info "数据目录: $PG_DATA_DIR"
}

configure_postgresql() {
    log_info "配置 PostgreSQL 认证..."

    local HBA_CONF="$PG_DATA_DIR/pg_hba.conf"
    local PG_CONF="$PG_DATA_DIR/postgresql.conf"

    if [[ -f "$HBA_CONF" ]]; then
        cp "$HBA_CONF" "${HBA_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
        # 将 peer/ident 认证改为 md5，允许密码登录
        sed -i 's/^\(local\s\+all\s\+postgres\s\+\)peer/\1md5/' "$HBA_CONF" || true
        sed -i 's/^\(local\s\+all\s\+all\s\+\)peer/\1md5/' "$HBA_CONF" || true
        sed -i 's/^\(host\s\+all\s\+all\s\+.*\)ident/\1md5/' "$HBA_CONF" || true
        # 允许所有 host 连接（md5 密码）
        grep -q "host all all 0.0.0.0/0" "$HBA_CONF" || \
            echo "host all all 0.0.0.0/0 md5" >> "$HBA_CONF"
        log_success "pg_hba.conf 认证配置完成"
    else
        log_warn "未找到 pg_hba.conf，跳过认证配置"
    fi

    if [[ -f "$PG_CONF" ]]; then
        # 配置监听地址和端口
        sed -i "s|^#listen_addresses = .*|listen_addresses = '*'|" "$PG_CONF" || true
        sed -i "s|^listen_addresses = .*|listen_addresses = '*'|" "$PG_CONF" || true
        sed -i "s|^#port = .*|port = $PG_PORT|" "$PG_CONF" || true
        sed -i "s|^port = .*|port = $PG_PORT|" "$PG_CONF" || true
        log_success "postgresql.conf 配置完成"
    fi
}

start_service() {
    log_info "启动 PostgreSQL 服务..."
    systemctl daemon-reload
    systemctl enable "$PG_SERVICE" 2>/dev/null || true
    systemctl start "$PG_SERVICE" 2>/dev/null || true
    sleep 3

    if systemctl is-active --quiet "$PG_SERVICE" 2>/dev/null; then
        log_success "PostgreSQL 服务启动成功"
    else
        log_error "PostgreSQL 服务启动失败"
        systemctl status "$PG_SERVICE" --no-pager 2>/dev/null || true
        exit 1
    fi
}

set_pg_password() {
    log_info "设置 postgres 用户密码..."
    sleep 2

    if sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$PG_PASSWORD';" 2>/dev/null; then
        log_success "postgres 用户密码设置成功"
    else
        log_warn "密码设置失败，请手动运行: sudo -u postgres psql -c \"ALTER USER postgres WITH PASSWORD 'your_password';\""
    fi
}

verify() {
    log_info "验证 PostgreSQL 安装..."
    local PG_VERSION
    PG_VERSION=$(psql --version 2>/dev/null | awk '{print $3}' || echo "unknown")
    log_success "PostgreSQL 版本: $PG_VERSION"

    if PGPASSWORD="$PG_PASSWORD" psql -U postgres -h 127.0.0.1 -p "$PG_PORT" -c "SELECT 1;" &>/dev/null 2>&1; then
        log_success "PostgreSQL 连接测试通过（带鉴权）"
    else
        log_warn "PostgreSQL 连接测试失败，请检查密码和 pg_hba.conf 配置"
    fi
}

save_config() {
    log_info "保存安装配置存档..."
    mkdir -p /etc/ant-eyes
    local OS_NAME
    OS_NAME=$(grep "^PRETTY_NAME" /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "$OS_TYPE")
    local PG_VERSION
    PG_VERSION=$(psql --version 2>/dev/null | awk '{print $3}' || echo "unknown")

    cat > /etc/ant-eyes/postgresql.conf <<EOF
# PostgreSQL 安装信息
# 安装时间: $(date '+%Y-%m-%d %H:%M:%S')
# 安装系统: $OS_NAME
# ----------------------------------------
SERVICE_VERSION=$PG_VERSION
SERVICE_PORT=$PG_PORT
DB_USER=postgres
DB_PASS=$PG_PASSWORD
DATA_DIR=$PG_DATA_DIR
SERVICE_NAME=$PG_SERVICE
EOF

    chmod 600 /etc/ant-eyes/postgresql.conf
    log_success "配置存档已保存至: /etc/ant-eyes/postgresql.conf"
}

main() {
    print_header
    check_root
    detect_os
    check_network
    install_deps
    configure_pkg_source
    prompt_config
    install_postgresql
    init_postgresql
    configure_postgresql
    start_service
    set_pg_password
    verify
    save_config

    echo ""
    log_success "PostgreSQL 安装完成！"
    echo ""
    echo -e "${YELLOW}连接信息:${NC}"
    echo "  psql -U postgres -h 127.0.0.1 -p $PG_PORT"
    echo ""
    echo -e "${YELLOW}配置存档:${NC} /etc/ant-eyes/postgresql.conf"
    echo ""
}

main
