#!/bin/bash

################################################################################
# Nginx 自动安装脚本
# 支持 CentOS/RHEL 7+, Ubuntu 18.04+, Kylin, UOS
# 功能:
#   - 从官方源安装最新稳定版 Nginx
#   - 配置基本 server 块
#   - 优化性能参数
#   - 配置开机自启
#   - 验证安装
#
# 使用方法:
#   sudo bash install_nginx.sh
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
HTTP_PORT=80
HTTPS_PORT=443

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 打印标题
print_header() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║           Nginx 自动安装脚本 v1.0.0                      ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        log_info "请使用: sudo bash $0"
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

# 检查是否已安装
check_installed() {
    if command -v nginx &> /dev/null; then
        NGINX_VERSION=$(nginx -v 2>&1 | cut -d'/' -f2)
        log_warn "检测到已安装 Nginx: $NGINX_VERSION"
        read -p "是否继续安装? (y/n): " -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "安装已取消"
            exit 0
        fi
    fi
}

# 检查端口占用
check_port() {
    local port=$1
    if ss -tuln 2>/dev/null | grep -q ":$port " || netstat -tuln 2>/dev/null | grep -q ":$port "; then
        log_warn "端口 $port 已被占用"
        return 1
    fi
    return 0
}

# 安装 Nginx (CentOS/RHEL)
install_nginx_yum() {
    # 麒麟系统特殊处理
    if [[ "$OS" == "kylin" ]]; then
        log_info "检测到麒麟系统,使用系统自带仓库..."

        # 尝试直接安装系统自带的Nginx
        log_info "从系统仓库安装 Nginx..."
        if yum install -y nginx 2>/dev/null; then
            log_success "Nginx 安装成功 (系统版本)"
            NGINX_VERSION=$(nginx -v 2>&1 | cut -d'/' -f2 || echo "unknown")
            log_info "实际安装版本: Nginx $NGINX_VERSION"
            return 0
        else
            log_error "系统仓库安装失败,请检查yum源配置"
            log_info "可用的Nginx包:"
            yum search nginx 2>/dev/null | grep "^nginx"
            exit 1
        fi
    fi

    # 标准CentOS/RHEL系统,使用官方仓库
    log_info "添加 Nginx 官方仓库..."

    cat > /etc/yum.repos.d/nginx.repo <<EOF
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF

    log_info "安装 Nginx..."
    if ! yum install -y nginx 2>/dev/null; then
        log_warn "官方仓库安装失败,尝试使用系统仓库..."
        if yum install -y nginx 2>/dev/null; then
            log_success "Nginx 安装成功 (系统版本)"
            return 0
        else
            log_error "无法安装Nginx,请检查yum源配置"
            exit 1
        fi
    fi

    log_success "Nginx 安装完成"
}

# 安装 Nginx (Ubuntu/Debian)
install_nginx_apt() {
    log_info "安装 Nginx..."

    apt-get update -qq
    apt-get install -y nginx

    log_success "Nginx 安装完成"
}

# 配置 Nginx
configure_nginx() {
    log_info "配置 Nginx..."

    # 备份原配置
    if [[ -f /etc/nginx/nginx.conf ]]; then
        cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak.$(date +%Y%m%d_%H%M%S)
    fi

    # 优化主配置
    cat > /etc/nginx/nginx.conf <<'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 2048;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 50M;

    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1000;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript
               application/json application/javascript application/xml+rss
               application/rss+xml font/truetype font/opentype
               application/vnd.ms-fontobject image/svg+xml;
    gzip_disable "msie6";

    # 隐藏版本号
    server_tokens off;

    # 包含其他配置文件
    include /etc/nginx/conf.d/*.conf;
}
EOF

    # 创建默认站点配置
    mkdir -p /etc/nginx/conf.d

    cat > /etc/nginx/conf.d/default.conf <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    root /usr/share/nginx/html;
    index index.html index.htm;

    # 日志
    access_log /var/log/nginx/default_access.log main;
    error_log /var/log/nginx/default_error.log warn;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # 禁止访问隐藏文件
    location ~ /\. {
        deny all;
    }

    # 状态页面 (仅本地访问)
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
    }
}
EOF

    # 创建欢迎页面
    mkdir -p /usr/share/nginx/html
    cat > /usr/share/nginx/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Nginx 安装成功!</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 50px;
            text-align: center;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            background: rgba(255,255,255,0.1);
            padding: 40px;
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        h1 { font-size: 3em; margin: 0; }
        p { font-size: 1.2em; }
        .success { color: #00ff88; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎉 Nginx 安装成功!</h1>
        <p class="success">服务器正在运行中</p>
        <p>配置文件: /etc/nginx/nginx.conf</p>
        <p>站点目录: /usr/share/nginx/html</p>
    </div>
</body>
</html>
EOF

    # 测试配置
    if nginx -t &> /dev/null; then
        log_success "Nginx 配置验证通过"
    else
        log_error "Nginx 配置验证失败"
        nginx -t
        exit 1
    fi
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙规则..."

    if command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            firewall-cmd --permanent --add-service=http
            firewall-cmd --permanent --add-service=https
            firewall-cmd --reload
            log_success "防火墙规则已添加"
        fi
    elif command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            ufw allow 80/tcp
            ufw allow 443/tcp
            log_success "防火墙规则已添加"
        fi
    else
        log_warn "未检测到防火墙，跳过配置"
    fi
}

# 启动服务
start_service() {
    log_info "启动 Nginx 服务..."

    systemctl daemon-reload
    systemctl enable nginx
    systemctl restart nginx

    sleep 2

    if systemctl is-active --quiet nginx; then
        log_success "Nginx 服务启动成功"
    else
        log_error "Nginx 服务启动失败"
        systemctl status nginx --no-pager
        exit 1
    fi
}

# 验证安装
verify_installation() {
    log_info "验证 Nginx 安装..."

    NGINX_VERSION=$(nginx -v 2>&1 | cut -d'/' -f2)
    log_success "Nginx 版本: $NGINX_VERSION"

    # 测试 HTTP 响应
    if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200"; then
        log_success "HTTP 服务正常"
    else
        log_warn "HTTP 服务响应异常"
    fi
}

# 生成安装报告
generate_report() {
    local REPORT_FILE="/tmp/install_nginx_report_$(date +%Y%m%d_%H%M%S).txt"
    local SERVER_IP=$(hostname -I | awk '{print $1}')

    cat > "$REPORT_FILE" <<EOF
╔═══════════════════════════════════════════════════════════╗
║           Nginx 安装报告                                  ║
╚═══════════════════════════════════════════════════════════╝

安装时间: $(date '+%Y-%m-%d %H:%M:%S')
操作系统: $OS_NAME ($OS_VERSION)

【安装版本】
Nginx: $(nginx -v 2>&1 | cut -d'/' -f2)

【服务状态】
$(systemctl status nginx --no-pager | head -n 3)

【访问地址】
HTTP:  http://$SERVER_IP
HTTPS: https://$SERVER_IP (需配置 SSL 证书)

【配置文件】
主配置:   /etc/nginx/nginx.conf
站点配置: /etc/nginx/conf.d/
网站目录: /usr/share/nginx/html
日志目录: /var/log/nginx/

【管理命令】
启动服务:   systemctl start nginx
停止服务:   systemctl stop nginx
重启服务:   systemctl restart nginx
重载配置:   systemctl reload nginx
查看状态:   systemctl status nginx
测试配置:   nginx -t
查看日志:   tail -f /var/log/nginx/access.log

【常用操作】
1. 添加新站点:
   - 在 /etc/nginx/conf.d/ 创建 yoursite.conf
   - 测试配置: nginx -t
   - 重载服务: systemctl reload nginx

2. 配置 SSL 证书:
   - 将证书放到 /etc/nginx/ssl/
   - 修改站点配置添加 SSL 指令
   - 重载服务

3. 查看状态:
   curl http://127.0.0.1/nginx_status

【性能优化】
- Worker 进程: auto (自动检测 CPU 核心数)
- 连接数: 2048
- Gzip 压缩: 已启用
- 文件发送: sendfile 已启用
- 客户端最大上传: 50MB

【安全配置】
- 隐藏版本号: 已启用
- 禁止访问隐藏文件: 已配置

【注意事项】
1. 默认站点目录: /usr/share/nginx/html
2. 修改配置后需执行 nginx -t 测试
3. 测试通过后执行 systemctl reload nginx 重载
4. 防火墙已开放 80/443 端口

【安装日志】
$REPORT_FILE

EOF

    log_success "安装报告已生成: $REPORT_FILE"

    # 显示摘要
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           Nginx 安装完成!                                 ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Nginx 版本:${NC} $(nginx -v 2>&1 | cut -d'/' -f2)"
    echo -e "${BLUE}服务状态:${NC} $(systemctl is-active nginx)"
    echo -e "${BLUE}访问地址:${NC} http://$SERVER_IP"
    echo ""
    echo -e "${YELLOW}提示:${NC} 请在浏览器访问 http://$SERVER_IP 查看欢迎页面"
    echo -e "${YELLOW}配置:${NC} /etc/nginx/nginx.conf"
    echo -e "${YELLOW}报告:${NC} $REPORT_FILE"
    echo ""
}

# 主函数
main() {
    print_header

    log_info "开始安装 Nginx..."
    echo ""

    check_root
    detect_os

    # 检查前置依赖
    if command -v check_and_install_dependencies &>/dev/null; then
        log_info "检查前置依赖..."
        check_and_install_dependencies "Nginx" "${NGINX_DEPENDENCIES[@]}"
        echo ""
    fi
    check_installed

    # 检查端口
    if ! check_port $HTTP_PORT; then
        log_warn "端口 $HTTP_PORT 已被占用，Nginx 可能无法正常启动"
    fi

    # 安装
    if [[ $PKG_MANAGER == "yum" ]]; then
        install_nginx_yum
    else
        install_nginx_apt
    fi

    configure_nginx
    configure_firewall
    start_service
    verify_installation

    echo ""
    generate_report
}

# 执行主函数
main
