#!/bin/bash

################################################################################
# MongoDB 自动安装脚本
# 支持 CentOS/RHEL 7+, Ubuntu 18.04+, Kylin, UOS
# 功能:
#   - 安装 MongoDB 6.x 或 5.x (可选版本)
#   - 强制启用认证并设置管理员密码
#   - 密码复杂度验证 (12+ 字符)
#   - 交互式创建数据库和用户
#   - 配置 bindIp 和端口
#   - 优化 wiredTiger 缓存
#   - 禁用匿名访问
#   - 配置开机自启
#
# 使用方法:
#   sudo bash install_mongodb.sh
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
MONGO_VERSION="6.0"
MONGO_PORT=27017
MONGO_ADMIN_PASSWORD=""
MONGO_DB_NAME=""
MONGO_DB_USER=""
MONGO_DB_PASSWORD=""
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
    echo "║          MongoDB 自动安装脚本 v1.0.0                     ║"
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

    # 长度检查 (至少12位)
    if [[ ${#password} -lt 12 ]]; then
        log_error "密码长度至少12位"
        return 1
    fi

    # 复杂度检查
    local has_upper=$(echo "$password" | grep -q '[A-Z]' && echo 1 || echo 0)
    local has_lower=$(echo "$password" | grep -q '[a-z]' && echo 1 || echo 0)
    local has_digit=$(echo "$password" | grep -q '[0-9]' && echo 1 || echo 0)
    local has_special=$(echo "$password" | grep -q '[!@#$%^&*()_+=-]' && echo 1 || echo 0)

    local complexity=$((has_upper + has_lower + has_digit + has_special))

    if [[ $complexity -lt 3 ]]; then
        log_error "密码必须包含以下至少3种: 大写字母、小写字母、数字、特殊字符"
        return 1
    fi

    # 弱密码检查
    local weak_passwords=("mongodb123456" "admin123456" "password123456" "123456789012")
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
    log_info "MongoDB 安装配置"
    echo ""

    # 选择版本
    echo -e "${BLUE}请选择 MongoDB 版本:${NC}"
    echo "  1) MongoDB 6.0 (推荐)"
    echo "  2) MongoDB 5.0"
    read -p "请选择 [1-2, 默认 1]: " version_choice

    case $version_choice in
        2)
            MONGO_VERSION="5.0"
            log_info "选择版本: MongoDB 5.0"
            ;;
        *)
            MONGO_VERSION="6.0"
            log_info "选择版本: MongoDB 6.0"
            ;;
    esac

    # 设置管理员密码 (MANDATORY)
    echo ""
    log_info "设置 MongoDB 管理员密码 (admin 用户)"
    echo -e "${YELLOW}密码要求:${NC}"
    echo "  - 至少12位长度"
    echo "  - 包含大写字母、小写字母、数字、特殊字符中的至少3种"
    echo "  - 不能使用常见弱密码"
    echo ""

    local password1=""
    local password2=""
    local attempts=0
    local max_attempts=3

    while [[ $attempts -lt $max_attempts ]]; do
        read -s -p "请输入管理员密码: " password1
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

        MONGO_ADMIN_PASSWORD="$password1"
        log_success "管理员密码设置成功"
        break
    done

    if [[ -z "$MONGO_ADMIN_PASSWORD" ]]; then
        log_error "管理员密码设置失败"
        exit 1
    fi

    # 创建自定义数据库和用户
    echo ""
    read -p "是否创建自定义数据库和用户? (y/n, 默认 n): " create_db_choice
    if [[ $create_db_choice =~ ^[Yy]$ ]]; then
        read -p "请输入数据库名称: " MONGO_DB_NAME
        read -p "请输入数据库用户名: " MONGO_DB_USER

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

            MONGO_DB_PASSWORD="$db_pwd1"
            log_success "数据库用户密码设置成功"
            break
        done

        if [[ -z "$MONGO_DB_PASSWORD" ]]; then
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
    if command -v mongod &> /dev/null; then
        CURRENT_VERSION=$(mongod --version | grep "db version" | awk '{print $3}')
        log_warn "检测到已安装 MongoDB: $CURRENT_VERSION"
        read -p "是否继续安装? (y/n): " -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

# 安装 MongoDB (CentOS/RHEL)
install_mongodb_yum() {
    log_info "安装 MongoDB $MONGO_VERSION..."

    # 麒麟系统特殊处理
    if [[ "$OS" == "kylin" ]]; then
        log_info "检测到麒麟系统,使用系统自带仓库..."

        # 尝试直接安装系统自带的MongoDB
        log_info "从系统仓库安装 MongoDB..."
        if yum install -y mongodb-server mongodb 2>/dev/null; then
            log_success "MongoDB 安装成功 (系统版本)"
            MONGO_VERSION=$(mongod --version 2>/dev/null | grep "db version" | awk '{print $3}' || echo "unknown")
            log_info "实际安装版本: MongoDB $MONGO_VERSION"
            return 0
        else
            log_error "系统仓库安装失败,请检查yum源配置"
            log_info "可用的MongoDB包:"
            yum search mongodb 2>/dev/null | grep "^mongodb"
            exit 1
        fi
    fi

    # 标准CentOS/RHEL系统,使用官方仓库
    log_info "使用MongoDB官方仓库..."

    # 创建 MongoDB 仓库文件
    cat > /etc/yum.repos.d/mongodb-org-${MONGO_VERSION}.repo <<EOF
[mongodb-org-${MONGO_VERSION}]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/${MONGO_VERSION}/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-${MONGO_VERSION}.asc
EOF

    # 安装 MongoDB
    if ! yum install -y mongodb-org 2>/dev/null; then
        log_warn "官方仓库安装失败,尝试使用系统仓库..."
        if yum install -y mongodb-server mongodb 2>/dev/null; then
            log_success "MongoDB 安装成功 (系统版本)"
            MONGO_VERSION=$(mongod --version 2>/dev/null | grep "db version" | awk '{print $3}' || echo "unknown")
            log_info "实际安装版本: MongoDB $MONGO_VERSION"
            return 0
        else
            log_error "无法安装MongoDB,请检查yum源配置"
            exit 1
        fi
    fi

    log_success "MongoDB 安装完成"
}

# 安装 MongoDB (Ubuntu/Debian)
install_mongodb_apt() {
    log_info "安装 MongoDB $MONGO_VERSION..."

    # 导入公钥
    wget -qO - https://www.mongodb.org/static/pgp/server-${MONGO_VERSION}.asc | apt-key add -

    # 创建列表文件
    if [[ "$OS" == "ubuntu" ]]; then
        echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/${MONGO_VERSION} multiverse" | tee /etc/apt/sources.list.d/mongodb-org-${MONGO_VERSION}.list
    elif [[ "$OS" == "debian" ]]; then
        echo "deb http://repo.mongodb.org/apt/debian $(lsb_release -cs)/mongodb-org/${MONGO_VERSION} main" | tee /etc/apt/sources.list.d/mongodb-org-${MONGO_VERSION}.list
    fi

    # 更新并安装
    apt-get update -qq
    apt-get install -y mongodb-org

    log_success "MongoDB 安装完成"
}

# 配置 MongoDB
configure_mongodb() {
    log_info "配置 MongoDB..."

    local MONGO_CONF="/etc/mongod.conf"

    # 备份原配置
    if [[ -f "$MONGO_CONF" ]]; then
        cp "$MONGO_CONF" "${MONGO_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
    fi

    # 计算 wiredTiger 缓存大小 (系统内存的50% - 1GB)
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    WT_CACHE=$(( (TOTAL_MEM / 2) - 1024 ))
    if [[ $WT_CACHE -lt 256 ]]; then
        WT_CACHE=256
    fi

    # 配置 bindIp
    local BIND_IP="127.0.0.1"
    if [[ "$ENABLE_REMOTE_ACCESS" == true ]]; then
        BIND_IP="0.0.0.0"
    fi

    # 重写配置文件
    cat > "$MONGO_CONF" <<EOF
# MongoDB Configuration File

# Where and how to store data.
storage:
  dbPath: /var/lib/mongo
  journal:
    enabled: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: $(echo "scale=1; $WT_CACHE / 1024" | bc)

# Where to write logging data.
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

# Network interfaces
net:
  port: $MONGO_PORT
  bindIp: $BIND_IP

# Process management
processManagement:
  timeZoneInfo: /usr/share/zoneinfo

# Security
security:
  authorization: enabled

# Replication (optional)
#replication:
#  replSetName: "rs0"
EOF

    # 创建必要的目录
    mkdir -p /var/lib/mongo /var/log/mongodb
    chown -R mongod:mongod /var/lib/mongo /var/log/mongodb

    log_success "MongoDB 配置完成"
}

# 初始化 MongoDB (创建管理员和数据库用户)
initialize_mongodb() {
    log_info "初始化 MongoDB..."

    # 启动服务 (无认证模式)
    systemctl start mongod

    sleep 5

    # 创建管理员用户
    mongosh --quiet <<EOF
use admin
db.createUser({
  user: "admin",
  pwd: "$MONGO_ADMIN_PASSWORD",
  roles: [
    { role: "userAdminAnyDatabase", db: "admin" },
    { role: "readWriteAnyDatabase", db: "admin" },
    { role: "dbAdminAnyDatabase", db: "admin" },
    { role: "clusterAdmin", db: "admin" }
  ]
})
EOF

    log_success "已创建管理员用户 admin"

    # 创建自定义数据库用户
    if [[ -n "$MONGO_DB_NAME" ]]; then
        mongosh --quiet <<EOF
use $MONGO_DB_NAME
db.createUser({
  user: "$MONGO_DB_USER",
  pwd: "$MONGO_DB_PASSWORD",
  roles: [
    { role: "readWrite", db: "$MONGO_DB_NAME" }
  ]
})
EOF
        log_success "已创建数据库 $MONGO_DB_NAME 和用户 $MONGO_DB_USER"
    fi

    # 重启服务以启用认证
    systemctl restart mongod
    sleep 3
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."

    if command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            firewall-cmd --permanent --add-port=$MONGO_PORT/tcp
            firewall-cmd --reload
            log_success "防火墙规则已添加"
        fi
    elif command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            ufw allow $MONGO_PORT/tcp
            log_success "防火墙规则已添加"
        fi
    fi
}

# 启动服务
start_service() {
    log_info "启动 MongoDB 服务..."

    systemctl daemon-reload
    systemctl enable mongod
    systemctl restart mongod

    sleep 3

    if systemctl is-active --quiet mongod; then
        log_success "MongoDB 服务启动成功"
    else
        log_error "MongoDB 服务启动失败"
        systemctl status mongod --no-pager
        exit 1
    fi
}

# 验证安装
verify_installation() {
    log_info "验证 MongoDB 安装..."

    MONGO_VER=$(mongod --version | grep "db version" | awk '{print $3}')
    log_success "MongoDB 版本: $MONGO_VER"

    # 测试连接
    if mongosh --quiet -u admin -p "$MONGO_ADMIN_PASSWORD" --authenticationDatabase admin --eval "db.adminCommand('ping')" &>/dev/null; then
        log_success "MongoDB 连接测试通过"
    else
        log_error "MongoDB 连接测试失败"
        exit 1
    fi
}

# 生成安装报告
generate_report() {
    local REPORT_FILE="/tmp/install_mongodb_report_$(date +%Y%m%d_%H%M%S).txt"
    local SERVER_IP=$(hostname -I | awk '{print $1}')

    cat > "$REPORT_FILE" <<EOF
╔═══════════════════════════════════════════════════════════╗
║          MongoDB 安装报告                                 ║
╚═══════════════════════════════════════════════════════════╝

安装时间: $(date '+%Y-%m-%d %H:%M:%S')
操作系统: $OS_NAME ($OS_VERSION)

【安装版本】
MongoDB: $(mongod --version | grep "db version" | awk '{print $3}')

【服务状态】
$(systemctl status mongod --no-pager | head -n 3)

【连接信息】
主机: $SERVER_IP
端口: $MONGO_PORT
管理员: admin
密码: $MONGO_ADMIN_PASSWORD
远程访问: $( [[ "$ENABLE_REMOTE_ACCESS" == true ]] && echo "已启用" || echo "已禁用" )

【自定义数据库】
$( [[ -n "$MONGO_DB_NAME" ]] && echo "数据库: $MONGO_DB_NAME" || echo "未创建" )
$( [[ -n "$MONGO_DB_USER" ]] && echo "用户: $MONGO_DB_USER" || echo "" )
$( [[ -n "$MONGO_DB_PASSWORD" ]] && echo "密码: $MONGO_DB_PASSWORD" || echo "" )

【连接命令】
本地连接 (管理员):
  mongosh -u admin -p '$MONGO_ADMIN_PASSWORD' --authenticationDatabase admin

远程连接 (管理员):
  mongosh "mongodb://admin:$MONGO_ADMIN_PASSWORD@$SERVER_IP:$MONGO_PORT/?authSource=admin"

自定义数据库连接 (如已创建):
  mongosh "mongodb://$MONGO_DB_USER:$MONGO_DB_PASSWORD@$SERVER_IP:$MONGO_PORT/$MONGO_DB_NAME"

Python 连接示例:
  from pymongo import MongoClient
  client = MongoClient('mongodb://admin:$MONGO_ADMIN_PASSWORD@$SERVER_IP:$MONGO_PORT/?authSource=admin')

【配置文件】
主配置: /etc/mongod.conf
数据目录: /var/lib/mongo
日志文件: /var/log/mongodb/mongod.log

【管理命令】
启动服务:   systemctl start mongod
停止服务:   systemctl stop mongod
重启服务:   systemctl restart mongod
查看状态:   systemctl status mongod
查看日志:   tail -f /var/log/mongodb/mongod.log

【MongoDB Shell 命令】
连接:       mongosh -u admin -p '$MONGO_ADMIN_PASSWORD' --authenticationDatabase admin
查看数据库: show dbs
切换数据库: use database_name
查看集合:   show collections
查看用户:   db.getUsers()
退出:       exit

【创建用户和数据库】
use mydb
db.createUser({
  user: "myuser",
  pwd: "mypassword",
  roles: [{ role: "readWrite", db: "mydb" }]
})

【安全配置】
✓ 已启用认证
✓ 已创建管理员用户
✓ 已禁用匿名访问
$( [[ "$ENABLE_REMOTE_ACCESS" == false ]] && echo "✓ 仅允许本地访问" || echo "⚠ 已允许远程访问" )

【性能优化】
WiredTiger 缓存: $(echo "scale=1; $WT_CACHE / 1024" | bc)GB
建议根据实际负载调整缓存大小

【备份命令】
导出数据库:
  mongodump -u admin -p '$MONGO_ADMIN_PASSWORD' --authenticationDatabase admin --db $MONGO_DB_NAME --out /backup/

导入数据库:
  mongorestore -u admin -p '$MONGO_ADMIN_PASSWORD' --authenticationDatabase admin --db $MONGO_DB_NAME /backup/$MONGO_DB_NAME/

【注意事项】
⚠ 请妥善保管管理员密码: $MONGO_ADMIN_PASSWORD
$( [[ -n "$MONGO_DB_PASSWORD" ]] && echo "⚠ 请妥善保管 $MONGO_DB_USER 密码: $MONGO_DB_PASSWORD" || echo "" )
⚠ 生产环境建议配置副本集以提高可用性
⚠ 定期备份数据库
⚠ 监控磁盘空间和性能指标

【安装日志】
$REPORT_FILE

EOF

    log_success "安装报告已生成: $REPORT_FILE"

    # 显示摘要
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          MongoDB 安装完成!                                ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}MongoDB 版本:${NC} $(mongod --version | grep "db version" | awk '{print $3}')"
    echo -e "${BLUE}服务状态:${NC} $(systemctl is-active mongod)"
    echo -e "${BLUE}连接地址:${NC} $SERVER_IP:$MONGO_PORT"
    echo -e "${BLUE}管理员:${NC} admin"
    echo -e "${BLUE}密    码:${NC} $MONGO_ADMIN_PASSWORD"
    [[ -n "$MONGO_DB_NAME" ]] && echo -e "${BLUE}自定义库:${NC} $MONGO_DB_NAME (用户: $MONGO_DB_USER)"
    echo ""
    echo -e "${YELLOW}连接测试:${NC} mongosh -u admin -p '$MONGO_ADMIN_PASSWORD' --authenticationDatabase admin"
    echo -e "${YELLOW}报    告:${NC} $REPORT_FILE"
    echo ""
    echo -e "${RED}⚠ 请妥善保管密码，建议将报告内容保存到安全位置${NC}"
    echo ""
}

# 主函数
main() {
    print_header

    log_info "开始安装 MongoDB..."
    echo ""

    check_root
    detect_os

    # 检查前置依赖
    if command -v check_and_install_dependencies &>/dev/null; then
        log_info "检查前置依赖..."
        check_and_install_dependencies "MongoDB" "${MONGODB_DEPENDENCIES[@]}"
        echo ""
    fi
    check_installed
    interactive_config

    # 安装
    if [[ $PKG_MANAGER == "yum" ]]; then
        install_mongodb_yum
    else
        install_mongodb_apt
    fi

    configure_mongodb
    initialize_mongodb
    configure_firewall
    start_service
    verify_installation

    echo ""
    generate_report
}

# 执行主函数
main
