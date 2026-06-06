================================================================================
                    Docker Compose 服务配置说明
================================================================================

本目录包含多个Docker Compose服务，每个服务的配置方式不同。
本文档说明每个服务的配置要求和使用步骤。

================================================================================
快速参考表
================================================================================

│ 服务名称  │ 配置文件    │ .env文件  │ 启动命令                │ 说明         │
├──────────┼───────────┼─────────┼──────────────────────┼──────────────┤
│ MySQL    │ ❌ 无      │ ✅ 需要  │ cd mysql && docker    │ 环境变量配置 │
│          │           │         │ compose up -d         │              │
├──────────┼───────────┼─────────┼──────────────────────┼──────────────┤
│ PostgreSQL│ ❌ 无     │ ✅ 需要  │ cd postgresql && ...  │ 环境变量配置 │
├──────────┼───────────┼─────────┼──────────────────────┼──────────────┤
│ Redis    │ ✅ 有      │ ✅ 需要  │ cd redis && docker    │ 配置文件+密码 │
│          │ redis.conf│         │ compose up -d         │              │
├──────────┼───────────┼─────────┼──────────────────────┼──────────────┤
│ MongoDB  │ ❌ 无      │ ✅ 需要  │ cd mongodb && ...     │ 环境变量配置 │
├──────────┼───────────┼─────────┼──────────────────────┼──────────────┤
│ Nginx    │ ✅ 有      │ ✅ 需要  │ cd nginx && docker    │ 配置文件+密码 │
│          │ nginx.conf│         │ compose up -d         │              │
├──────────┼───────────┼─────────┼──────────────────────┼──────────────┤
│ RabbitMQ │ ✅ 有      │ ✅ 需要  │ cd rabbitmq && ...    │ 配置文件+密码 │
│          │ rabbitmq  │         │ docker compose up -d  │              │
│          │ .conf     │         │                       │              │
├──────────┼───────────┼─────────┼──────────────────────┼──────────────┤
│ MinIO    │ ❌ 无      │ ✅ 需要  │ cd minio && docker    │ 环境变量配置 │
│          │           │         │ compose up -d         │              │
├──────────┼───────────┼─────────┼──────────────────────┼──────────────┤
│ Docker   │ 不适用    │ 不适用   │ 见operations/         │ 安装脚本     │
│ (安装脚本)│           │         │ install_docker.sh     │              │
└──────────┴───────────┴─────────┴──────────────────────┴──────────────┘

================================================================================
详细配置说明
================================================================================

【1. MySQL】
─────────────────────────────────────────────────────────────────────────────

配置方式: 仅使用.env环境变量
配置文件: ❌ 无配置文件（docker-compose.yml中直接指定）
.env文件: ✅ 需要

必需步骤:
1. cd mysql
2. cp .env.example .env
3. 编辑.env文件:
   - MYSQL_ROOT_PASSWORD=<强密码>
   - MYSQL_DATABASE=<数据库名>
   - MYSQL_USER=<用户名>
   - MYSQL_PASSWORD=<用户密码>
4. docker compose up -d

验证:
docker exec mysql mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SELECT 1"

关键配置:
├── 版本: mysql:8.0
├── 端口: 3306
├── 存储: /var/lib/mysql → mysql_data volume
├── 字符集: utf8mb4
└── 最大连接数: 1000


【2. PostgreSQL】
─────────────────────────────────────────────────────────────────────────────

配置方式: 仅使用.env环境变量
配置文件: ❌ 无配置文件
.env文件: ✅ 需要

必需步骤:
1. cd postgresql
2. cp .env.example .env
3. 编辑.env文件:
   - POSTGRES_USER=<用户名>
   - POSTGRES_PASSWORD=<强密码>
   - POSTGRES_DB=<数据库名>
4. docker compose up -d

验证:
docker exec postgresql psql -U postgres -c "SELECT 1"

关键配置:
├── 版本: postgres:15
├── 端口: 5432
├── 存储: /var/lib/postgresql → postgres_data volume
├── 编码: UTF8
└── 最大连接数: 200


【3. Redis】⭐ 最复杂
─────────────────────────────────────────────────────────────────────────────

配置方式: 配置文件 + .env环境变量
配置文件: ✅ redis.conf (272行)
.env文件: ✅ 需要

必需步骤:
1. cd redis
2. 检查redis.conf文件是否存在 ← 重要！
3. cp .env.example .env
4. 编辑.env文件:
   - REDIS_PASSWORD=<强密码>
   - REDIS_PORT=6379 (默认可不改)
5. docker compose up -d

验证:
docker exec redis redis-cli -a ${REDIS_PASSWORD} ping

关键配置（在redis.conf中）:
├── 内存限制: maxmemory 512mb
├── 淘汰策略: maxmemory-policy allkeys-lru
├── 持久化: RDB + AOF同时启用
│   ├── RDB save规则: 900秒/1变 300秒/10变 60秒/10000变
│   └── AOF: appendonly yes, appendfsync everysec
├── 最大连接: maxclients 10000
├── 日志级别: loglevel notice
└── 其他优化: activerehashing, activedefrag等

⚠️  重要提示:
    - redis.conf必须存在于redis目录下
    - docker-compose.yml会将本地redis.conf挂载到容器
    - .env中的REDIS_PASSWORD会覆盖redis.conf中的设置


【4. MongoDB】
─────────────────────────────────────────────────────────────────────────────

配置方式: 仅使用.env环境变量
配置文件: ❌ 无配置文件
.env文件: ✅ 需要

必需步骤:
1. cd mongodb
2. cp .env.example .env
3. 编辑.env文件:
   - MONGO_INITDB_ROOT_USERNAME=<用户名>
   - MONGO_INITDB_ROOT_PASSWORD=<强密码>
   - MONGO_INITDB_DATABASE=<初始数据库>
4. docker compose up -d

验证:
docker exec mongodb mongosh -u admin -p ${MONGO_PASSWORD} --eval "db.adminCommand('ping')"

关键配置:
├── 版本: mongo:7
├── 端口: 27017
├── 存储: /data/db → mongodb_data volume
├── 认证: SCRAM-SHA-1
└── 副本集: 可选（需要修改docker-compose.yml）


【5. Nginx】
─────────────────────────────────────────────────────────────────────────────

配置方式: 配置文件 + .env环境变量
配置文件: ✅ nginx.conf (Nginx配置)
.env文件: ✅ 需要

必需步骤:
1. cd nginx
2. 检查nginx.conf文件是否存在 ← 重要！
3. cp .env.example .env
4. 编辑.env文件（如需）:
   - NGINX_HTTP_PORT=80
   - NGINX_HTTPS_PORT=443
5. docker compose up -d

验证:
curl http://localhost

关键配置（在nginx.conf中）:
├── 工作进程: worker_processes auto
├── 连接数: worker_connections 1024
├── 超时: proxy_connect_timeout 60s
├── 缓存: client_max_body_size 100m
└── 日志: access_log和error_log配置

⚠️  重要提示:
    - nginx.conf必须存在于nginx目录下
    - 需要配置upstream指向其他服务
    - HTTP和HTTPS端口可在docker-compose.yml中修改


【6. RabbitMQ】⭐ 需要特别注意
─────────────────────────────────────────────────────────────────────────────

配置方式: 配置文件 + .env环境变量
配置文件: ✅ rabbitmq.conf (简化配置，避免启动失败)
.env文件: ✅ 需要

必需步骤:
1. cd rabbitmq
2. 检查rabbitmq.conf文件是否存在 ← 重要！
3. cp .env.example .env
4. 编辑.env文件:
   - RABBITMQ_USER=admin
   - RABBITMQ_PASSWORD=<强密码>
   - RABBITMQ_VHOST=/
5. docker compose up -d

验证:
docker logs rabbitmq  # 检查是否有错误
docker exec rabbitmq rabbitmq-diagnostics -q ping  # 应返回pong

关键配置（在rabbitmq.conf中）:
├── 内存阈值: vm_memory_high_watermark.relative = 0.6
├── 磁盘限制: disk_free_limit.absolute = 50MB
├── 连接数: channel_max = 2048
├── 心跳: heartbeat = 60
└── 其他: connection_max = unlimited

⚠️  关键注意事项:
    1. rabbitmq.conf必须存在 - 用于配置内存和性能
    2. 不要包含会导致解析错误的复杂配置
    3. 使用简化的.conf文件避免启动失败
    4. 密码通过.env文件传入更安全
    5. Management UI访问: http://localhost:15672
    6. 默认用户: guest/guest（需改为admin用户）

常见错误:
❌ BOOT FAILED - failed_to_prepare_configuration
   原因: rabbitmq.conf配置语法错误或参数无效
   解决: 使用简化的conf文件，删除复杂配置

❌ enabled_plugins 挂载失败
   原因: 尝试挂载不存在的文件
   解决: 移除该volume挂载


【7. MinIO】
─────────────────────────────────────────────────────────────────────────────

配置方式: 仅使用.env环境变量
配置文件: ❌ 无配置文件（通过命令行参数配置）
.env文件: ✅ 需要

必需步骤:
1. cd minio
2. cp .env.example .env
3. 编辑.env文件:
   - MINIO_ROOT_USER=<访问密钥>
   - MINIO_ROOT_PASSWORD=<秘密密钥>
4. docker compose up -d

验证:
curl -X GET http://localhost:9000/minio/health/live

访问Console:
浏览器访问: http://localhost:9001
用户: MINIO_ROOT_USER
密码: MINIO_ROOT_PASSWORD

关键配置:
├── API端口: 9000
├── Console端口: 9001
├── 存储: /data → minio_data volume
├── 访问密钥: 由.env文件设置
└── 秘密密钥: 由.env文件设置

================================================================================
通用步骤总结
================================================================================

所有服务都遵循以下步骤:

第1步: 进入服务目录
  $ cd <服务名>

第2步: 检查.env.example
  $ cat .env.example  # 查看需要配置的参数

第3步: 创建.env文件
  $ cp .env.example .env

第4步: 编辑.env文件
  $ vim .env  # 或使用其他编辑器
  设置所有必需的密码和配置项

第5步: （仅限需要配置文件的服务）检查配置文件
  $ ls *.conf  # 确保配置文件存在
  如果不存在，查看本文档相关部分

第6步: 启动服务
  $ docker compose up -d

第7步: 验证服务
  $ docker logs <服务名>  # 查看日志
  $ docker ps | grep <服务名>  # 确认容器运行中

================================================================================
需要配置文件的服务详细说明
================================================================================

【Redis】
位置: redis/redis.conf
来源: Redis官方标准配置
大小: 272行
用途: 配置内存、持久化、性能等

如需修改:
1. 编辑redis/redis.conf
2. 重启容器: docker compose down && docker compose up -d

【Nginx】
位置: nginx/nginx.conf
来源: Nginx官方配置
用途: 配置代理、负载均衡、缓存等

如需修改:
1. 编辑nginx/nginx.conf
2. 测试配置: docker exec nginx nginx -t
3. 重启容器: docker compose down && docker compose up -d

【RabbitMQ】
位置: rabbitmq/rabbitmq.conf
来源: RabbitMQ官方配置（简化版）
大小: 4行关键配置
用途: 配置内存、连接数、心跳等

⚠️  特别注意:
   - 只包含必需的配置参数
   - 避免包含会导致启动失败的复杂配置
   - 如需高级配置，查看官方文档

================================================================================
故障排查
================================================================================

【问题1: docker compose up失败】
检查清单:
□ 是否cd进入了正确的服务目录?
□ 是否创建了.env文件?
□ 是否在.env中设置了密码(至少12位)?
□ 对于需要配置文件的服务，配置文件是否存在?

【问题2: 容器启动后立即退出】
排查步骤:
1. 查看日志: docker logs <容器名>
2. 检查配置: 查看是否有语法错误
3. 检查.env: 确保密码和配置正确

【问题3: 容器运行但无法连接】
排查步骤:
1. 检查端口: docker ps 看是否暴露了正确的端口
2. 检查防火墙: sudo ufw status
3. 检查网络: docker network ls

【问题4: RabbitMQ启动失败 (BOOT FAILED)】
原因: rabbitmq.conf配置错误
解决:
1. 使用本文档提供的rabbitmq.conf
2. 移除所有可能导致解析错误的复杂配置
3. 如需自定义，参考官方文档逐个添加

================================================================================
最佳实践
================================================================================

1. 密码管理
   ✅ 使用强密码（至少12位，包含大小写和特殊字符）
   ✅ 每个服务使用不同的密码
   ✅ 将.env文件加入.gitignore（不要提交到git）
   ❌ 不要使用123456这样的弱密码

2. 配置文件管理
   ✅ 配置文件应该在服务目录下
   ✅ 修改配置后重启容器
   ✅ 保留.env.example作为参考
   ❌ 不要直接编辑部署中的.env文件

3. 数据持久化
   ✅ 使用named volumes存储重要数据
   ✅ 定期备份volume: docker run --rm -v <volume>:/data -v $(pwd):/backup ubuntu tar czf /backup/backup.tar.gz /data
   ❌ 不要删除已运行的volume

4. 监控和维护
   ✅ 定期查看日志: docker logs -f <容器名>
   ✅ 定期更新镜像: docker pull <镜像>
   ✅ 监控资源使用: docker stats
   ❌ 不要修改容器内文件（因为不会持久化）

================================================================================
多服务启动脚本
================================================================================

如需一次启动多个服务，可以创建启动脚本:

#!/bin/bash
services=("mysql" "postgresql" "redis" "mongodb" "rabbitmq" "minio" "nginx")

for service in "${services[@]}"; do
    echo "启动 $service..."
    cd $service
    cp .env.example .env 2>/dev/null
    docker compose up -d
    cd ..
    sleep 2
done

echo "所有服务已启动"

================================================================================
快速参考命令
================================================================================

查看所有容器:
$ docker ps

查看特定服务日志:
$ docker logs -f <服务名>

进入容器:
$ docker exec -it <容器名> /bin/bash

停止所有服务:
$ for dir in */; do cd "$dir" && docker compose down && cd ..; done

重启服务:
$ cd <服务名> && docker compose restart && cd ..

查看volume:
$ docker volume ls

================================================================================
                              帮助和支持
================================================================================

遇到问题?

1. 查看服务日志:
   docker logs <服务名>

2. 检查docker-compose.yml:
   查看是否有syntax错误

3. 检查.env文件:
   确保所有密码和参数正确

4. 查看官方文档:
   - MySQL: https://hub.docker.com/_/mysql
   - Redis: https://hub.docker.com/_/redis
   - RabbitMQ: https://hub.docker.com/_/rabbitmq
   - MongoDB: https://hub.docker.com/_/mongo
   - MinIO: https://hub.docker.com/r/minio/minio
   - Nginx: https://hub.docker.com/_/nginx
   - PostgreSQL: https://hub.docker.com/_/postgres

================================================================================
