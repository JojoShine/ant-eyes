# Shell Collections - 安装脚本集合

完整的 Linux 系统自动化安装脚本和 Docker Compose 配置集合。

## 📁 目录结构

```
installation/
├── README.md                           # 本文档
├── centos/                             # CentOS 7+ 脚本集（6 个）
│   ├── README.md
│   ├── install_docker.sh
│   ├── install_nginx.sh
│   ├── install_mysql.sh
│   ├── install_postgresql.sh
│   ├── install_mongodb.sh
│   └── install_redis.sh
├── ubuntu/                             # Ubuntu 18.04+ 脚本集（6 个）
│   ├── README.md
│   ├── install_docker.sh
│   ├── install_nginx.sh
│   ├── install_mysql.sh
│   ├── install_postgresql.sh
│   ├── install_mongodb.sh
│   └── install_redis.sh
├── kylin/                              # 麒麟 Linux 脚本集（6 个）
│   ├── README.md
│   ├── install_docker.sh
│   ├── install_nginx.sh
│   ├── install_mysql.sh
│   ├── install_postgresql.sh
│   ├── install_mongodb.sh
│   └── install_redis.sh
├── docker-compose/                     # Docker Compose 配置文件
│   ├── README.md
│   ├── mysql/
│   ├── postgresql/
│   ├── mongodb/
│   ├── redis/
│   ├── rabbitmq/
│   └── minio/
└── utils/                              # 工具脚本和框架
    ├── README.md
    ├── certificate/                    # SSL/TLS 证书管理
    │   ├── README.md
    │   ├── install_certbot.sh
    │   ├── manage_certificates.sh
    │   └── renew_certificates.sh
    └── data_governance/                # 数据治理框架
        ├── README.md
        ├── install_doris.sh
        ├── install_flink.sh
        └── install_spark.sh
```

## 🎯 快速导航

### 1. 操作系统特定脚本

选择您的操作系统，进入对应目录：

- **[CentOS 7+](./centos/README.md)** - `cd centos && cat README.md`
- **[Ubuntu 18.04+](./ubuntu/README.md)** - `cd ubuntu && cat README.md`
- **[麒麟 Linux](./kylin/README.md)** - `cd kylin && cat README.md`

### 2. Docker Compose 快速启动

快速启动开发环境：

- **[Docker Compose 配置](./docker-compose/README.md)** - `cd docker-compose && cat README.md`

### 3. 工具和框架

高级工具和大数据框架：

- **[工具脚本总览](./utils/README.md)** - `cd utils && cat README.md`
- **[SSL 证书管理](./utils/certificate/README.md)** - 证书自动化
- **[数据治理框架](./utils/data_governance/README.md)** - Doris、Flink、Spark

## 🚀 使用流程

### 步骤 1：识别您的系统

```bash
cat /etc/os-release | grep -E "^NAME|^VERSION"
```

### 步骤 2：选择安装脚本目录

| 系统 | 命令 |
|------|------|
| CentOS | `cd centos` |
| Ubuntu | `cd ubuntu` |
| Kylin | `cd kylin` |

### 步骤 3：查看可用脚本

```bash
ls -la install_*.sh
# 输出：install_docker.sh  install_mysql.sh  install_nginx.sh  ...
```

### 步骤 4：执行安装脚本

```bash
# 以 Docker 为例
sudo bash install_docker.sh

# 或其他服务
sudo bash install_mysql.sh
sudo bash install_postgresql.sh
sudo bash install_nginx.sh
```

## 📊 可用服务

### 核心服务（18 个脚本）

| 服务 | CentOS | Ubuntu | Kylin |
|------|--------|--------|-------|
| Docker | ✅ | ✅ | ✅ |
| Nginx | ✅ | ✅ | ✅ |
| MySQL | ✅ | ✅ | ✅ |
| PostgreSQL | ✅ | ✅ | ✅ |
| MongoDB | ✅ | ✅ | ✅ |
| Redis | ✅ | ✅ | ✅ |

### Docker Compose 服务（6 个）

- MySQL
- PostgreSQL
- MongoDB
- Redis
- RabbitMQ
- MinIO

### 工具脚本（7 个）

| 类别 | 脚本 |
|------|------|
| **证书管理** | install_certbot.sh, manage_certificates.sh, renew_certificates.sh |
| **数据治理** | install_doris.sh, install_flink.sh, install_spark.sh |

## 💡 典型使用场景

### 场景 1：快速搭建 Web 环境

```bash
cd ubuntu
sudo bash install_nginx.sh      # Web 服务器
sudo bash install_mysql.sh      # 数据库
sudo bash install_redis.sh      # 缓存
```

### 场景 2：容器化应用

```bash
cd ubuntu
sudo bash install_docker.sh     # Docker 引擎
cd ../docker-compose/mysql
docker-compose up -d            # 启动 MySQL 容器
```

### 场景 3：完整企业栈

```bash
cd centos
sudo bash install_docker.sh
sudo bash install_nginx.sh
sudo bash install_postgresql.sh
sudo bash install_mongodb.sh
sudo bash install_redis.sh
```

### 场景 4：大数据分析

```bash
cd ../utils/data_governance
sudo bash install_doris.sh      # 分析数据库
sudo bash install_flink.sh      # 实时处理
sudo bash install_spark.sh      # 批量处理
```

## 📖 详细文档

### 系统指南
- [CentOS 安装指南](./centos/README.md)
- [Ubuntu 安装指南](./ubuntu/README.md)
- [Kylin 安装指南](./kylin/README.md)

### 服务指南
- [Docker Compose 指南](./docker-compose/README.md)
- [工具脚本指南](./utils/README.md)

### 专项指南
- [证书管理指南](./utils/certificate/README.md)
- [数据治理指南](./utils/data_governance/README.md)

## ⚙️ 脚本特性

✅ **完全独立** - 每个脚本都可独立运行
✅ **多系统支持** - CentOS、Ubuntu、麒麟 Linux
✅ **国内优化** - 配置国内镜像源加速
✅ **生产就绪** - 完善的错误处理和验证
✅ **标准化** - 所有脚本遵循统一规范

## 🔐 安全建议

1. 执行前审查脚本内容
2. 在测试环境先验证
3. 修改默认密码和配置
4. 配置防火墙和访问控制
5. 定期备份重要数据
6. 保持系统和软件更新

## 🐛 快速排查

### 权限问题
```bash
sudo bash install_docker.sh
```

### 网络问题
```bash
ping 8.8.8.8
curl -I https://mirrors.aliyun.com
```

### 服务问题
```bash
sudo systemctl status docker
sudo journalctl -u docker -n 50
```

## 📊 统计信息

- **操作系统支持**：3 个（CentOS、Ubuntu、Kylin）
- **核心服务**：6 个
- **核心脚本**：18 个
- **工具脚本**：7 个
- **Docker Compose 配置**：6 个
- **总脚本数量**：31 个
- **文档数量**：8 个

## 🎯 下一步

1. **选择系统** - 进入 centos/、ubuntu/ 或 kylin/ 目录
2. **阅读指南** - 查看对应目录的 README.md
3. **执行脚本** - 根据需求运行安装脚本
4. **验证安装** - 检查服务是否正常运行

## 📞 常见问题

**Q: 脚本支持哪些系统？**
A: CentOS 7+、Ubuntu 18.04+、麒麟 Linux

**Q: 可以在生产环境使用吗？**
A: 可以，但建议先在测试环境验证

**Q: 如何修改配置？**
A: 编辑对应的配置文件或修改脚本参数

**Q: 如何卸载服务？**
A: 使用系统包管理器：`sudo yum remove` 或 `sudo apt-get remove`

---

**项目版本**：1.0.0
**最后更新**：2025年1月21日
**维护者**：Shell Collections Team
