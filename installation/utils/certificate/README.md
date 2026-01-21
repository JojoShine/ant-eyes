# SSL/TLS 证书管理工具集

本目录包含完整的 SSL/TLS 证书自动化管理工具，支持 Let's Encrypt 和手动证书管理。

## 📋 工具清单

| 脚本 | 功能 | 使用场景 |
|------|------|--------|
| `install_certbot.sh` | Certbot 安装和证书获取 | 获取 Let's Encrypt 免费证书 |
| `manage_certificates.sh` | 证书管理和查询 | 日常证书维护 |
| `renew_certificates.sh` | 自动证书续期 | 定时任务、自动续期 |

## 🚀 快速开始

### 第 1 步：安装 Certbot

```bash
sudo bash install_certbot.sh
```

**安装内容：**
- Certbot CLI 工具
- Let's Encrypt Python 客户端
- Nginx/Apache 插件（根据系统）
- Cron 自动续期任务

### 第 2 步：获取证书

```bash
# 方式 1：使用 Web 根认证（推荐）
sudo certbot certonly --webroot -w /var/www/html -d example.com

# 方式 2：使用 Nginx 自动配置
sudo certbot certonly --nginx -d example.com

# 方式 3：交互式向导
sudo certbot certonly
```

### 第 3 步：验证和使用

```bash
# 查看已安装的证书
sudo certbot certificates

# 检查证书详情
sudo openssl x509 -in /etc/letsencrypt/live/example.com/cert.pem -text -noout

# 配置 Nginx
# 编辑 /etc/nginx/sites-available/default，添加：
# ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
# ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
```

---

## 📄 脚本详解

### install_certbot.sh

**用途：** 安装和配置 Certbot，获取 Let's Encrypt 证书

**支持的系统：**
- CentOS 7+
- Ubuntu 18.04+
- 麒麟 Linux

**功能：**
- ✅ 安装 Certbot 和依赖
- ✅ 检查是否已安装 Nginx/Apache
- ✅ 自动获取证书
- ✅ 配置自动续期 Cron 任务
- ✅ 验证证书安装

**使用示例：**

```bash
# 标准安装
sudo bash install_certbot.sh

# 为多个域名获取证书
sudo bash install_certbot.sh
# 按提示输入多个域名

# 使用 DNS 认证（用于通配符证书）
sudo certbot certonly --manual --preferred-challenges dns -d "*.example.com"
```

**配置文件位置：**
```
/etc/letsencrypt/                 # Let's Encrypt 主目录
/etc/letsencrypt/live/            # 活跃证书
/etc/letsencrypt/archive/         # 证书归档
/etc/letsencrypt/renewal/         # 续期配置
```

---

### manage_certificates.sh

**用途：** 日常证书管理、查询和维护

**功能：**
- ✅ 列出所有证书
- ✅ 检查证书有效期
- ✅ 手动续期证书
- ✅ 备份证书文件
- ✅ 查看证书详情

**使用示例：**

```bash
# 列出所有证书
sudo bash manage_certificates.sh list

# 检查证书状态（包括过期警告）
sudo bash manage_certificates.sh check

# 续期特定证书
sudo bash manage_certificates.sh renew example.com

# 备份所有证书到特定目录
sudo bash manage_certificates.sh backup /backup/certs

# 查看证书详细信息
sudo bash manage_certificates.sh details example.com
```

**输出示例：**

```
╔════════════════════════════════════════════════════════════╗
║         SSL/TLS 证书管理工具 - 证书检查报告              ║
╚════════════════════════════════════════════════════════════╝

[INFO] 检查证书状态...

证书：example.com
  - 有效期：2025-01-21 至 2026-01-21
  - 剩余天数：365 天
  - 状态：✓ 正常

证书：api.example.com
  - 有效期：2025-02-10 至 2026-02-10
  - 剩余天数：384 天
  - 状态：✓ 正常

[SUCCESS] 所有证书状态正常！
```

---

### renew_certificates.sh

**用途：** 自动续期将要过期的证书

**功能：**
- ✅ 自动检查证书过期时间
- ✅ 自动续期即将过期的证书（30天内）
- ✅ 重启 Web 服务以应用新证书
- ✅ 生成详细的续期日志
- ✅ 邮件通知（可选）

**使用示例：**

```bash
# 手动运行续期
sudo bash renew_certificates.sh

# 运行并指定日志输出
sudo bash renew_certificates.sh >> /var/log/cert_renew.log 2>&1

# 作为 Cron 定时任务（推荐）
# 编辑 crontab：
sudo crontab -e

# 添加此行（每月 1 号 2 点运行）：
0 2 1 * * /usr/bin/bash /path/to/utils/certificate/renew_certificates.sh >> /var/log/cert_renew.log 2>&1
```

**日志位置：**
```
/var/log/letsencrypt/renew.log       # Let's Encrypt 续期日志
/var/log/cert_renew.log              # 自定义脚本日志
```

---

## 🔧 常见配置

### 配置 Nginx 使用 HTTPS 证书

```nginx
# /etc/nginx/sites-available/default

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name example.com www.example.com;

    # SSL 证书配置
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    # SSL 安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # HSTS（可选但推荐）
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # 其他配置...
    root /var/www/html;
    index index.html;
}

# 重定向 HTTP 到 HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;

    location / {
        return 301 https://$server_name$request_uri;
    }
}
```

然后重启 Nginx：
```bash
sudo nginx -t          # 测试配置
sudo systemctl restart nginx
```

### 配置 Apache 使用 HTTPS 证书

```apache
# /etc/apache2/sites-available/default-ssl.conf

<VirtualHost *:443>
    ServerName example.com
    ServerAlias www.example.com

    DocumentRoot /var/www/html

    # SSL 证书配置
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/example.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/example.com/privkey.pem

    # SSL 安全配置
    SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite HIGH:!aNULL:!MD5

    # HSTS
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
</VirtualHost>
```

### 设置自动续期

```bash
# 检查 Crontab 中的自动续期任务
sudo crontab -l

# 编辑 Crontab
sudo crontab -e

# 添加以下行（每月 1 号 2 点运行）
0 2 1 * * certbot renew --quiet --post-hook "systemctl restart nginx"

# 或使用我们的脚本
0 2 1 * * /usr/bin/bash /path/to/utils/certificate/renew_certificates.sh
```

---

## 📊 证书管理最佳实践

### 1. 定期备份

```bash
# 备份所有证书
sudo tar -czf /backup/letsencrypt-$(date +%Y%m%d).tar.gz /etc/letsencrypt/

# 定期备份（Cron）
0 3 * * 0 tar -czf /backup/letsencrypt-$(date +\%Y\%m\%d).tar.gz /etc/letsencrypt/
```

### 2. 监控过期日期

```bash
# 创建检查脚本
cat > /usr/local/bin/check_certs.sh << 'EOF'
#!/bin/bash
for cert in /etc/letsencrypt/live/*/cert.pem; do
    expiry=$(openssl x509 -enddate -noout -in "$cert" | cut -d= -f2)
    days=$(( ($(date -d "$expiry" +%s) - $(date +%s)) / 86400 ))
    if [ $days -lt 30 ]; then
        echo "ALERT: Certificate $cert expires in $days days"
    fi
done
EOF

chmod +x /usr/local/bin/check_certs.sh

# 添加到 Crontab（每周检查一次）
0 9 * * 1 /usr/local/bin/check_certs.sh
```

### 3. 证书链验证

```bash
# 验证证书链完整性
openssl verify -CAfile /etc/letsencrypt/live/example.com/chain.pem \
  /etc/letsencrypt/live/example.com/cert.pem

# 检查证书和密钥是否匹配
openssl x509 -noout -modulus -in /etc/letsencrypt/live/example.com/cert.pem | openssl md5
openssl rsa -noout -modulus -in /etc/letsencrypt/live/example.com/privkey.pem | openssl md5
```

---

## 🐛 故障排查

### 问题 1：Certbot 命令不找到

```bash
# 解决方案：检查安装
which certbot

# 如果未找到，手动安装
pip install certbot

# 或使用包管理器
sudo apt-get install certbot
sudo yum install certbot
```

### 问题 2：证书续期失败

```bash
# 1. 检查网络连接
ping -c 1 8.8.8.8

# 2. 检查 DNS
nslookup example.com

# 3. 强制续期
sudo certbot renew --force-renewal

# 4. 查看详细错误
sudo certbot renew -v

# 5. 检查日志
sudo tail -f /var/log/letsencrypt/renew.log
```

### 问题 3：Nginx/Apache 不识别证书

```bash
# 1. 验证证书路径
ls -la /etc/letsencrypt/live/example.com/

# 2. 检查权限
sudo chmod 644 /etc/letsencrypt/live/example.com/cert.pem
sudo chmod 644 /etc/letsencrypt/live/example.com/fullchain.pem
sudo chmod 600 /etc/letsencrypt/live/example.com/privkey.pem

# 3. 重启 Web 服务
sudo systemctl restart nginx
sudo systemctl restart apache2

# 4. 测试配置
sudo nginx -t
sudo apache2ctl configtest
```

---

## 📝 手动证书创建

如果不使用 Let's Encrypt，可以使用自签名证书：

```bash
# 生成私钥
openssl genrsa -out /etc/ssl/private/example.com.key 2048

# 生成证书签名请求
openssl req -new -key /etc/ssl/private/example.com.key \
  -out /tmp/example.com.csr

# 生成自签名证书（365天有效）
openssl x509 -req -days 365 -in /tmp/example.com.csr \
  -signkey /etc/ssl/private/example.com.key \
  -out /etc/ssl/certs/example.com.crt

# 配置权限
sudo chmod 600 /etc/ssl/private/example.com.key
sudo chmod 644 /etc/ssl/certs/example.com.crt
```

---

## 📞 更多信息

- Let's Encrypt 官网：https://letsencrypt.org
- Certbot 文档：https://certbot.eff.org
- SSL 测试工具：https://www.ssllabs.com/ssltest

---

**最后更新时间：** 2025年1月21日