# ant-eyes - Linux 运维工具集

一套完整的 Linux 系统运维工具集，包含系统检查、安全审计、服务安装等功能。

## 🎯 核心功能：系统检查工具

**ant-eyes 的核心是强大的系统检查工具**，提供全面的服务器健康检查、安全审计和运维诊断能力。

### 📊 10 大功能模块

1. **系统基本信息检查** - CPU、内存、磁盘、网络等关键信息
2. **系统异常访问检查** - SSH 登录监控、暴力破解检测、可疑连接分析
3. **常用组件运行状态** - Oracle、MySQL、Redis、Kafka 等应用状态检测
4. **系统服务部署信息** - 运行中的服务、监听端口、Docker 容器状态
5. **系统安全情况检查** - 防火墙、SELinux、用户权限、文件安全审计
6. **网络诊断工具** - Ping、Telnet、DNS 解析、端口扫描、网速测试、防火墙管理
7. **Crontab 定时任务管理** - 查看、添加、删除定时任务，支持常用模板
8. **NTP/Chrony 时间同步** - 管理时间同步服务，同步系统时间
9. **磁盘分区挂载工具** - MBR/GPT 分区识别、挂载、文件系统管理
10. **磁盘 I/O 性能检查** - iostat 实时监控、fio 基准测试、SMART 健康检查

### 🚀 快速使用系统检查工具

```bash
# 通过 npm 运行（推荐）
npx ant-eyes-install check

# 或直接执行脚本
sudo bash server_check.sh
```

**特点：**
- ✅ 交互式菜单，易于使用
- ✅ 支持报告导出功能
- ✅ 支持多种 Linux 发行版（CentOS、Ubuntu、Kylin、UOS）
- ✅ 完整的系统安全检查能力
- ✅ 强大的网络诊断工具集

---

## 📦 快速安装

### 前置条件：安装 Node.js

使用 npm 方式需要先安装 Node.js 环境。推荐使用 NVM 管理 Node.js 版本：

```bash
# 方式 1：使用本项目的 NVM 安装脚本（推荐，已配置国内镜像）
sudo bash installation/services/install_nvm.sh

# 方式 2：手动安装 NVM（需要配置镜像）
curl -o- https://gitee.com/mirrors/nvm/raw/v0.39.7/install.sh | bash
export NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node
source ~/.nvm/nvm.sh
nvm install 20
```

安装完成后，验证 Node.js 环境：
```bash
node --version  # 应显示 v20.x.x
npm --version   # 应显示 npm 版本
```

### 使用 npm 快速安装

通过 npm 快速使用所有工具，无需克隆仓库：

```bash
# 系统检查（核心功能）
npx ant-eyes-install check

# 安装单个服务
npx ant-eyes-install redis

# 批量安装多个服务
npx ant-eyes-install redis mysql nginx

# 使用 Docker Compose 配置
npx ant-eyes-install --compose redis mysql

# 列出所有可用服务
npx ant-eyes-install --list
```

---

## 🛠️ 辅助工具：服务安装脚本

除了核心的系统检查工具，ant-eyes 还提供了一键安装常用服务的脚本。

### 数据库
- **redis** - 内存数据库（含鉴权配置）
- **mysql** - 关系型数据库（含鉴权配置）
- **postgresql** - 高级关系型数据库（含鉴权配置）
- **mongodb** - NoSQL 文档数据库（含鉴权配置）

### Web 服务
- **nginx** - 高性能 Web 服务器和反向代理

### 存储
- **minio** - 对象存储服务，S3 兼容（含鉴权配置）

### 开发工具
- **nvm** - Node.js 版本管理器 + Node.js v20 LTS
- **python** - Python 3.11 + uv 包管理器
- **docker** - Docker CE + Docker Compose

### 证书管理
- **certbot** - Let's Encrypt 自动证书获取
- **renew-cert** - 证书自动续期
- **manage-cert** - 证书管理工具

### 数据治理
- **spark** - Apache Spark 大数据处理（单机模式）
- **flink** - Apache Flink 流处理（单机模式）
- **doris** - Apache Doris OLAP 分析（单机模式）

---

## 📁 项目结构

```
ant-eyes/
├── server_check.sh                 # ★ 核心：系统检查工具
├── package.json                    # npm 包配置
├── bin/install.js                  # CLI 入口
│
└── installation/                   # 服务安装脚本
    ├── services/                   # 统一安装脚本（自动检测系统）
    │   ├── install_redis.sh
    │   ├── install_mysql.sh
    │   ├── install_postgresql.sh
    │   ├── install_mongodb.sh
    │   ├── install_nginx.sh
    │   ├── install_minio.sh
    │   ├── install_nvm.sh
    │   ├── install_python.sh
    │   └── install_docker.sh
    │
    ├── docker-compose/             # Docker Compose 配置
    │   ├── mysql/
    │   ├── postgresql/
    │   ├── mongodb/
    │   ├── redis/
    │   └── minio/
    │
    └── utils/                      # 工具脚本
        ├── certificate/            # SSL/TLS 证书管理
        └── data_governance/        # 数据治理框架
```

---

## 🔄 典型使用场景

### 场景 1：系统健康检查（核心功能）

```bash
# 运行系统检查工具
npx ant-eyes-install check

# 选择功能：
# 1. 完整检查 - 一次性检查所有项目
# 2. 系统信息 - 查看 CPU、内存、磁盘等
# 3. 安全审计 - 检查防火墙、用户权限等
# 4. 网络诊断 - Ping、端口扫描、DNS 解析
# 5. 性能分析 - 磁盘 I/O、网络速度测试
```

### 场景 2：搭建 Web 后端环境

```bash
npx ant-eyes-install docker nginx mysql redis
```

### 场景 3：搭建数据分析环境

```bash
npx ant-eyes-install spark flink doris
```

### 场景 4：配置 SSL 证书

```bash
npx ant-eyes-install certbot
```

---

## ✨ 安装脚本特性（v2.0.0）

### 🎯 统一脚本，自动检测系统

所有 `services/` 目录下的脚本都内置了系统自动检测：

- ✅ 自动识别 CentOS/Ubuntu/Kylin
- ✅ 自动选择正确的包管理器（yum/apt）
- ✅ 自动配置对应的镜像源
- ✅ 一个脚本，全平台通用

### 🔐 强制鉴权配置

所有数据库和存储服务强制设置密码：

- **Redis** - 强制输入不少于 6 位密码
- **MySQL** - 强制输入不少于 8 位 root 密码
- **PostgreSQL** - 强制输入不少于 8 位密码
- **MongoDB** - 强制输入不少于 8 位 admin 密码
- **MinIO** - 强制输入 root 用户名和密码

### 📝 配置存档

安装完成后，配置信息自动保存到 `/etc/ant-eyes/<service>.conf`，方便后续查阅和管理。

---

## 🔐 安全建议

1. **以 root 身份运行** - 系统检查工具需要 root 权限获取完整信息
2. **定期健康检查** - 建议每周运行一次系统检查工具
3. **在生产前测试** - 安装脚本先在测试环境验证
4. **审查脚本内容** - 运行任何脚本前都要查看其代码
5. **保护配置文件** - `/etc/ant-eyes/` 下的配置文件包含敏感信息

---

## 📦 npm 包信息

- **包名**: `ant-eyes-install`
- **版本**: 1.0.4
- **npm 地址**: https://www.npmjs.com/package/ant-eyes-install

---

**项目版本**：v2.0.0  
**最后更新**：2026年4月2日  
**最低要求**：root 权限、网络连接、Node.js 14+（仅 npm 方式需要，推荐使用 Node.js 20 LTS）
