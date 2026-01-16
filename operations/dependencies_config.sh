#!/bin/bash

################################################################################
# 应用依赖配置文件
# 定义所有应用的前置依赖列表
#
# 使用方法:
#   source ./dependencies_config.sh
#   check_and_install_dependencies "flink" "${FLINK_DEPENDENCIES[@]}"
#
# 作者: Shell Collections Team
# 版本: 1.0.0
################################################################################

# ======================== 大数据框架 ========================

# Apache Flink - 流处理框架
declare -a FLINK_DEPENDENCIES=(
    "java"          # Java 8+
    "python"        # Python 3.6+
)

# Apache Spark - 分布式计算框架
declare -a SPARK_DEPENDENCIES=(
    "java"          # Java 8+
    "python"        # Python 3.6+
    "scala"         # Scala 2.12+
)

# Apache Doris - 列式分析数据库
declare -a DORIS_DEPENDENCIES=(
    "java"          # Java 8+
    "gcc"           # C/C++ 编译器
    "g++"
    "make"
    "byacc"         # 语法分析器
    "libtool"
)

# ======================== 数据库 ========================

# MySQL - 关系型数据库
declare -a MYSQL_DEPENDENCIES=(
    "libaio"        # 异步I/O库
    "gcc"
    "gcc-c++"
    "make"
)

# PostgreSQL - 高级关系型数据库
declare -a POSTGRESQL_DEPENDENCIES=(
    "gcc"
    "gcc-c++"
    "make"
    "readline-devel"    # CentOS/RHEL
    "libreadline-dev"   # Ubuntu (会自动检测)
    "zlib-devel"        # CentOS/RHEL
    "zlib1g-dev"        # Ubuntu (会自动检测)
    "openssl-devel"     # CentOS/RHEL
    "libssl-dev"        # Ubuntu (会自动检测)
)

# MongoDB - NoSQL 文档数据库
declare -a MONGODB_DEPENDENCIES=(
    "gcc"
    "gcc-c++"
    "make"
)

# Redis - 内存数据结构存储
declare -a REDIS_DEPENDENCIES=(
    "gcc"
    "gcc-c++"
    "make"
    "tcl"           # Redis tests require tcl
)

# ======================== 消息队列 ========================

# RabbitMQ - 消息代理
declare -a RABBITMQ_DEPENDENCIES=(
    "java"          # Java 8+
    "erlang"        # Erlang 运行时
)

# ======================== Web 服务器 ========================

# Nginx - 高性能 Web 服务器
declare -a NGINX_DEPENDENCIES=(
    "gcc"
    "gcc-c++"
    "make"
    "pcre-devel"        # CentOS/RHEL - 正则表达式库
    "libpcre3-dev"      # Ubuntu
    "zlib-devel"        # CentOS/RHEL - 压缩库
    "zlib1g-dev"        # Ubuntu
    "openssl-devel"     # CentOS/RHEL
    "libssl-dev"        # Ubuntu
)

# ======================== 容器化 ========================

# Docker - 容器化平台
declare -a DOCKER_DEPENDENCIES=(
    "curl"          # HTTP 客户端
    "device-mapper" # 或 "device-mapper-persistent-data" for CentOS
)

# ======================== 证书管理 ========================

# Certbot - Let's Encrypt 证书管理工具
declare -a CERTBOT_DEPENDENCIES=(
    "python"        # Python 3.6+
    "pip"           # Python 包管理器
    "openssl"       # SSL/TLS 工具
)

# ======================== 对象存储 ========================

# MinIO - 对象存储服务
declare -a MINIO_DEPENDENCIES=(
    # MinIO 是单个二进制文件，无特殊依赖
)

# ======================== Kylin ========================

# Docker + Kylin - 基于 Docker 的 Kylin 部署
declare -a DOCKER_KYLIN_DEPENDENCIES=(
    "docker"        # Docker 容器
)

# ======================== 依赖映射表 ========================

# 用于快速查找应用的依赖
declare -A APP_DEPENDENCIES_MAP=(
    ["flink"]="FLINK_DEPENDENCIES"
    ["spark"]="SPARK_DEPENDENCIES"
    ["doris"]="DORIS_DEPENDENCIES"
    ["mysql"]="MYSQL_DEPENDENCIES"
    ["postgresql"]="POSTGRESQL_DEPENDENCIES"
    ["mongodb"]="MONGODB_DEPENDENCIES"
    ["redis"]="REDIS_DEPENDENCIES"
    ["rabbitmq"]="RABBITMQ_DEPENDENCIES"
    ["nginx"]="NGINX_DEPENDENCIES"
    ["docker"]="DOCKER_DEPENDENCIES"
    ["certbot"]="CERTBOT_DEPENDENCIES"
    ["minio"]="MINIO_DEPENDENCIES"
    ["docker_kylin"]="DOCKER_KYLIN_DEPENDENCIES"
)

# ======================== 辅助函数 ========================

# 根据应用名获取依赖列表
get_app_dependencies() {
    local app_name=$1

    # 转小写
    app_name=$(echo "$app_name" | tr '[:upper:]' '[:lower:]')

    # 特殊处理 docker_kylin
    if [[ "$app_name" == "kylin" || "$app_name" == "docker-kylin" ]]; then
        app_name="docker_kylin"
    fi

    if [[ -v "APP_DEPENDENCIES_MAP[$app_name]" ]]; then
        local deps_var="${APP_DEPENDENCIES_MAP[$app_name]}"
        eval "echo \"\${${deps_var}[@]}\""
    else
        echo ""
    fi
}

# 显示应用的依赖列表
show_app_dependencies() {
    local app_name=$1

    echo "应用: $app_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local deps=$(get_app_dependencies "$app_name")
    if [[ -z "$deps" ]]; then
        echo "此应用无特殊依赖"
    else
        echo "所需依赖:"
        local i=1
        for dep in $deps; do
            echo "  $i. $dep"
            ((i++))
        done
    fi
    echo ""
}

# 显示所有应用的依赖
show_all_dependencies() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "所有应用的前置依赖列表"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local apps=("flink" "spark" "doris" "mysql" "postgresql" "mongodb" "redis" "rabbitmq" "nginx" "docker" "certbot" "minio" "docker_kylin")

    for app in "${apps[@]}"; do
        show_app_dependencies "$app"
    done
}

export -f get_app_dependencies show_app_dependencies show_all_dependencies