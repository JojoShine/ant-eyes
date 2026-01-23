#!/bin/bash

################################################################################
# NVM 自动安装脚本 - CentOS/RHEL 7+
# 为指定用户安装 NVM (Node Version Manager) 和 Node.js LTS
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
    echo "║     NVM 自动安装脚本 v1.0.0 (CentOS/RHEL 7+)            ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 检测目标用户
detect_user() {
    # 如果以 root 运行，默认为当前非 root 用户，或者 nobody
    if [[ $EUID -eq 0 ]]; then
        # 如果指定了用户参数，使用该参数
        if [[ -n "$1" ]]; then
            TARGET_USER="$1"
        else
            log_warn "正在以 root 用户运行脚本"
            log_info "建议：使用普通用户运行此脚本以安装到该用户"
            log_info "用法: bash install_nvm.sh [username]"
            # 交互式选择
            read -p "是否继续为 root 用户安装 NVM？(y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
            TARGET_USER="root"
        fi
    else
        TARGET_USER=$(whoami)
        if [[ -n "$1" && "$1" != "$TARGET_USER" ]]; then
            log_error "无法为其他用户安装 NVM，需要 root 权限"
            exit 1
        fi
    fi

    TARGET_HOME=$(eval echo ~$TARGET_USER)
    log_info "将为用户 '$TARGET_USER' 安装 NVM (主目录: $TARGET_HOME)"
}


# 检查依赖
check_dependencies() {
    log_info "检查依赖..."

    local required_cmds=("curl" "git")
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_warn "缺少命令: $cmd"
            log_info "尝试安装 $cmd..."

            if command -v yum &> /dev/null; then
                yum install -y "$cmd" || true
            elif command -v apt-get &> /dev/null; then
                apt-get update && apt-get install -y "$cmd" || true
            fi
        fi
    done

    if ! command -v curl &> /dev/null; then
        log_error "curl 不可用，无法继续"
        exit 1
    fi

    log_success "依赖检查完成"
}

# 安装 NVM
install_nvm() {
    log_info "下载并安装 NVM..."

    # 检查是否已安装
    if [[ -d "$TARGET_HOME/.nvm" ]]; then
        log_warn "NVM 已安装在 $TARGET_HOME/.nvm"
        return 0
    fi

    # NVM 安装脚本 URL - 多个国内镜像源
    local NVM_URLS=(
        "https://ghproxy.com/https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh"
        "https://raw.fastgit.org/nvm-sh/nvm/v0.39.0/install.sh"
        "https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh"
    )

    log_info "从 GitHub 下载 NVM（尝试多个镜像源）..."

    local download_success=0
    for url in "${NVM_URLS[@]}"; do
        log_info "尝试从: ${url##*/} ..."
        if curl -s -f -m 30 -o /tmp/nvm_install.sh "$url" 2>/dev/null; then
            log_success "NVM 下载成功"
            download_success=1
            break
        fi
    done

    if [[ $download_success -eq 0 ]]; then
        log_error "无法从任何源下载 NVM 安装脚本，请检查网络连接"
        exit 1
    fi

    # 以目标用户身份运行安装脚本
    log_info "执行 NVM 安装脚本..."
    if [[ "$TARGET_USER" == "root" ]]; then
        bash /tmp/nvm_install.sh
    else
        sudo -u "$TARGET_USER" bash /tmp/nvm_install.sh
    fi

    rm -f /tmp/nvm_install.sh
    log_success "NVM 安装完成"
}

# 配置 NVM 环境变量
configure_nvm() {
    log_info "配置 NVM 环境变量..."

    local profile_files=("$TARGET_HOME/.bashrc" "$TARGET_HOME/.bash_profile" "$TARGET_HOME/.zshrc")
    local nvm_init_str='[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'

    # NVM 安装脚本通常已自动添加，但做个确认
    for profile_file in "${profile_files[@]}"; do
        if [[ -f "$profile_file" ]]; then
            if ! grep -q "nvm.sh" "$profile_file" 2>/dev/null; then
                log_info "向 $profile_file 添加 NVM 配置..."
                if [[ "$TARGET_USER" == "root" ]]; then
                    echo "" >> "$profile_file"
                    echo "# NVM Configuration" >> "$profile_file"
                    echo "export NVM_DIR=\"\$HOME/.nvm\"" >> "$profile_file"
                    echo "$nvm_init_str" >> "$profile_file"
                else
                    echo "" >> "$profile_file"
                    echo "# NVM Configuration" >> "$profile_file"
                    echo "export NVM_DIR=\"\$HOME/.nvm\"" >> "$profile_file"
                    echo "$nvm_init_str" >> "$profile_file"
                fi
            fi
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
        sudo -u "$TARGET_USER" bash -c "cat > '$npmrc_file' <<'EOF'
registry=https://registry.npmmirror.com
disturl=https://cdn.npmmirror.com/dist
EOF"
    fi

    log_success "NVM 环境变量和 NPM 镜像配置完成"
}

# 安装 Node LTS（v18 或 v20，兼容性更好）
install_node_lts() {
    log_info "安装 Node.js LTS（v18/v20）..."

    # 加载 NVM
    if [[ "$TARGET_USER" == "root" ]]; then
        export NVM_DIR="$TARGET_HOME/.nvm"
        if [[ -s "$NVM_DIR/nvm.sh" ]]; then
            . "$NVM_DIR/nvm.sh"
        fi

        # 使用 nvm 命令
        if command -v nvm &> /dev/null || [[ $(type -t nvm) == function ]]; then
            log_info "清理旧版本的 Node..."
            rm -rf "$NVM_DIR/versions/node/v24"* 2>/dev/null || true
            rm -rf "$NVM_DIR/versions/node/v20"* 2>/dev/null || true
            rm -rf "$NVM_DIR/versions/node/v18"* 2>/dev/null || true
            rm -rf "$NVM_DIR/versions/node/v16"* 2>/dev/null || true

            log_info "安装 Node.js v20（推荐）..."
            nvm install 20
            nvm use 20
            nvm alias default 20
            log_success "Node.js v20 安装完成"
        else
            log_warn "无法加载 NVM，请手动运行: source ~/.nvm/nvm.sh && nvm install 16"
        fi
    else
        log_info "为用户 $TARGET_USER 安装 Node.js v20..."
        sudo -u "$TARGET_USER" bash -c "
            export NVM_DIR=\"\$HOME/.nvm\"
            [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"

            # 清理旧版本
            rm -rf \"\$NVM_DIR/versions/node/v24\"* 2>/dev/null || true
            rm -rf \"\$NVM_DIR/versions/node/v20\"* 2>/dev/null || true
            rm -rf \"\$NVM_DIR/versions/node/v18\"* 2>/dev/null || true

            nvm install 20
            nvm use 20
            nvm alias default 20
        " || log_warn "Node.js 安装需要手动完成"
    fi
}

# 创建全局 Node 软链接
create_global_symlinks() {
    log_info "创建全局 Node/npm 软链接..."

    export NVM_DIR="$TARGET_HOME/.nvm"
    if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
        log_warn "NVM 未正确安装，跳过软链接创建"
        return 0
    fi

    # 查找最新安装的 Node 版本
    local NODE_VERSION_DIR=$(find "$NVM_DIR/versions/node" -maxdepth 1 -type d | sort -V | tail -1 2>/dev/null)

    if [[ -z "$NODE_VERSION_DIR" || ! -d "$NODE_VERSION_DIR" ]]; then
        log_warn "未找到 NVM 安装的 Node 版本目录，跳过软链接创建"
        return 0
    fi

    local NODE_BIN="$NODE_VERSION_DIR/bin/node"
    local NPM_BIN="$NODE_VERSION_DIR/bin/npm"
    local NPX_BIN="$NODE_VERSION_DIR/bin/npx"

    # 创建全局软链接
    if [[ -e "$NODE_BIN" ]]; then
        ln -sf "$NODE_BIN" /usr/local/bin/node 2>/dev/null
        if [[ -e /usr/local/bin/node ]]; then
            log_success "Node 全局软链接已创建: /usr/local/bin/node -> $NODE_BIN"
        fi
    fi

    if [[ -e "$NPM_BIN" ]]; then
        ln -sf "$NPM_BIN" /usr/local/bin/npm 2>/dev/null
        if [[ -e /usr/local/bin/npm ]]; then
            log_success "npm 全局软链接已创建: /usr/local/bin/npm -> $NPM_BIN"
        fi
    fi

    if [[ -e "$NPX_BIN" ]]; then
        ln -sf "$NPX_BIN" /usr/local/bin/npx 2>/dev/null
        if [[ -e /usr/local/bin/npx ]]; then
            log_success "npx 全局软链接已创建: /usr/local/bin/npx -> $NPX_BIN"
        fi
    fi
}

# 验证安装
verify() {
    log_info "验证安装..."

    if [[ -d "$TARGET_HOME/.nvm" ]]; then
        log_success "NVM 已成功安装"
    else
        log_error "NVM 安装失败"
        exit 1
    fi

    # 验证 Node 和 npm
    if [[ $EUID -eq 0 ]]; then
        # Root 用户：检查全局软链接
        if command -v node &> /dev/null; then
            NODE_VERSION=$(node --version)
            NODE_PATH=$(command -v node)
            log_success "✓ Node.js 版本: $NODE_VERSION (全局可用: $NODE_PATH)"
        else
            log_warn "Node 未在全局可用，但 NVM 已安装"
        fi

        if command -v npm &> /dev/null; then
            NPM_VERSION=$(npm --version)
            NPM_PATH=$(command -v npm)
            log_success "✓ npm 版本: $NPM_VERSION (全局可用: $NPM_PATH)"
        fi

        if command -v npx &> /dev/null; then
            log_success "✓ npx 已全局可用"
        fi
    else
        # 普通用户：需要加载 NVM
        export NVM_DIR="$TARGET_HOME/.nvm"
        if [[ -s "$NVM_DIR/nvm.sh" ]]; then
            . "$NVM_DIR/nvm.sh"
            if command -v node &> /dev/null; then
                NODE_VERSION=$(node --version)
                log_success "Node.js 版本: $NODE_VERSION"
            else
                log_info "需要运行 'source ~/.nvm/nvm.sh' 来使用 Node"
            fi

            if command -v npm &> /dev/null; then
                NPM_VERSION=$(npm --version)
                log_success "npm 版本: $NPM_VERSION"
            fi
        fi
    fi
}

main() {
    print_header
    detect_user "$@"
    check_dependencies
    install_nvm
    configure_nvm
    install_node_lts

    # 创建全局软链接（仅限 root 用户执行）
    if [[ $EUID -eq 0 ]]; then
        create_global_symlinks
    fi

    verify

    echo ""
    log_success "NVM 安装完成！"
    echo ""

    if [[ "$TARGET_USER" != "root" ]]; then
        echo -e "${YELLOW}提示${NC}："
        echo "  请使用以下命令激活 NVM："
        echo "    source ~/.nvm/nvm.sh"
        echo ""
        echo "  或者在新的 shell 会话中使用（已自动配置）"
        echo ""
    else
        echo -e "${GREEN}✓${NC} Node/npm 已创建全局软链接，可以直接使用"
        echo ""
    fi
}

main "$@"
