# CentOS/RHEL 7+ 运维安装脚本集

这个目录包含了6个完全独立的、针对 CentOS/RHEL 7+ 系统优化的安装脚本。每个脚本都是自包含的，无需任何外部依赖。

## 脚本列表

| 脚本名称 | 功能 | 版本 |
|---------|------|------|
| `install_docker.sh` | Docker + Docker Compose | 最新版 |
| `install_nginx.sh` | Nginx Web 服务器 | 最新稳定版 |
| `install_mysql.sh` | MySQL 数据库 | 5.7/8.0 |
| `install_postgresql.sh` | PostgreSQL 数据库 | 系统版本 |
| `install_mongodb.sh` | MongoDB NoSQL 数据库 | 系统版本 |
| `install_redis.sh` | Redis 缓存数据库 | 系统版本 |

## 主要特性

✅ **完全独立** - 每个脚本都是自包含的，无需任何外部库依赖
✅ **国内镜像源** - 自动配置阿里云和清华大学镜像源
✅ **自动化部署** - 一键安装和配置
✅ **容错处理** - 包含多种备份和回退机制
✅ **彩色输出** - 清晰的日志输出便于调试

## 快速开始

### 1. 安装 Docker

```bash
sudo bash install_docker.sh
```

Docker 安装包括：
- Docker CE（社区版）
- Docker Compose（容器编排工具）
- 国内镜像源配置（13个镜像源）

### 2. 安装 Nginx

```bash
sudo bash install_nginx.sh
```

Nginx 安装包括：
- Nginx Web 服务器
- 防火墙规则配置
- 服务自启动

### 3. 安装 MySQL

```bash
sudo bash install_mysql.sh
```

MySQL 安装包括：
- MySQL 数据库服务
- UTF-8 字符集配置
- 服务自启动

### 4. 安装 PostgreSQL

```bash
sudo bash install_postgresql.sh
```

PostgreSQL 安装包括：
- PostgreSQL 数据库服务
- 数据库初始化
- 服务自启动

### 5. 安装 MongoDB

```bash
sudo bash install_mongodb.sh
```

MongoDB 安装包括：
- MongoDB 数据库服务
- 数据目录配置
- 服务自启动

### 6. 安装 Redis

```bash
sudo bash install_redis.sh
```

Redis 安装包括：
- Redis 缓存服务
- 基础配置
- 服务自启动

## 使用说明

### 前置要求

- 系统：CentOS 7+ / RHEL 7+
- 权限：需要 root 权限
- 网络：需要互联网连接

### 执行脚本

```bash
# 方式1：直接执行
sudo bash install_docker.sh

# 方式2：添加执行权限后运行
sudo chmod +x install_docker.sh
sudo ./install_docker.sh
```

### 常见问题

#### 1. Docker 启动失败

如果遇到 `daemon.json` 配置冲突错误，CentOS 7 的 Docker 版本较旧，请手动清理：

```bash
sudo systemctl stop docker
sudo rm /etc/docker/daemon.json
sudo mkdir -p /etc/docker

# 重新配置只保留镜像源
sudo cat > /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://dockerhub.azk8s.cn",
    "https://mirror.baidubce.com"
  ]
}
EOF

sudo systemctl daemon-reload
sudo systemctl start docker
```

#### 2. 权限不足

所有脚本都需要 root 权限：

```bash
sudo bash install_nginx.sh
# 或
sudo ./install_nginx.sh
```

#### 3. yum 源配置问题

脚本会自动备份旧的源配置到 `/etc/yum.repos.d.bak/`，如需恢复：

```bash
sudo cp /etc/yum.repos.d.bak/* /etc/yum.repos.d/
sudo yum clean all
sudo yum makecache
```

## 脚本结构

每个脚本都包含以下基本步骤：

1. **权限检查** - 验证 root 权限
2. **yum 源配置** - 配置国内镜像源
3. **软件安装** - 使用 yum 安装相应软件
4. **配置调整** - 应用基础配置
5. **服务启动** - 启动相应服务
6. **验证测试** - 验证安装成功

## 国内镜像源

脚本使用以下国内镜像源：

- **基础源**：阿里云、清华大学
- **Docker 镜像**：USTC、网易、阿里云、腾讯云等

## 日志输出说明

脚本使用彩色输出进行状态提示：

- 🔵 `[INFO]` - 信息提示
- 🟢 `[SUCCESS]` - 成功标记
- 🟡 `[WARN]` - 警告提示
- 🔴 `[ERROR]` - 错误提示

## 注意事项

1. **备份重要数据** - 安装前备份系统配置
2. **测试环境验证** - 建议先在测试环境运行
3. **网络连接** - 确保系统能访问互联网
4. **系统更新** - 某些情况下可能需要先运行 `yum update`
5. **防火墙规则** - 脚本会自动配置防火墙

## 故障排查

### 查看服务状态

```bash
# Docker
sudo systemctl status docker

# Nginx
sudo systemctl status nginx

# MySQL
sudo systemctl status mysqld

# PostgreSQL
sudo systemctl status postgresql

# MongoDB
sudo systemctl status mongod

# Redis
sudo systemctl status redis
```

### 查看服务日志

```bash
# 查看最后100行日志
sudo journalctl -u docker -n 100 -f

# 查看 syslog
sudo tail -f /var/log/messages
```

### 重新启动服务

```bash
sudo systemctl restart <service-name>
```

## 支持的版本

- **CentOS 7**
- **CentOS 8+**
- **RHEL 7+**

## 许可证

这些脚本是为运维自动化而创建的工具，可自由使用和修改。

## 更新日期

2026-01-21

---

**提示**：如遇到问题，请检查系统日志和脚本输出信息，通常会给出明确的错误提示。