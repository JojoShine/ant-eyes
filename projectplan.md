# 发布 npm 包 v1.2.0

## 更新内容
本次更新主要针对数据库安装脚本的重大改进：

### 主要变更
1. **PostgreSQL 升级到 18.2 版本**
   - 改为源码编译安装，不再依赖系统包管理器
   - 安装路径：/usr/local/pgsql
   - 支持 OpenSSL、libxml、libxslt
   - 优先使用国内镜像源下载

2. **所有数据库数据目录迁移到 /data**
   - PostgreSQL: /data/postgresql
   - MySQL: /data/mysql
   - MongoDB: /data/mongodb
   - Redis: /data/redis
   - 避免占用系统盘空间

3. **防火墙配置**
   - 自动配置防火墙规则，支持远程访问
   - CentOS/RHEL: firewalld
   - Ubuntu/Kylin: ufw

4. **PostgreSQL 安装改进**
   - 修复密码设置问题
   - 安装前检查并清理旧服务
   - 自动备份旧数据目录

### 涉及文件
- installation/centos/install_postgresql.sh
- installation/centos/install_mysql.sh
- installation/centos/install_mongodb.sh
- installation/centos/install_redis.sh
- installation/kylin/install_postgresql.sh
- installation/kylin/install_mysql.sh
- installation/kylin/install_mongodb.sh
- installation/kylin/install_redis.sh
- installation/services/install_postgresql.sh

## 计划

### Todo 列表
- [ ] 升级 package.json 版本号从 1.1.0 到 1.2.0
- [ ] 提交代码到 git
- [ ] 发布到 npm
- [ ] 验证发布成功

## Review
待完成...

## 问题
1. PostgreSQL/MySQL/MongoDB/Redis 安装后无法远程访问 - 缺少防火墙配置
2. 所有数据存储应该放到 /data 目录（外部挂载存储，不占用系统盘）

## 计划

### Todo 列表
- [x] 修改 PostgreSQL 安装脚本（CentOS 和 Kylin）
  - 添加防火墙规则（端口 5432）
  - 修改数据目录到 /data/postgresql
  - 配置 pg_hba.conf 允许远程访问
  - 配置 postgresql.conf 监听所有地址
- [x] 修改 MySQL 安装脚本（CentOS 和 Kylin）
  - 添加防火墙规则（端口 3306）
  - 修改数据目录到 /data/mysql
  - 修改 bind-address 配置允许远程访问
- [x] 修改 MongoDB 安装脚本（CentOS 和 Kylin）
  - 添加防火墙规则（端口 27017）
  - 修改数据目录到 /data/mongodb
  - 配置 bindIp 允许远程访问
- [x] 修改 Redis 安装脚本（CentOS 和 Kylin）
  - 添加防火墙规则（端口 6379）
  - 修改数据目录到 /data/redis
  - 配置 bind 允许远程访问

## 实现细节

### 防火墙配置
使用 firewalld（CentOS/RHEL）或 ufw（Kylin）添加端口规则

### 数据目录迁移
- PostgreSQL: /data/postgresql
- MySQL: /data/mysql
- MongoDB: /data/mongodb
- Redis: /data/redis

### 远程访问配置
- PostgreSQL: 修改 pg_hba.conf 和 postgresql.conf
- MySQL: 修改 bind-address = 0.0.0.0
- MongoDB: 修改 bindIp = 0.0.0.0
- Redis: 修改 bind = 0.0.0.0

## 新增需求
- [x] PostgreSQL 改为源码编译安装 18 版本
  - 修改 installation/centos/install_postgresql.sh
  - 修改 installation/kylin/install_postgresql.sh
  - 修改 installation/services/install_postgresql.sh
  - 使用源码编译而非 yum/apt 默认版本
- [x] 修复 PostgreSQL 密码设置问题
  - 临时使用 trust 认证设置密码
  - 设置成功后改回 md5 认证
- [x] 安装前检查并清理旧服务
  - 检测包管理器安装的 PostgreSQL
  - 检测运行中的 PostgreSQL 服务
  - 检测旧的数据目录
  - 提示用户确认是否卸载
  - 自动备份旧数据目录

## Review

### 第一阶段：防火墙和数据目录（已完成）
已完成所有 8 个安装脚本的修改（PostgreSQL、MySQL、MongoDB、Redis 各 2 个版本）：

1. **防火墙配置**
   - CentOS/RHEL: 使用 firewalld 添加端口规则
   - Kylin: 使用 ufw 添加端口规则
   - 如果防火墙服务未运行，会显示警告但不会中断安装

2. **数据目录迁移**
   - 所有数据库数据目录统一迁移到 /data 目录
   - 创建目录并设置正确的权限和所有者

3. **远程访问配置**
   - PostgreSQL: listen_addresses = '*', pg_hba.conf 添加远程访问规则
   - MySQL: bind-address = 0.0.0.0, datadir = /data/mysql
   - MongoDB: bindIp = 0.0.0.0, dbPath = /data/mongodb
   - Redis: bind = 0.0.0.0, dir = /data/redis

4. **安装完成提示**
   - 每个脚本在安装完成后会显示数据目录位置和远程访问端口信息

### 第二阶段：PostgreSQL 源码编译（已完成）
已完成 3 个 PostgreSQL 安装脚本的源码编译改造：

1. **版本升级**
   - 从系统默认版本升级到 PostgreSQL 18.2
   - 使用官方源码编译安装

2. **编译配置**
   - 安装路径: /usr/local/pgsql
   - 数据目录: /data/postgresql
   - 支持 OpenSSL、libxml、libxslt
   - 启用线程安全

3. **下载优化**
   - 优先使用清华大学镜像源
   - 失败后自动切换到官方源

4. **系统集成**
   - 创建 systemd 服务文件
   - 添加 PATH 环境变量
   - 配置防火墙规则
   - 支持远程访问

5. **修改的文件**
   - installation/centos/install_postgresql.sh
   - installation/kylin/install_postgresql.sh
   - installation/services/install_postgresql.sh