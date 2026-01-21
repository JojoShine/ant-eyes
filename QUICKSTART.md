# Shell Collections v1.0.0 快速开始指南

## 📦 包内容

```
shell_collections/
├── README.md                 # 项目概览
├── server_check.sh          # 系统诊断工具 (3782行)
└── installation/            # 安装脚本集合
    ├── centos/              # CentOS 7+ 脚本 (6个)
    ├── ubuntu/              # Ubuntu 18.04+ 脚本 (6个)
    ├── kylin/               # 麒麟 Linux 脚本 (6个)
    ├── docker-compose/      # Docker Compose 配置 (6个)
    └── utils/               # 工具脚本 (7个)
```

## 🚀 快速开始

### 1. 解压包

```bash
tar -xzf shell_collections-v1.0.0.tar.gz
cd shell_collections
```

### 2. 确定你的操作系统

```bash
cat /etc/os-release | grep -E "^NAME|^VERSION"
```

### 3. 选择对应的脚本

| 系统 | 目录 | 说明 |
|------|------|------|
| CentOS 7+ | `installation/centos/` | RedHat 系统 |
| Ubuntu 18.04+ | `installation/ubuntu/` | Debian 系统 |
| 麒麟 Linux | `installation/kylin/` | 国产 Linux |

### 4. 执行安装脚本

**以 Kylin Linux 安装 Docker 为例：**

```bash
cd installation/kylin
sudo bash install_docker.sh
```

**支持的服务：**
- Docker - 容器运行时
- Nginx - Web 服务器
- MySQL - 关系型数据库
- PostgreSQL - 高级关系型数据库
- MongoDB - NoSQL 文档数据库
- Redis - 内存数据库

## 🐳 Docker Compose 快速部署

```bash
# 进入 docker-compose 目录
cd installation/docker-compose/postgresql

# 创建 .env 文件（从 .env.example 复制）
cp .env.example .env

# 编辑 .env 设置密码等参数
nano .env

# 启动服务
docker-compose up -d

# 查看状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

## 🔧 系统诊断工具

运行 `server_check.sh` 进行全面的系统检查：

```bash
sudo bash server_check.sh
```

**功能包括：**
- 系统基本信息检查
- 异常访问监控
- 服务运行状态
- 安全情况检查
- 网络诊断工具
- Crontab 任务管理
- NTP 时间同步
- 磁盘分区管理
- I/O 性能检查

## ⚙️ 国内镜像源支持

所有脚本都已配置以下国内镜像源支持（优先级顺序）：

**Docker 镜像源：**
- USTC 中科大
- 网易 163
- 阿里云
- 腾讯云
- DaoCloud
- 清华大学

**APT/YUM 源：**
- 阿里云
- 清华大学
- USTC 中科大

## 📋 支持的服务列表

### 核心服务 (18 个脚本)
| 服务 | CentOS | Ubuntu | Kylin |
|------|--------|--------|-------|
| Docker | ✅ | ✅ | ✅ |
| Nginx | ✅ | ✅ | ✅ |
| MySQL | ✅ | ✅ | ✅ |
| PostgreSQL | ✅ | ✅ | ✅ |
| MongoDB | ✅ | ✅ | ✅ |
| Redis | ✅ | ✅ | ✅ |

### Docker Compose 服务 (6 个配置)
- MySQL 5.7 / 8.0
- PostgreSQL 13 / 15
- MongoDB 5.0
- Redis 7.0
- RabbitMQ 3.x
- MinIO (对象存储)

### 工具脚本 (7 个)
- Certbot (SSL 证书)
- 证书管理工具
- 证书自动续期
- Doris (分析数据库)
- Flink (流处理)
- Spark (大数据处理)

## 🔐 安全建议

1. **修改默认密码** - 所有配置中的密码都需要更改
2. **限制网络访问** - 不要在生产环境暴露所有端口
3. **启用认证** - 为所有服务启用用户认证
4. **定期备份** - 定期备份重要数据
5. **更新镜像** - 定期更新 Docker 镜像版本
6. **防火墙配置** - 配置防火墙限制访问

## 🐛 故障排查

### 网络问题

如果遇到镜像源无法访问：

```bash
# 1. 检查网络连接
ping 8.8.8.8

# 2. 检查 DNS
nslookup docker.mirrors.ustc.edu.cn

# 3. 检查防火墙
sudo firewall-cmd --list-all

# 4. 尝试其他镜像源
# 修改 /etc/docker/daemon.json 中的镜像源顺序
```

### Docker 问题

```bash
# 查看 Docker 状态
sudo systemctl status docker

# 查看 Docker 日志
sudo journalctl -u docker -n 50

# 重启 Docker
sudo systemctl restart docker

# 清理空间
docker system prune -a
```

### 权限问题

```bash
# 确保以 root 运行
sudo bash install_docker.sh

# 或添加当前用户到 docker 组
sudo usermod -aG docker $USER
```

## 📖 详细文档

- `README.md` - 项目完整说明
- `installation/README.md` - 安装指南导航
- `installation/centos/README.md` - CentOS 详细说明
- `installation/ubuntu/README.md` - Ubuntu 详细说明
- `installation/kylin/README.md` - Kylin 详细说明
- `installation/docker-compose/README.md` - Docker Compose 使用指南
- `installation/utils/README.md` - 工具脚本说明

## 💡 典型使用场景

### 场景 1：快速搭建 Web 环境

```bash
cd installation/kylin
sudo bash install_nginx.sh      # Web 服务器
sudo bash install_postgresql.sh # 数据库
sudo bash install_redis.sh      # 缓存
```

### 场景 2：容器化部署

```bash
cd installation/kylin
sudo bash install_docker.sh

cd installation/docker-compose/postgresql
docker-compose up -d
```

### 场景 3：完整企业环境

```bash
cd installation/centos
sudo bash install_docker.sh
sudo bash install_nginx.sh
sudo bash install_postgresql.sh
sudo bash install_mongodb.sh
sudo bash install_redis.sh
```

## ✨ 脚本特点

✅ **完全独立** - 每个脚本都可独立运行
✅ **多系统支持** - CentOS、Ubuntu、Kylin
✅ **国内优化** - 所有脚本都已优化国内网络
✅ **生产就绪** - 完善的错误处理和验证
✅ **标准化** - 所有脚本遵循统一规范
✅ **彩色日志** - 清晰的输出提示（INFO、SUCCESS、WARN、ERROR）

## 📞 常见问题

**Q: 可以在生产环境使用吗？**
A: 可以，但建议先在测试环境验证。

**Q: 脚本需要网络吗？**
A: 是的，需要网络才能下载软件包和依赖。

**Q: 如何卸载已安装的服务？**
A: 使用系统包管理器：`sudo yum remove` 或 `sudo apt-get remove`

**Q: 如何修改配置？**
A: 编辑对应的配置文件，通常在 `/etc/` 下。

**Q: 如何查看安装日志？**
A: 脚本会输出彩色日志，也可以查看系统日志：`journalctl -u <service>`

---

**版本：** v1.0.0
**最后更新：** 2026年1月21日
**项目网址：** https://github.com/yourusername/shell_collections
