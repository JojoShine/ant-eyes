#!/bin/bash

################################################################################
# PostgreSQL 18 源码编译安装脚本 v3.0.0
# 支持系统: CentOS/RHEL 7+, Ubuntu 18.04+, Kylin Linux
# 功能: 系统检测、密码认证配置、网络检查、安装存档
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# PostgreSQL 版本
PG_VERSION="18.2"
PG_DOWNLOAD_URL="https://ftp.postgresql.org/pub/source/v${PG_VERSION}/postgresql-${PG_VERSION}.tar.gz"
PG_MIRROR_URL="https://mirrors.tuna.tsinghua.edu.cn/postgresql/source/v${PG_VERSION}/postgresql-${PG_VERSION}.tar.gz"

OS_TYPE=""
PKG_MGR=""
PG_PORT="5432"
PG_PASSWORD=""
PG_DATA_DIR="/data/postgresql"
PG_SERVICE="postgresql"

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║      PostgreSQL 18 源码编译安装脚本 v3.0.0               ║"
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
    log_info "安装编译依赖..."
    if [[ "$PKG_MGR" == "apt" ]]; then
        apt-get update -qq
        apt-get install -y build-essential libreadline-dev zlib1g-dev libssl-dev libxml2-dev libxslt1-dev python3-dev wget curl
    else
        yum install -y gcc gcc-c++ make readline-devel zlib-devel openssl-devel libxml2-devel libxslt-devel perl-ExtUtils-Embed python3-devel wget curl
    fi
    log_success "编译依赖安装完成"
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

check_existing_installation() {
    log_info "检查现有 PostgreSQL 安装..."
    local has_old=0
    local old_services=()

    # 检查系统包管理器安装的 PostgreSQL
    if command -v psql &>/dev/null && [[ ! -f /usr/local/pgsql/bin/postgres ]]; then
        log_warn "检测到通过包管理器安装的 PostgreSQL"
        has_old=1
    fi

    # 检查运行中的 PostgreSQL 服务
    if systemctl is-active --quiet postgresql 2>/dev/null; then
        old_services+=("postgresql")
    fi
    if systemctl is-active --quiet postgresql-* 2>/dev/null; then
        old_services+=($(systemctl list-units --type=service --state=active | grep postgresql | awk '{print $1}'))
    fi

    # 检查旧的数据目录
    local old_data_dirs=()
    [[ -d /var/lib/pgsql/data ]] && old_data_dirs+=("/var/lib/pgsql/data")
    [[ -d /var/lib/postgresql ]] && old_data_dirs+=("/var/lib/postgresql")

    if [[ $has_old -eq 1 ]] || [[ ${#old_services[@]} -gt 0 ]] || [[ ${#old_data_dirs[@]} -gt 0 ]]; then
        echo ""
        log_warn "检测到现有 PostgreSQL 安装："
        [[ $has_old -eq 1 ]] && echo "  - 通过包管理器安装的 PostgreSQL"
        [[ ${#old_services[@]} -gt 0 ]] && echo "  - 运行中的服务: ${old_services[*]}"
        [[ ${#old_data_dirs[@]} -gt 0 ]] && echo "  - 数据目录: ${old_data_dirs[*]}"
        echo ""
        log_warn "继续安装将使用源码编译的 PostgreSQL 18，可能与现有安装冲突"
        echo ""
        read -p "是否卸载现有 PostgreSQL 并继续？(y/n): " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            remove_old_postgresql
        else
            log_info "安装已取消"
            exit 0
        fi
    else
        log_success "未检测到现有 PostgreSQL 安装"
    fi
}

remove_old_postgresql() {
    log_info "卸载现有 PostgreSQL..."

    # 停止所有 PostgreSQL 服务
    systemctl stop postgresql 2>/dev/null || true
    systemctl stop postgresql-* 2>/dev/null || true
    systemctl disable postgresql 2>/dev/null || true

    # 卸载包管理器安装的 PostgreSQL
    if [[ "$PKG_MGR" == "apt" ]]; then
        apt-get remove -y postgresql postgresql-* 2>/dev/null || true
        apt-get autoremove -y 2>/dev/null || true
    else
        yum remove -y postgresql postgresql-* 2>/dev/null || true
    fi

    # 备份旧数据目录
    if [[ -d /var/lib/pgsql/data ]]; then
        log_info "备份旧数据目录到 /var/lib/pgsql/data.bak.$(date +%Y%m%d_%H%M%S)"
        mv /var/lib/pgsql/data /var/lib/pgsql/data.bak.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
    fi
    if [[ -d /var/lib/postgresql ]]; then
        log_info "备份旧数据目录到 /var/lib/postgresql.bak.$(date +%Y%m%d_%H%M%S)"
        mv /var/lib/postgresql /var/lib/postgresql.bak.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
    fi

    log_success "旧版本 PostgreSQL 已卸载"
}

install_postgresql() {
    log_info "下载并编译安装 PostgreSQL ${PG_VERSION}..."

    if [[ -f /usr/local/pgsql/bin/postgres ]]; then
        log_warn "PostgreSQL 已安装，跳过安装步骤"
        return 0
    fi

    cd /tmp

    # 尝试从国内镜像下载
    log_info "下载 PostgreSQL ${PG_VERSION} 源码..."
    if ! wget -q --timeout=30 "$PG_MIRROR_URL" -O postgresql-${PG_VERSION}.tar.gz; then
        log_warn "国内镜像下载失败，尝试官方源..."
        wget -q --timeout=60 "$PG_DOWNLOAD_URL" -O postgresql-${PG_VERSION}.tar.gz
    fi

    log_info "解压源码..."
    tar -xzf postgresql-${PG_VERSION}.tar.gz
    cd postgresql-${PG_VERSION}

    log_info "配置编译选项..."
    ./configure --prefix=/usr/local/pgsql \
                --with-openssl \
                --with-libxml \
                --with-libxslt \
                --enable-thread-safety

    log_info "编译 PostgreSQL（这可能需要几分钟）..."
    make -j$(nproc)

    log_info "安装 PostgreSQL..."
    make install

    # 创建 postgres 用户
    if ! id -u postgres &>/dev/null; then
        useradd -r -s /bin/bash postgres
    fi

    # 添加到 PATH
    echo 'export PATH=/usr/local/pgsql/bin:$PATH' > /etc/profile.d/postgresql.sh
    source /etc/profile.d/postgresql.sh

    # 清理临时文件
    cd /tmp
    rm -rf postgresql-${PG_VERSION} postgresql-${PG_VERSION}.tar.gz

    log_success "PostgreSQL ${PG_VERSION} 编译安装完成"
}

init_postgresql() {
    log_info "初始化 PostgreSQL 数据目录..."

    # 使用 /data/postgresql 作为数据目录
    mkdir -p "$PG_DATA_DIR"
    chown postgres:postgres "$PG_DATA_DIR"
    chmod 700 "$PG_DATA_DIR"

    if [[ ! -d "$PG_DATA_DIR/base" ]]; then
        sudo -u postgres /usr/local/pgsql/bin/initdb -D "$PG_DATA_DIR"
        log_success "PostgreSQL 数据库初始化完成"
    else
        log_warn "数据目录已存在，跳过初始化"
    fi

    log_info "数据目录: $PG_DATA_DIR"
}

configure_postgresql() {
    log_info "配置 PostgreSQL 认证..."

    local HBA_CONF="$PG_DATA_DIR/pg_hba.conf"
    local PG_CONF="$PG_DATA_DIR/postgresql.conf"

    if [[ -f "$HBA_CONF" ]]; then
        cp "$HBA_CONF" "${HBA_CONF}.bak.$(date +%Y%m%d_%H%M%S)"

        # 临时允许本地 trust 认证，用于设置密码
        sed -i 's/^\(local\s\+all\s\+postgres\s\+\)peer/\1trust/' "$HBA_CONF" || true
        sed -i 's/^\(local\s\+all\s\+postgres\s\+\)md5/\1trust/' "$HBA_CONF" || true

        # 其他本地连接使用 md5
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
    log_info "配置并启动 PostgreSQL 服务..."

    # 创建 systemd 服务文件
    cat > /etc/systemd/system/postgresql.service <<EOF
[Unit]
Description=PostgreSQL 18 database server
After=network.target

[Service]
Type=forking
User=postgres
Group=postgres
Environment=PGDATA=$PG_DATA_DIR
ExecStart=/usr/local/pgsql/bin/pg_ctl start -D $PG_DATA_DIR -s -w -t 300
ExecStop=/usr/local/pgsql/bin/pg_ctl stop -D $PG_DATA_DIR -s -m fast
ExecReload=/usr/local/pgsql/bin/pg_ctl reload -D $PG_DATA_DIR -s
TimeoutSec=300

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable postgresql
    systemctl start postgresql
    sleep 3

    if systemctl is-active --quiet postgresql; then
        log_success "PostgreSQL 服务启动成功"
    else
        log_error "PostgreSQL 服务启动失败"
        systemctl status postgresql --no-pager 2>/dev/null || true
        exit 1
    fi
}

configure_firewall() {
    log_info "配置防火墙..."

    # 检查 firewalld (CentOS/RHEL)
    if systemctl is-active --quiet firewalld 2>/dev/null; then
        firewall-cmd --permanent --add-port=$PG_PORT/tcp
        firewall-cmd --reload
        log_success "防火墙规则已添加（端口 $PG_PORT）"
    # 检查 ufw (Ubuntu/Kylin)
    elif command -v ufw &> /dev/null; then
        ufw allow $PG_PORT/tcp
        log_success "防火墙规则已添加（端口 $PG_PORT）"
    else
        log_warn "未检测到防火墙服务，跳过防火墙配置"
    fi
}

set_pg_password() {
    log_info "设置 postgres 用户密码..."
    sleep 3

    # 使用 trust 认证设置密码
    if sudo -u postgres /usr/local/pgsql/bin/psql -c "ALTER USER postgres WITH PASSWORD '$PG_PASSWORD';" 2>/dev/null; then
        log_success "postgres 用户密码设置成功"

        # 密码设置成功后，将 postgres 用户的认证方式改为 md5
        local HBA_CONF="$PG_DATA_DIR/pg_hba.conf"
        if [[ -f "$HBA_CONF" ]]; then
            sed -i 's/^\(local\s\+all\s\+postgres\s\+\)trust/\1md5/' "$HBA_CONF"

            # 重新加载配置
            sudo -u postgres /usr/local/pgsql/bin/pg_ctl reload -D "$PG_DATA_DIR" -s
            sleep 1
            log_success "认证方式已更新为 md5"
        fi
    else
        log_error "密码设置失败"
        log_warn "请手动运行: sudo -u postgres /usr/local/pgsql/bin/psql -c \"ALTER USER postgres WITH PASSWORD 'your_password';\""
        log_warn "然后修改 $PG_DATA_DIR/pg_hba.conf 中 postgres 用户的认证方式为 md5"
    fi
}

verify() {
    log_info "验证 PostgreSQL 安装..."
    local PG_VER
    PG_VER=$(/usr/local/pgsql/bin/psql --version 2>/dev/null | awk '{print $3}' || echo "unknown")
    log_success "PostgreSQL 版本: $PG_VER"

    if PGPASSWORD="$PG_PASSWORD" /usr/local/pgsql/bin/psql -U postgres -h 127.0.0.1 -p "$PG_PORT" -c "SELECT 1;" &>/dev/null 2>&1; then
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
    PG_VERSION=$(/usr/local/pgsql/bin/psql --version 2>/dev/null | awk '{print $3}' || echo "unknown")

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
INSTALL_PATH=/usr/local/pgsql
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
    check_existing_installation
    prompt_config
    install_postgresql
    init_postgresql
    configure_postgresql
    configure_firewall
    start_service
    set_pg_password
    verify
    save_config

    echo ""
    log_success "PostgreSQL ${PG_VERSION} 安装完成！"
    echo ""
    echo -e "${YELLOW}连接信息:${NC}"
    echo "  /usr/local/pgsql/bin/psql -U postgres -h 127.0.0.1 -p $PG_PORT"
    echo ""
    echo -e "${YELLOW}数据目录:${NC} $PG_DATA_DIR"
    echo -e "${YELLOW}安装路径:${NC} /usr/local/pgsql"
    echo -e "${YELLOW}配置存档:${NC} /etc/ant-eyes/postgresql.conf"
    echo ""
}

main
