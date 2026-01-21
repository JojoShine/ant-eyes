# Shell Collections - 自动化安装脚本集合

一套完整的、独立的、生产就绪的 Linux 系统自动化安装脚本集合。针对 CentOS 7+、Ubuntu 18.04+ 和麒麟 Linux 进行了优化。

## 📁 项目结构

```
shell_collections/
├── README.md                    # 本文件 - 项目概述
│
└── 📁 installation/             # 统一安装脚本入口
    ├── README.md                # 导航指南
    │
    ├── 📁 centos/               # CentOS 7+ 脚本集（6 个）
    │   ├── README.md
    │   ├── install_docker.sh
    │   ├── install_nginx.sh
    │   ├── install_mysql.sh
    │   ├── install_postgresql.sh
    │   ├── install_mongodb.sh
    │   └── install_redis.sh
    │
    ├── 📁 ubuntu/               # Ubuntu 18.04+ 脚本集（6 个）
    │   ├── README.md
    │   ├── install_docker.sh
    │   ├── install_nginx.sh
    │   ├── install_mysql.sh
    │   ├── install_postgresql.sh
    │   ├── install_mongodb.sh
    │   └── install_redis.sh
    │
    ├── 📁 kylin/                # 麒麟 Linux 脚本集（6 个）
    │   ├── README.md
    │   ├── install_docker.sh
    │   ├── install_nginx.sh
    │   ├── install_mysql.sh
    │   ├── install_postgresql.sh
    │   ├── install_mongodb.sh
    │   └── install_redis.sh
    │
    ├── 📁 docker-compose/       # Docker Compose 配置（6 个）
    │   ├── README.md
    │   ├── mysql/
    │   ├── postgresql/
    │   ├── mongodb/
    │   ├── redis/
    │   ├── rabbitmq/
    │   └── minio/
    │
    └── 📁 utils/                # 工具脚本和框架
        ├── README.md
        ├── 📁 certificate/      # SSL/TLS 证书管理（3 个脚本）
        │   ├── README.md
        │   ├── install_certbot.sh
        │   ├── manage_certificates.sh
        │   └── renew_certificates.sh
        │
        └── 📁 data_governance/  # 大数据框架（3 个脚本）
            ├── README.md
            ├── install_doris.sh
            ├── install_flink.sh
            └── install_spark.sh
```

## ✨ 项目特点

### 🎯 核心优势

- **完全独立** - 每个脚本都是独立的，无外部库依赖
- **直接可执行** - 拿来即用，无需任何配置或依赖安装
- **多系统支持** - 适配 CentOS 7+、Ubuntu 18.04+、麒麟 Linux
- **生产就绪** - 包含错误处理、服务验证、健康检查
- **国内镜像** - 集成国内多个源加速下载（阿里云、清华、网易等）
- **标准化设计** - 所有脚本遵循统一的结构和规范

### 🛠️ 支持的服务

#### 核心服务（跨平台支持）

| 服务 | CentOS | Ubuntu | Kylin | 类型 |
|------|--------|--------|-------|------|
| Docker | ✅ | ✅ | ✅ | 容器化平台 |
| Nginx | ✅ | ✅ | ✅ | Web 服务器 |
| MySQL | ✅ | ✅ | ✅ | 关系型数据库 |
| PostgreSQL | ✅ | ✅ | ✅ | 高级关系型数据库 |
| MongoDB | ✅ | ✅ | ✅ | NoSQL 数据库 |
| Redis | ✅ | ✅ | ✅ | 内存数据库 |

**核心脚本总计：18 个** (3 个系统 × 6 个服务)

#### 工具脚本和框架

| 脚本/框架 | 位置 | 说明 |
|---------|------|------|
| Docker Compose | 根目录 | Docker Compose 独立安装脚本 |
| **证书管理** | `utils/certificate/` |  |
| - Certbot | `utils/certificate/install_certbot.sh` | Let's Encrypt 自动证书 |
| - 证书管理 | `utils/certificate/manage_certificates.sh` | SSL 证书日常管理 |
| - 证书续期 | `utils/certificate/renew_certificates.sh` | 自动续期工具 |
| **数据治理** | `utils/data_governance/` |  |
| - Doris | `utils/data_governance/install_doris.sh` | 分析数据库 |
| - Flink | `utils/data_governance/install_flink.sh` | 流处理框架 |
| - Spark | `utils/data_governance/install_spark.sh` | 大数据处理框架 |

**工具脚本总计：7 个**

## 🚀 快速开始

### 选择正确的脚本版本

首先确定您的操作系统：

```bash
# 查看系统信息
cat /etc/os-release

# 或者
lsb_release -a
```

然后选择对应目录中的脚本：

- **CentOS/RHEL 7+** → `centos/` 目录
- **Ubuntu 18.04+** → `ubuntu/` 目录
- **麒麟 Linux** → `kylin/` 目录

### 执行脚本

```bash
# 进入 installation 目录
cd installation

# 以 Docker 为例，在 Ubuntu 上安装：
cd ubuntu
sudo bash install_docker.sh

# 或者直接执行：
sudo bash installation/ubuntu/install_docker.sh
```

## 📖 快速导航

**进入 installation 目录后：**

- **系统指南**：`centos/README.md`、`ubuntu/README.md`、`kylin/README.md`
- **Docker 快速启动**：`docker-compose/README.md`
- **工具脚本**：`utils/README.md`
- **证书管理**：`utils/certificate/README.md`
- **大数据框架**：`utils/data_governance/README.md`
- **安装导航**：`README.md`（installation 目录下）

## 🔄 典型使用场景

### 场景 1：部署完整的 Web 服务栈

```bash
# 以 Ubuntu 为例
cd ubuntu/

# 1. 安装容器运行时
sudo bash install_docker.sh

# 2. 安装 Web 服务器
sudo bash install_nginx.sh

# 3. 安装数据库
sudo bash install_postgresql.sh

# 4. 安装缓存
sudo bash install_redis.sh
```

## ⚙️ 脚本特性详解

### 标准化结构

所有脚本都遵循相同的执行流程：

1. **check_root()** - 验证 root 权限
2. **安装步骤** - 系统相关的安装逻辑
3. **配置步骤** - 应用特定的配置
4. **start_service()** - 启动服务并启用自启动
5. **verify()** - 验证安装结果

### 彩色日志输出

- 🔵 `[INFO]` - 信息（蓝色）
- 🟢 `[SUCCESS]` - 成功（绿色）
- 🟡 `[WARN]` - 警告（黄色）
- 🔴 `[ERROR]` - 错误（红色）

## 🔐 安全建议

1. **在生产前测试** - 先在测试环境验证脚本
2. **审查脚本内容** - 运行任何脚本前都要查看其代码
3. **定期更新** - 检查新版本的脚本

---

**项目最后更新**：2025年1月21日
**版本**：1.0.0
**最低要求**：root 权限、网络连接
