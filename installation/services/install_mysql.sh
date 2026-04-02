#!/bin/bash

################################################################################
# MySQL 自动安装脚本 v2.0.0
# 支持系统: CentOS/RHEL 7+, Ubuntu 18.04+, Kylin Linux
# 功能: 系统检测、密码配置、网络检查、安装存档
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

OS_TYPE=""
PKG_MGR=""
MYSQL_PORT="3306"
MYSQL_ROOT_PASS=""
MYSQL_BIND="0.0.0.0"
MYSQL_SERVICE=""

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         MySQL 自动安装脚本 v2.0.0                        ║"
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
        OS_TYPE="kylin"
        PKG_MGR="yum"
    elif grep -qi "centos\|rhel\|red hat" /etc/os-release 2>/dev/null; then
        OS_TYPE="centos"
        PKG_MGR="yum"
    elif grep -qi "ubuntu\|debian" /etc/os-release 2>/dev/null; then
        OS_TYPE="ubuntu"
        PKG_MGR="apt"
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
    log_info "配置 MySQL 安装参数..."
    echo ""

    read -p "请输入 MySQL 监听端口 [默认: 3306]: " input_port
    [[ -n "$input_port" ]] && MYSQL_PORT="$input_port"

    while true; do
        read -s -p "请输入 MySQL root 密码（必填，不少于8位）: " input_pass; echo
        if [[ ${#input_pass} -ge 8 ]]; then
            read -s -p "请再次输入密码确认: " input_pass2; echo
            if [[ "$input_pass" == "$input_pass2" ]]; then
                MYSQL_ROOT_PASS="$input_pass"; break
            else
                log_warn "两次输入的密码不一致，请重新输入"
            fi
        else
            log_warn "密码不能少于 8 位，请重新输入"
        fi
    done

    log_success "配置参数已确认: 端口=$MYSQL_PORT"
    echo ""
}

install_mysql() {
    log_info "安装 MySQL..."
    if command -v mysql &>/dev/null; then
        log_warn "MySQL 已安装，跳过安装步骤"
        return 0
    fi

    if [[ "$PKG_MGR" == "apt" ]]; then
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server
    else
        yum remove -y mariadb-libs mariadb-server 2>/dev/null || true
        yum install -y mysql-server mysql
    fi
    log_success "MySQL 安装完成"
}

configure_mysql() {
    log_info "配置 MySQL..."
    local CONF_DIR

    if [[ "$PKG_MGR" == "apt" ]]; then
        CONF_DIR="/etc/mysql/mysql.conf.d"
        MYSQL_SERVICE="mysql"
    else
        CONF_DIR="/etc/mysql/conf.d"
        mkdir -p "$CONF_DIR"
        MYSQL_SERVICE="mysqld"
    fi

    mkdir -p "$CONF_DIR"
    cat > "$CONF_DIR/custom.cnf" <<EOF
[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
init_connect = 'SET NAMES utf8mb4'
bind-address = $MYSQL_BIND
port = $MYSQL_PORT
max_connections = 500

[client]
default-character-set = utf8mb4
EOF

    log_success "MySQL 配置文件已写入: $CONF_DIR/custom.cnf"
}

start_service() {
    log_info "启动 MySQL 服务..."
    systemctl daemon-reload
    systemctl enable "$MYSQL_SERVICE" 2>/dev/null || systemctl enable mysql 2>/dev/null || true
    systemctl start "$MYSQL_SERVICE" 2>/dev/null || systemctl start mysql 2>/dev/null || true
    sleep 3

    local svc_active=0
    if systemctl is-active --quiet "$MYSQL_SERVICE" 2>/dev/null || systemctl is-active --quiet mysql 2>/dev/null; then
        svc_active=1
    fi

    if [[ $svc_active -eq 1 ]]; then
        log_success "MySQL 服务启动成功"
    else
        log_error "MySQL 服务启动失败"
        systemctl status "$MYSQL_SERVICE" --no-pager 2>/dev/null || true
        exit 1
    fi
}

set_root_password() {
    log_info "设置 MySQL root 密码..."
    sleep 2

    # 尝试无密码连接并设置密码
    if mysql -u root --connect-expired-password -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS'; FLUSH PRIVILEGES;" 2>/dev/null; then
        log_success "root 密码设置成功"
    elif mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS'; FLUSH PRIVILEGES;" 2>/dev/null; then
        log_success "root 密码设置成功"
    else
        # Ubuntu 初始化方式
        local TEMP_PASS
        TEMP_PASS=$(grep 'temporary password' /var/log/mysqld.log 2>/dev/null | tail -1 | awk '{print $NF}')
        if [[ -n "$TEMP_PASS" ]]; then
            mysql -u root -p"$TEMP_PASS" --connect-expired-password \
                -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS'; FLUSH PRIVILEGES;" 2>/dev/null
            log_success "root 密码设置成功（通过临时密码）"
        else
            log_warn "无法自动设置密码，请手动运行: mysql_secure_installation"
        fi
    fi
}

verify() {
    log_info "验证 MySQL 安装..."
    local MYSQL_VERSION
    MYSQL_VERSION=$(mysql -V 2>/dev/null | awk '{print $5}' | cut -d',' -f1 || echo "unknown")
    log_success "MySQL 版本: $MYSQL_VERSION"

    if mysql -u root -p"$MYSQL_ROOT_PASS" -e "SELECT 1;" &>/dev/null 2>&1; then
        log_success "MySQL 连接测试通过（带鉴权）"
    else
        log_warn "MySQL 连接测试失败，请检查密码配置"
    fi
}

save_config() {
    log_info "保存安装配置存档..."
    mkdir -p /etc/ant-eyes
    local OS_NAME
    OS_NAME=$(grep "^PRETTY_NAME" /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "$OS_TYPE")
    local MYSQL_VERSION
    MYSQL_VERSION=$(mysql -V 2>/dev/null | awk '{print $5}' | cut -d',' -f1 || echo "unknown")

    cat > /etc/ant-eyes/mysql.conf <<EOF
# MySQL 安装信息
# 安装时间: $(date '+%Y-%m-%d %H:%M:%S')
# 安装系统: $OS_NAME
# ----------------------------------------
SERVICE_VERSION=$MYSQL_VERSION
SERVICE_PORT=$MYSQL_PORT
ROOT_USER=root
ROOT_PASS=$MYSQL_ROOT_PASS
BIND_ADDRESS=$MYSQL_BIND
DATA_DIR=/var/lib/mysql
SERVICE_NAME=$MYSQL_SERVICE
EOF

    chmod 600 /etc/ant-eyes/mysql.conf
    log_success "配置存档已保存至: /etc/ant-eyes/mysql.conf"
}

main() {
    print_header
    check_root
    detect_os
    check_network
    install_deps
    configure_pkg_source
    prompt_config
    install_mysql
    configure_mysql
    start_service
    set_root_password
    verify
    save_config

    echo ""
    log_success "MySQL 安装完成！"
    echo ""
    echo -e "${YELLOW}连接信息:${NC}"
    echo "  mysql -u root -p"
    echo ""
    echo -e "${YELLOW}配置存档:${NC} /etc/ant-eyes/mysql.conf"
    echo ""
}

main
