#!/bin/bash

################################################################################
# Certbot (Let's Encrypt) 自动安装脚本
# 支持 CentOS/RHEL 7+, Ubuntu 18.04+, Kylin, UOS
# 功能:
#   - 安装 Certbot 和相应的服务器插件
#   - 交互式选择服务器类型 (Nginx/Apache/手动)
#   - 申请免费 HTTPS 证书
#   - 支持 HTTP 和 DNS 验证方式
#   - 自动配置证书续期 (cron 任务)
#   - 证书自动更新时服务重新加载
#   - DNS 提供商自动识别
#
# 使用方法:
#   sudo bash install_certbot.sh
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




# 配置变量
CERTBOT_VERSION="latest"
DOMAIN_NAME=""
DOMAIN_EMAIL=""
SERVER_TYPE="nginx"              # nginx, apache, manual
VALIDATION_METHOD="http"         # http, dns
RENEW_METHOD="auto"             # auto, manual
CERTBOT_HOME="/etc/letsencrypt"
CERT_RENEWAL_SCRIPT="/opt/certbot-auto-renew.sh"

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 打印标题
print_header() {
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║    Certbot (Let's Encrypt) 自动安装脚本 v1.0.0           ║"
    echo "╚════════════════════════════════════════════════════════════╝"
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

# 检查是否已安装
check_installed() {
    if command -v certbot &> /dev/null; then
        local INSTALLED_VERSION=$(certbot --version 2>&1 | awk '{print $2}')
        log_warn "Certbot 已安装 (版本: $INSTALLED_VERSION)"
        read -p "是否继续？(y/n) [n]: " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "安装已取消"
            exit 0
        fi
    fi
}

# 检查 Python 前置依赖
check_python() {
    log_info "检查 Python 前置依赖..."

    if ! command -v python3 &> /dev/null; then
        log_warn "未找到 Python3，正在安装..."
        if [[ "$PKG_MANAGER" == "yum" ]]; then
            yum install -y python3 python3-pip
        else
            apt-get update -qq
            apt-get install -y python3 python3-pip
        fi
    fi

    local python_version=$(python3 --version 2>&1 | awk '{print $2}')
    log_success "Python 已安装: $python_version"

    # 检查 pip3
    if ! command -v pip3 &> /dev/null; then
        log_error "pip3 未安装，无法继续"
        exit 1
    fi
    log_success "pip3 已安装"
}

# 检查并创建证书目录
check_certificate_dir() {
    log_info "检查证书目录..."

    if [[ ! -d "$CERTBOT_HOME" ]]; then
        log_warn "证书目录不存在: $CERTBOT_HOME"
        log_info "创建证书目录..."
        mkdir -p "$CERTBOT_HOME"
        chmod 700 "$CERTBOT_HOME"
        log_success "证书目录已创建: $CERTBOT_HOME"
    else
        log_success "证书目录已存在: $CERTBOT_HOME"
    fi

    # 检查 live 目录
    if [[ ! -d "$CERTBOT_HOME/live" ]]; then
        log_info "live 子目录不存在，这是正常的（第一次安装）"
    else
        local cert_count=$(ls "$CERTBOT_HOME/live" 2>/dev/null | wc -l)
        log_info "已有 $cert_count 个证书"
    fi
}
    log_info "检查已安装的服务器..."

    if command -v nginx &> /dev/null; then
        log_success "检测到 Nginx"
        NGINX_INSTALLED=true
    fi

    if command -v apache2 &> /dev/null || command -v httpd &> /dev/null; then
        log_success "检测到 Apache"
        APACHE_INSTALLED=true
    fi

    if [[ -z "$NGINX_INSTALLED" ]] && [[ -z "$APACHE_INSTALLED" ]]; then
        log_warn "未检测到 Nginx 或 Apache，将使用手动验证模式"
        SERVER_TYPE="manual"
    fi
}

# 交互式配置
interactive_config() {
    echo ""
    log_info "Certbot 配置向导"
    echo ""

    # 输入域名
    echo -e "${BLUE}请输入要申请证书的域名:${NC}"
    read -p "域名 (如: example.com): " DOMAIN_NAME
    if [[ -z "$DOMAIN_NAME" ]]; then
        log_error "域名不能为空"
        exit 1
    fi
    log_info "域名: $DOMAIN_NAME"

    # 支持通配符和多个域名
    echo -e "${BLUE}是否添加更多域名？(y/n) [n]:${NC}"
    read -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "请输入其他域名，用逗号分隔 (如: www.example.com,api.example.com): " MORE_DOMAINS
        if [[ -n "$MORE_DOMAINS" ]]; then
            DOMAIN_NAME="$DOMAIN_NAME,$MORE_DOMAINS"
            log_info "域名列表: $DOMAIN_NAME"
        fi
    fi

    # 输入邮箱
    echo ""
    read -p "请输入邮箱地址 (用于证书过期提醒): " DOMAIN_EMAIL
    if [[ -z "$DOMAIN_EMAIL" ]]; then
        log_error "邮箱不能为空"
        exit 1
    fi
    log_info "邮箱: $DOMAIN_EMAIL"

    # 选择服务器类型
    if [[ "$NGINX_INSTALLED" == "true" ]] || [[ "$APACHE_INSTALLED" == "true" ]]; then
        echo ""
        echo -e "${BLUE}请选择服务器类型:${NC}"
        echo "  1) Nginx"
        echo "  2) Apache"
        echo "  3) 手动验证 (DNS/HTTP 手动管理)"
        read -p "请选择 [1-3, 默认 1]: " server_choice

        case $server_choice in
            2)
                SERVER_TYPE="apache"
                log_info "选择服务器: Apache"
                ;;
            3)
                SERVER_TYPE="manual"
                log_info "选择模式: 手动验证"
                ;;
            *)
                SERVER_TYPE="nginx"
                log_info "选择服务器: Nginx"
                ;;
        esac
    fi

    # 选择验证方式
    if [[ "$SERVER_TYPE" == "manual" ]]; then
        echo ""
        echo -e "${BLUE}请选择验证方式:${NC}"
        echo "  1) HTTP 验证 (需要 80 端口可访问)"
        echo "  2) DNS 验证 (使用 DNS 记录验证)"
        read -p "请选择 [1-2, 默认 1]: " validation_choice

        case $validation_choice in
            2)
                VALIDATION_METHOD="dns"
                log_info "选择验证方式: DNS"
                ;;
            *)
                VALIDATION_METHOD="http"
                log_info "选择验证方式: HTTP"
                ;;
        esac
    else
        # 自动选择服务器配置验证
        VALIDATION_METHOD="http"
        log_info "将使用服务器插件自动验证"
    fi

    # 询问是否自动续期
    echo ""
    read -p "是否启用自动续期? (y/n) [y]: " -r
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        RENEW_METHOD="manual"
        log_info "选择: 手动续期"
    else
        RENEW_METHOD="auto"
        log_info "选择: 自动续期 (每天检查)"
    fi
}

# 安装 Certbot
install_certbot() {
    log_info "安装 Certbot..."
    echo ""
    log_info "【安装步骤 1】检查 Python 环境"
    check_python

    echo ""
    log_info "【安装步骤 2】安装 Certbot 和依赖"

    if [[ "$PKG_MANAGER" == "yum" ]]; then
        # CentOS/RHEL
        log_info "使用 yum 安装 Certbot..."
        yum install -y python3 python3-pip
        pip3 install certbot

        # 安装服务器插件
        if [[ "$SERVER_TYPE" == "nginx" ]]; then
            log_info "安装 Nginx 插件..."
            pip3 install certbot-nginx
        elif [[ "$SERVER_TYPE" == "apache" ]]; then
            log_info "安装 Apache 插件..."
            yum install -y python3-certbot-apache
        fi

    else
        # Ubuntu/Debian
        log_info "使用 apt 安装 Certbot..."
        apt-get update -qq
        apt-get install -y certbot

        # 安装服务器插件
        if [[ "$SERVER_TYPE" == "nginx" ]]; then
            log_info "安装 Nginx 插件..."
            apt-get install -y python3-certbot-nginx
        elif [[ "$SERVER_TYPE" == "apache" ]]; then
            log_info "安装 Apache 插件..."
            apt-get install -y python3-certbot-apache
        fi
    fi

    log_success "Certbot 安装完成"
}

# 申请证书
obtain_certificate() {
    echo ""
    log_info "【安装步骤 3】申请 Let's Encrypt 证书"
    log_info "域名: $DOMAIN_NAME"
    log_info "验证方式: $VALIDATION_METHOD"
    echo ""

    local DOMAINS=$(echo "$DOMAIN_NAME" | tr ',' ' ')
    local DOMAIN_ARGS=""

    for domain in $DOMAINS; do
        DOMAIN_ARGS="$DOMAIN_ARGS -d $domain"
    done

    # 根据不同的验证方式申请证书
    case $SERVER_TYPE in
        nginx)
            log_info "使用 Nginx 插件申请证书..."
            log_info "正在与 Let's Encrypt 通讯..."
            certbot --nginx $DOMAIN_ARGS \
                --email "$DOMAIN_EMAIL" \
                --agree-tos \
                --non-interactive \
                --redirect || log_warn "Nginx 自动配置失败，请手动配置"
            ;;
        apache)
            log_info "使用 Apache 插件申请证书..."
            log_info "正在与 Let's Encrypt 通讯..."
            certbot --apache $DOMAIN_ARGS \
                --email "$DOMAIN_EMAIL" \
                --agree-tos \
                --non-interactive \
                --redirect || log_warn "Apache 自动配置失败，请手动配置"
            ;;
        manual)
            # 手动验证
            if [[ "$VALIDATION_METHOD" == "dns" ]]; then
                log_info "使用 DNS 验证申请证书..."
                log_info "请根据下面的提示完成 DNS 验证"
                log_info "---"
                certbot certonly --manual --preferred-challenges=dns $DOMAIN_ARGS \
                    --email "$DOMAIN_EMAIL" \
                    --agree-tos || true
                log_info "---"
                log_info "DNS 验证已完成"
            else
                log_info "使用 HTTP 验证申请证书..."
                log_info "确保 HTTP 端口 (80) 可访问..."
                certbot certonly --standalone --preferred-challenges=http $DOMAIN_ARGS \
                    --email "$DOMAIN_EMAIL" \
                    --agree-tos \
                    --non-interactive || true
            fi
            ;;
    esac

    log_success "证书申请步骤完成"
}

# 配置自动续期
configure_auto_renewal() {
    if [[ "$RENEW_METHOD" != "auto" ]]; then
        log_info "已选择手动续期模式"
        log_info "手动续期命令: certbot renew"
        return
    fi

    log_info "配置自动续期..."

    # 创建续期脚本
    cat > "$CERT_RENEWAL_SCRIPT" << 'EOF'
#!/bin/bash
# Certbot 自动续期脚本

# 续期所有证书
certbot renew --quiet

# 如果证书已更新，重新加载服务
if [ $? -eq 0 ]; then
    # 重新加载 Nginx
    if systemctl is-active --quiet nginx; then
        systemctl reload nginx
    fi

    # 重新加载 Apache
    if systemctl is-active --quiet apache2 || systemctl is-active --quiet httpd; then
        systemctl reload apache2 || systemctl reload httpd
    fi
fi
EOF

    chmod 755 "$CERT_RENEWAL_SCRIPT"

    # 添加 cron 任务
    local CRON_TASK="0 3 * * * $CERT_RENEWAL_SCRIPT"
    local CRON_FILE="/etc/cron.d/certbot-renewal"

    if grep -q "certbot-renewal" /etc/cron.d/* 2>/dev/null; then
        log_warn "cron 任务已存在"
    else
        echo "$CRON_TASK" | tee "$CRON_FILE" > /dev/null
        chmod 644 "$CRON_FILE"
        log_success "自动续期 cron 任务已配置"
        log_info "  执行时间: 每天凌晨 3:00"
        log_info "  续期脚本: $CERT_RENEWAL_SCRIPT"
    fi

    log_info "测试自动续期: certbot renew --dry-run"
}

# 配置防火墙
configure_firewall() {
    if [[ "$VALIDATION_METHOD" == "http" ]] || [[ "$SERVER_TYPE" != "manual" ]]; then
        log_info "配置防火墙 (HTTP/HTTPS)..."

        if command -v firewall-cmd &> /dev/null; then
            firewall-cmd --permanent --add-service=http
            firewall-cmd --permanent --add-service=https
            firewall-cmd --reload
            log_success "防火墙规则已添加 (yum系统)"
        elif command -v ufw &> /dev/null; then
            ufw allow 80/tcp
            ufw allow 443/tcp
            log_success "防火墙规则已添加 (apt系统)"
        fi
    fi
}

# 验证证书
verify_certificates() {
    log_info "验证证书..."

    if [[ ! -d "$CERTBOT_HOME/live" ]]; then
        log_warn "证书目录不存在: $CERTBOT_HOME/live"
        log_info "可能原因："
        log_info "  1. 证书申请还未完成"
        log_info "  2. 使用了手动验证模式，需要手动完成DNS/HTTP验证"
        log_info "  3. 证书申请过程中出现错误"
        log_info ""
        log_info "请检查日志文件: /var/log/letsencrypt/letsencrypt.log"
        return 1
    fi

    local DOMAINS=$(echo "$DOMAIN_NAME" | tr ',' ' ')
    local cert_found=0

    for domain in $DOMAINS; do
        if [[ -f "$CERTBOT_HOME/live/$domain/cert.pem" ]]; then
            local EXPIRY=$(openssl x509 -enddate -noout -in "$CERTBOT_HOME/live/$domain/cert.pem" | cut -d= -f2)
            log_success "证书已获得: $domain"
            log_info "  过期时间: $EXPIRY"
            ((cert_found++))
        else
            log_warn "未找到证书: $domain"
            log_info "  证书路径: $CERTBOT_HOME/live/$domain/cert.pem"
        fi
    done

    if [[ $cert_found -eq 0 ]]; then
        log_error "没有找到任何有效的证书"
        return 1
    fi

    log_success "找到 $cert_found 个证书"
    return 0
}

# 生成 Nginx 配置示例
generate_nginx_config() {
    local FIRST_DOMAIN=$(echo "$DOMAIN_NAME" | cut -d',' -f1)
    local CONFIG_FILE="/tmp/nginx_ssl_config.conf"

    cat > "$CONFIG_FILE" << EOF
# Nginx SSL 配置示例
# 将以下配置添加到您的 Nginx server 块

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $FIRST_DOMAIN;

    # SSL 证书路径
    ssl_certificate /etc/letsencrypt/live/$FIRST_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$FIRST_DOMAIN/privkey.pem;

    # SSL 安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # 其他配置...
    location / {
        proxy_pass http://backend;
    }
}

# HTTP 重定向到 HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $FIRST_DOMAIN;

    location / {
        return 301 https://\$server_name\$request_uri;
    }

    # Certbot 验证路径（保留以便续期）
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
}
EOF

    echo ""
    log_success "Nginx 配置示例已生成: $CONFIG_FILE"
}

# 生成 Apache 配置示例
generate_apache_config() {
    local FIRST_DOMAIN=$(echo "$DOMAIN_NAME" | cut -d',' -f1)
    local CONFIG_FILE="/tmp/apache_ssl_config.conf"

    cat > "$CONFIG_FILE" << EOF
# Apache SSL 配置示例
# 将以下配置添加到您的 VirtualHost

<VirtualHost *:443>
    ServerName $FIRST_DOMAIN
    ServerAdmin admin@$FIRST_DOMAIN

    # SSL 证书
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/$FIRST_DOMAIN/cert.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/$FIRST_DOMAIN/privkey.pem
    SSLCertificateChainFile /etc/letsencrypt/live/$FIRST_DOMAIN/chain.pem

    # SSL 安全配置
    SSLProtocol TLSv1.2 TLSv1.3
    SSLCipherSuite HIGH:!aNULL:!MD5

    # 其他配置...
    DocumentRoot /var/www/html
</VirtualHost>

# HTTP 重定向到 HTTPS
<VirtualHost *:80>
    ServerName $FIRST_DOMAIN
    Redirect permanent / https://$FIRST_DOMAIN/

    # Certbot 验证路径
    DocumentRoot /var/www/certbot
</VirtualHost>
EOF

    echo ""
    log_success "Apache 配置示例已生成: $CONFIG_FILE"
}

# 生成安装报告
generate_report() {
    local report_file="/tmp/install_certbot_report_$(date +%Y%m%d_%H%M%S).txt"
    local FIRST_DOMAIN=$(echo "$DOMAIN_NAME" | cut -d',' -f1)

    cat > "$report_file" << EOF
╔════════════════════════════════════════════════════════════════╗
║         Certbot (Let's Encrypt) 安装报告                     ║
╚════════════════════════════════════════════════════════════════╝

【安装信息】
安装时间: $(date '+%Y-%m-%d %H:%M:%S')
Certbot 版本: $(certbot --version 2>&1 | awk '{print $2}')
服务器类型: $SERVER_TYPE
验证方式: $VALIDATION_METHOD

【证书信息】
域名: $DOMAIN_NAME
邮箱: $DOMAIN_EMAIL
续期方式: $RENEW_METHOD

【证书位置】
证书路径: $CERTBOT_HOME/live/$FIRST_DOMAIN/
- fullchain.pem (完整证书链)
- cert.pem (证书)
- privkey.pem (私钥)
- chain.pem (链证书)

【常用命令】
1. 查看所有证书:
   certbot certificates

2. 手动续期所有证书:
   certbot renew

3. 手动续期特定证书:
   certbot renew --cert-name $FIRST_DOMAIN

4. 删除证书:
   certbot delete --cert-name $FIRST_DOMAIN

5. 强制续期 (用于测试):
   certbot renew --force-renewal

6. 查看证书详情:
   openssl x509 -text -noout -in $CERTBOT_HOME/live/$FIRST_DOMAIN/cert.pem

7. 查看证书过期日期:
   openssl x509 -enddate -noout -in $CERTBOT_HOME/live/$FIRST_DOMAIN/cert.pem

【配置建议】

1. Nginx 用户:
   - 查看生成的配置示例: /tmp/nginx_ssl_config.conf
   - 将配置添加到您的 Nginx 配置文件
   - 测试配置: nginx -t
   - 重新加载: systemctl reload nginx

2. Apache 用户:
   - 查看生成的配置示例: /tmp/apache_ssl_config.conf
   - 启用 SSL 模块: a2enmod ssl
   - 启用 Rewrite 模块: a2enmod rewrite
   - 重新加载: systemctl reload apache2

3. 手动验证用户:
   - 根据提示完成 DNS/HTTP 验证
   - 使用上述命令手动续期证书

【自动续期设置】
$(if [[ "$RENEW_METHOD" == "auto" ]]; then
    echo "✅ 已启用自动续期"
    echo "   - Cron 任务: 每天凌晨 3 点检查"
    echo "   - 续期脚本: $CERT_RENEWAL_SCRIPT"
    echo "   - 证书更新时自动重新加载 Nginx/Apache"
else
    echo "❌ 禁用了自动续期"
    echo "   - 需要手动运行: certbot renew"
    echo "   - 建议定期检查证书过期时间"
fi)

【安全建议】
1. 保护私钥文件: chmod 600 $CERTBOT_HOME/live/$FIRST_DOMAIN/privkey.pem
2. 定期检查证书有效期
3. 配置邮件告警 (Let's Encrypt 会在过期前发邮件)
4. 测试自动续期: certbot renew --dry-run
5. 监控日志: /var/log/letsencrypt/

【常见问题】
Q1: 如何同时为多个域名申请证书?
A: 脚本支持输入多个域名，用逗号分隔

Q2: 如何更新已有证书?
A: 运行 certbot renew 或等待自动续期

Q3: 证书过期了怎么办?
A: Let's Encrypt 会发邮件提醒，运行 certbot renew 即可

Q4: 如何测试自动续期?
A: 运行 certbot renew --dry-run

【技术支持】
Let's Encrypt 官网: https://letsencrypt.org/
Certbot 文档: https://certbot.eff.org/
EOF

    echo ""
    cat "$report_file"
    log_success "安装报告已生成: $report_file"
}

# 主函数
main() {
    print_header
    check_root
    detect_os

    echo ""
    log_info "╔════════════════════════════════════════════════════════╗"
    log_info "║        Certbot 安装流程指南                           ║"
    log_info "╚════════════════════════════════════════════════════════╝"
    echo ""
    log_info "本脚本将执行以下步骤:"
    log_info "  1️⃣  检查系统环境和 Python 依赖"
    log_info "  2️⃣  安装 Certbot 和相关插件"
    log_info "  3️⃣  申请 Let's Encrypt 免费证书"
    log_info "  4️⃣  配置自动续期任务 (可选)"
    log_info "  5️⃣  配置防火墙规则"
    log_info "  6️⃣  验证证书并生成配置示例"
    log_info "  7️⃣  生成安装报告"
    echo ""

    # 检查前置依赖
    log_info "【前置检查】"
    if command -v check_and_install_dependencies &>/dev/null; then
        log_info "检查前置依赖..."
        check_and_install_dependencies "Certbot" "${CERTBOT_DEPENDENCIES[@]}"
        echo ""
    fi
    check_installed
    check_server
    check_certificate_dir

    echo ""
    log_info "【交互配置】"
    interactive_config

    echo ""
    log_info "【开始安装】"
    install_certbot

    if [[ "$SERVER_TYPE" != "manual" ]]; then
        obtain_certificate
    else
        log_info "手动验证模式: 请根据提示完成域名验证"
        obtain_certificate || true
    fi

    echo ""
    log_info "【配置续期】"
    configure_auto_renewal

    echo ""
    log_info "【配置防火墙】"
    configure_firewall

    echo ""
    log_info "【验证安装】"
    if verify_certificates; then
        echo ""
        log_info "【生成配置】"
        if [[ "$SERVER_TYPE" == "nginx" ]]; then
            generate_nginx_config
        elif [[ "$SERVER_TYPE" == "apache" ]]; then
            generate_apache_config
        fi

        echo ""
        log_info "【生成报告】"
        generate_report

        echo ""
        log_success "✅ Certbot 安装完成！"
        echo ""
        log_info "【后续步骤】"
        log_info "1. 根据您的服务器类型（Nginx/Apache），参考生成的配置示例"
        log_info "2. 测试证书是否生效"
        log_info "3. 监控日志确保续期正常工作"
        echo ""
        exit 0
    else
        echo ""
        log_error "❌ 证书验证失败，安装未完成"
        log_info ""
        log_info "【故障排查】"
        log_info "1. 检查域名是否正确解析"
        log_info "2. 确保 HTTP/HTTPS 端口可访问"
        log_info "3. 查看详细日志: tail -f /var/log/letsencrypt/letsencrypt.log"
        log_info "4. 运行以下命令查看证书申请状态:"
        log_info "   certbot certificates"
        echo ""
        exit 1
    fi
}

main
