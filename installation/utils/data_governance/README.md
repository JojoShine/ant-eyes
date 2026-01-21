# 数据治理框架 (Data Governance)

本目录包含大数据和数据分析框架的自动化安装脚本，包括实时流处理、分布式计算和分析数据库。

## 📋 框架清单

| 框架 | 类型 | 使用场景 | 文件 |
|------|------|--------|------|
| **Apache Flink** | 流处理 | 实时数据处理、事件驱动应用 | `install_flink.sh` |
| **Apache Spark** | 批处理/流处理 | 大数据分析、机器学习、图处理 | `install_spark.sh` |
| **Apache Doris** | OLAP 数据库 | 实时分析、数据仓库、BI 系统 | `install_doris.sh` |

## 🏗️ 架构概览

```
数据源
  ↓
┌─────────────────────────────────────┐
│ Flink (实时数据处理)                │  ← 流处理、数据清洗
└────────────┬────────────────────────┘
             ↓
┌─────────────────────────────────────┐
│ Spark (数据处理/分析)               │  ← 批处理、计算
└────────────┬────────────────────────┘
             ↓
┌─────────────────────────────────────┐
│ Doris (分析数据库)                  │  ← 数据存储、查询
└─────────────────────────────────────┘
             ↓
        BI/可视化
```

---

## 🚀 快速开始

### 安装顺序建议

1. **先安装 Doris（存储层）**
   ```bash
   sudo bash install_doris.sh
   ```

2. **再安装 Flink（实时处理）或 Spark（批处理）**
   ```bash
   sudo bash install_flink.sh
   # 或
   sudo bash install_spark.sh
   ```

3. **配置数据管道**
   - Flink → Doris（实时流写入）
   - Spark → Doris（批量写入）

---

## 📄 脚本详解

### install_flink.sh

**用途：** 安装 Apache Flink 流处理框架

**关于 Flink：**
- 分布式流处理引擎
- 支持有状态计算
- 提供恰好一次（Exactly-Once）语义
- 高吞吐、低延迟

**支持系统：**
- CentOS 7+
- Ubuntu 18.04+
- 麒麟 Linux

**安装内容：**
- ✅ Java 运行环境（JDK 8/11）
- ✅ Flink 核心库
- ✅ JobManager（主控节点）
- ✅ TaskManager（计算节点）
- ✅ Flink CLI 工具
- ✅ Web UI（端口 8081）

**使用示例：**

```bash
# 安装
sudo bash install_flink.sh

# 启动集群
$FLINK_HOME/bin/start-cluster.sh

# 访问 Web UI
# http://localhost:8081

# 提交作业
$FLINK_HOME/bin/flink run /path/to/job.jar

# 停止集群
$FLINK_HOME/bin/stop-cluster.sh
```

**常用环境变量：**
```bash
export FLINK_HOME=/opt/flink
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk

# 启动单个服务
$FLINK_HOME/bin/jobmanager.sh start
$FLINK_HOME/bin/taskmanager.sh start
```

**配置文件位置：**
```
$FLINK_HOME/conf/flink-conf.yaml       # 主配置文件
$FLINK_HOME/conf/log4j.properties      # 日志配置
$FLINK_HOME/conf/logback.xml           # Logback 配置
```

**常用配置参数：**
```yaml
# flink-conf.yaml

# 网络配置
jobmanager.rpc.address: localhost
jobmanager.rpc.port: 6123
taskmanager.rpc.port: 6124

# 内存配置
jobmanager.memory.process.size: 1600m
taskmanager.memory.process.size: 1728m
taskmanager.numberOfTaskSlots: 8

# 并行度配置
parallelism.default: 4

# 检查点配置
state.backend: hashmap
state.checkpoints.dir: file:///tmp/flink-checkpoints
state.savepoints.dir: file:///tmp/flink-savepoints
```

**监控和日志：**
```bash
# 查看日志
tail -f $FLINK_HOME/log/flink-*.log

# 查看作业状态
curl http://localhost:8081/v1/jobs

# 查看 TaskManager 状态
curl http://localhost:8081/v1/taskmanagers
```

---

### install_spark.sh

**用途：** 安装 Apache Spark 大数据处理框架

**关于 Spark：**
- 分布式计算框架
- 支持批处理、流处理、SQL、ML
- 内存计算，性能优异
- 支持 Scala、Python、Java、R

**安装内容：**
- ✅ Java 运行环境（JDK 8/11）
- ✅ Spark 核心库
- ✅ Spark SQL 和 DataFrame API
- ✅ Spark Streaming
- ✅ MLlib 机器学习库
- ✅ GraphX 图处理库
- ✅ PySpark（Python 支持）
- ✅ Spark Shell

**使用示例：**

```bash
# 安装
sudo bash install_spark.sh

# 启动 Spark Shell
spark-shell

# 启动 Python 交互环境
pyspark

# 提交批处理作业
spark-submit --class com.example.MyApp \
  --master local[4] \
  --deploy-mode client \
  myapp.jar

# 启动 Standalone 集群
$SPARK_HOME/sbin/start-all.sh

# 停止集群
$SPARK_HOME/sbin/stop-all.sh
```

**常用环境变量：**
```bash
export SPARK_HOME=/opt/spark
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk

# 配置 Hadoop（如果需要）
export HADOOP_CONF_DIR=/etc/hadoop/conf
```

**配置文件位置：**
```
$SPARK_HOME/conf/spark-defaults.conf    # 默认配置
$SPARK_HOME/conf/log4j.properties       # 日志配置
$SPARK_HOME/conf/spark-env.sh           # 环境变量
```

**常用配置参数：**
```properties
# spark-defaults.conf

# 应用程序配置
spark.app.name MyApplication
spark.master local[4]

# 内存配置
spark.driver.memory 2g
spark.executor.memory 4g
spark.executor.cores 4

# 性能配置
spark.sql.shuffle.partitions 200
spark.default.parallelism 32

# 持久化配置
spark.serializer org.apache.spark.serializer.KryoSerializer
spark.kryo.registrationRequired false

# 日志级别
spark.driver.loglevel INFO
spark.executor.loglevel INFO
```

**代码示例（Python）：**

```python
from pyspark.sql import SparkSession

# 创建 Spark Session
spark = SparkSession.builder \
    .appName("MyApp") \
    .master("local[4]") \
    .getOrCreate()

# 读取数据
df = spark.read.csv("data.csv", header=True, inferSchema=True)

# DataFrame 操作
df.select("name", "age").show()
df.filter(df.age > 25).show()
df.groupBy("department").count().show()

# Spark SQL
df.createOrReplaceTempView("people")
spark.sql("SELECT * FROM people WHERE age > 25").show()

# 保存数据
df.write.parquet("output/data.parquet")
df.write.mode("overwrite").parquet("output/data.parquet")
```

**监控和日志：**
```bash
# 查看日志
tail -f $SPARK_HOME/logs/*.log

# 查看 Web UI（Standalone 模式）
# http://localhost:8080

# 查看应用程序 UI（运行时）
# http://localhost:4040
```

---

### install_doris.sh

**用途：** 安装 Apache Doris OLAP 分析数据库

**关于 Doris：**
- 极速分析数据库，专为 OLAP 设计
- 支持 SQL 查询和实时更新
- 行列混合存储
- 高性能、低延迟、易扩展

**安装内容：**
- ✅ Java 运行环境（JDK 8）
- ✅ Doris Frontend（主控节点）
- ✅ Doris Backend（数据节点）
- ✅ MySQL 兼容的 SQL 接口
- ✅ 管理工具和脚本

**使用示例：**

```bash
# 安装
sudo bash install_doris.sh

# 连接到 Doris（使用 MySQL 客户端）
mysql -h localhost -P 9030 -uroot

# 查看集群状态
SHOW FRONTENDS;
SHOW BACKENDS;

# 查看数据库
SHOW DATABASES;

# 创建数据库和表
CREATE DATABASE IF NOT EXISTS my_db;
USE my_db;

CREATE TABLE IF NOT EXISTS users (
    id INT NOT NULL,
    name VARCHAR(255),
    age INT,
    create_time DATETIME
)
ENGINE=OLAP
DUPLICATE KEY(id)
DISTRIBUTED BY HASH(id) BUCKETS 10
PROPERTIES (
    "replication_num" = "1"
);

# 导入数据
INSERT INTO users VALUES (1, 'Alice', 25, now());
INSERT INTO users VALUES (2, 'Bob', 30, now());

# 查询数据
SELECT * FROM users;
SELECT COUNT(*) as cnt FROM users;

# 导出数据
SELECT * FROM users INTO OUTFILE "/tmp/export" FORMAT CSV;
```

**连接方式：**

```bash
# 方式 1：使用 MySQL 命令行
mysql -h localhost -P 9030 -uroot

# 方式 2：使用 Python
import pymysql
conn = pymysql.connect(
    host='localhost',
    port=9030,
    user='root',
    database='my_db'
)
cursor = conn.cursor()
cursor.execute('SELECT * FROM users')
results = cursor.fetchall()
cursor.close()
conn.close()

# 方式 3：使用 JDBC
String url = "jdbc:mysql://localhost:9030/my_db";
String user = "root";
String password = "";
Connection conn = DriverManager.getConnection(url, user, password);
```

**配置文件位置：**
```
$DORIS_HOME/conf/fe.conf              # Frontend 配置
$DORIS_HOME/conf/be.conf              # Backend 配置
$DORIS_HOME/log/                      # 日志目录
```

**常用配置参数：**

```properties
# fe.conf (Frontend)
fe_port = 9010
query_port = 9030
edit_log_port = 9000
http_port = 8030

# be.conf (Backend)
be_port = 9060
webserver_port = 8040
heartbeat_service_port = 9050
```

**监控和日志：**
```bash
# 查看日志
tail -f $DORIS_HOME/log/fe.log
tail -f $DORIS_HOME/log/be.log

# 访问 Web UI
# http://localhost:8030

# 查看集群状态
mysql -h localhost -P 9030 -uroot << 'EOF'
SHOW BACKENDS;
SHOW FRONTENDS;
EOF
```

---

## 🔗 数据管道示例

### Flink → Doris 实时管道

```java
// Flink 作业，实时数据写入 Doris
StreamExecutionEnvironment env =
    StreamExecutionEnvironment.getExecutionEnvironment();

DataStream<String> source = env.readTextFile("hdfs://path/to/data");

source
    .map(line -> parseJson(line))
    .addSink(new DorisStreamLoad(
        "localhost:8030",
        "my_db.users"
    ));

env.execute("Flink to Doris");
```

### Spark → Doris 批处理管道

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("SparkToDoris") \
    .master("local[4]") \
    .getOrCreate()

# 读取数据
df = spark.read.csv("hdfs://path/to/data.csv", header=True)

# 写入 Doris
df.write \
    .format("doris") \
    .option("doris.fenodes", "localhost:8030") \
    .option("doris.table.identifier", "my_db.users") \
    .option("user", "root") \
    .option("password", "") \
    .mode("append") \
    .save()
```

---

## 🐛 故障排查

### Flink 问题

```bash
# 检查 Java 版本
java -version

# 检查端口占用
netstat -tlnp | grep 8081

# 查看集群状态
$FLINK_HOME/bin/flink list

# 重启服务
$FLINK_HOME/bin/stop-cluster.sh
$FLINK_HOME/bin/start-cluster.sh
```

### Spark 问题

```bash
# 检查 Spark 配置
spark-shell --version

# 检查 Python 支持
pyspark

# 查看应用程序日志
grep "ERROR\|WARN" $SPARK_HOME/logs/*.log
```

### Doris 问题

```bash
# 检查连接
mysql -h localhost -P 9030 -uroot -e "SELECT 1"

# 查看集群状态
mysql -h localhost -P 9030 -uroot -e "SHOW BACKENDS"

# 重启服务
$DORIS_HOME/fe/bin/stop_fe.sh
$DORIS_HOME/be/bin/stop_be.sh
$DORIS_HOME/fe/bin/start_fe.sh
$DORIS_HOME/be/bin/start_be.sh
```

---

## 📊 性能优化建议

### Flink 优化
- 调整 `parallelism.default` 匹配 CPU 核心数
- 配置合适的 `taskmanager.memory.process.size`
- 启用 Checkpoint 确保容错性

### Spark 优化
- 增加 `spark.executor.memory` 和 `spark.executor.cores`
- 调整 `spark.sql.shuffle.partitions` 匹配数据量
- 使用 Parquet 或 ORC 格式存储

### Doris 优化
- 根据数据量调整 Bucket 数量
- 使用合适的分区策略
- 启用数据压缩

---

## 📞 常见问题

**Q: 如何扩展 Flink 集群？**
A: 添加新的 TaskManager 节点，修改 `flink-conf.yaml` 并重启。

**Q: Spark 和 Flink 可以共享 Doris 吗？**
A: 可以，Doris 支持多个数据源并发写入。

**Q: 如何导入大量数据到 Doris？**
A: 使用 Spark 批量导入或 Flink 流式导入。

---

**最后更新时间：** 2025年1月21日
