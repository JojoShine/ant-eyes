#!/bin/bash

################################################################################
# MongoDB 自动安装脚本 - CentOS/RHEL 7+
# 完全独立，无外部依赖
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║     MongoDB 自动安装脚本 v1.0.0 (CentOS/RHEL 7+)        ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        exit 1
    fi
}

configure_yum_mirror() {
    log_info "配置国内 yum 源..."
    mkdir -p /etc/yum.repos.d.bak

    # 备份并删除所有旧的repo文件
    mv /etc/yum.repos.d/*.repo /etc/yum.repos.d.bak/ 2>/dev/null || true

    OS_VERSION=$(rpm -E %rhel)

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

install_mongodb() {
    log_info "安装 MongoDB..."
    yum install -y mongodb-server mongodb
    log_success "MongoDB 安装完成"
}

configure_mongodb() {
    log_info "配置 MongoDB..."
    DATA_DIR="/data/mongodb"
    LOG_DIR="/data/mongodb/log"
    mkdir -p "$DATA_DIR" "$LOG_DIR"
    chown -R mongod:mongod "$DATA_DIR" "$LOG_DIR"
    chmod 750 "$DATA_DIR"

    # 配置 MongoDB
    if [[ -f /etc/mongod.conf ]]; then
        cp /etc/mongod.conf /etc/mongod.conf.bak.$(date +%Y%m%d_%H%M%S)

        # 修改数据目录和日志目录
        sed -i "s|dbPath: .*|dbPath: $DATA_DIR|" /etc/mongod.conf
        sed -i "s|path: .*|path: $LOG_DIR/mongod.log|" /etc/mongod.conf

        # 配置 bindIp 允许远程访问
        sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
    fi

    log_success "MongoDB 配置完成"
}

configure_firewall() {
    log_info "配置防火墙..."

    # 检查 firewalld 是否运行
    if systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --add-port=27017/tcp
        firewall-cmd --reload
        log_success "防火墙规则已添加（端口 27017）"
    else
        log_warn "firewalld 未运行，跳过防火墙配置"
    fi
}

start_service() {
    log_info "启动 MongoDB 服务..."
    systemctl daemon-reload
    systemctl enable mongod
    systemctl start mongod

    sleep 2

    if systemctl is-active --quiet mongod; then
        log_success "MongoDB 服务启动成功"
    else
        log_error "MongoDB 服务启动失败"
        exit 1
    fi
}

verify() {
    log_info "验证 MongoDB 安装..."
    MONGO_VERSION=$(mongod --version | grep "db version" | awk '{print $3}')
    log_success "MongoDB 版本: $MONGO_VERSION"

    if mongo --eval "db.adminCommand('ping')" &>/dev/null; then
        log_success "MongoDB 连接测试通过"
    else
        log_warn "MongoDB 连接测试失败"
    fi
}

main() {
    print_header
    check_root
    configure_yum_mirror
    install_mongodb
    configure_mongodb
    configure_firewall
    start_service
    verify

    echo ""
    log_success "MongoDB 安装完成！"
    log_info "数据目录: /data/mongodb"
    log_info "远程访问已启用，端口: 27017"
}

main
