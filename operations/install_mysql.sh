#!/bin/bash

################################################################################
# MySQL 自动安装脚本
# 支持 CentOS/RHEL 7+, Ubuntu 18.04+, Kylin, UOS
# 功能:
#   - 安装 MySQL 8.0 或 5.7
#   - 交互式设置 root 密码 (首次安装即设置)
#   - 密码复杂度验证
#   - 配置字符集 utf8mb4
#   - 优化配置参数
#   - 可选远程访问
#   - 配置开机自启
#
# 使用方法:
#   sudo bash install_mysql.sh
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
MYSQL_VERSION="8.0"
MYSQL_PORT=3306
MYSQL_ROOT_PASSWORD=""
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
    echo "║           MySQL 自动安装脚本 v1.0.0                      ║"
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
    log_info "MySQL 安装配置"
    echo ""

    # 选择版本
    echo -e "${BLUE}请选择 MySQL 版本:${NC}"
    echo "  1) MySQL 8.0 (推荐)"
    echo "  2) MySQL 5.7"
    read -p "请选择 [1-2, 默认 1]: " version_choice

    case $version_choice in
        2)
            MYSQL_VERSION="5.7"
            log_info "选择版本: MySQL 5.7"
            ;;
        *)
            MYSQL_VERSION="8.0"
            log_info "选择版本: MySQL 8.0"
            ;;
    esac

    # 设置 root 密码
    echo ""
    log_info "设置 MySQL root 密码"
    echo -e "${YELLOW}密码要求:${NC}"
    echo "  - 至少8位长度"
    echo "  - 必须包含大写字母、小写字母、数字"
    echo ""

    local password1=""
    local password2=""
    local attempts=0
    local max_attempts=3

    while [[ $attempts -lt $max_attempts ]]; do
        read -s -p "请输入 MySQL root 密码: " password1
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

        MYSQL_ROOT_PASSWORD="$password1"
        log_success "密码设置成功"
        break
    done

    if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
        log_error "密码设置失败"
        exit 1
    fi

    # 是否允许远程访问
    echo ""
    read -p "是否允许 root 远程访问? (y/n, 默认 n): " remote_choice
    if [[ $remote_choice =~ ^[Yy]$ ]]; then
        ENABLE_REMOTE_ACCESS=true
        log_warn "已启用远程访问 (生产环境不推荐)"
    else
        log_info "仅允许本地访问 (推荐)"
    fi
}

# 检查是否已安装
check_installed() {
    if command -v mysql &> /dev/null; then
        CURRENT_VERSION=$(mysql --version 2>&1 | awk '{print $5}' | cut -d',' -f1)
        log_warn "检测到已安装 MySQL: $CURRENT_VERSION"
        read -p "是否继续安装? (y/n): " -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

# 安装 MySQL (CentOS/RHEL/Kylin)
install_mysql_yum() {
    log_info "安装 MySQL $MYSQL_VERSION..."

    # 卸载 MariaDB
    yum remove -y mariadb-libs mariadb-server 2>/dev/null || true

    # 麒麟系统特殊处理
    if [[ "$OS" == "kylin" ]]; then
        log_info "检测到麒麟系统,使用系统自带仓库..."

        # 尝试直接安装系统自带的MySQL
        log_info "从系统仓库安装 MySQL..."
        if yum install -y mysql-server mysql 2>/dev/null; then
            log_success "MySQL 安装成功 (系统版本)"
            MYSQL_VERSION=$(mysql -V 2>/dev/null | grep -oP '\d+\.\d+' | head -1 || echo "unknown")
            log_info "实际安装版本: MySQL $MYSQL_VERSION"
            return 0
        else
            log_error "系统仓库安装失败,请检查yum源配置"
            log_info "可用的MySQL包:"
            yum search mysql 2>/dev/null | grep "^mysql-server"
            exit 1
        fi
    fi

    # 标准CentOS/RHEL系统,使用官方仓库
    log_info "使用MySQL官方仓库..."

    # 添加 MySQL 仓库
    if [[ "$MYSQL_VERSION" == "8.0" ]]; then
        if ! yum install -y https://dev.mysql.com/get/mysql80-community-release-el$(rpm -E %rhel)-1.noarch.rpm 2>/dev/null; then
            log_warn "官方仓库安装失败,尝试使用系统仓库..."
            yum install -y mysql-server mysql || exit 1
            MYSQL_VERSION=$(mysql -V 2>/dev/null | grep -oP '\d+\.\d+' | head -1 || echo "unknown")
            log_info "实际安装版本: MySQL $MYSQL_VERSION"
            return 0
        fi
    else
        if ! yum install -y https://dev.mysql.com/get/mysql57-community-release-el$(rpm -E %rhel)-1.noarch.rpm 2>/dev/null; then
            log_warn "官方仓库安装失败,尝试使用系统仓库..."
            yum install -y mysql-server mysql || exit 1
            MYSQL_VERSION=$(mysql -V 2>/dev/null | grep -oP '\d+\.\d+' | head -1 || echo "unknown")
            log_info "实际安装版本: MySQL $MYSQL_VERSION"
            return 0
        fi
    fi

    # 安装 MySQL
    yum install -y mysql-community-server

    log_success "MySQL 安装完成"
}

# 安装 MySQL (Ubuntu/Debian)
install_mysql_apt() {
    log_info "安装 MySQL $MYSQL_VERSION..."

    # 设置自动化安装 (不交互)
    export DEBIAN_FRONTEND=noninteractive

    # 预配置 root 密码
    echo "mysql-community-server mysql-community-server/root-pass password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
    echo "mysql-community-server mysql-community-server/re-root-pass password $MYSQL_ROOT_PASSWORD" | debconf-set-selections

    # 添加 MySQL APT 仓库
    wget https://dev.mysql.com/get/mysql-apt-config_0.8.29-1_all.deb -O /tmp/mysql-apt-config.deb
    dpkg -i /tmp/mysql-apt-config.deb || true
    apt-get update -qq

    # 安装 MySQL
    apt-get install -y mysql-server mysql-client

    log_success "MySQL 安装完成"
}

# 配置 MySQL
configure_mysql() {
    log_info "配置 MySQL..."

    local MY_CNF="/etc/my.cnf"
    if [[ ! -f "$MY_CNF" ]]; then
        MY_CNF="/etc/mysql/my.cnf"
    fi

    # 备份原配置
    if [[ -f "$MY_CNF" ]]; then
        cp "$MY_CNF" "${MY_CNF}.bak.$(date +%Y%m%d_%H%M%S)"
    fi

    # 创建自定义配置文件
    mkdir -p /etc/mysql/conf.d

    cat > /etc/mysql/conf.d/custom.cnf <<EOF
[mysqld]
# 基本设置
port = $MYSQL_PORT
datadir = /var/lib/mysql
socket = /var/lib/mysql/mysql.sock
pid-file = /var/run/mysqld/mysqld.pid

# 字符集
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
init_connect = 'SET NAMES utf8mb4'

# 网络设置
bind-address = 0.0.0.0
max_connections = 500
max_connect_errors = 100

# InnoDB 设置
innodb_buffer_pool_size = 512M
innodb_log_file_size = 128M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT

# 日志设置
log-error = /var/log/mysql/error.log
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2

# 二进制日志
server-id = 1
log-bin = /var/log/mysql/mysql-bin
binlog_format = ROW
expire_logs_days = 7

[client]
default-character-set = utf8mb4
EOF

    # 创建日志目录
    mkdir -p /var/log/mysql
    chown -R mysql:mysql /var/log/mysql

    log_success "MySQL 配置完成"
}

# 初始化 MySQL (设置 root 密码)
initialize_mysql() {
    log_info "初始化 MySQL..."

    # 启动 MySQL
    systemctl start mysqld || systemctl start mysql

    sleep 3

    if [[ $PKG_MANAGER == "yum" ]]; then
        # CentOS: 获取临时密码并修改
        if [[ "$MYSQL_VERSION" == "8.0" ]]; then
            TEMP_PASSWORD=$(grep 'temporary password' /var/log/mysqld.log 2>/dev/null | tail -1 | awk '{print $NF}')

            if [[ -n "$TEMP_PASSWORD" ]]; then
                log_info "检测到临时密码，正在修改..."

                mysql -u root -p"$TEMP_PASSWORD" --connect-expired-password <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';
FLUSH PRIVILEGES;
EOF
            fi
        else
            # MySQL 5.7
            TEMP_PASSWORD=$(grep 'temporary password' /var/log/mysqld.log 2>/dev/null | tail -1 | awk '{print $NF}')

            if [[ -n "$TEMP_PASSWORD" ]]; then
                mysql -u root -p"$TEMP_PASSWORD" --connect-expired-password <<EOF
SET PASSWORD = PASSWORD('$MYSQL_ROOT_PASSWORD');
FLUSH PRIVILEGES;
EOF
            fi
        fi
    fi

    # 创建远程访问用户 (如果启用)
    if [[ "$ENABLE_REMOTE_ACCESS" == true ]]; then
        mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
        log_success "已创建远程访问权限"
    fi

    # 删除匿名用户和测试数据库
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

    log_success "MySQL 初始化完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."

    if command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            firewall-cmd --permanent --add-port=$MYSQL_PORT/tcp
            firewall-cmd --reload
            log_success "防火墙规则已添加"
        fi
    elif command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            ufw allow $MYSQL_PORT/tcp
            log_success "防火墙规则已添加"
        fi
    fi
}

# 启动服务
start_service() {
    log_info "启动 MySQL 服务..."

    systemctl daemon-reload
    systemctl enable mysqld 2>/dev/null || systemctl enable mysql
    systemctl restart mysqld 2>/dev/null || systemctl restart mysql

    sleep 2

    if systemctl is-active --quiet mysqld || systemctl is-active --quiet mysql; then
        log_success "MySQL 服务启动成功"
    else
        log_error "MySQL 服务启动失败"
        exit 1
    fi
}

# 验证安装
verify_installation() {
    log_info "验证 MySQL 安装..."

    MYSQL_VER=$(mysql -V | awk '{print $5}' | cut -d',' -f1)
    log_success "MySQL 版本: $MYSQL_VER"

    # 测试连接
    if mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1;" &>/dev/null; then
        log_success "MySQL 连接测试通过"
    else
        log_error "MySQL 连接测试失败"
        exit 1
    fi
}

# 生成安装报告
generate_report() {
    local REPORT_FILE="/tmp/install_mysql_report_$(date +%Y%m%d_%H%M%S).txt"
    local SERVER_IP=$(hostname -I | awk '{print $1}')

    cat > "$REPORT_FILE" <<EOF
╔═══════════════════════════════════════════════════════════╗
║           MySQL 安装报告                                  ║
╚═══════════════════════════════════════════════════════════╝

安装时间: $(date '+%Y-%m-%d %H:%M:%S')
操作系统: $OS_NAME ($OS_VERSION)

【安装版本】
MySQL: $(mysql -V | awk '{print $5}' | cut -d',' -f1)

【服务状态】
$(systemctl status mysqld 2>/dev/null || systemctl status mysql 2>/dev/null | head -n 3)

【连接信息】
主机: $SERVER_IP
端口: $MYSQL_PORT
用户: root
密码: $MYSQL_ROOT_PASSWORD
远程访问: $( [[ "$ENABLE_REMOTE_ACCESS" == true ]] && echo "已启用" || echo "已禁用" )

【连接命令】
本地连接:
  mysql -u root -p'$MYSQL_ROOT_PASSWORD'

远程连接 (如已启用):
  mysql -h $SERVER_IP -P $MYSQL_PORT -u root -p'$MYSQL_ROOT_PASSWORD'

【配置文件】
主配置: /etc/my.cnf 或 /etc/mysql/my.cnf
自定义配置: /etc/mysql/conf.d/custom.cnf
数据目录: /var/lib/mysql
日志目录: /var/log/mysql

【管理命令】
启动服务:   systemctl start mysqld
停止服务:   systemctl stop mysqld
重启服务:   systemctl restart mysqld
查看状态:   systemctl status mysqld

【MySQL 命令】
连接数据库: mysql -u root -p
查看数据库: SHOW DATABASES;
创建数据库: CREATE DATABASE dbname CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
创建用户:   CREATE USER 'username'@'%' IDENTIFIED BY 'password';
授权:       GRANT ALL PRIVILEGES ON dbname.* TO 'username'@'%';
刷新权限:   FLUSH PRIVILEGES;

【常用查询】
查看版本:   SELECT VERSION();
查看用户:   SELECT user, host FROM mysql.user;
查看进程:   SHOW PROCESSLIST;
查看状态:   SHOW STATUS;
查看变量:   SHOW VARIABLES LIKE '%char%';

【性能优化】
- InnoDB 缓冲池: 512MB
- 最大连接数: 500
- 慢查询日志: 已启用 (>2秒)
- 二进制日志: 已启用

【安全建议】
1. 定期修改 root 密码
2. 创建专用数据库用户，避免使用 root
3. 禁止 root 远程访问 (生产环境)
4. 定期备份数据库
5. 监控慢查询日志

【备份命令】
导出数据库:
  mysqldump -u root -p'$MYSQL_ROOT_PASSWORD' dbname > backup.sql

导入数据库:
  mysql -u root -p'$MYSQL_ROOT_PASSWORD' dbname < backup.sql

【注意事项】
⚠ 请妥善保管 root 密码: $MYSQL_ROOT_PASSWORD
⚠ 字符集已配置为 utf8mb4
⚠ 二进制日志保留 7 天
⚠ 建议定期备份数据

【安装日志】
$REPORT_FILE

EOF

    log_success "安装报告已生成: $REPORT_FILE"

    # 显示摘要
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           MySQL 安装完成!                                 ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}MySQL 版本:${NC} $(mysql -V | awk '{print $5}' | cut -d',' -f1)"
    echo -e "${BLUE}服务状态:${NC} $(systemctl is-active mysqld 2>/dev/null || systemctl is-active mysql 2>/dev/null)"
    echo -e "${BLUE}连接地址:${NC} $SERVER_IP:$MYSQL_PORT"
    echo -e "${BLUE}Root密码:${NC} $MYSQL_ROOT_PASSWORD"
    echo ""
    echo -e "${YELLOW}连接测试:${NC} mysql -h $SERVER_IP -P $MYSQL_PORT -u root -p'$MYSQL_ROOT_PASSWORD' -e 'SELECT 1;'"
    echo -e "${YELLOW}报    告:${NC} $REPORT_FILE"
    echo ""
    echo -e "${RED}⚠ 请妥善保管密码，建议将报告内容保存到安全位置${NC}"
    echo ""
}

# 主函数
main() {
    print_header

    # 初始化进度显示（8个主要步骤）
    progress_init "MySQL 数据库" 8
    progress_show_tasks \
        "检查root权限" \
        "检测操作系统" \
        "检查现有安装" \
        "交互式配置" \
        "安装MySQL包" \
        "配置MySQL" \
        "启动服务" \
        "验证安装"

    log_info "开始安装 MySQL..."
    echo ""

    # Step 1
    progress_step 1 "检查root权限..."
    check_root
    progress_success "root权限验证通过"
    echo ""

    # Step 2
    progress_step 2 "检测操作系统..."
    detect_os

    # 检查前置依赖
    if command -v check_and_install_dependencies &>/dev/null; then
        log_info "检查前置依赖..."
        check_and_install_dependencies "MySQL" "${MYSQL_DEPENDENCIES[@]}"
        echo ""
    fi
    progress_success "操作系统检测完成: $OS_NAME"
    echo ""

    # Step 3
    progress_step 3 "检查现有安装..."
    check_installed
    progress_success "安装前检查完成"
    echo ""

    # Step 4
    progress_step 4 "交互式配置..."
    interactive_config
    progress_success "配置完成"
    echo ""

    # Step 5
    progress_step 5 "安装MySQL包..."
    if [[ $PKG_MANAGER == "yum" ]]; then
        progress_status "使用 yum 进行安装..."
        install_mysql_yum
    else
        progress_status "使用 apt 进行安装..."
        install_mysql_apt
    fi
    progress_success "MySQL包安装完成"
    echo ""

    # Step 6
    progress_step 6 "配置MySQL参数..."
    configure_mysql
    progress_success "MySQL配置完成"
    echo ""

    # Step 7
    progress_step 7 "启动MySQL服务..."
    start_service
    progress_success "MySQL服务已启动"
    echo ""

    # Step 8
    progress_step 8 "验证安装..."
    initialize_mysql
    configure_firewall
    verify_installation
    progress_success "安装验证完成"
    echo ""

    progress_complete
    generate_report
}

# 执行主函数
main
