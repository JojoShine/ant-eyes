#!/bin/bash

################################################################################
# NVM 自动安装脚本 v2.0.0
# 支持系统: CentOS/RHEL 7+, Ubuntu 18.04+, Kylin Linux
# 功能: 系统检测、多镜像源下载、Node.js v20 LTS、网络检查、安装存档
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

OS_TYPE=""
PKG_MGR=""
TARGET_USER=""
TARGET_HOME=""
NVM_VERSION="v0.39.7"
NODE_VERSION="20"

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         NVM 自动安装脚本 v2.0.0                          ║"
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
    for host in "mirrors.aliyun.com" "raw.githubusercontent.com" "8.8.8.8"; do
        if ping -c 1 -W 3 "$host" &>/dev/null 2>&1; then
            connected=1; break
        fi
    done
    if [[ $connected -eq 0 ]]; then
        log_warn "网络连通性检测失败，NVM 下载可能受影响"
        read -p "是否仍然继续安装? (y/n): " -n 1 -r; echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    else
        log_success "网络连通性正常"
    fi
}

detect_user() {
    if [[ -n "$1" ]]; then
        TARGET_USER="$1"
    else
        log_warn "正在以 root 用户运行脚本"
        log_info "建议：使用普通用户运行此脚本以安装到该用户"
        log_info "用法: bash install_nvm.sh [username]"
        read -p "是否继续为 root 用户安装 NVM？(y/n): " -n 1 -r; echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        TARGET_USER="root"
    fi

    if [[ "$TARGET_USER" != "root" ]] && ! id "$TARGET_USER" &>/dev/null; then
        log_error "用户 '$TARGET_USER' 不存在"
        exit 1
    fi

    TARGET_HOME=$(eval echo ~"$TARGET_USER")
    log_info "将为用户 '$TARGET_USER' 安装 NVM (主目录: $TARGET_HOME)"
}

install_deps() {
    log_info "安装前置依赖（curl, git）..."
    if [[ "$PKG_MGR" == "apt" ]]; then
        apt-get update -qq
        apt-get install -y curl git 2>/dev/null || true
    else
        yum install -y curl git 2>/dev/null || true
    fi

    if ! command -v curl &>/dev/null; then
        log_error "curl 不可用，无法继续"
        exit 1
    fi
    log_success "前置依赖检查完成"
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

install_nvm() {
    log_info "下载并安装 NVM $NVM_VERSION..."

    if [[ -d "$TARGET_HOME/.nvm" ]]; then
        log_warn "NVM 已安装在 $TARGET_HOME/.nvm，跳过安装"
        return 0
    fi

    local NVM_URLS=(
        "https://gitee.com/mirrors/nvm/raw/$NVM_VERSION/install.sh"
        "https://cdn.npmmirror.com/binaries/nvm/$NVM_VERSION/install.sh"
        "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh"
    )

    local download_success=0
    for url in "${NVM_URLS[@]}"; do
        log_info "尝试从镜像源下载..."
        if curl -fsSL -m 60 -o /tmp/nvm_install.sh "$url" 2>/dev/null; then
            download_success=1
            log_success "NVM 安装脚本下载成功"
            break
        fi
    done

    if [[ $download_success -eq 0 ]]; then
        log_error "无法下载 NVM 安装脚本，请检查网络连接"
        exit 1
    fi

    log_info "执行 NVM 安装脚本..."
    export NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node
    if [[ "$TARGET_USER" == "root" ]]; then
        bash /tmp/nvm_install.sh
    else
        sudo -u "$TARGET_USER" bash -c "export NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node && bash /tmp/nvm_install.sh"
    fi

    rm -f /tmp/nvm_install.sh
    log_success "NVM 安装完成"
}

configure_nvm() {
    log_info "配置 NVM 环境变量..."

    local profile_files=("$TARGET_HOME/.bashrc" "$TARGET_HOME/.bash_profile" "$TARGET_HOME/.zshrc")
    for profile_file in "${profile_files[@]}"; do
        if [[ -f "$profile_file" ]] && ! grep -q "nvm.sh" "$profile_file" 2>/dev/null; then
            {
                echo ""
                echo "# NVM Configuration"
                echo "export NVM_DIR=\"\$HOME/.nvm\""
                echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
                echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'
            } >> "$profile_file"
            log_info "已向 $profile_file 添加 NVM 配置"
        fi
    done

    # 配置国内 NPM 镜像
    log_info "配置国内 NPM 镜像..."
    local npmrc_file="$TARGET_HOME/.npmrc"
    if [[ "$TARGET_USER" == "root" ]]; then
        cat > "$npmrc_file" <<'EOF'
registry=https://registry.npmmirror.com
disturl=https://cdn.npmmirror.com/dist
EOF
    else
        sudo -u "$TARGET_USER" tee "$npmrc_file" > /dev/null <<'EOF'
registry=https://registry.npmmirror.com
disturl=https://cdn.npmmirror.com/dist
EOF
    fi

    log_success "NVM 环境配置完成"
}

install_node_lts() {
    log_info "安装 Node.js v$NODE_VERSION LTS..."

    if [[ "$TARGET_USER" == "root" ]]; then
        export NVM_DIR="$TARGET_HOME/.nvm"
        if [[ -s "$NVM_DIR/nvm.sh" ]]; then
            # shellcheck source=/dev/null
            . "$NVM_DIR/nvm.sh"
        fi
        if declare -f nvm &>/dev/null || [[ $(type -t nvm) == function ]]; then
            export NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node
            nvm install "$NODE_VERSION"
            nvm use "$NODE_VERSION"
            nvm alias default "$NODE_VERSION"
            log_success "Node.js v$NODE_VERSION 安装完成"
        else
            log_warn "无法加载 NVM，请手动运行: source ~/.nvm/nvm.sh && nvm install $NODE_VERSION"
        fi
    else
        sudo -u "$TARGET_USER" bash -c "
            export NVM_DIR=\"\$HOME/.nvm\"
            export NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node
            [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"
            nvm install $NODE_VERSION
            nvm use $NODE_VERSION
            nvm alias default $NODE_VERSION
        " 2>/dev/null || log_warn "Node.js 安装可能需要手动完成"
    fi
}

create_global_symlinks() {
    log_info "创建全局 Node/npm 软链接..."
    export NVM_DIR="$TARGET_HOME/.nvm"

    if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
        log_warn "NVM 未正确安装，跳过软链接创建"
        return 0
    fi

    local NODE_VERSION_DIR
    NODE_VERSION_DIR=$(find "$NVM_DIR/versions/node" -maxdepth 1 -type d 2>/dev/null | sort -V | tail -1)

    if [[ -z "$NODE_VERSION_DIR" || ! -d "$NODE_VERSION_DIR" ]]; then
        log_warn "未找到 NVM Node 版本目录，跳过软链接创建"
        return 0
    fi

    for bin in node npm npx; do
        local BIN_PATH="$NODE_VERSION_DIR/bin/$bin"
        if [[ -e "$BIN_PATH" ]]; then
            ln -sf "$BIN_PATH" "/usr/local/bin/$bin" 2>/dev/null || true
            log_success "$bin 全局软链接已创建"
        fi
    done
}

verify() {
    log_info "验证安装..."

    if [[ ! -d "$TARGET_HOME/.nvm" ]]; then
        log_error "NVM 安装失败"
        exit 1
    fi
    log_success "NVM 已成功安装"

    if [[ $EUID -eq 0 ]]; then
        if command -v node &>/dev/null; then
            log_success "Node.js 版本: $(node --version) (全局可用)"
        else
            log_warn "Node 未在全局可用，NVM 已安装"
        fi
        if command -v npm &>/dev/null; then
            log_success "npm 版本: $(npm --version)"
        fi
    else
        export NVM_DIR="$TARGET_HOME/.nvm"
        if [[ -s "$NVM_DIR/nvm.sh" ]]; then
            # shellcheck source=/dev/null
            . "$NVM_DIR/nvm.sh"
            command -v node &>/dev/null && log_success "Node.js 版本: $(node --version)"
            command -v npm &>/dev/null && log_success "npm 版本: $(npm --version)"
        fi
    fi
}

save_config() {
    log_info "保存安装配置存档..."
    mkdir -p /etc/ant-eyes
    local OS_NAME
    OS_NAME=$(grep "^PRETTY_NAME" /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "$OS_TYPE")
    local INSTALLED_NODE_VERSION
    INSTALLED_NODE_VERSION=$(command -v node &>/dev/null && node --version 2>/dev/null || echo "unknown")

    cat > /etc/ant-eyes/nvm.conf <<EOF
# NVM 安装信息
# 安装时间: $(date '+%Y-%m-%d %H:%M:%S')
# 安装系统: $OS_NAME
# ----------------------------------------
NVM_VERSION=$NVM_VERSION
NODE_LTS_VERSION=v$NODE_VERSION
INSTALLED_NODE=$INSTALLED_NODE_VERSION
TARGET_USER=$TARGET_USER
NVM_DIR=$TARGET_HOME/.nvm
NPMRC_FILE=$TARGET_HOME/.npmrc
EOF

    chmod 644 /etc/ant-eyes/nvm.conf
    log_success "配置存档已保存至: /etc/ant-eyes/nvm.conf"
}

main() {
    print_header
    check_root
    detect_os
    check_network
    detect_user "$@"
    install_deps
    configure_pkg_source
    install_nvm
    configure_nvm
    install_node_lts

    if [[ $EUID -eq 0 ]]; then
        create_global_symlinks
    fi

    verify
    save_config

    echo ""
    log_success "NVM 安装完成！"
    echo ""
    if [[ "$TARGET_USER" != "root" ]]; then
        echo -e "${YELLOW}提示:${NC}"
        echo "  请使用以下命令激活 NVM:"
        echo "    source ~/.nvm/nvm.sh"
        echo ""
    else
        echo -e "${GREEN}Node/npm 已创建全局软链接，可以直接使用${NC}"
    fi
    echo -e "${YELLOW}配置存档:${NC} /etc/ant-eyes/nvm.conf"
    echo ""
}

main "$@"
