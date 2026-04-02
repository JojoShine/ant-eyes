#!/bin/bash

################################################################################
# Python 3.11 + uv 自动安装脚本 v2.0.0
# 支持系统: CentOS/RHEL 7+, Ubuntu 18.04+, Kylin Linux
# 功能: 安装 Python 3.11，安装 uv 包管理器，配置国内镜像，安装存档
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

OS_TYPE=""
PKG_MGR=""
PYTHON_VERSION="3.11"
TARGET_USER=""
TARGET_HOME=""

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         Python 3.11 + uv 自动安装脚本 v2.0.0             ║"
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

detect_user() {
    if [[ -n "$1" ]]; then
        TARGET_USER="$1"
    else
        TARGET_USER="root"
    fi
    TARGET_HOME=$(eval echo ~"$TARGET_USER")
    log_info "将为用户 '$TARGET_USER' 安装 uv (主目录: $TARGET_HOME)"
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
        apt-get install -y curl wget gcc make libssl-dev zlib1g-dev \
            libffi-dev libsqlite3-dev libbz2-dev libreadline-dev 2>/dev/null || true
    else
        yum install -y curl wget gcc make openssl-devel zlib-devel \
            libffi-devel sqlite-devel bzip2-devel readline-devel 2>/dev/null || true
    fi
    log_success "前置依赖安装完成"
}

install_python() {
    log_info "安装 Python $PYTHON_VERSION..."

    # 检查是否已有合适版本
    if command -v "python$PYTHON_VERSION" &>/dev/null; then
        log_warn "Python $PYTHON_VERSION 已安装"
        return 0
    fi

    if [[ "$PKG_MGR" == "apt" ]]; then
        _install_python_apt
    else
        _install_python_yum
    fi
}

_install_python_apt() {
    log_info "通过 apt 安装 Python $PYTHON_VERSION..."

    # 检查系统源是否有 Python 3.11
    if apt-cache show "python${PYTHON_VERSION}" &>/dev/null 2>&1; then
        apt-get install -y "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-venv" \
            "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-pip" 2>/dev/null || true
    else
        # 添加 deadsnakes PPA（Ubuntu）
        log_info "添加 deadsnakes PPA 以安装 Python $PYTHON_VERSION..."
        apt-get install -y software-properties-common 2>/dev/null || true
        add-apt-repository -y ppa:deadsnakes/ppa 2>/dev/null || true
        apt-get update -qq 2>/dev/null || true
        apt-get install -y "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-venv" \
            "python${PYTHON_VERSION}-dev" 2>/dev/null || true
    fi

    log_success "Python $PYTHON_VERSION 安装完成（apt）"
}

_install_python_yum() {
    log_info "通过 yum 安装 Python $PYTHON_VERSION..."

    # 尝试直接安装
    if yum install -y "python${PYTHON_VERSION//./}" 2>/dev/null || \
       yum install -y "python3.11" 2>/dev/null; then
        log_success "Python $PYTHON_VERSION 安装完成（yum）"
        return 0
    fi

    # 尝试通过 EPEL 或 SCL
    log_info "尝试通过 EPEL 安装 Python $PYTHON_VERSION..."
    yum install -y epel-release 2>/dev/null || true
    yum install -y python3.11 2>/dev/null || true

    # 如果还不行，从源码编译
    if ! command -v "python${PYTHON_VERSION}" &>/dev/null && \
       ! command -v python3.11 &>/dev/null; then
        log_warn "无法通过包管理器安装 Python $PYTHON_VERSION，尝试源码编译..."
        _compile_python_from_source
    fi
}

_compile_python_from_source() {
    log_info "从源码编译 Python $PYTHON_VERSION（这可能需要几分钟）..."

    local PYTHON_FULL_VERSION="${PYTHON_VERSION}.0"
    local PYTHON_URLS=(
        "https://mirrors.huaweicloud.com/python/${PYTHON_FULL_VERSION}/Python-${PYTHON_FULL_VERSION}.tgz"
        "https://mirrors.aliyun.com/python-release/source/Python-${PYTHON_FULL_VERSION}.tgz"
        "https://www.python.org/ftp/python/${PYTHON_FULL_VERSION}/Python-${PYTHON_FULL_VERSION}.tgz"
    )

    local download_success=0
    for url in "${PYTHON_URLS[@]}"; do
        log_info "尝试从镜像源下载 Python 源码..."
        if curl -fsSL -o /tmp/Python.tgz "$url" 2>/dev/null; then
            download_success=1; break
        fi
    done

    if [[ $download_success -eq 0 ]]; then
        log_error "无法下载 Python 源码"
        exit 1
    fi

    cd /tmp
    tar -xzf Python.tgz
    cd "Python-${PYTHON_FULL_VERSION}"
    ./configure --enable-optimizations --prefix=/usr/local 2>/dev/null
    make -j"$(nproc)" 2>/dev/null
    make altinstall 2>/dev/null
    cd /tmp
    rm -rf Python.tgz "Python-${PYTHON_FULL_VERSION}"
    log_success "Python $PYTHON_VERSION 源码编译安装完成"
}

set_python_default() {
    log_info "配置 Python 默认版本..."

    # 确定 Python 3.11 可执行文件位置
    local PYTHON_BIN=""
    for candidate in "python${PYTHON_VERSION}" "python3.11" "/usr/local/bin/python${PYTHON_VERSION}"; do
        if command -v "$candidate" &>/dev/null; then
            PYTHON_BIN=$(command -v "$candidate")
            break
        fi
    done

    if [[ -z "$PYTHON_BIN" ]]; then
        log_warn "未找到 Python $PYTHON_VERSION 可执行文件"
        return 0
    fi

    # 设置 python3 软链接（如果 python3 不指向 3.11）
    if command -v python3 &>/dev/null; then
        local CURRENT_VER
        CURRENT_VER=$(python3 --version 2>/dev/null | awk '{print $2}' | cut -d. -f1,2)
        if [[ "$CURRENT_VER" != "$PYTHON_VERSION" ]]; then
            log_info "当前 python3 指向 $CURRENT_VER，不修改（保留系统默认）"
            log_info "Python $PYTHON_VERSION 可通过 python$PYTHON_VERSION 命令使用"
        fi
    else
        ln -sf "$PYTHON_BIN" /usr/local/bin/python3 2>/dev/null || true
        log_success "python3 软链接已创建 -> $PYTHON_BIN"
    fi
}

install_uv() {
    log_info "安装 uv 包管理器..."

    if command -v uv &>/dev/null; then
        log_warn "uv 已安装，跳过安装步骤"
        return 0
    fi

    # uv 安装脚本（多个镜像源）
    local UV_URLS=(
        "https://astral.sh/uv/install.sh"
        "https://ghproxy.com/https://raw.githubusercontent.com/astral-sh/uv/main/scripts/install.sh"
    )

    local download_success=0
    for url in "${UV_URLS[@]}"; do
        log_info "尝试从镜像源下载 uv 安装脚本..."
        if curl -fsSL -m 60 -o /tmp/uv_install.sh "$url" 2>/dev/null; then
            download_success=1; break
        fi
    done

    if [[ $download_success -eq 0 ]]; then
        log_warn "无法下载 uv 安装脚本，尝试通过 pip 安装..."
        _install_uv_via_pip
        return
    fi

    if [[ "$TARGET_USER" == "root" ]]; then
        HOME="$TARGET_HOME" bash /tmp/uv_install.sh 2>/dev/null || true
    else
        sudo -u "$TARGET_USER" HOME="$TARGET_HOME" bash /tmp/uv_install.sh 2>/dev/null || true
    fi

    rm -f /tmp/uv_install.sh

    # 创建全局软链接
    local UV_BIN="$TARGET_HOME/.local/bin/uv"
    if [[ -f "$UV_BIN" ]]; then
        ln -sf "$UV_BIN" /usr/local/bin/uv 2>/dev/null || true
        log_success "uv 安装完成，全局软链接已创建"
    else
        log_warn "uv 安装路径未找到，请手动将 ~/.local/bin 加入 PATH"
    fi
}

_install_uv_via_pip() {
    log_info "通过 pip 安装 uv..."
    local PYTHON_BIN=""
    for candidate in "python${PYTHON_VERSION}" "python3.11" "python3"; do
        if command -v "$candidate" &>/dev/null; then
            PYTHON_BIN="$candidate"; break
        fi
    done

    if [[ -z "$PYTHON_BIN" ]]; then
        log_error "未找到 Python，无法通过 pip 安装 uv"
        return 1
    fi

    $PYTHON_BIN -m pip install --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple 2>/dev/null || true
    $PYTHON_BIN -m pip install uv -i https://pypi.tuna.tsinghua.edu.cn/simple 2>/dev/null || true

    if command -v uv &>/dev/null; then
        log_success "uv 通过 pip 安装成功"
    else
        log_warn "uv 安装失败，请手动安装"
    fi
}

configure_uv() {
    log_info "配置 uv 使用国内 PyPI 镜像..."

    local UV_CONFIG_DIR="$TARGET_HOME/.config/uv"
    mkdir -p "$UV_CONFIG_DIR"

    if [[ "$TARGET_USER" == "root" ]]; then
        cat > "$UV_CONFIG_DIR/uv.toml" <<'EOF'
[pip]
index-url = "https://pypi.tuna.tsinghua.edu.cn/simple"
extra-index-url = [
    "https://mirrors.aliyun.com/pypi/simple/",
    "https://pypi.mirrors.ustc.edu.cn/simple/"
]
EOF
        chown -R root:root "$UV_CONFIG_DIR"
    else
        sudo -u "$TARGET_USER" mkdir -p "$UV_CONFIG_DIR"
        sudo -u "$TARGET_USER" tee "$UV_CONFIG_DIR/uv.toml" > /dev/null <<'EOF'
[pip]
index-url = "https://pypi.tuna.tsinghua.edu.cn/simple"
extra-index-url = [
    "https://mirrors.aliyun.com/pypi/simple/",
    "https://pypi.mirrors.ustc.edu.cn/simple/"
]
EOF
    fi

    # 配置 pip 使用国内镜像
    local PIP_CONF_DIR="$TARGET_HOME/.config/pip"
    mkdir -p "$PIP_CONF_DIR"
    if [[ "$TARGET_USER" == "root" ]]; then
        cat > "$PIP_CONF_DIR/pip.conf" <<'EOF'
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
extra-index-url =
    https://mirrors.aliyun.com/pypi/simple/
    https://pypi.mirrors.ustc.edu.cn/simple/
trusted-host =
    pypi.tuna.tsinghua.edu.cn
    mirrors.aliyun.com
    pypi.mirrors.ustc.edu.cn
EOF
    else
        sudo -u "$TARGET_USER" mkdir -p "$PIP_CONF_DIR"
        sudo -u "$TARGET_USER" tee "$PIP_CONF_DIR/pip.conf" > /dev/null <<'EOF'
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
extra-index-url =
    https://mirrors.aliyun.com/pypi/simple/
    https://pypi.mirrors.ustc.edu.cn/simple/
trusted-host =
    pypi.tuna.tsinghua.edu.cn
    mirrors.aliyun.com
    pypi.mirrors.ustc.edu.cn
EOF
    fi

    log_success "uv 和 pip 国内镜像配置完成"
}

verify() {
    log_info "验证安装..."

    local PYTHON_BIN=""
    for candidate in "python${PYTHON_VERSION}" "python3.11" "python3"; do
        if command -v "$candidate" &>/dev/null; then
            local ver
            ver=$("$candidate" --version 2>/dev/null | awk '{print $2}' | cut -d. -f1,2)
            if [[ "$ver" == "$PYTHON_VERSION" ]]; then
                PYTHON_BIN="$candidate"; break
            fi
        fi
    done

    if [[ -n "$PYTHON_BIN" ]]; then
        log_success "Python $PYTHON_VERSION 版本: $($PYTHON_BIN --version 2>/dev/null)"
    else
        log_warn "未找到 Python $PYTHON_VERSION，请手动检查"
    fi

    if command -v uv &>/dev/null; then
        log_success "uv 版本: $(uv --version 2>/dev/null)"
    else
        log_warn "uv 未在全局路径中，请检查 ~/.local/bin/uv"
    fi
}

save_config() {
    log_info "保存安装配置存档..."
    mkdir -p /etc/ant-eyes
    local OS_NAME
    OS_NAME=$(grep "^PRETTY_NAME" /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "$OS_TYPE")

    local INSTALLED_PYTHON_VERSION="unknown"
    for candidate in "python${PYTHON_VERSION}" "python3.11" "python3"; do
        if command -v "$candidate" &>/dev/null; then
            local ver
            ver=$("$candidate" --version 2>/dev/null | awk '{print $2}' | cut -d. -f1,2)
            if [[ "$ver" == "$PYTHON_VERSION" ]]; then
                INSTALLED_PYTHON_VERSION=$("$candidate" --version 2>/dev/null | awk '{print $2}')
                break
            fi
        fi
    done

    local UV_VERSION="unknown"
    command -v uv &>/dev/null && UV_VERSION=$(uv --version 2>/dev/null | awk '{print $2}')

    cat > /etc/ant-eyes/python.conf <<EOF
# Python + uv 安装信息
# 安装时间: $(date '+%Y-%m-%d %H:%M:%S')
# 安装系统: $OS_NAME
# ----------------------------------------
PYTHON_TARGET_VERSION=$PYTHON_VERSION
PYTHON_INSTALLED_VERSION=$INSTALLED_PYTHON_VERSION
UV_VERSION=$UV_VERSION
TARGET_USER=$TARGET_USER
UV_CONFIG=$TARGET_HOME/.config/uv/uv.toml
PIP_CONFIG=$TARGET_HOME/.config/pip/pip.conf
PYPI_MIRROR=https://pypi.tuna.tsinghua.edu.cn/simple
EOF

    chmod 644 /etc/ant-eyes/python.conf
    log_success "配置存档已保存至: /etc/ant-eyes/python.conf"
}

main() {
    print_header
    check_root
    detect_os
    check_network
    detect_user "$@"
    install_deps
    configure_pkg_source
    install_python
    set_python_default
    install_uv
    configure_uv
    verify
    save_config

    echo ""
    log_success "Python $PYTHON_VERSION + uv 安装完成！"
    echo ""
    echo -e "${YELLOW}常用命令:${NC}"
    echo "  python${PYTHON_VERSION} --version      # 查看 Python 版本"
    echo "  uv --version                # 查看 uv 版本"
    echo "  uv venv .venv               # 创建虚拟环境"
    echo "  uv pip install <package>    # 安装包"
    echo "  uv run python script.py     # 运行脚本"
    echo ""
    echo -e "${YELLOW}配置存档:${NC} /etc/ant-eyes/python.conf"
    echo ""
}

main "$@"
