# ant-eyes

Linux 服务器健康检查和运维管理工具

简体中文 | [English](./README.en.md)

## 概述

ant-eyes 是一个全面的 Linux 服务器运维工具集，提供系统检查、服务管理、运维工具等功能。支持 CentOS、Ubuntu、Kylin、UOS 等多种 Linux 发行版。

### 核心特性

- 系统健康检查：CPU、内存、磁盘、网络等关键信息
- 安全审计：SSH 登录失败、暴力破解检测
- 运维管理：定时任务、时间同步、磁盘管理、防火墙管理、性能检查
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

# 防火墙管理
ant-eyes manage firewall
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
- `firewall` - 防火墙管理（端口开放、Rich 规则）

示例：
```bash
ant-eyes manage cron           # 管理定时任务
ant-eyes manage time           # 管理时间同步
ant-eyes manage disk           # 磁盘分区挂载
ant-eyes manage performance    # 磁盘性能检查
ant-eyes manage firewall       # 防火墙管理
```

#### manage cron - 定时任务管理

交互式菜单，支持以下操作：
1. **查看定时任务** - 显示当前用户的所有定时任务
2. **添加新的定时任务** - 支持常用模板或自定义
   - 每日备份 (凌晨2点)
   - 每周清理 (周日凌晨3点)
   - 每月检查 (1号凌晨0点)
   - 每小时执行
   - 自定义频率
3. **删除定时任务** - 按编号删除不需要的任务
4. **编辑定时任务** - 使用编辑器修改crontab
5. **查看常用模板** - 参考预设的任务模板

**使用流程：**
```bash
ant-eyes manage cron
# 进入菜单后，按数字选择操作
# 0 - 返回退出
```

#### manage time - 时间同步管理

交互式菜单，支持以下操作：
1. **查看时间同步状态** - 检查NTP/Chrony服务状态
2. **配置NTP服务器** - 修改NTP服务器列表
3. **手动调整系统时间** - 设置系统时间
4. **查看时间同步指南** - 了解NTP配置方法

**使用流程：**
```bash
ant-eyes manage time
# 进入菜单后，按数字选择操作
# 0 - 返回退出
```

#### manage disk - 磁盘分区管理

**交互式完整磁盘管理工具，9个菜单选项：**

1. **查看磁盘和分区信息** - 显示当前所有磁盘分区
2. **查看分区类型（MBR/GPT）** - 自动检测分区表类型
3. **创建新分区** - 支持 fdisk/gdisk 创建分区
   - 自动检测是否需要用 fdisk (MBR) 还是 gdisk (GPT)
   - 可选择是否立即启动分区工具
4. **格式化分区** - 支持多种文件系统
   - ext4（推荐）
   - xfs（高性能）
   - btrfs（新一代）
   - ntfs（Windows）
   - exfat（便携式）
   - vfat（FAT32）
5. **挂载分区** - 临时挂载分区到指定目录
6. **卸载分区** - 卸载已挂载的分区
7. **创建挂载点** - 创建新的挂载目录
8. **配置开机自动挂载** - 编辑 /etc/fstab 实现自启
9. **查看分区挂载指南** - 完整的操作指南

**三种场景的执行顺序指南：**

**场景1️⃣：新硬盘未分区（完整流程）**
```bash
ant-eyes manage disk
# 第1步：菜单选项 1 - 查看磁盘信息
#        目的：找到新硬盘（如 /dev/sdb）
#
# 第2步：菜单选项 2 - 查看分区类型
#        目的：检测分区表类型（会自动创建如果不存在）
#
# 第3步：菜单选项 3 - 创建新分区
#        目的：用 fdisk/gdisk 划分磁盘空间
#        选择磁盘 → 选择是否启动工具
#        如启动：n 创建分区 → 设置大小 → w 保存
#
# 第4步：菜单选项 1 - 查看磁盘信息（可选）
#        目的：验证分区已创建（如 /dev/sdb1）
#
# 第5步：菜单选项 4 - 格式化分区
#        目的：选择文件系统（推荐 ext4）
#        确认分区名 → 输入设备名确认
#
# 第6步：菜单选项 5 - 挂载分区
#        目的：临时挂载到目录（如 /mnt/data）
#
# 第7步：菜单选项 8 - 配置开机自启
#        目的：编辑 /etc/fstab 永久挂载
#
# 完成：0 - 返回退出
```

**场景2️⃣：新硬盘已分区未格式化（跳过第3步）**
```bash
ant-eyes manage disk
# 第1步：菜单选项 1 - 查看磁盘信息
# 第4步：菜单选项 4 - 格式化分区
# 第5步：菜单选项 5 - 挂载分区
# 第6步：菜单选项 8 - 配置开机自启
# 完成：0 - 返回退出
```

**场景3️⃣：分区已存在只需挂载（跳过第3、4步）**
```bash
ant-eyes manage disk
# 第1步：菜单选项 1 - 查看磁盘信息（确认分区）
# 第5步：菜单选项 5 - 挂载分区
# 第6步：菜单选项 8 - 配置开机自启
# 完成：0 - 返回退出
```

**⚠️ 重要提示 - 关键执行顺序：**

1. **必须先格式化再挂载** - 不能颠倒
   - ❌ 错误：先挂载未格式化的分区
   - ✅ 正确：先格式化 → 再挂载 → 最后配置自启

2. **第4步（格式化）的关键操作：**
   - 选择要格式化的分区（如 /dev/sdb1）
   - 选择文件系统类型
   - **确认警告**：输入分区设备名（如 sdb1）进行确认
   - 这一步是为了防止误操作

3. **第5步（挂载）前需要第7步（创建挂载点）：**
   - 如果挂载点不存在，先执行选项 7 创建目录
   - 然后回到菜单执行选项 5 挂载

4. **菜单选项 2 "查看分区类型"会一闪而过：**
   - 这是正常的，脚本快速检测完成就返回菜单
   - 信息会显示在屏幕上，可能需要快速查看

**注意事项：**
- 所有操作需要 root 权限（使用 sudo）
- 创建和格式化分区是**不可逆操作**，会导致数据丢失
- 格式化前务必确认选择的是正确的分区
- 所有操作完成后**不会立即退出**，可继续其他操作（选 0 返回）

#### manage firewall - 防火墙管理

**交互式防火墙管理工具，支持 firewalld 和 ufw 双引擎：**

1. **查看防火墙状态** - 展示当前开放端口、允许服务、Rich 规则
2. **开放端口** - 支持单端口/端口段、tcp/udp 协议选择
   - 可选永久生效（`--permanent`）或仅本次运行
   - 自动检测端口是否已开放
   - 显示常用端口服务名称参考
3. **关闭端口** - 交互式选择关闭，同步清理永久规则
4. **Rich 规则管理** - 交互式构建高级防火墙规则
   - 允许/拒绝指定 IP 访问端口
   - 允许/拒绝指定 IP 段（CIDR）访问端口
   - 端口转发
   - 限速（rate limit，防暴力破解）
   - 手动输入自定义 Rich 规则
   - 内置 Rich 规则语法说明
5. **服务管理** - 添加/移除 firewalld 服务（http、ssh、mysql 等）
6. **重载规则** - 一键重载防火墙配置

**使用流程：**
```bash
ant-eyes manage firewall
# 进入菜单后，按数字选择操作
# 0 - 返回退出
```

**注意事项：**
- 自动检测防火墙类型（firewalld / ufw），提供对应管理界面
- firewalld 支持完整功能（端口、Rich 规则、服务管理）
- ufw 支持端口开放/关闭和规则查看
- 开放端口时可选择永久生效或临时生效
- 所有操作需要 root 权限

#### manage performance - 磁盘 I/O 性能检查

**交互式磁盘性能诊断工具，4个菜单选项：**

1. **iostat 实时 I/O 监控** - 查看当前磁盘 I/O 性能指标
   - 采集 3 次样本（每次间隔 2 秒）
   - 显示每个磁盘的吞吐量、IOPS 等指标
   - 需要安装 sysstat 工具（脚本自动安装）

2. **fio 磁盘性能基准测试** - 测试磁盘最大性能
   - 顺序读测试（128K块）
   - 顺序写测试（128K块）
   - 随机读测试（4K块）
   - 随机写测试（4K块）
   - 混合读写测试
   - 需要安装 fio 工具（脚本自动安装）

3. **磁盘 SMART 健康检查** - 检查磁盘硬件健康状态
   - 显示磁盘温度
   - 检查 SMART 属性
   - 提醒磁盘寿命预测
   - 需要安装 smartctl 工具（脚本自动安装）

4. **I/O 综合报告** - 系统 I/O 负载分析
   - 显示磁盘利用率
   - 分析当前 I/O 压力
   - 提供性能优化建议

**使用流程：**
```bash
ant-eyes manage performance
# 菜单选项 1: 运行 iostat 监控
# 菜单选项 2: 运行 fio 基准测试
# 菜单选项 3: 运行 SMART 检查
# 菜单选项 4: 查看综合报告
# 0 - 返回退出
```

**注意事项：**
- 所有工具会自动安装，无需手动配置
- fio 基准测试可能耗时较长（取决于磁盘性能）
- 建议在系统空闲时运行性能测试
- 所有操作完成后不会立即退出，可继续进行其他操作

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
- UOS（统信UOS）

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
├── manage/               # 管理模块（5个脚本）
│   ├── manage_cron.sh
│   ├── manage_time.sh
│   ├── manage_disk.sh
│   ├── manage_performance.sh
│   └── manage_firewall.sh
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
