# ant-eyes

Linux 服务器健康检查和运维管理工具

简体中文 | [English](./README.en.md)

## 概述

ant-eyes 是一个全面的 Linux 服务器运维工具集，提供系统检查、服务管理、运维工具等功能。支持 CentOS、Ubuntu、Kylin、UOS 等多种 Linux 发行版。

### 核心特性

- 系统健康检查：CPU、内存、磁盘、网络等关键信息
- 安全审计：SSH 登录失败、暴力破解检测
- 运维管理：定时任务、时间同步、磁盘管理、性能检查
- 快速部署：一键安装 Redis、MySQL、PostgreSQL、Nginx、Docker 等
- 交互式菜单：简单易用的命令行界面
- 模块化设计：清晰的功能划分，易于扩展

## 安装

### 使用 npm

```bash
npm install -g ant-eyes
```

### 从源代码安装

```bash
git clone https://github.com/JojoShine/ant-eyes.git
cd ant-eyes
npm install -g .
```

## 快速开始

### 系统检查

```bash
# 系统基本信息（CPU、内存、磁盘、网络）
ant-eyes check --system

# 安全审计（SSH 登录失败、暴力破解）
ant-eyes check --security

# 服务部署信息（监听端口、Docker 容器、系统服务）
ant-eyes check --services

# 防火墙和安全检查（防火墙状态、SELinux、SUID文件）
ant-eyes check --firewall

# 网络诊断工具（接口、DNS、网关、连接统计）
ant-eyes check --network

# 完整检查（执行上述所有检查）
ant-eyes check --full
```

### 服务安装

```bash
# 安装 Redis
ant-eyes install redis

# 批量安装
ant-eyes install redis mysql nginx

# 查看可用服务
ant-eyes install --list

# 使用 Docker Compose
ant-eyes install --compose redis
```

### 运维管理

```bash
# 定时任务管理
ant-eyes manage cron

# 时间同步
ant-eyes manage time

# 磁盘管理
ant-eyes manage disk

# 磁盘性能检查
ant-eyes manage performance
```

## 命令参考

### check - 系统检查

用法：`ant-eyes check [options]`

选项：
- `--system` - 系统基本信息（CPU、内存、磁盘、网络）
- `--security` - 系统异常访问检查（SSH 登录、暴力破解）
- `--services` - 系统服务部署信息
- `--firewall` - 系统安全情况检查
- `--network` - 网络诊断工具
- `--full` - 完整检查（所有模块）

示例：
```bash
ant-eyes check --system        # 检查系统信息
ant-eyes check --security      # 检查安全状态
ant-eyes check --full          # 完整检查
```

### install - 服务安装

用法：`ant-eyes install <service> [services...] [options]`

可用服务：
- `redis` - Redis 缓存数据库
- `mysql` - MySQL 数据库
- `postgresql` - PostgreSQL 数据库
- `mongodb` - MongoDB 文档数据库
- `nginx` - Nginx Web 服务器
- `minio` - MinIO 对象存储
- `nvm` - Node.js 版本管理器
- `python` - Python 环境
- `docker` - Docker 容器引擎

选项：
- `--compose` - 使用 Docker Compose 部署
- `--list, -l` - 列出所有可用服务

示例：
```bash
ant-eyes install redis         # 安装 Redis
ant-eyes install mysql nginx   # 批量安装
ant-eyes install --compose redis  # 使用 Docker Compose 安装
ant-eyes install --list        # 查看服务列表
```

### manage - 运维管理

用法：`ant-eyes manage <subcommand> [options]`

子命令：
- `cron` - Crontab 定时任务管理
- `time` - NTP/Chrony 时间同步管理
- `disk` - 磁盘分区管理
- `performance` - 磁盘 I/O 性能检查

示例：
```bash
ant-eyes manage cron           # 管理定时任务
ant-eyes manage time           # 管理时间同步
ant-eyes manage disk           # 磁盘分区挂载
ant-eyes manage performance    # 磁盘性能检查
```

### tools - 工具集

用法：`ant-eyes <tool> [options]`

可用工具：
- `certbot` - 安装和配置 Certbot（Let's Encrypt 客户端）
- `renew-cert` - 更新和续期 SSL 证书
- `manage-cert` - 管理 SSL 证书

示例：
```bash
ant-eyes certbot              # 安装 Certbot
ant-eyes renew-cert           # 续期证书
ant-eyes manage-cert          # 管理证书
```

## 支持的系统

- CentOS 7.x, 8.x
- Ubuntu 18.04, 20.04, 22.04
- Kylin（麒麟）
- UOS（统一操作系统）

## 常见问题

### Q: 需要 root 权限吗？

A: 大多数功能需要 root 权限才能获取完整信息。建议使用 `sudo` 运行：
```bash
sudo ant-eyes check --full
```

### Q: 如何查看帮助？

A: 使用 `--help` 选项：
```bash
ant-eyes --help              # 显示主帮助
ant-eyes check --help        # 显示 check 帮助
ant-eyes install --help      # 显示 install 帮助
```

### Q: 可以批量安装多个服务吗？

A: 可以。在一条命令中指定多个服务即可：
```bash
ant-eyes install redis mysql nginx
```

### Q: 如何使用 Docker Compose 安装服务？

A: 使用 `--compose` 选项：
```bash
ant-eyes install --compose redis
```
这会将 Docker Compose 配置文件复制到当前目录，然后可以运行 `docker-compose up -d` 启动服务。

### Q: 如何卸载？

A: 使用 npm 卸载：
```bash
npm uninstall -g ant-eyes
```

## 目录结构

```
scripts/
├── check/                # 检查模块（5个脚本）
│   ├── check_system.sh
│   ├── check_security.sh
│   ├── check_services.sh
│   ├── check_firewall.sh
│   └── check_network.sh
├── manage/               # 管理模块（4个脚本）
│   ├── manage_cron.sh
│   ├── manage_time.sh
│   ├── manage_disk.sh
│   └── manage_performance.sh
├── install/              # 安装模块（9个脚本）
│   ├── install_redis.sh
│   ├── install_mysql.sh
│   ├── install_postgresql.sh
│   ├── install_mongodb.sh
│   ├── install_nginx.sh
│   ├── install_minio.sh
│   ├── install_nvm.sh
│   ├── install_python.sh
│   └── install_docker.sh
├── tools/                # 工具模块（3个脚本）
│   ├── install_certbot.sh
│   ├── renew_certificates.sh
│   └── manage_certificates.sh
├── compose/              # Docker Compose 配置
│   ├── redis/
│   ├── mysql/
│   ├── postgresql/
│   ├── mongodb/
│   └── minio/
└── utils/
    └── common.sh         # 共享函数库
```

## 开发

### 项目结构

本项目采用模块化设计，每个功能都是独立的脚本文件。

### 添加新的检查模块

1. 在 `scripts/check/` 目录创建新脚本
2. 加载共享函数库：`source "$SCRIPT_DIR/../utils/common.sh"`
3. 使用现有的打印函数：`print_header`、`print_info` 等
4. 在 `bin/install.js` 中添加路由

### 添加新的管理模块

1. 在 `scripts/manage/` 目录创建新脚本
2. 遵循相同的模板和命名规范
3. 保持交互式菜单的一致风格

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！

## 联系方式

如有问题或建议，请提交 GitHub Issue。
