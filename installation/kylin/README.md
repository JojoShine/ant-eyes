# 麒麟 Linux 自动安装脚本集合

本目录包含了为麒麟 (Kylin) Linux 系统优化的自动化安装脚本。所有脚本完全独立，无外部依赖，可直接执行。

## 📋 脚本清单

| 脚本名称 | 说明 | 用途 |
|---------|------|------|
| `install_docker.sh` | Docker + Docker Compose | 容器化应用部署 |
| `install_nginx.sh` | Nginx Web服务器 | 反向代理/负载均衡 |
| `install_mysql.sh` | MySQL 数据库 | 关系型数据库 |
| `install_postgresql.sh` | PostgreSQL 数据库 | 高级关系型数据库 |
| `install_mongodb.sh` | MongoDB NoSQL数据库 | 文档型数据库 |
| `install_redis.sh` | Redis 内存数据库 | 缓存/Session存储 |

## 🚀 使用方法

### 基本使用

每个脚本都需要 root 权限运行：

```bash
# 安装 Docker
sudo bash install_docker.sh

# 安装 Nginx
sudo bash install_nginx.sh

# 安装 MySQL
sudo bash install_mysql.sh

# 安装 PostgreSQL
sudo bash install_postgresql.sh

# 安装 MongoDB
sudo bash install_mongodb.sh

# 安装 Redis
sudo bash install_redis.sh
```

### 权限说明

如果当前用户不是 root，需要使用 `sudo` 或切换到 root 用户：

```bash
# 方式1：使用 sudo
sudo bash install_docker.sh

# 方式2：切换到 root 用户后执行
su - root
bash install_docker.sh
```

## 📦 脚本功能详解

### install_docker.sh
- ✅ 安装 Docker CE（社区版）
- ✅ 配置官方 Docker 仓库
- ✅ 安装 Docker Compose（支持插件版本和独立版本）
- ✅ 配置13个国内镜像源（加速镜像拉取）
- ✅ 配置 UFW 防火墙规则（开放80, 443端口）
- ✅ 启动并验证服务
- ⚠️ 支持 GitHub 备用源下载（如主源失败）

**配置的镜像源包括：**
- USTC (中国科学技术大学)
- 163.com (网易)
- Aliyun (阿里云)
- Tencent (腾讯云)
- Qiniu (七牛)
- Daocloud
- Tsinghua (清华大学)
- ISCAS (中国科学院)
- SJTU (上海交通大学)
等多个国内镜像源

### install_nginx.sh
- ✅ 使用官方源安装 Nginx
- ✅ 配置基础 Nginx 目录结构
- ✅ 验证 Nginx 配置文件
- ✅ 配置 UFW 防火墙（开放80, 443端口）
- ✅ 启动并验证服务
- ✅ HTTP 连接测试

### install_mysql.sh
- ✅ 使用非交互式安装（DEBIAN_FRONTEND=noninteractive）
- ✅ 安装 MySQL Server 和 Client
- ✅ 配置字符集为 utf8mb4
- ✅ 配置默认数据库连接参数
- ✅ 启动并验证服务
- ✅ 版本和连接测试

**配置项：**
- 字符集：utf8mb4
- 最大连接数：500
- 默认监听：127.0.0.1

### install_postgresql.sh
- ✅ 安装 PostgreSQL Server 和扩展
- ✅ 创建数据目录 `/var/lib/postgresql/data`
- ✅ 配置目录权限
- ✅ 启动并验证服务
- ✅ 版本和连接测试（sudo -u postgres）

### install_mongodb.sh
- ✅ 安装 MongoDB Server
- ✅ 创建数据目录 `/var/lib/mongodb` 和日志目录
- ✅ 配置目录权限和所有权
- ✅ 启动并验证服务
- ✅ 版本和连接测试

### install_redis.sh
- ✅ 安装 Redis Server
- ✅ 配置 Redis 认证密码（可选）
- ✅ 备份原始配置文件
- ✅ 启动并验证服务
- ✅ 版本和连接测试（PING 命令）

## 🔧 配置修改指南

### 修改 MySQL 配置

编辑 `/etc/mysql/conf.d/custom.cnf` 文件：

```bash
sudo nano /etc/mysql/conf.d/custom.cnf
```

常用配置项：
```ini
[mysqld]
max_connections = 1000          # 增加最大连接数
max_allowed_packet = 256M       # 增加包大小限制
```

### 修改 Redis 密码

编辑 `/etc/redis/redis.conf` 文件，找到 `requirepass` 行：

```bash
sudo nano /etc/redis/redis.conf

# 找到这一行并修改：
# requirepass foobared
```

### 修改 PostgreSQL 配置

编辑 PostgreSQL 配置文件：

```bash
sudo nano /etc/postgresql/*/main/postgresql.conf
```

## ✅ 验证安装

每个脚本在安装完成后会自动进行验证，包括：

1. **版本检查** - 显示已安装的版本号
2. **服务状态** - 确认服务已启动
3. **连接测试** - 验证可以连接到服务

示例输出：
```
[INFO] 验证 Docker 安装...
Docker version 20.10.x
Docker Compose version v2.x.x
[SUCCESS] Docker 安装验证完成
```

## 🐛 故障排查

### 脚本需要 root 权限

```bash
# 错误信息：此脚本需要 root 权限运行
# 解决方案：使用 sudo 运行脚本
sudo bash install_docker.sh
```

### 网络连接问题

如果脚本因为网络问题（如下载失败）中断：

```bash
# 1. 检查网络连接
ping 8.8.8.8

# 2. 检查 DNS
cat /etc/resolv.conf

# 3. 重新运行脚本（会重新连接和下载）
sudo bash install_docker.sh
```

### 服务启动失败

如果看到 "服务启动失败" 的错误：

```bash
# 1. 查看服务日志
sudo journalctl -u docker -n 50    # 查看 Docker 日志
sudo journalctl -u mysql -n 50     # 查看 MySQL 日志

# 2. 检查服务状态
sudo systemctl status docker
sudo systemctl status mysql

# 3. 手动启动服务进行故障排查
sudo systemctl start docker
```

### APT 源问题

如果遇到 APT 源相关问题：

```bash
# 1. 更新 APT 源列表
sudo apt-get update

# 2. 清理 APT 缓存
sudo apt-get clean
sudo apt-get autoclean

# 3. 重新运行安装脚本
sudo bash install_docker.sh
```

## 📝 脚本特性

### 标准化功能

所有脚本都遵循统一的标准化结构：

```
1. check_root()          - 检查 root 权限
2. install_xxx()         - 安装软件包
3. configure_xxx()       - 配置应用
4. start_service()       - 启动服务
5. verify()              - 验证安装
```

### 彩色日志输出

- 🔵 [INFO] - 信息消息（蓝色）
- 🟢 [SUCCESS] - 成功消息（绿色）
- 🟡 [WARN] - 警告消息（黄色）
- 🔴 [ERROR] - 错误消息（红色）

### 错误处理

使用 `set -e` 确保脚本在出现错误时立即停止，防止半成功安装。

## 🔄 常见工作流

### 安装完整 Web 栈

```bash
# 1. 安装 Docker（用于应用部署）
sudo bash install_docker.sh

# 2. 安装 Nginx（前端反向代理）
sudo bash install_nginx.sh

# 3. 安装 PostgreSQL（数据库）
sudo bash install_postgresql.sh

# 4. 安装 Redis（缓存）
sudo bash install_redis.sh
```

### 安装多数据库环境

```bash
# 同时安装 MySQL 和 PostgreSQL
sudo bash install_mysql.sh
sudo bash install_postgresql.sh
sudo bash install_mongodb.sh
```

## 📄 许可证

这些脚本用于自动化部署和系统初始化。请在使用前审查脚本内容。

## 💡 建议和最佳实践

1. **在生产环境前测试** - 在非关键系统上先测试脚本
2. **备份重要数据** - 安装数据库前备份现有数据
3. **查看脚本内容** - 运行任何脚本前都要查看其内容
4. **按需修改配置** - 根据实际需要修改配置文件
5. **定期检查日志** - 安装后检查服务日志确认正常运行

## 📞 常见问题

**Q: 可以在生产环境使用这些脚本吗？**
A: 可以，但建议先在测试环境验证，然后根据实际需求调整配置。

**Q: 如何卸载已安装的服务？**
A: 使用麒麟 Linux 的标准卸载命令：
```bash
sudo apt-get remove docker-ce
sudo apt-get remove mysql-server
# 等等...
```

**Q: 脚本支持哪些麒麟版本？**
A: 支持麒麟 V10、V10 SP1、V10 SP2 及更新版本

**Q: 如何自定义安装选项？**
A: 编辑脚本文件，修改相应的配置部分即可。

---

最后更新时间：2025年1月21日