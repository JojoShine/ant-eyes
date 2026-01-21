# Docker Compose 配置文件集合

本目录包含常用服务的 Docker Compose 配置文件，用于快速启动开发和测试环境。

## 📋 包含的服务

| 服务 | 描述 | 目录 |
|------|------|------|
| **MySQL** | 关系型数据库 | `mysql/` |
| **PostgreSQL** | 高级关系型数据库 | `postgresql/` |
| **MongoDB** | NoSQL 文档数据库 | `mongodb/` |
| **Redis** | 内存数据库 | `redis/` |
| **RabbitMQ** | 消息队列 | `rabbitmq/` |
| **MinIO** | 对象存储 | `minio/` |

## 🚀 快速开始

### 前置条件

```bash
# 确保已安装 Docker 和 Docker Compose
docker --version
docker-compose --version

# 或使用独立的 docker-compose 脚本
sudo bash ../docker-compose-install.sh
```

### 启动服务

```bash
# 进入服务目录
cd mysql

# 启动服务（后台运行）
docker-compose up -d

# 查看运行状态
docker-compose ps

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

### 常用命令

```bash
# 启动服务
docker-compose up -d

# 停止服务
docker-compose down

# 重启服务
docker-compose restart

# 查看日志
docker-compose logs -f

# 进入容器
docker-compose exec mysql bash

# 查看网络
docker network ls

# 查看数据卷
docker volume ls
```

---

## 📁 各服务详解

### MySQL

**目录：** `mysql/`

```bash
cd mysql
docker-compose up -d
```

**连接信息：**
- 主机：localhost 或容器网络中的 `mysql`
- 端口：3306
- 用户：root
- 密码：（在 docker-compose.yml 中配置）
- 数据库：myapp

**连接命令：**
```bash
# 本地连接
mysql -h localhost -P 3306 -uroot -p

# 或在容器中
docker-compose exec mysql mysql -uroot -p
```

---

### PostgreSQL

**目录：** `postgresql/`

```bash
cd postgresql
docker-compose up -d
```

**连接信息：**
- 主机：localhost 或容器网络中的 `postgres`
- 端口：5432
- 用户：postgres
- 密码：（在 docker-compose.yml 中配置）
- 数据库：myapp

**连接命令：**
```bash
# 本地连接
psql -h localhost -U postgres -d myapp

# 或在容器中
docker-compose exec postgres psql -U postgres -d myapp
```

---

### MongoDB

**目录：** `mongodb/`

```bash
cd mongodb
docker-compose up -d
```

**连接信息：**
- 主机：localhost 或容器网络中的 `mongodb`
- 端口：27017
- 用户：root（如配置）
- 密码：（在 docker-compose.yml 中配置）
- 数据库：admin

**连接命令：**
```bash
# 本地连接（无认证）
mongo mongodb://localhost:27017

# 有认证的连接
mongo mongodb://root:password@localhost:27017/admin

# 或在容器中
docker-compose exec mongodb mongo
```

---

### Redis

**目录：** `redis/`

```bash
cd redis
docker-compose up -d
```

**连接信息：**
- 主机：localhost 或容器网络中的 `redis`
- 端口：6379
- 密码：（可选，在 docker-compose.yml 中配置）

**连接命令：**
```bash
# 本地连接
redis-cli -h localhost -p 6379

# 有密码的连接
redis-cli -h localhost -p 6379 -a password

# 或在容器中
docker-compose exec redis redis-cli
```

---

### RabbitMQ

**目录：** `rabbitmq/`

```bash
cd rabbitmq
docker-compose up -d
```

**连接信息：**
- AMQP 主机：localhost
- AMQP 端口：5672
- 管理界面：http://localhost:15672
- 用户：guest
- 密码：guest

**访问管理界面：**
```
http://localhost:15672
用户名：guest
密码：guest
```

**连接命令（Python 示例）：**
```python
import pika

connection = pika.BlockingConnection(
    pika.ConnectionParameters(host='localhost')
)
channel = connection.channel()
```

---

### MinIO

**目录：** `minio/`

```bash
cd minio
docker-compose up -d
```

**连接信息：**
- API 端点：http://localhost:9000
- 控制台：http://localhost:9001
- Access Key：（在 docker-compose.yml 中配置）
- Secret Key：（在 docker-compose.yml 中配置）

**访问控制台：**
```
http://localhost:9001
用户名：minioadmin
密码：minioadmin（默认）
```

**连接命令（Python 示例）：**
```python
from minio import Minio

client = Minio(
    "localhost:9000",
    access_key="minioadmin",
    secret_key="minioadmin",
    secure=False
)
```

---

## 🔧 配置修改

### 修改端口

编辑 `docker-compose.yml` 文件中的 `ports` 部分：

```yaml
# 修改前
services:
  mysql:
    ports:
      - "3306:3306"

# 修改后（改为 3307）
services:
  mysql:
    ports:
      - "3307:3306"
```

然后重启服务：
```bash
docker-compose down
docker-compose up -d
```

### 修改密码

编辑 `docker-compose.yml` 文件中的环境变量：

```yaml
# MySQL 示例
services:
  mysql:
    environment:
      MYSQL_ROOT_PASSWORD: your_new_password
```

### 持久化数据

数据卷配置：

```yaml
volumes:
  mysql-data:
    driver: local

services:
  mysql:
    volumes:
      - mysql-data:/var/lib/mysql
```

---

## 📊 多服务编排

### 启动多个服务

```bash
# 创建 docker-compose.yml 整合多个服务
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    ports:
      - "3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: root123
    networks:
      - mynetwork

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    networks:
      - mynetwork

  mongodb:
    image: mongo:5
    ports:
      - "27017:27017"
    networks:
      - mynetwork

networks:
  mynetwork:
    driver: bridge
EOF

# 启动所有服务
docker-compose up -d

# 查看所有服务
docker-compose ps

# 检查网络连接
docker network inspect <network-name>
```

### 服务间通信

在同一网络中，容器可以通过服务名称相互通信：

```python
# Python 应用连接多个服务
import mysql.connector
import redis
import pymongo

# 连接 MySQL
mysql_conn = mysql.connector.connect(
    host='mysql',  # 服务名
    user='root',
    password='root123',
    database='myapp'
)

# 连接 Redis
redis_client = redis.Redis(host='redis', port=6379)

# 连接 MongoDB
mongo_client = pymongo.MongoClient('mongodb://mongodb:27017/')
```

---

## 🐛 故障排查

### 端口已被占用

```bash
# 查看占用的端口
lsof -i :3306

# 修改 docker-compose.yml 中的端口
# 或停止占用该端口的服务
kill -9 <PID>

# 重启服务
docker-compose down
docker-compose up -d
```

### 容器无法启动

```bash
# 查看错误日志
docker-compose logs mysql

# 查看容器详细信息
docker-compose ps -a

# 删除容器并重新创建
docker-compose down
docker-compose up -d
```

### 无法连接到服务

```bash
# 检查容器是否运行
docker-compose ps

# 检查网络连接
docker network inspect <network-name>

# 进入容器测试
docker-compose exec mysql bash
ping redis

# 检查防火墙
sudo ufw status
```

### 性能问题

```bash
# 查看容器资源使用
docker stats

# 限制容器资源（编辑 docker-compose.yml）
services:
  mysql:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
```

---

## 📦 备份和恢复

### 备份数据库

```bash
# MySQL 备份
docker-compose exec mysql mysqldump -uroot -p --all-databases > backup.sql

# MongoDB 备份
docker-compose exec mongodb mongodump --out /backup

# Redis 备份
docker-compose exec redis redis-cli BGSAVE
```

### 恢复数据库

```bash
# MySQL 恢复
docker-compose exec -T mysql mysql -uroot -p < backup.sql

# MongoDB 恢复
docker-compose exec mongodb mongorestore /backup

# Redis 恢复
docker-compose exec redis redis-cli BGREWRITEAOF
```

---

## 🔐 安全建议

1. **修改默认密码** - 所有服务都应使用强密码
2. **限制网络访问** - 不要在生产环境中暴露所有端口
3. **启用认证** - 为所有服务启用用户认证
4. **定期备份** - 定期备份重要数据
5. **使用持久化存储** - 配置数据卷确保数据持久化
6. **更新镜像** - 定期更新 Docker 镜像版本

---

## 📝 常见问题

**Q: 如何在容器间使用不同的网络？**
A: 在 docker-compose.yml 中定义自定义网络，并在服务中指定。

**Q: 如何让数据在容器删除后保留？**
A: 使用 Docker 数据卷（volumes）而不是 bind mounts。

**Q: 如何扩展容器？**
A: 使用 `docker-compose up -d --scale service=3` 命令。

**Q: 如何在生产环境使用？**
A: 使用 Docker Swarm 或 Kubernetes 进行容器编排。

---

**最后更新时间：** 2025年1月21日
