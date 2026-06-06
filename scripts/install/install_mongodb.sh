#!/bin/bash

################################################################################
# MongoDB 自动安装脚本 v2.0.0
# 支持系统: CentOS/RHEL 7+, Ubuntu 18.04+, Kylin Linux
# 功能: 系统检测、--auth 鉴权、admin 用户创建、网络检查、安装存档
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

OS_TYPE=""
PKG_MGR=""
MONGO_PORT="27017"
MONGO_ADMIN_USER="admin"
MONGO_ADMIN_PASS=""

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         MongoDB 自动安装脚本 v2.0.0                      ║"
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
    _setup_mongodb_repo
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

_setup_mongodb_repo() {
    log_info "配置 MongoDB 软件源..."
    if [[ "$PKG_MGR" == "apt" ]]; then
        if ! apt-cache show mongodb-org &>/dev/null 2>&1; then
            apt-get install -y gnupg curl 2>/dev/null || true
            # 使用阿里云 MongoDB 镜像源，跳过 GPG 验证
            local UBUNTU_CODENAME
            UBUNTU_CODENAME=$(lsb_release -cs 2>/dev/null || echo "focal")
            # 仅支持 focal/jammy，其余回退到 focal
            if [[ "$UBUNTU_CODENAME" != "focal" && "$UBUNTU_CODENAME" != "jammy" ]]; then
                UBUNTU_CODENAME="focal"
            fi

            echo "deb [ arch=amd64,arm64 trusted=yes ] https://mirrors.aliyun.com/mongodb/apt/ubuntu $UBUNTU_CODENAME/mongodb-org/7.0 multiverse" \
                > /etc/apt/sources.list.d/mongodb-org-7.0.list
            apt-get update -qq 2>/dev/null || true
        fi
    else
        cat > /etc/yum.repos.d/mongodb-org-7.0.repo <<'EOF'
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://mirrors.aliyun.com/mongodb/yum/redhat/$releasever/mongodb-org/7.0/x86_64/
gpgcheck=0
enabled=1
EOF
        yum makecache 2>/dev/null || true
    fi
    log_success "MongoDB 软件源配置完成"
}

install_deps() {
    log_info "安装前置依赖..."
    if [[ "$PKG_MGR" == "apt" ]]; then
        apt-get update -qq
        apt-get install -y curl gnupg lsb-release 2>/dev/null || true
    else
        yum install -y curl 2>/dev/null || true
    fi
    log_success "前置依赖检查完成"
}

prompt_config() {
    log_info "配置 MongoDB 安装参数..."
    echo ""

    read -p "请输入 MongoDB 监听端口 [默认: 27017]: " input_port
    [[ -n "$input_port" ]] && MONGO_PORT="$input_port"

    read -p "请输入 MongoDB 管理员用户名 [默认: admin]: " input_user
    [[ -n "$input_user" ]] && MONGO_ADMIN_USER="$input_user"

    while true; do
        read -s -p "请输入 MongoDB 管理员密码（必填，不少于8位）: " input_pass; echo
        if [[ ${#input_pass} -ge 8 ]]; then
            read -s -p "请再次输入密码确认: " input_pass2; echo
            if [[ "$input_pass" == "$input_pass2" ]]; then
                MONGO_ADMIN_PASS="$input_pass"; break
            else
                log_warn "两次输入的密码不一致，请重新输入"
            fi
        else
            log_warn "密码不能少于 8 位，请重新输入"
        fi
    done

    log_success "配置参数已确认: 端口=$MONGO_PORT, 管理员用户=$MONGO_ADMIN_USER"
    echo ""
}

install_mongodb() {
    log_info "安装 MongoDB..."
    if command -v mongod &>/dev/null; then
        log_warn "MongoDB 已安装，跳过安装步骤"
        return 0
    fi

    if [[ "$PKG_MGR" == "apt" ]]; then
        apt-get install -y mongodb-org
    else
        yum install -y mongodb-org 2>/dev/null || yum install -y mongodb-server mongodb 2>/dev/null || true
    fi
    log_success "MongoDB 安装完成"
}

configure_mongodb() {
    log_info "配置 MongoDB..."
    mkdir -p /var/lib/mongo /var/log/mongodb

    if id mongod &>/dev/null; then
        chown -R mongod:mongod /var/lib/mongo /var/log/mongodb 2>/dev/null || true
        # 修正 mongod.conf 中自定义 dbPath 的权限
        local DB_PATH
        DB_PATH=$(grep -E "^\s*path:|^\s*dbPath:" "$MONGO_CONF" 2>/dev/null | awk '{print $2}' | head -1)
        if [[ -n "$DB_PATH" && -d "$DB_PATH" ]]; then
            chown -R mongod:mongod "$DB_PATH" 2>/dev/null || true
        fi
    fi

    # 先不启用 auth，启动后创建用户再开启
    local MONGO_CONF=""
    if [[ -f /etc/mongod.conf ]]; then
        MONGO_CONF="/etc/mongod.conf"
    elif [[ -f /etc/mongodb.conf ]]; then
        MONGO_CONF="/etc/mongodb.conf"
    fi

    if [[ -n "$MONGO_CONF" ]]; then
        cp "$MONGO_CONF" "${MONGO_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
        # 设置端口
        sed -i "s|^\s*port:.*|  port: $MONGO_PORT|" "$MONGO_CONF" || true
        # 绑定所有地址
        sed -i "s|^\s*bindIp:.*|  bindIp: 0.0.0.0|" "$MONGO_CONF" || true
        log_success "MongoDB 配置文件已更新: $MONGO_CONF"
    fi
}

start_service() {
    log_info "启动 MongoDB 服务（初始无认证模式）..."
    systemctl daemon-reload
    systemctl enable mongod 2>/dev/null || true
    systemctl start mongod 2>/dev/null || true
    sleep 5

    if systemctl is-active --quiet mongod 2>/dev/null; then
        log_success "MongoDB 服务启动成功"
    else
        log_error "MongoDB 服务启动失败"
        systemctl status mongod --no-pager 2>/dev/null || true
        exit 1
    fi
}

create_admin_user() {
    log_info "创建 MongoDB 管理员用户..."
    sleep 3

    # 确定 mongo 客户端命令（mongosh 或 mongo）
    local MONGO_CLI=""
    if command -v mongosh &>/dev/null; then
        MONGO_CLI="mongosh"
    elif command -v mongo &>/dev/null; then
        MONGO_CLI="mongo"
    else
        log_warn "未找到 mongo/mongosh 客户端，跳过用户创建"
        return 0
    fi

    $MONGO_CLI --port "$MONGO_PORT" --quiet admin --eval "
db.createUser({
  user: '$MONGO_ADMIN_USER',
  pwd: '$MONGO_ADMIN_PASS',
  roles: [
    { role: 'root', db: 'admin' },
    { role: 'userAdminAnyDatabase', db: 'admin' },
    { role: 'dbAdminAnyDatabase', db: 'admin' },
    { role: 'readWriteAnyDatabase', db: 'admin' }
  ]
})
" 2>/dev/null && log_success "管理员用户 '$MONGO_ADMIN_USER' 创建成功" || \
    log_warn "用户可能已存在或创建失败，请手动检查"
}

enable_auth() {
    log_info "开启 MongoDB 鉴权..."

    local MONGO_CONF=""
    if [[ -f /etc/mongod.conf ]]; then
        MONGO_CONF="/etc/mongod.conf"
    elif [[ -f /etc/mongodb.conf ]]; then
        MONGO_CONF="/etc/mongodb.conf"
    fi

    if [[ -n "$MONGO_CONF" ]]; then
        if grep -q "^security:" "$MONGO_CONF"; then
            sed -i '/^security:/,/^[^ ]/s/^  authorization:.*/  authorization: enabled/' "$MONGO_CONF" || true
        else
            echo -e "\nsecurity:\n  authorization: enabled" >> "$MONGO_CONF"
        fi
        log_success "已在 $MONGO_CONF 中启用鉴权"
    else
        log_warn "未找到 MongoDB 配置文件，请手动添加 security.authorization: enabled"
    fi

    # 重启服务以生效
    systemctl restart mongod
    sleep 5
    log_success "MongoDB 以鉴权模式重启完成"
}

verify() {
    log_info "验证 MongoDB 安装..."
    local MONGO_VERSION
    MONGO_VERSION=$(mongod --version 2>/dev/null | grep "db version" | awk '{print $3}' || echo "unknown")
    log_success "MongoDB 版本: $MONGO_VERSION"

    local MONGO_CLI=""
    if command -v mongosh &>/dev/null; then
        MONGO_CLI="mongosh"
    elif command -v mongo &>/dev/null; then
        MONGO_CLI="mongo"
    fi

    if [[ -n "$MONGO_CLI" ]]; then
        if $MONGO_CLI --port "$MONGO_PORT" -u "$MONGO_ADMIN_USER" -p "$MONGO_ADMIN_PASS" \
            --authenticationDatabase admin --quiet --eval "db.adminCommand('ping')" &>/dev/null 2>&1; then
            log_success "MongoDB 连接测试通过（带鉴权）"
        else
            log_warn "MongoDB 连接测试失败，请检查密码配置"
        fi
    fi
}

save_config() {
    log_info "保存安装配置存档..."
    mkdir -p /etc/ant-eyes
    local OS_NAME
    OS_NAME=$(grep "^PRETTY_NAME" /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "$OS_TYPE")
    local MONGO_VERSION
    MONGO_VERSION=$(mongod --version 2>/dev/null | grep "db version" | awk '{print $3}' || echo "unknown")

    cat > /etc/ant-eyes/mongodb.conf <<EOF
# MongoDB 安装信息
# 安装时间: $(date '+%Y-%m-%d %H:%M:%S')
# 安装系统: $OS_NAME
# ----------------------------------------
SERVICE_VERSION=$MONGO_VERSION
SERVICE_PORT=$MONGO_PORT
ADMIN_USER=$MONGO_ADMIN_USER
ADMIN_PASS=$MONGO_ADMIN_PASS
AUTH_DB=admin
DATA_DIR=/var/lib/mongo
SERVICE_NAME=mongod
EOF

    chmod 600 /etc/ant-eyes/mongodb.conf
    log_success "配置存档已保存至: /etc/ant-eyes/mongodb.conf"
}

main() {
    print_header
    check_root
    detect_os
    check_network
    install_deps
    configure_pkg_source
    prompt_config
    install_mongodb
    configure_mongodb
    start_service
    create_admin_user
    enable_auth
    verify
    save_config

    echo ""
    log_success "MongoDB 安装完成！"
    echo ""
    echo -e "${YELLOW}连接信息:${NC}"
    echo "  mongosh --port $MONGO_PORT -u $MONGO_ADMIN_USER -p '<密码>' --authenticationDatabase admin"
    echo ""
    echo -e "${YELLOW}配置存档:${NC} /etc/ant-eyes/mongodb.conf"
    echo ""
}

main
