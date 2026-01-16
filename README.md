# Shell Collections v2.5 - Unified Installation Framework

Automated installation and repair scripts for enterprise Linux systems (CentOS/RHEL, Ubuntu, Kylin, UOS).

## What's New in v2.5 (Unified Edition)

🎯 **Major Update**: Installation and repair functionality are now unified into single scripts!

### Highlights
- ✅ **Single Scripts with Triple Functionality**: Each installation script now includes repair and auto-config modes
- ✅ **Built-in Fix Functionality**: No more separate fix_*.sh scripts needed
- ✅ **Auto-Memory Detection**: Intelligent system resource detection and configuration
- ✅ **Multiple Operational Modes**: Fresh install, repair existing, or auto-configure
- ✅ **Consistent Interface**: Same usage patterns across all services

### Command Examples
```bash
# Mode 1: Fresh Installation
sudo bash install_flink.sh

# Mode 2: Repair Existing Installation
sudo bash install_flink.sh --fix-only

# Mode 3: Auto-Configuration
sudo bash install_flink.sh --auto-config
```

All three modes available for: Flink, Spark, Doris, and many other services.

---

## Quick Reference

| Service | Installation | Repair | Auto-Config |
|---------|-------------|--------|-------------|
| Flink | `bash install_flink.sh` | `bash install_flink.sh --fix-only` | `bash install_flink.sh --auto-config` |
| Spark | `bash install_spark.sh` | `bash install_spark.sh --fix-only` | `bash install_spark.sh --auto-config` |
| Doris | `bash install_doris.sh` | `bash install_doris.sh --fix-only` | `bash install_doris.sh --auto-config` |

---

## Unified Installation Scripts

### Big Data & Analytics
- **install_flink.sh** - Apache Flink v1.18.1 (Local/Cluster mode)
- **install_spark.sh** - Apache Spark v3.4.1 (Standalone/Cluster mode)
- **install_doris.sh** - Apache Doris v2.0.1 (Single-node/Cluster mode)

### Databases
- **install_postgresql.sh** - PostgreSQL with optional PostGIS
- **install_mysql.sh** - MySQL/MariaDB with optimized configurations
- **install_mongodb.sh** - MongoDB with replica sets support
- **install_redis.sh** - Redis with persistence and replication

### Message Queues & Caching
- **install_rabbitmq.sh** - RabbitMQ with cluster support
- **install_minio.sh** - MinIO object storage (S3-compatible)

### Infrastructure
- **install_docker.sh** - Docker Engine with optimized settings
- **install_docker_kylin.sh** - Docker for Kylin Linux systems
- **install_nginx.sh** - Nginx web server with common modules
- **install_certbot.sh** - Certbot for SSL certificate management

### Utilities
- **server_check.sh** - Comprehensive system health check
- **app_manager.sh** - Unified application lifecycle management

---

## Installation Modes Explained

### Mode 1: Fresh Installation (Default)
```bash
sudo bash install_flink.sh
```
**Use when**: Installing on a clean system

**What it does**:
- Detects OS and system resources
- Installs Java if needed
- Prompts for deployment preferences
- Downloads and configures the service
- Creates systemd service
- Generates installation report

### Mode 2: Repair Existing Installation (--fix-only)
```bash
sudo bash install_flink.sh --fix-only
```
**Use when**: Service is already installed but startup fails

**What it does**:
- Detects system memory automatically
- Regenerates configuration with proper settings
- Backs up original configuration
- Restarts the service
- Verifies operation

**No interactive prompts** - fully automatic!

### Mode 3: Auto-Configuration (--auto-config)
```bash
sudo bash install_flink.sh --auto-config
```
**Use when**: You want automatic detection and repair

**What it does**:
- Detects OS and resources
- Assumes service is already installed
- Auto-repairs configuration
- Restarts services
- Similar to --fix-only but with OS detection

---

## Common Use Cases

### Scenario 1: Flink Fails to Start with Memory Error
```bash
# Error message might be:
# [ERROR] java.lang.OutOfMemoryError
# [ERROR] jobmanager.memory.process.size not configured

# Solution:
sudo bash install_flink.sh --fix-only

# The script will:
# 1. Detect your system's total memory
# 2. Calculate optimal JobManager and TaskManager memory
# 3. Update flink-conf.yaml
# 4. Restart Flink with new configuration
```

### Scenario 2: Spark Performance Issues
```bash
# Spark is running but using suboptimal memory settings
sudo bash install_spark.sh --fix-only

# The script will:
# 1. Auto-detect system memory
# 2. Regenerate spark-defaults.conf
# 3. Configure driver and executor memory
# 4. Restart Spark service
```

### Scenario 3: Doris FE/BE Startup Fails
```bash
# Both FE and BE components configured incorrectly
sudo bash install_doris.sh --fix-only

# The script will:
# 1. Auto-detect system memory
# 2. Fix both fe.conf and be.conf
# 3. Set appropriate memory limits
# 4. Restart both services
```

---

## Memory Configuration

Each script automatically calculates optimal memory based on total system RAM:

### Flink (v1.18.1)
- **JobManager**: `total_memory / 4` (min 512m)
- **TaskManager**: `total_memory / 2` (min 1024m)
- Example: 16GB system → JM: 4GB, TM: 8GB

### Spark (v3.4.1)
- **Driver**: `total_memory / 4` (min 512m)
- **Executor**: `total_memory / 2` (min 1024m)
- Example: 8GB system → Driver: 2GB, Executor: 4GB

### Doris (v2.0.1)
- **FE**: 512m minimum (fixed)
- **BE**: `total_memory / 2` (min 1024m)
- Example: 32GB system → FE: 512m, BE: 16GB

---

## Configuration Backup & Recovery

All scripts automatically backup original configurations:

```bash
# Backups are timestamped
/opt/flink/conf/flink-conf.yaml.backup.20240112_143022
/opt/spark/conf/spark-defaults.conf.backup.20240112_143022
/opt/doris/fe/conf/fe.conf.backup.20240112_143022

# To restore from backup
cp /opt/flink/conf/flink-conf.yaml.backup.20240112_143022 \
   /opt/flink/conf/flink-conf.yaml
```

---

## Supported Operating Systems

| OS Family | Versions | Package Manager |
|-----------|----------|-----------------|
| CentOS/RHEL | 7, 8, 9+ | yum/dnf |
| Ubuntu/Debian | 18.04, 20.04, 22.04+ | apt |
| Kylin Linux | 10+ | yum/apt |
| UOS | All versions | yum/apt |

---

## System Requirements

### Minimum
- **CPU**: 2 cores
- **RAM**: 4GB (8GB+ recommended)
- **Disk**: 10GB free space
- **Network**: Internet access for package downloads

### Recommended
- **CPU**: 8+ cores
- **RAM**: 32GB+
- **Disk**: SSD with 100GB+ space
- **Network**: Dedicated network interface (cluster mode)

---

## Usage Examples

### Flink Installation
```bash
# Fresh installation with interactive prompts
sudo bash install_flink.sh

# Repair existing Flink installation automatically
sudo bash install_flink.sh --fix-only

# Auto-detect and repair
sudo bash install_flink.sh --auto-config
```

### Check Flink Status
```bash
# Service status
systemctl status flink

# View logs
tail -f /opt/flink/logs/flink-*.log

# Web UI
http://your_ip:8081/
```

### Spark Installation
```bash
# Fresh installation
sudo bash install_spark.sh

# Quick repair for memory issues
sudo bash install_spark.sh --fix-only
```

### Doris Installation
```bash
# Fresh installation (single-node or cluster)
sudo bash install_doris.sh

# Fix startup issues for both FE and BE
sudo bash install_doris.sh --fix-only

# Access Doris
mysql -h 127.0.0.1 -P 9030 -u root
```

---

## Advanced Features

### Multi-Node Cluster Setup

**Flink Cluster**:
```bash
# On JobManager node
sudo bash install_flink.sh

# On TaskManager nodes
sudo bash install_flink.sh --auto-config
# Then manually configure workers file
```

**Spark Cluster**:
```bash
# On Master node
sudo bash install_spark.sh
# Select: Cluster mode, Master role

# On Worker nodes
sudo bash install_spark.sh --auto-config
# Then update slaves configuration
```

**Doris Cluster**:
```bash
# On FE nodes
sudo bash install_doris.sh

# On BE nodes
sudo bash install_doris.sh
# Select: Cluster mode, BE role, provide FE IP
```

### Performance Tuning

After installation, optimize via configuration files:

**Flink**:
```yaml
# Edit /opt/flink/conf/flink-conf.yaml
taskmanager.numberOfTaskSlots: 8
parallelism.default: 16
state.backend: rocksdb  # For production
```

**Spark**:
```properties
# Edit /opt/spark/conf/spark-defaults.conf
spark.executor.cores: 4
spark.default.parallelism: 32
spark.sql.shuffle.partitions: 200
```

**Doris**:
```conf
# Edit /opt/doris/be/conf/be.conf
max_query_cache_mem: 314572800
be_service_threads: 64
```

---

## Troubleshooting

### Service Fails to Start

1. Check service status:
   ```bash
   systemctl status flink
   journalctl -u flink -n 50
   ```

2. View application logs:
   ```bash
   tail -f /opt/flink/logs/flink-*.log
   ```

3. Use repair mode:
   ```bash
   sudo bash install_flink.sh --fix-only
   ```

### Memory-Related Errors

```bash
# Common error:
# [ERROR] jobmanager.memory.process.size not configured

# Fix:
sudo bash install_flink.sh --fix-only
```

### Port Conflicts

```bash
# Check which process uses port 8081
lsof -i :8081

# Either:
# 1. Stop the conflicting service
# 2. Change port in configuration
# 3. Run repair mode (may resolve auto-configuration issues)
```

---

## File Structure

```
shell_collections/
├── operations/
│   ├── install_flink.sh
│   ├── install_spark.sh
│   ├── install_doris.sh
│   ├── install_*.sh (other services)
│   ├── dependencies_lib.sh
│   ├── dependencies_config.sh
│   ├── app_manager.sh
│   ├── progress_lib.sh
│   └── ...
├── server_check.sh
├── UNIFIED_INSTALLATION_GUIDE.md
└── README.md (this file)
```

---

## Key Improvements in v2.5

| Feature | v2.4 | v2.5 |
|---------|------|------|
| Fix Scripts | Separate files | **Built-in** |
| Auto-Memory | Manual calc | **Auto-detect** |
| Command Modes | Single mode | **Three modes** |
| Config Backups | Optional | **Automatic** |
| Error Recovery | Manual | **Automatic repair** |

---

## Documentation

- **UNIFIED_INSTALLATION_GUIDE.md** - Comprehensive guide for all three modes
- **README.md** - This file, quick reference

---

## Version Info

- **Current Version**: 2.5 (Unified Edition)
- **Last Updated**: January 2024
- **Repository**: Shell Collections

---

## Quick Links

- [Unified Installation Guide](./UNIFIED_INSTALLATION_GUIDE.md)
- [Flink Documentation](https://nightlies.apache.org/flink/flink-docs-stable/)
- [Spark Documentation](https://spark.apache.org/docs/latest/)
- [Doris Documentation](https://doris.apache.org/zh-CN/docs/)

---

## License & Support

Community-supported shell script collection for enterprise Linux systems.

For issues or questions:
1. Check logs: `/opt/service_name/logs/`
2. Review configuration: `/opt/service_name/conf/`
3. Run repair mode: `sudo bash install_service.sh --fix-only`

---

*Shell Collections v2.5 - Making big data deployment simple and reliable*
