# 工具脚本集合 (Utils)

本目录包含了与系统部署和管理相关的各种工具脚本，分为两个子目录：
- `certificate/` - SSL/TLS 证书管理工具
- `data_governance/` - 数据治理和大数据框架安装脚本

## 📁 目录结构

```
utils/
├── README.md                    # 本文档
├── certificate/                 # SSL/TLS 证书管理
│   ├── install_certbot.sh      # Certbot 自动证书安装
│   ├── manage_certificates.sh  # 证书管理工具
│   └── renew_certificates.sh   # 证书自动续期工具
└── data_governance/             # 数据治理框架
    ├── install_doris.sh        # Doris 分析数据库
    ├── install_flink.sh        # Flink 流处理框架
    └── install_spark.sh        # Spark 大数据处理框架
```

## 🔐 证书管理工具 (certificate/)

### 文件说明

#### install_certbot.sh
**自动化 SSL 证书获取和安装工具**

- 使用 Let's Encrypt 提供免费 SSL 证书
- 自动配置 Nginx/Apache 的证书
- 支持自动续期

**使用方法：**
```bash
sudo bash utils/certificate/install_certbot.sh
```

**功能：**
- 安装 Certbot 工具
- 创建证书
- 自动配置 Web 服务器
- 设置定时续期任务

---

#### manage_certificates.sh
**SSL 证书管理和维护工具**

- 列出已安装的证书
- 检查证书有效期
- 续期即将过期的证书
- 备份证书文件

**使用方法：**
```bash
# 列出所有证书
sudo bash utils/certificate/manage_certificates.sh list

# 检查证书状态
sudo bash utils/certificate/manage_certificates.sh check

# 续期证书
sudo bash utils/certificate/manage_certificates.sh renew

# 备份证书
sudo bash utils/certificate/manage_certificates.sh backup
```

---

#### renew_certificates.sh
**自动证书续期脚本**

- 检查所有证书的过期时间
- 自动续期即将过期的证书
- 重启 Web 服务以应用新证书
- 生成续期日志

**使用方法：**
```bash
# 手动续期所有证书
sudo bash utils/certificate/renew_certificates.sh

# 作为定时任务运行（推荐每月一次）
# 在 crontab 中添加：
# 0 2 1 * * bash /path/to/utils/certificate/renew_certificates.sh
```

**建议的定时任务：**
```bash
# 编辑 crontab
sudo crontab -e

# 添加此行（每月 1 号 2 点运行）
0 2 1 * * /usr/bin/bash /path/to/utils/certificate/renew_certificates.sh >> /var/log/cert_renew.log 2>&1
```

---

## 📊 数据治理框架 (data_governance/)

### 文件说明

#### install_doris.sh
**Apache Doris 分析数据库安装脚本**

**关于 Doris：**
- 极速分析数据库，专为 OLAP 设计
- 支持 SQL 查询和实时更新
- 高性能、低延迟
- 适合数据分析和 BI 应用

**使用方法：**
```bash
sudo bash utils/data_governance/install_doris.sh
```

**安装内容：**
- Doris FE (Frontend) - 主节点
- Doris BE (Backend) - 数据节点
- Java 运行环境
- 系统配置优化

**验证安装：**
```bash
# 连接到 Doris
mysql -h localhost -P 9030 -uroot

# 查看集群状态
SHOW FRONTENDS;
SHOW BACKENDS;
```

---

#### install_flink.sh
**Apache Flink 流处理框架安装脚本**

**关于 Flink：**
- 分布式流处理框架
- 支持实时数据处理
- 提供高吞吐、低延迟的处理能力
- 适合实时分析、异常检测、数据管道

**使用方法：**
```bash
sudo bash utils/data_governance/install_flink.sh
```

**安装内容：**
- Flink 运行时库
- JobManager（主节点）
- TaskManager（计算节点）
- 示例应用

**启动 Flink：**
```bash
# 启动 Flink 集群
$FLINK_HOME/bin/start-cluster.sh

# 访问 Web UI
# http://localhost:8081

# 停止集群
$FLINK_HOME/bin/stop-cluster.sh
```

---

#### install_spark.sh
**Apache Spark 大数据处理框架安装脚本**

**关于 Spark：**
- 分布式计算框架
- 支持批处理和流处理
- 提供 SQL、DataFrame、RDD 等 API
- 适合大规模数据处理、机器学习、图处理

**使用方法：**
```bash
sudo bash utils/data_governance/install_spark.sh
```

**安装内容：**
- Spark 核心库
- Scala/Python 支持
- Spark SQL 和 DataFrame
- Spark Streaming
- MLlib 机器学习库

**启动 Spark：**
```bash
# 交互式 Spark Shell
spark-shell

# Python 交互环境
pyspark

# 运行 Spark 作业
spark-submit --class com.example.MyApp myapp.jar

# 启动 Standalone 集群
$SPARK_HOME/sbin/start-all.sh
```

---

## 🔄 使用场景

### 场景 1：SSL 证书自动化
```bash
# 1. 安装 Certbot
sudo bash utils/certificate/install_certbot.sh

# 2. 管理证书
sudo bash utils/certificate/manage_certificates.sh check

# 3. 设置自动续期
sudo bash utils/certificate/renew_certificates.sh
```

### 场景 2：实时数据分析平台
```bash
# 1. 安装 Flink（实时处理）
sudo bash utils/data_governance/install_flink.sh

# 2. 安装 Doris（分析存储）
sudo bash utils/data_governance/install_doris.sh

# 3. 使用 Flink 处理数据并写入 Doris
```

### 场景 3：大数据分析
```bash
# 1. 安装 Spark
sudo bash utils/data_governance/install_spark.sh

# 2. 运行批处理任务
spark-submit --class com.example.Analysis myapp.jar

# 3. 使用 Spark SQL
spark-sql -e "SELECT * FROM my_table"
```

---

## 📋 可用命令

### 证书管理命令

```bash
# Certbot 常用命令
certbot certonly --webroot -w /var/www/html -d example.com
certbot renew
certbot revoke --cert-path /etc/letsencrypt/live/example.com/cert.pem

# 查看证书信息
openssl x509 -in /etc/letsencrypt/live/example.com/cert.pem -text -noout

# 检查证书过期时间
openssl x509 -enddate -noout -in /path/to/cert.pem
```

### 数据治理框架命令

```bash
# Doris 连接
mysql -h localhost -P 9030 -uroot -ppassword

# Flink 提交作业
$FLINK_HOME/bin/flink run /path/to/job.jar

# Spark 运行应用
spark-submit --master yarn --deploy-mode cluster myapp.jar
```

---

## 🐛 故障排查

### 证书问题

```bash
# 检查证书过期
sudo certbot certificates

# 强制续期
sudo certbot renew --force-renewal

# 查看续期日志
sudo tail -f /var/log/letsencrypt/renew.log
```

### 数据框架问题

```bash
# 检查 Flink 日志
tail -f $FLINK_HOME/log/*.log

# 检查 Spark 日志
tail -f $SPARK_HOME/logs/*.log

# 查看 Doris 日志
tail -f $DORIS_HOME/log/doris.log
```

---

## 💡 最佳实践

### 证书管理
1. **定期检查** - 每月检查一次证书过期状态
2. **自动续期** - 配置定时任务自动续期
3. **备份** - 定期备份证书文件
4. **监控** - 设置通知，在证书即将过期时告警

### 数据框架
1. **性能调优** - 根据数据量调整内存和并行度
2. **定期备份** - 备份数据和配置文件
3. **监控日志** - 定期检查框架日志
4. **容量规划** - 根据数据增长进行扩容

---

## 📞 常见问题

**Q: 证书续期失败怎么办？**
A: 检查网络连接、DNS 设置和防火墙规则，然后使用 `sudo certbot renew --force-renewal` 强制续期。

**Q: Spark 和 Flink 可以一起运行吗？**
A: 可以，但建议在不同的主机上运行以避免资源竞争。

**Q: 如何调整 Flink 的并行度？**
A: 在 `flink-conf.yaml` 中修改 `parallelism.default` 参数。

---

**最后更新时间：** 2025年1月21日
