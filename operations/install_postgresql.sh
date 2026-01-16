#!/bin/bash

################################################################################
# PostgreSQL 自动安装脚本
# 支持 CentOS/RHEL 7+, Ubuntu 18.04+, Kylin, UOS
# 功能:
#   - 安装 PostgreSQL 14/15/16 (可选版本)
#   - 交互式设置 postgres 用户密码
#   - 创建自定义数据库和用户
#   - 配置 pg_hba.conf 允许远程连接 (可选)
#   - 优化 shared_buffers 参数
#   - 密码复杂度验证
#   - 配置开机自启
#
# 使用方法:
#   sudo bash install_postgresql.sh
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
PG_VERSION="16"
PG_PORT=5432
PG_PASSWORD=""
PG_DB_NAME=""
PG_DB_USER=""
PG_DB_PASSWORD=""
ENABLE_REMOTE_ACCESS=false

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 打印标题
print_header() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         PostgreSQL 自动安装脚本 v1.0.0                   ║"
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

# 验证密码复杂度
validate_password() {
    local password="$1"

    # 长度检查 (至少8位)
    if [[ ${#password} -lt 8 ]]; then
        log_error "密码长度至少8位"
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

    return 0
}

# 交互式配置
interactive_config() {
    echo ""
    log_info "PostgreSQL 安装配置"
    echo ""

    # 选择版本
    echo -e "${BLUE}请选择 PostgreSQL 版本:${NC}"
    echo "  1) PostgreSQL 16 (推荐)"
    echo "  2) PostgreSQL 15"
    echo "  3) PostgreSQL 14"
    read -p "请选择 [1-3, 默认 1]: " version_choice

    case $version_choice in
        2)
            PG_VERSION="15"
            log_info "选择版本: PostgreSQL 15"
            ;;
        3)
            PG_VERSION="14"
            log_info "选择版本: PostgreSQL 14"
            ;;
        *)
            PG_VERSION="16"
            log_info "选择版本: PostgreSQL 16"
            ;;
    esac

    # 设置 postgres 用户密码
    echo ""
    log_info "设置 PostgreSQL postgres 用户密码"
    echo -e "${YELLOW}密码要求:${NC}"
    echo "  - 至少8位长度"
    echo "  - 必须包含大写字母、小写字母、数字"
    echo ""

    local password1=""
    local password2=""
    local attempts=0
    local max_attempts=3

    while [[ $attempts -lt $max_attempts ]]; do
        read -s -p "请输入 postgres 用户密码: " password1
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

        PG_PASSWORD="$password1"
        log_success "密码设置成功"
        break
    done

    if [[ -z "$PG_PASSWORD" ]]; then
        log_error "密码设置失败"
        exit 1
    fi

    # 创建自定义数据库
    echo ""
    read -p "是否创建自定义数据库? (y/n, 默认 n): " create_db_choice
    if [[ $create_db_choice =~ ^[Yy]$ ]]; then
        read -p "请输入数据库名称: " PG_DB_NAME
        read -p "请输入数据库用户名: " PG_DB_USER

        local db_pwd1=""
        local db_pwd2=""
        attempts=0

        while [[ $attempts -lt $max_attempts ]]; do
            read -s -p "请输入数据库用户密码: " db_pwd1
            echo ""

            if ! validate_password "$db_pwd1"; then
                ((attempts++))
                if [[ $attempts -lt $max_attempts ]]; then
                    log_warn "还有 $((max_attempts - attempts)) 次机会"
                fi
                continue
            fi

            read -s -p "请再次输入密码: " db_pwd2
            echo ""

            if [[ "$db_pwd1" != "$db_pwd2" ]]; then
                log_error "两次密码不一致"
                ((attempts++))
                if [[ $attempts -lt $max_attempts ]]; then
                    log_warn "还有 $((max_attempts - attempts)) 次机会"
                fi
                continue
            fi

            PG_DB_PASSWORD="$db_pwd1"
            log_success "数据库用户密码设置成功"
            break
        done

        if [[ -z "$PG_DB_PASSWORD" ]]; then
            log_error "数据库用户密码设置失败"
            exit 1
        fi
    fi

    # 是否允许远程访问
    echo ""
    read -p "是否允许远程访问? (y/n, 默认 n): " remote_choice
    if [[ $remote_choice =~ ^[Yy]$ ]]; then
        ENABLE_REMOTE_ACCESS=true
        log_warn "已启用远程访问 (生产环境请谨慎)"
    else
        log_info "仅允许本地访问 (推荐)"
    fi
}

# 检查是否已安装
check_installed() {
    if command -v psql &> /dev/null; then
        CURRENT_VERSION=$(psql --version 2>&1 | awk '{print $3}')
        log_warn "检测到已安装 PostgreSQL: $CURRENT_VERSION"

        echo ""
        echo "请选择操作:"
        echo "  1) 继续使用现有安装 (重新配置)"
        echo "  2) 完全卸载后重新安装"
        echo "  3) 退出"
        read -p "请选择 [1-3]: " choice

        case $choice in
            1)
                log_info "将使用现有PostgreSQL安装并重新配置"
                ;;
            2)
                log_warn "将卸载现有PostgreSQL (数据将被删除!)"
                read -p "确认卸载? (yes/no): " confirm
                if [[ "$confirm" == "yes" ]]; then
                    uninstall_postgresql
                else
                    log_info "取消卸载"
                    exit 0
                fi
                ;;
            3)
                log_info "退出安装"
                exit 0
                ;;
            *)
                log_error "无效选择"
                exit 1
                ;;
        esac
    fi
}

# 卸载PostgreSQL
uninstall_postgresql() {
    log_info "卸载PostgreSQL..."

    # 停止服务
    systemctl stop postgresql 2>/dev/null || true
    systemctl stop postgresql-${PG_VERSION} 2>/dev/null || true

    # 卸载包
    if [[ $PKG_MANAGER == "yum" ]]; then
        yum remove -y postgresql* 2>/dev/null || true
    else
        apt-get remove --purge -y postgresql* 2>/dev/null || true
    fi

    # 删除数据和配置
    rm -rf /var/lib/pgsql/*
    rm -rf /var/lib/postgresql/*
    rm -rf /etc/postgresql/*

    log_success "PostgreSQL已卸载"
}

# 安装 PostgreSQL (CentOS/RHEL/Kylin)
install_postgresql_yum() {
    log_info "安装 PostgreSQL $PG_VERSION..."

    # 麒麟系统特殊处理
    if [[ "$OS" == "kylin" ]]; then
        log_info "检测到麒麟系统,使用系统自带仓库..."

        # 禁用内置 PostgreSQL 模块
        if [[ -n "$(yum module list postgresql 2>/dev/null)" ]]; then
            yum module disable postgresql -y 2>/dev/null || true
        fi

        # 尝试直接安装系统自带的PostgreSQL
        log_info "从系统仓库安装 PostgreSQL..."
        if yum install -y postgresql-server postgresql-contrib 2>/dev/null; then
            log_success "PostgreSQL 安装成功 (系统版本)"
            PG_VERSION=$(psql --version 2>/dev/null | grep -oP '\d+' | head -1 || echo "unknown")
            log_info "实际安装版本: PostgreSQL $PG_VERSION"
        else
            log_error "系统仓库安装失败,请检查yum源配置"
            log_info "可用的PostgreSQL包:"
            yum search postgresql 2>/dev/null | grep "^postgresql"
            exit 1
        fi
    else
        # 标准CentOS/RHEL系统,使用官方仓库
        log_info "使用PostgreSQL官方仓库..."

        # 安装 PostgreSQL 仓库
        if ! yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-$(rpm -E %rhel)-x86_64/pgdg-redhat-repo-latest.noarch.rpm 2>/dev/null; then
            log_warn "官方仓库安装失败,尝试使用系统仓库..."
            yum install -y postgresql-server postgresql-contrib || exit 1
            PG_VERSION=$(psql --version 2>/dev/null | grep -oP '\d+' | head -1 || echo "unknown")
            log_info "实际安装版本: PostgreSQL $PG_VERSION"
            return 0
        fi

        # 禁用内置 PostgreSQL 模块 (CentOS 8+)
        if [[ -n "$(yum module list postgresql 2>/dev/null)" ]]; then
            yum module disable postgresql -y
        fi

        # 安装指定版本的 PostgreSQL
        yum install -y postgresql${PG_VERSION}-server postgresql${PG_VERSION}-contrib

        # 初始化数据库 (官方版本)
        /usr/pgsql-${PG_VERSION}/bin/postgresql-${PG_VERSION}-setup initdb
    fi

    # 如果是系统版本的PostgreSQL,初始化方式不同
    if [[ "$OS" == "kylin" ]] || [[ ! -f "/usr/pgsql-${PG_VERSION}/bin/postgresql-${PG_VERSION}-setup" ]]; then
        log_info "检查PostgreSQL数据库初始化状态..."

        # 检查数据目录是否已存在且非空
        if [[ -d "/var/lib/pgsql/data" ]] && [[ -n "$(ls -A /var/lib/pgsql/data 2>/dev/null)" ]]; then
            log_warn "PostgreSQL数据库已初始化，跳过初始化步骤"
        else
            log_info "初始化系统版本PostgreSQL数据库..."
            # 系统版本使用postgresql-setup命令
            if command -v postgresql-setup &> /dev/null; then
                postgresql-setup --initdb || postgresql-setup initdb || true
            elif command -v initdb &> /dev/null; then
                # 或者直接使用initdb
                mkdir -p /var/lib/pgsql/data
                chown -R postgres:postgres /var/lib/pgsql
                su - postgres -c "initdb -D /var/lib/pgsql/data" || true
            fi
        fi
    fi

    log_success "PostgreSQL 安装完成"
}

# 安装 PostgreSQL (Ubuntu/Debian)
install_postgresql_apt() {
    log_info "安装 PostgreSQL $PG_VERSION..."

    # 添加 PostgreSQL APT 仓库
    apt-get install -y wget ca-certificates
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
    echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list

    # 更新并安装
    apt-get update -qq
    apt-get install -y postgresql-${PG_VERSION} postgresql-contrib-${PG_VERSION}

    log_success "PostgreSQL 安装完成"
}

# 配置 PostgreSQL
configure_postgresql() {
    log_info "配置 PostgreSQL..."

    # 查找配置文件路径
    if [[ $PKG_MANAGER == "yum" ]]; then
        # 检测配置文件位置 (官方版本 vs 系统版本)
        if [[ -d "/var/lib/pgsql/${PG_VERSION}/data" ]]; then
            # 官方版本
            PG_DATA_DIR="/var/lib/pgsql/${PG_VERSION}/data"
        elif [[ -d "/var/lib/pgsql/data" ]]; then
            # 系统版本
            PG_DATA_DIR="/var/lib/pgsql/data"
        else
            log_error "无法找到PostgreSQL数据目录"
            exit 1
        fi
        PG_CONF="${PG_DATA_DIR}/postgresql.conf"
        PG_HBA="${PG_DATA_DIR}/pg_hba.conf"
    else
        PG_DATA_DIR="/var/lib/postgresql/${PG_VERSION}/main"
        PG_CONF="/etc/postgresql/${PG_VERSION}/main/postgresql.conf"
        PG_HBA="/etc/postgresql/${PG_VERSION}/main/pg_hba.conf"
    fi

    log_info "配置文件路径: $PG_CONF"

    # 备份原配置
    if [[ -f "$PG_CONF" ]]; then
        cp "$PG_CONF" "${PG_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
    fi
    if [[ -f "$PG_HBA" ]]; then
        cp "$PG_HBA" "${PG_HBA}.bak.$(date +%Y%m%d_%H%M%S)"
    fi

    # 修改 postgresql.conf
    sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF"
    sed -i "s/^listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF"
    sed -i "s/^#port = 5432/port = $PG_PORT/" "$PG_CONF"
    sed -i "s/^port = 5432/port = $PG_PORT/" "$PG_CONF"

    # 优化 shared_buffers (设置为系统内存的25%)
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    SHARED_BUFFERS=$((TOTAL_MEM / 4))
    if [[ $SHARED_BUFFERS -lt 128 ]]; then
        SHARED_BUFFERS=128
    fi

    sed -i "s/^shared_buffers = .*/shared_buffers = ${SHARED_BUFFERS}MB/" "$PG_CONF"
    if ! grep -q "^shared_buffers" "$PG_CONF"; then
        echo "shared_buffers = ${SHARED_BUFFERS}MB" >> "$PG_CONF"
    fi

    # 其他优化参数
    cat >> "$PG_CONF" <<EOF

# Custom Configuration
effective_cache_size = $((TOTAL_MEM * 3 / 4))MB
maintenance_work_mem = $((TOTAL_MEM / 16))MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
EOF

    # 配置 pg_hba.conf
    if [[ "$ENABLE_REMOTE_ACCESS" == true ]]; then
        # 允许远程访问 (使用密码认证)
        echo "host    all             all             0.0.0.0/0               md5" >> "$PG_HBA"
        echo "host    all             all             ::/0                    md5" >> "$PG_HBA"
        log_success "已配置远程访问"
    fi

    # 确保本地访问使用 md5 认证
    sed -i 's/^local   all             all                                     peer/local   all             all                                     md5/' "$PG_HBA"
    sed -i 's/^host    all             all             127.0.0.1\/32            ident/host    all             all             127.0.0.1\/32            md5/' "$PG_HBA"

    log_success "PostgreSQL 配置完成"
}

# 初始化 PostgreSQL (设置密码和创建数据库)
initialize_postgresql() {
    log_info "初始化 PostgreSQL..."

    # 查找pg_hba.conf路径
    if [[ $PKG_MANAGER == "yum" ]]; then
        if [[ -d "/var/lib/pgsql/${PG_VERSION}/data" ]]; then
            PG_HBA="/var/lib/pgsql/${PG_VERSION}/data/pg_hba.conf"
        elif [[ -d "/var/lib/pgsql/data" ]]; then
            PG_HBA="/var/lib/pgsql/data/pg_hba.conf"
        fi
    else
        PG_HBA="/etc/postgresql/${PG_VERSION}/main/pg_hba.conf"
    fi

    # 临时配置trust认证以便修改密码
    log_info "临时启用trust认证..."
    cp "$PG_HBA" "${PG_HBA}.tmp_backup"
    sed -i 's/^local   all             all                                     peer/local   all             all                                     trust/' "$PG_HBA"
    sed -i 's/^local   all             all                                     md5/local   all             all                                     trust/' "$PG_HBA"
    sed -i 's/^host    all             all             127.0.0.1\/32            ident/host    all             all             127.0.0.1\/32            trust/' "$PG_HBA"
    sed -i 's/^host    all             all             127.0.0.1\/32            md5/host    all             all             127.0.0.1\/32            trust/' "$PG_HBA"

    # 启动服务
    start_service

    sleep 3

    # 设置 postgres 用户密码
    log_info "设置postgres用户密码..."
    if su - postgres -c "psql -c \"ALTER USER postgres PASSWORD '$PG_PASSWORD';\"" &>/dev/null; then
        log_success "已设置 postgres 用户密码"
    else
        log_warn "设置密码可能失败，继续执行..."
    fi

    # 创建自定义数据库和用户
    if [[ -n "$PG_DB_NAME" ]]; then
        su - postgres -c "psql -c \"CREATE DATABASE $PG_DB_NAME;\"" 2>/dev/null || log_warn "数据库可能已存在"
        su - postgres -c "psql -c \"CREATE USER $PG_DB_USER WITH ENCRYPTED PASSWORD '$PG_DB_PASSWORD';\"" 2>/dev/null || log_warn "用户可能已存在"
        su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE $PG_DB_NAME TO $PG_DB_USER;\""
        log_success "已创建数据库 $PG_DB_NAME 和用户 $PG_DB_USER"
    fi

    # 恢复md5认证
    log_info "恢复md5认证..."
    mv "${PG_HBA}.tmp_backup" "$PG_HBA"

    # 重新加载配置
    if [[ $PKG_MANAGER == "yum" ]]; then
        PG_SERVICE=$(systemctl list-unit-files | grep -q "postgresql-${PG_VERSION}.service" && echo "postgresql-${PG_VERSION}" || echo "postgresql")
        systemctl reload $PG_SERVICE
    else
        systemctl reload postgresql
    fi

    sleep 5

    log_success "PostgreSQL 初始化完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."

    if command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            firewall-cmd --permanent --add-port=$PG_PORT/tcp
            firewall-cmd --reload
            log_success "防火墙规则已添加"
        fi
    elif command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            ufw allow $PG_PORT/tcp
            log_success "防火墙规则已添加"
        fi
    fi
}

# 启动服务
start_service() {
    log_info "启动 PostgreSQL 服务..."

    if [[ $PKG_MANAGER == "yum" ]]; then
        systemctl daemon-reload

        # 尝试官方版本的服务名,如果不存在则使用系统版本
        PG_SERVICE=""
        if systemctl list-unit-files | grep -q "postgresql-${PG_VERSION}.service"; then
            PG_SERVICE="postgresql-${PG_VERSION}"
        elif systemctl list-unit-files | grep -q "postgresql.service"; then
            PG_SERVICE="postgresql"
        else
            log_error "无法找到PostgreSQL服务"
            exit 1
        fi

        log_info "使用服务: $PG_SERVICE"
        systemctl enable $PG_SERVICE
        systemctl restart $PG_SERVICE

        sleep 2

        if systemctl is-active --quiet $PG_SERVICE; then
            log_success "PostgreSQL 服务启动成功"
        else
            log_error "PostgreSQL 服务启动失败"
            systemctl status $PG_SERVICE --no-pager
            exit 1
        fi
    else
        systemctl daemon-reload
        systemctl enable postgresql
        systemctl restart postgresql

        sleep 2

        if systemctl is-active --quiet postgresql; then
            log_success "PostgreSQL 服务启动成功"
        else
            log_error "PostgreSQL 服务启动失败"
            exit 1
        fi
    fi
}

# 验证安装
verify_installation() {
    log_info "验证 PostgreSQL 安装..."

    PG_VER=$(psql --version | awk '{print $3}')
    log_success "PostgreSQL 版本: $PG_VER"

    # 等待服务完全就绪
    sleep 3

    # 测试连接 (先尝试localhost，失败则尝试socket)
    if PGPASSWORD="$PG_PASSWORD" psql -U postgres -h localhost -c "SELECT 1;" &>/dev/null; then
        log_success "PostgreSQL 连接测试通过 (TCP)"
    elif PGPASSWORD="$PG_PASSWORD" psql -U postgres -c "SELECT 1;" &>/dev/null; then
        log_success "PostgreSQL 连接测试通过 (Socket)"
    else
        log_warn "PostgreSQL 连接测试失败，但服务已安装"
        log_info "请手动测试连接: PGPASSWORD='$PG_PASSWORD' psql -U postgres -h localhost"
        log_info "如果连接失败，请检查 /var/lib/pgsql/data/pg_hba.conf 配置"
    fi
}

# 生成安装报告
generate_report() {
    local REPORT_FILE="/tmp/install_postgresql_report_$(date +%Y%m%d_%H%M%S).txt"
    local SERVER_IP=$(hostname -I | awk '{print $1}')

    cat > "$REPORT_FILE" <<EOF
╔═══════════════════════════════════════════════════════════╗
║         PostgreSQL 安装报告                               ║
╚═══════════════════════════════════════════════════════════╝

安装时间: $(date '+%Y-%m-%d %H:%M:%S')
操作系统: $OS_NAME ($OS_VERSION)

【安装版本】
PostgreSQL: $(psql --version | awk '{print $3}')

【服务状态】
$(systemctl status postgresql-${PG_VERSION} 2>/dev/null || systemctl status postgresql 2>/dev/null | head -n 3)

【连接信息】
主机: $SERVER_IP
端口: $PG_PORT
超级用户: postgres
密码: $PG_PASSWORD
远程访问: $( [[ "$ENABLE_REMOTE_ACCESS" == true ]] && echo "已启用" || echo "已禁用" )

【自定义数据库】
$( [[ -n "$PG_DB_NAME" ]] && echo "数据库: $PG_DB_NAME" || echo "未创建" )
$( [[ -n "$PG_DB_USER" ]] && echo "用户: $PG_DB_USER" || echo "" )
$( [[ -n "$PG_DB_PASSWORD" ]] && echo "密码: $PG_DB_PASSWORD" || echo "" )

【连接命令】
本地连接:
  psql -U postgres -h localhost

远程连接 (如已启用):
  psql -h $SERVER_IP -p $PG_PORT -U postgres -d postgres

自定义数据库连接 (如已创建):
  psql -h $SERVER_IP -p $PG_PORT -U $PG_DB_USER -d $PG_DB_NAME

【配置文件】
$( [[ $PKG_MANAGER == "yum" ]] && echo "数据目录: /var/lib/pgsql/${PG_VERSION}/data" || echo "数据目录: /var/lib/postgresql/${PG_VERSION}/main" )
$( [[ $PKG_MANAGER == "yum" ]] && echo "主配置: /var/lib/pgsql/${PG_VERSION}/data/postgresql.conf" || echo "主配置: /etc/postgresql/${PG_VERSION}/main/postgresql.conf" )
$( [[ $PKG_MANAGER == "yum" ]] && echo "访问控制: /var/lib/pgsql/${PG_VERSION}/data/pg_hba.conf" || echo "访问控制: /etc/postgresql/${PG_VERSION}/main/pg_hba.conf" )

【管理命令】
启动服务:   systemctl start $( [[ $PKG_MANAGER == "yum" ]] && echo "postgresql-${PG_VERSION}" || echo "postgresql" )
停止服务:   systemctl stop $( [[ $PKG_MANAGER == "yum" ]] && echo "postgresql-${PG_VERSION}" || echo "postgresql" )
重启服务:   systemctl restart $( [[ $PKG_MANAGER == "yum" ]] && echo "postgresql-${PG_VERSION}" || echo "postgresql" )
查看状态:   systemctl status $( [[ $PKG_MANAGER == "yum" ]] && echo "postgresql-${PG_VERSION}" || echo "postgresql" )

【常用 SQL 命令】
连接数据库: psql -U postgres
列出数据库: \l
切换数据库: \c database_name
列出表:     \dt
查看用户:   \du
退出:       \q

【创建用户和数据库】
CREATE USER myuser WITH PASSWORD 'mypassword';
CREATE DATABASE mydb OWNER myuser;
GRANT ALL PRIVILEGES ON DATABASE mydb TO myuser;

【性能优化】
- Shared Buffers: ${SHARED_BUFFERS}MB (系统内存的25%)
- Effective Cache Size: $((TOTAL_MEM * 3 / 4))MB
- Maintenance Work Mem: $((TOTAL_MEM / 16))MB

【安全建议】
1. 定期修改 postgres 密码
2. 为不同应用创建专用数据库用户
3. 生产环境谨慎开启远程访问
4. 定期备份数据库
5. 监控慢查询日志

【备份命令】
导出数据库:
  pg_dump -U postgres -d dbname > backup.sql

导入数据库:
  psql -U postgres -d dbname < backup.sql

【注意事项】
⚠ 请妥善保管 postgres 密码: $PG_PASSWORD
$( [[ -n "$PG_DB_PASSWORD" ]] && echo "⚠ 请妥善保管 $PG_DB_USER 密码: $PG_DB_PASSWORD" || echo "" )
⚠ 数据目录: $PG_DATA_DIR
⚠ 建议定期备份数据

【安装日志】
$REPORT_FILE

EOF

    log_success "安装报告已生成: $REPORT_FILE"

    # 显示摘要
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         PostgreSQL 安装完成!                              ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}PostgreSQL 版本:${NC} $(psql --version | awk '{print $3}')"
    echo -e "${BLUE}服务状态:${NC} $(systemctl is-active postgresql-${PG_VERSION} 2>/dev/null || systemctl is-active postgresql 2>/dev/null)"
    echo -e "${BLUE}连接地址:${NC} $SERVER_IP:$PG_PORT"
    echo -e "${BLUE}超级用户:${NC} postgres"
    echo -e "${BLUE}密    码:${NC} $PG_PASSWORD"
    [[ -n "$PG_DB_NAME" ]] && echo -e "${BLUE}自定义库:${NC} $PG_DB_NAME (用户: $PG_DB_USER)"
    echo ""
    echo -e "${YELLOW}连接测试:${NC} psql -h $SERVER_IP -p $PG_PORT -U postgres -d postgres"
    echo -e "${YELLOW}报    告:${NC} $REPORT_FILE"
    echo ""
    echo -e "${RED}⚠ 请妥善保管密码，建议将报告内容保存到安全位置${NC}"
    echo ""
}

# 主函数
main() {
    print_header

    log_info "开始安装 PostgreSQL..."
    echo ""

    check_root
    detect_os

    # 检查前置依赖
    if command -v check_and_install_dependencies &>/dev/null; then
        log_info "检查前置依赖..."
        check_and_install_dependencies "PostgreSQL" "${POSTGRESQL_DEPENDENCIES[@]}"
        echo ""
    fi
    check_installed
    interactive_config

    # 安装
    if [[ $PKG_MANAGER == "yum" ]]; then
        install_postgresql_yum
    else
        install_postgresql_apt
    fi

    configure_postgresql
    initialize_postgresql
    configure_firewall
    verify_installation

    echo ""
    generate_report
}

# 执行主函数
main
