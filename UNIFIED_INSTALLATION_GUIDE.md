# Shell Collections v2.5 - Unified Installation Guide

## Overview

This guide describes the unified installation and repair scripts for Apache big data platforms (Flink, Spark, Doris, and others). Each installation script now includes built-in repair functionality, eliminating the need for separate fix scripts.

---

## Quick Start

### Installation Modes

Each unified script supports three operational modes:

```bash
# Mode 1: Fresh Installation (Default)
sudo bash install_flink.sh
sudo bash install_spark.sh
sudo bash install_doris.sh

# Mode 2: Repair Existing Installation
sudo bash install_flink.sh --fix-only
sudo bash install_spark.sh --fix-only
sudo bash install_doris.sh --fix-only

# Mode 3: Auto-Configuration (Detect & Repair)
sudo bash install_flink.sh --auto-config
sudo bash install_spark.sh --auto-config
sudo bash install_doris.sh --auto-config
```

---

## Detailed Usage

### Apache Flink (v1.18.1)

#### Mode 1: Fresh Installation
```bash
sudo bash install_flink.sh
```
- Prompts for deployment mode: Local or Cluster
- Configures TaskManager slots and memory
- Detects/installs Java environment
- Sets up systemd service
- Generates configuration report

#### Mode 2: Repair Existing Installation (--fix-only)
```bash
sudo bash install_flink.sh --fix-only
```
- **Requirements**: Flink must already be installed at `/opt/flink`
- Auto-detects system memory
- Generates proper `flink-conf.yaml` with required memory settings
- **Key Fix**: Adds `jobmanager.memory.process.size` and `taskmanager.memory.process.size` (required for Flink 1.18+)
- Backs up original configuration with timestamp
- Restarts the service
- No interactive prompts

#### Mode 3: Auto-Configuration (--auto-config)
```bash
sudo bash install_flink.sh --auto-config
```
- Assumes Flink is already installed at `/opt/flink`
- Detects OS and system resources
- Auto-repairs configuration
- Starts services and verifies operation

#### Memory Configuration
- **JobManager**: Total System Memory ÷ 4 (minimum 512m)
- **TaskManager**: Total System Memory ÷ 2 (minimum 1024m)
- Example: On 16GB system → JM: 4GB, TM: 8GB

#### Troubleshooting Flink
If Flink fails to start with memory errors:
```bash
# View logs for details
tail -f /opt/flink/logs/flink-*.log

# Repair configuration
sudo bash install_flink.sh --fix-only

# Check status
systemctl status flink
```

---

### Apache Spark (v3.4.1)

#### Mode 1: Fresh Installation
```bash
sudo bash install_spark.sh
```
- Prompts for deployment mode: Standalone or Cluster
- Selects Master or Worker node (cluster mode)
- Configures memory and executor cores
- Creates spark-defaults.conf and spark-env.sh
- Enables systemd service with auto-restart

#### Mode 2: Repair Existing Installation (--fix-only)
```bash
sudo bash install_spark.sh --fix-only
```
- **Requirements**: Spark must be installed at `/opt/spark`
- Auto-detects system memory
- Regenerates `spark-defaults.conf` with proper memory settings
- **Key Fix**: Configures `spark.driver.memory` and `spark.executor.memory`
- Backs up configuration and restarts service
- Verifies Master/Worker processes

#### Mode 3: Auto-Configuration
```bash
sudo bash install_spark.sh --auto-config
```
- Auto-repairs Spark configuration
- Restarts service automatically

#### Memory Configuration
- **Driver**: Total System Memory ÷ 4 (minimum 512m)
- **Executor**: Total System Memory ÷ 2 (minimum 1024m)
- Example: On 8GB system → Driver: 2GB, Executor: 4GB

#### Troubleshooting Spark
```bash
# View logs
tail -f /opt/spark/logs/spark-*.log

# Repair configuration
sudo bash install_spark.sh --fix-only

# Check cluster status
systemctl status spark
```

---

### Apache Doris (v2.0.1)

#### Mode 1: Fresh Installation
```bash
sudo bash install_doris.sh
```
- Selects deployment: Single-node or Cluster
- Chooses node type: FE (Frontend), BE (Backend), or Observer
- Configures database credentials
- Auto-detects/installs Java
- Sets up both FE and BE services
- Generates installation report

#### Mode 2: Repair Existing Installation (--fix-only)
```bash
sudo bash install_doris.sh --fix-only
```
- **Requirements**: Doris must be installed at `/opt/doris`
- Auto-detects system memory
- Regenerates both `fe.conf` and `be.conf` with proper memory settings
- **Key Fix**:
  - FE: Sets `JAVA_OPTS = -Xms512m -Xmx512m`
  - BE: Configures `mem_limit` based on system memory
- Backs up original configs and restarts services
- Verifies FE/BE process status

#### Mode 3: Auto-Configuration
```bash
sudo bash install_doris.sh --auto-config
```
- Auto-detects and repairs both FE and BE configurations
- Restarts all Doris services

#### Memory Configuration
- **FE**: 512m (fixed minimum) to 2GB typical
- **BE**: Total System Memory ÷ 2 (minimum 1024m)
- Example: 32GB system → FE: 512m, BE: 16GB

#### Troubleshooting Doris
```bash
# View FE logs
tail -f /opt/doris/fe/log/*.log

# View BE logs
tail -f /opt/doris/be/log/*.log

# Repair both components
sudo bash install_doris.sh --fix-only

# Check service status
systemctl status doris-fe
systemctl status doris-be
```

---

## Unified Features

### Common Features Across All Scripts

1. **Root Privilege Check**: All scripts require `sudo`
2. **OS Detection**: Supports CentOS/RHEL 7+, Ubuntu 18.04+, Kylin, UOS
3. **Automatic Memory Tuning**: Detects system resources and generates optimal configs
4. **Configuration Backup**: Original configs backed up with timestamps before modification
5. **Service Management**: Uses systemd for reliable service control
6. **Process Verification**: Checks for running processes after startup
7. **Color-Coded Output**: Easy-to-read status messages (INFO/SUCCESS/WARN/ERROR)

### Backup and Recovery

All scripts create timestamped backups:
```bash
# Flink backup example
/opt/flink/conf/flink-conf.yaml.backup.20240112_143022

# Spark backup example
/opt/spark/conf/spark-defaults.conf.backup.20240112_143022

# Doris backup example
/opt/doris/fe/conf/fe.conf.backup.20240112_143022
```

### System Resource Detection

Each script automatically:
1. Reads total system memory: `free -m`
2. Calculates optimal allocation based on platform requirements
3. Applies minimum thresholds to ensure viability
4. Reports detected resources to user

Example:
```
[INFO] 系统总内存: 16384MB
[INFO] 建议 JobManager 内存: 4096m
[INFO] 建议 TaskManager 内存: 8192m
```

---

## Common Issues and Solutions

### Issue: "[ERROR] Service startup failed"

**Diagnosis**:
```bash
systemctl status service_name
journalctl -u service_name -n 50
tail -f /opt/service_name/logs/*.log
```

**Solution**:
```bash
# Run repair mode
sudo bash install_service.sh --fix-only
```

### Issue: "Memory configuration errors"

**Cause**: Flink 1.18+ and newer Spark/Doris versions require explicit memory configuration

**Solution**:
```bash
# Automatic fix via repair mode
sudo bash install_service.sh --fix-only
```

### Issue: "Permission denied on config files"

**Cause**: Configuration files have incorrect ownership or permissions

**Solution**:
```bash
# Scripts automatically fix permissions, but manual fix:
sudo chown flink:flink /opt/flink/conf/flink-conf.yaml
sudo chmod 644 /opt/flink/conf/flink-conf.yaml
```

### Issue: "Port already in use"

**Diagnosis**:
```bash
lsof -i :8081  # Check specific port (Flink)
netstat -tulpn | grep 8080  # Check Spark Master port
```

**Solution**:
- Modify ports in configuration files
- Or stop other services using the ports

---

## Service Management

### Check Service Status
```bash
systemctl status flink     # or spark, doris-fe, doris-be
```

### Start Service
```bash
systemctl start flink
```

### Stop Service
```bash
systemctl stop flink
```

### View Logs
```bash
# Flink
tail -f /opt/flink/logs/flink-*.log

# Spark
tail -f /opt/spark/logs/spark-*.log

# Doris FE
tail -f /opt/doris/fe/log/*.log

# Doris BE
tail -f /opt/doris/be/log/*.log
```

### Enable Auto-Start on Boot
```bash
systemctl enable flink
```

---

## Performance Tuning

### Flink Performance
```yaml
# In flink-conf.yaml
taskmanager.numberOfTaskSlots: 4  # Adjust based on CPU cores
parallelism.default: 4
state.backend: filesystem  # Use rocksdb for production
```

### Spark Performance
```properties
# In spark-defaults.conf
spark.executor.cores: 2
spark.default.parallelism: 4
spark.shuffle.partitions: 200  # For large datasets
```

### Doris Performance
```conf
# In be.conf
max_query_cache_mem: 314572800
default_query_timeout: 300
```

---

## Docker Support

For Docker-based deployments, use:
- `install_docker.sh` - Install Docker engine
- `install_docker_kylin.sh` - Docker for Kylin Linux

---

## Additional Resources

- **Flink Docs**: https://nightlies.apache.org/flink/flink-docs-stable/
- **Spark Docs**: https://spark.apache.org/docs/latest/
- **Doris Docs**: https://doris.apache.org/zh-CN/docs/

---

## Version History

### v2.5 (Current - Unified)
- **New**: Merged install and fix functionality into single scripts
- **New**: `--fix-only` mode for repairing existing installations
- **New**: `--auto-config` mode for automatic configuration detection and repair
- **Improved**: Auto-detection of system memory for optimal configuration
- **Improved**: Consistent behavior across all three scripts
- **Removed**: Separate fix_flink_config.sh, fix_spark_config.sh, fix_doris_config.sh scripts

### v2.4
- Added separate fix scripts for configuration problems
- Improved memory configuration handling

### v2.0+
- Initial unified installation framework

---

## Support and Troubleshooting

For detailed logs, check:
- Installation logs: Generated after each run
- System logs: `journalctl -u service_name`
- Application logs: `/opt/service_name/logs/`

To report issues:
1. Collect logs and system info
2. Include command used (with --fix-only or --auto-config if applicable)
3. Attach configuration files

---

*Last Updated: January 2024*
*Shell Collections v2.5 - Unified Installation Framework*