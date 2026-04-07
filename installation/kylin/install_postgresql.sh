#!/bin/bash

################################################################################
# PostgreSQL 18 源码编译安装脚本 - Kylin Linux
# 完全独立，无外部依赖
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# PostgreSQL 版本
PG_VERSION="18.2"
PG_DOWNLOAD_URL="https://ftp.postgresql.org/pub/source/v${PG_VERSION}/postgresql-${PG_VERSION}.tar.gz"
PG_MIRROR_URL="https://mirrors.tuna.tsinghua.edu.cn/postgresql/source/v${PG_VERSION}/postgresql-${PG_VERSION}.tar.gz"

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║     PostgreSQL 18 源码编译安装脚本 (Kylin Linux)        ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        exit 1
    fi
}

install_postgresql() {
    log_info "安装编译依赖..."
    apt-get update -qq
    apt-get install -y build-essential libreadline-dev zlib1g-dev libssl-dev libxml2-dev libxslt1-dev python3-dev wget

    log_info "下载 PostgreSQL ${PG_VERSION} 源码..."
    cd /tmp

    # 尝试从国内镜像下载
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

configure_postgresql() {
    log_info "配置 PostgreSQL..."
    DATA_DIR="/data/postgresql"
    mkdir -p "$DATA_DIR"
    chown postgres:postgres "$DATA_DIR"
    chmod 700 "$DATA_DIR"

    # 初始化数据库
    if [[ ! -d "$DATA_DIR/base" ]]; then
        sudo -u postgres /usr/local/pgsql/bin/initdb -D "$DATA_DIR"
    fi

    # 配置 postgresql.conf 允许远程访问
    if [[ -f "$DATA_DIR/postgresql.conf" ]]; then
        sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$DATA_DIR/postgresql.conf"
        sed -i "s/listen_addresses = 'localhost'/listen_addresses = '*'/" "$DATA_DIR/postgresql.conf"
    fi

    # 配置 pg_hba.conf 允许远程连接
    if [[ -f "$DATA_DIR/pg_hba.conf" ]]; then
        echo "host    all             all             0.0.0.0/0               md5" >> "$DATA_DIR/pg_hba.conf"
    fi

    # 创建 systemd 服务文件
    cat > /etc/systemd/system/postgresql.service <<EOF
[Unit]
Description=PostgreSQL 18 database server
After=network.target

[Service]
Type=forking
User=postgres
Group=postgres
Environment=PGDATA=$DATA_DIR
ExecStart=/usr/local/pgsql/bin/pg_ctl start -D $DATA_DIR -s -w -t 300
ExecStop=/usr/local/pgsql/bin/pg_ctl stop -D $DATA_DIR -s -m fast
ExecReload=/usr/local/pgsql/bin/pg_ctl reload -D $DATA_DIR -s
TimeoutSec=300

[Install]
WantedBy=multi-user.target
EOF

    log_success "PostgreSQL 配置完成"
}

configure_firewall() {
    log_info "配置防火墙..."

    # 检查 ufw 是否安装
    if command -v ufw &> /dev/null; then
        ufw allow 5432/tcp
        log_success "防火墙规则已添加（端口 5432）"
    else
        log_warn "ufw 未安装，跳过防火墙配置"
    fi
}

start_service() {
    log_info "启动 PostgreSQL 服务..."
    systemctl daemon-reload
    systemctl enable postgresql
    systemctl start postgresql

    sleep 2

    if systemctl is-active --quiet postgresql; then
        log_success "PostgreSQL 服务启动成功"
    else
        log_error "PostgreSQL 服务启动失败"
        exit 1
    fi
}

verify() {
    log_info "验证 PostgreSQL 安装..."
    POSTGRES_VERSION=$(/usr/local/pgsql/bin/postgres --version)
    log_success "$POSTGRES_VERSION"

    if sudo -u postgres /usr/local/pgsql/bin/psql -c "SELECT 1;" &>/dev/null; then
        log_success "PostgreSQL 连接测试通过"
    else
        log_warn "PostgreSQL 连接测试失败"
    fi
}

main() {
    print_header
    check_root
    install_postgresql
    configure_postgresql
    configure_firewall
    start_service
    verify

    echo ""
    log_success "PostgreSQL ${PG_VERSION} 安装完成！"
    log_info "数据目录: /data/postgresql"
    log_info "远程访问已启用，端口: 5432"
    log_info "可执行文件: /usr/local/pgsql/bin/"
}

main