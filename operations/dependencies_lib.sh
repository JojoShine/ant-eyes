#!/bin/bash

################################################################################
# 前置依赖检查与自动安装库
# 支持 CentOS/RHEL 7+, Ubuntu 18.04+, Kylin, UOS
# 功能:
#   - 检查 Java、Python、Scala 等环境
#   - 检查系统包依赖 (gcc, make, openssl 等)
#   - 自动检测操作系统并选择合适的安装方式
#   - 自动安装缺失的依赖
#   - 友好的交互式界面和进度提示
#
# 使用方法:
#   source ./dependencies_lib.sh
#   check_and_install_dependencies "flink"
#
# 作者: Shell Collections Team
# 版本: 1.0.0
################################################################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ======================== 系统检测函数 ========================

# 检测操作系统
detect_os_for_deps() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" == "rhel" || "$ID" == "centos" || "$ID" == "kylin" || "$ID" == "uos" ]]; then
            echo "rhel"
        elif [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
            echo "debian"
        fi
    fi
}

# 获取系统版本
get_os_version() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$VERSION_ID"
    fi
}

# ======================== Java 检查与安装 ========================

# 检查 Java 是否已安装
check_java_installed() {
    if command -v java &> /dev/null; then
        local java_version=$(java -version 2>&1 | grep -oP '(?<=version ")[^"]*' | head -1)
        echo "installed:$java_version"
        return 0
    fi
    echo "not_installed"
    return 1
}

# 获取 Java 主版本号
get_java_major_version() {
    local version=$(java -version 2>&1 | grep -oP '(?<=version ")[^"]*')
    if [[ $version =~ ^1\.([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "$version" | cut -d'.' -f1
    fi
}

# 自动安装 Java
install_java_auto() {
    local os=$(detect_os_for_deps)

    echo -e "${BLUE}→${NC} 检测到缺失 Java, 正在安装..."

    if [[ "$os" == "rhel" ]]; then
        # CentOS/RHEL
        if ! yum install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel &>/dev/null; then
            echo -e "${RED}✗${NC} Java 安装失败"
            return 1
        fi
    elif [[ "$os" == "debian" ]]; then
        # Ubuntu
        if ! apt-get update &>/dev/null || ! apt-get install -y openjdk-8-jdk &>/dev/null; then
            echo -e "${RED}✗${NC} Java 安装失败"
            return 1
        fi
    else
        echo -e "${RED}✗${NC} 不支持的操作系统"
        return 1
    fi

    echo -e "${GREEN}✓${NC} Java 安装成功"
    return 0
}

# ======================== Python 检查与安装 ========================

# 检查 Python 是否已安装
check_python_installed() {
    if command -v python3 &> /dev/null; then
        local python_version=$(python3 --version 2>&1 | awk '{print $2}')
        echo "installed:$python_version"
        return 0
    fi
    echo "not_installed"
    return 1
}

# 获取 Python 主版本号
get_python_major_version() {
    local version=$(python3 --version 2>&1 | awk '{print $2}')
    echo "$version" | cut -d'.' -f1
}

# 自动安装 Python
install_python_auto() {
    local os=$(detect_os_for_deps)

    echo -e "${BLUE}→${NC} 检测到缺失 Python3, 正在安装..."

    if [[ "$os" == "rhel" ]]; then
        # CentOS/RHEL
        if ! yum install -y python3 python3-devel python3-pip &>/dev/null; then
            echo -e "${RED}✗${NC} Python3 安装失败"
            return 1
        fi
    elif [[ "$os" == "debian" ]]; then
        # Ubuntu
        if ! apt-get update &>/dev/null || ! apt-get install -y python3 python3-dev python3-pip &>/dev/null; then
            echo -e "${RED}✗${NC} Python3 安装失败"
            return 1
        fi
    else
        echo -e "${RED}✗${NC} 不支持的操作系统"
        return 1
    fi

    echo -e "${GREEN}✓${NC} Python3 安装成功"
    return 0
}

# ======================== Pip 检查与安装 ========================

# 检查 pip 是否已安装
check_pip_installed() {
    if command -v pip3 &> /dev/null; then
        local pip_version=$(pip3 --version 2>&1 | awk '{print $2}')
        echo "installed:$pip_version"
        return 0
    fi
    echo "not_installed"
    return 1
}

# 自动安装 pip
install_pip_auto() {
    local os=$(detect_os_for_deps)

    echo -e "${BLUE}→${NC} 检测到缺失 pip, 正在安装..."

    if [[ "$os" == "rhel" ]]; then
        if ! yum install -y python3-pip &>/dev/null; then
            echo -e "${RED}✗${NC} pip 安装失败"
            return 1
        fi
    elif [[ "$os" == "debian" ]]; then
        if ! apt-get install -y python3-pip &>/dev/null; then
            echo -e "${RED}✗${NC} pip 安装失败"
            return 1
        fi
    fi

    echo -e "${GREEN}✓${NC} pip 安装成功"
    return 0
}

# ======================== OpenSSL 检查与安装 ========================

# 检查 OpenSSL 是否已安装
check_openssl_installed() {
    if command -v openssl &> /dev/null; then
        local openssl_version=$(openssl version 2>&1 | awk '{print $2}')
        echo "installed:$openssl_version"
        return 0
    fi
    echo "not_installed"
    return 1
}

# 自动安装 OpenSSL
install_openssl_auto() {
    local os=$(detect_os_for_deps)

    echo -e "${BLUE}→${NC} 检测到缺失 OpenSSL, 正在安装..."

    if [[ "$os" == "rhel" ]]; then
        if ! yum install -y openssl openssl-devel &>/dev/null; then
            echo -e "${RED}✗${NC} OpenSSL 安装失败"
            return 1
        fi
    elif [[ "$os" == "debian" ]]; then
        if ! apt-get install -y openssl libssl-dev &>/dev/null; then
            echo -e "${RED}✗${NC} OpenSSL 安装失败"
            return 1
        fi
    fi

    echo -e "${GREEN}✓${NC} OpenSSL 安装成功"
    return 0
}

# ======================== Scala 检查与安装 ========================

# 检查 Scala 是否已安装
check_scala_installed() {
    if command -v scala &> /dev/null; then
        local scala_version=$(scala -version 2>&1 | awk '{print $NF}')
        echo "installed:$scala_version"
        return 0
    fi
    echo "not_installed"
    return 1
}

# 自动安装 Scala
install_scala_auto() {
    local os=$(detect_os_for_deps)

    echo -e "${BLUE}→${NC} 检测到缺失 Scala, 正在安装..."

    if [[ "$os" == "rhel" ]]; then
        if ! yum install -y scala &>/dev/null; then
            echo -e "${RED}✗${NC} Scala 安装失败"
            return 1
        fi
    elif [[ "$os" == "debian" ]]; then
        if ! apt-get install -y scala &>/dev/null; then
            echo -e "${RED}✗${NC} Scala 安装失败"
            return 1
        fi
    fi

    echo -e "${GREEN}✓${NC} Scala 安装成功"
    return 0
}

# ======================== 系统包检查与安装 ========================

# 检查系统包是否已安装
check_package_installed() {
    local package_name=$1
    local os=$(detect_os_for_deps)

    if [[ "$os" == "rhel" ]]; then
        rpm -q "$package_name" &>/dev/null
    elif [[ "$os" == "debian" ]]; then
        dpkg -l | grep "^ii.*$package_name" &>/dev/null
    fi
}

# 获取包的版本
get_package_version() {
    local package_name=$1
    local os=$(detect_os_for_deps)

    if [[ "$os" == "rhel" ]]; then
        rpm -q "$package_name" 2>/dev/null | cut -d'-' -f2-
    elif [[ "$os" == "debian" ]]; then
        apt-cache show "$package_name" 2>/dev/null | grep Version | awk '{print $2}'
    fi
}

# 自动安装系统包
install_package_auto() {
    local package_name=$1
    local os=$(detect_os_for_deps)

    echo -e "${BLUE}→${NC} 正在安装系统包: $package_name"

    if [[ "$os" == "rhel" ]]; then
        if ! yum install -y "$package_name" &>/dev/null; then
            echo -e "${RED}✗${NC} 包 $package_name 安装失败"
            return 1
        fi
    elif [[ "$os" == "debian" ]]; then
        if ! apt-get update &>/dev/null || ! apt-get install -y "$package_name" &>/dev/null; then
            echo -e "${RED}✗${NC} 包 $package_name 安装失败"
            return 1
        fi
    fi

    echo -e "${GREEN}✓${NC} 包 $package_name 安装成功"
    return 0
}

# ======================== 依赖检查函数 ========================

# 检查应用的所有依赖
check_dependencies_status() {
    local app_name=$1
    shift
    local dependencies=("$@")

    local missing_count=0
    local total_count=${#dependencies[@]}

    echo -e "${CYAN}📦 检查 ${app_name} 的依赖${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for dep in "${dependencies[@]}"; do
        case "$dep" in
            "java")
                local status=$(check_java_installed)
                if [[ "$status" != "not_installed" ]]; then
                    echo -e "  ${GREEN}✓${NC} Java (${status#installed:})"
                else
                    echo -e "  ${RED}✗${NC} Java 8+ (未安装)"
                    ((missing_count++))
                fi
                ;;
            "python")
                local status=$(check_python_installed)
                if [[ "$status" != "not_installed" ]]; then
                    echo -e "  ${GREEN}✓${NC} Python 3 (${status#installed:})"
                else
                    echo -e "  ${RED}✗${NC} Python 3.6+ (未安装)"
                    ((missing_count++))
                fi
                ;;
            "pip")
                local status=$(check_pip_installed)
                if [[ "$status" != "not_installed" ]]; then
                    echo -e "  ${GREEN}✓${NC} pip (${status#installed:})"
                else
                    echo -e "  ${RED}✗${NC} pip (未安装)"
                    ((missing_count++))
                fi
                ;;
            "openssl")
                local status=$(check_openssl_installed)
                if [[ "$status" != "not_installed" ]]; then
                    echo -e "  ${GREEN}✓${NC} OpenSSL (${status#installed:})"
                else
                    echo -e "  ${RED}✗${NC} OpenSSL (未安装)"
                    ((missing_count++))
                fi
                ;;
            "scala")
                local status=$(check_scala_installed)
                if [[ "$status" != "not_installed" ]]; then
                    echo -e "  ${GREEN}✓${NC} Scala (${status#installed:})"
                else
                    echo -e "  ${RED}✗${NC} Scala (未安装)"
                    ((missing_count++))
                fi
                ;;
            *)
                if check_package_installed "$dep"; then
                    local version=$(get_package_version "$dep")
                    echo -e "  ${GREEN}✓${NC} $dep ($version)"
                else
                    echo -e "  ${RED}✗${NC} $dep (未安装)"
                    ((missing_count++))
                fi
                ;;
        esac
    done

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ $missing_count -eq 0 ]]; then
        echo -e "${GREEN}✓ 所有依赖已就绪${NC}\n"
        return 0
    else
        echo -e "${YELLOW}⚠ 缺失 $missing_count/$total_count 个依赖${NC}\n"
        return 1
    fi
}

# ======================== 自动安装依赖 ========================

# 自动安装缺失的依赖
install_missing_dependencies() {
    local app_name=$1
    shift
    local dependencies=("$@")

    echo -e "${BLUE}[安装缺失的依赖...]${NC}\n"

    local failed_count=0

    for dep in "${dependencies[@]}"; do
        case "$dep" in
            "java")
                if [[ $(check_java_installed) == "not_installed" ]]; then
                    if ! install_java_auto; then
                        ((failed_count++))
                    fi
                fi
                ;;
            "python")
                if [[ $(check_python_installed) == "not_installed" ]]; then
                    if ! install_python_auto; then
                        ((failed_count++))
                    fi
                fi
                ;;
            "pip")
                if [[ $(check_pip_installed) == "not_installed" ]]; then
                    if ! install_pip_auto; then
                        ((failed_count++))
                    fi
                fi
                ;;
            "openssl")
                if ! check_openssl_installed &>/dev/null; then
                    if ! install_openssl_auto; then
                        ((failed_count++))
                    fi
                fi
                ;;
            "scala")
                if [[ $(check_scala_installed) == "not_installed" ]]; then
                    if ! install_scala_auto; then
                        ((failed_count++))
                    fi
                fi
                ;;
            *)
                if ! check_package_installed "$dep"; then
                    if ! install_package_auto "$dep"; then
                        ((failed_count++))
                    fi
                fi
                ;;
        esac
    done

    echo ""

    if [[ $failed_count -eq 0 ]]; then
        echo -e "${GREEN}✓ 所有依赖安装成功${NC}\n"
        return 0
    else
        echo -e "${RED}✗ $failed_count 个依赖安装失败${NC}\n"
        return 1
    fi
}

# ======================== 主检查函数 ========================

# 检查并安装依赖（带交互）
check_and_install_dependencies() {
    local app_name=$1
    shift
    local dependencies=("$@")

    # 检查依赖状态
    if check_dependencies_status "$app_name" "${dependencies[@]}"; then
        # 所有依赖已就绪
        return 0
    fi

    # 询问是否安装缺失的依赖
    echo -e "${YELLOW}是否立即安装缺失的依赖? [y/n]${NC}"
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        if install_missing_dependencies "$app_name" "${dependencies[@]}"; then
            return 0
        else
            echo -e "${RED}⚠ 部分依赖安装失败，请手动检查${NC}\n"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ 跳过依赖安装，请手动安装所需依赖${NC}\n"
        return 1
    fi
}

# 仅检查不安装
check_dependencies_only() {
    local app_name=$1
    shift
    local dependencies=("$@")

    check_dependencies_status "$app_name" "${dependencies[@]}"
}

# 仅安装不询问
install_dependencies_auto() {
    local app_name=$1
    shift
    local dependencies=("$@")

    echo -e "${BLUE}[自动安装 ${app_name} 的依赖...]${NC}\n"
    install_missing_dependencies "$app_name" "${dependencies[@]}"
}

export -f detect_os_for_deps get_os_version
export -f check_java_installed get_java_major_version install_java_auto
export -f check_python_installed get_python_major_version install_python_auto
export -f check_pip_installed install_pip_auto
export -f check_openssl_installed install_openssl_auto
export -f check_scala_installed install_scala_auto
export -f check_package_installed get_package_version install_package_auto
export -f check_dependencies_status install_missing_dependencies
export -f check_and_install_dependencies check_dependencies_only install_dependencies_auto