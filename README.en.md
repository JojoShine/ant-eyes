# ant-eyes

Linux Server Health Check and Operations Management Tool

[简体中文](./README.md) | English

## Overview

ant-eyes is a comprehensive Linux server operations tool set that provides system checking, service management, and operations tools. It supports multiple Linux distributions including CentOS, Ubuntu, Kylin, and UOS.

### Core Features

- System Health Check: CPU, memory, disk, network and other critical information
- Security Audit: SSH login failure detection, brute force attack detection
- Operations Management: Cron jobs, time synchronization, disk management, firewall management, performance checking
- Quick Deployment: One-command installation of Redis, MySQL, PostgreSQL, Nginx, Docker, etc.
- Interactive Menu: Simple and user-friendly command-line interface
- Modular Design: Clear functional divisions for easy extension

## Installation

### Using npm

```bash
npm install -g ant-eyes
```

### From Source Code

```bash
git clone https://github.com/JojoShine/ant-eyes.git
cd ant-eyes
npm install -g .
```

## Quick Start

### System Check

```bash
# System basic information (CPU, memory, disk, network)
ant-eyes check --system

# Security audit (SSH login failure, brute force detection)
ant-eyes check --security

# Service deployment information (listening ports, Docker containers, system services)
ant-eyes check --services

# Firewall and security check (firewall status, SELinux, SUID files)
ant-eyes check --firewall

# Network diagnostic tools (interfaces, DNS, gateway, connection statistics)
ant-eyes check --network

# Full check (execute all the above checks)
ant-eyes check --full
```

### Service Installation

```bash
# Install Redis
ant-eyes install redis

# Batch installation
ant-eyes install redis mysql nginx

# List available services
ant-eyes install --list

# Using Docker Compose
ant-eyes install --compose redis
```

### Operations Management

```bash
# Cron job management
ant-eyes manage cron

# Time synchronization
ant-eyes manage time

# Disk management
ant-eyes manage disk

# Disk performance check
ant-eyes manage performance

# Firewall management
ant-eyes manage firewall
```

## Command Reference

### check - System Check

Usage: `ant-eyes check [options]`

Options:
- `--system` - Basic system information (CPU, memory, disk, network)
- `--security` - System anomaly access check (SSH login, brute force)
- `--services` - System service deployment information
- `--firewall` - System security check
- `--network` - Network diagnostic tools
- `--full` - Full check (all modules)

Examples:
```bash
ant-eyes check --system        # Check system information
ant-eyes check --security      # Check security status
ant-eyes check --full          # Full check
```

### install - Service Installation

Usage: `ant-eyes install <service> [services...] [options]`

Available Services:
- `redis` - Redis cache database
- `mysql` - MySQL database
- `postgresql` - PostgreSQL database
- `mongodb` - MongoDB document database
- `nginx` - Nginx web server
- `minio` - MinIO object storage
- `nvm` - Node.js version manager
- `python` - Python environment
- `docker` - Docker container engine

Options:
- `--compose` - Deploy using Docker Compose
- `--list, -l` - List all available services

Examples:
```bash
ant-eyes install redis         # Install Redis
ant-eyes install mysql nginx   # Batch installation
ant-eyes install --compose redis  # Install using Docker Compose
ant-eyes install --list        # View service list
```

### manage - Operations Management

Usage: `ant-eyes manage <subcommand> [options]`

Subcommands:
- `cron` - Crontab job management
- `time` - NTP/Chrony time synchronization
- `disk` - Disk partition management
- `performance` - Disk I/O performance check
- `firewall` - Firewall management (port opening, rich rules)

Examples:
```bash
ant-eyes manage cron           # Manage cron jobs
ant-eyes manage time           # Manage time sync
ant-eyes manage disk           # Disk partition mounting
ant-eyes manage performance    # Disk performance check
ant-eyes manage firewall       # Firewall management
```

#### manage cron - Cron Job Management

Interactive menu supporting the following operations:
1. **View cron jobs** - Display all scheduled tasks
2. **Add new cron job** - Supports common templates or custom
   - Daily backup (2 AM)
   - Weekly cleanup (Sunday 3 AM)
   - Monthly check (1st at midnight)
   - Hourly execution
   - Custom frequency
3. **Delete cron job** - Remove tasks by number
4. **Edit cron jobs** - Modify crontab using editor
5. **View templates** - Check predefined task templates

**Usage flow:**
```bash
ant-eyes manage cron
# Select operation by number in the menu
# 0 - Exit
```

#### manage time - Time Synchronization Management

Interactive menu supporting the following operations:
1. **View time sync status** - Check NTP/Chrony service status
2. **Configure NTP servers** - Modify NTP server list
3. **Manually adjust system time** - Set system time
4. **View sync guide** - Learn about NTP configuration

**Usage flow:**
```bash
ant-eyes manage time
# Select operation by number in the menu
# 0 - Exit
```

#### manage disk - Disk Partition Management

**Interactive complete disk management tool with 9 menu options:**

1. **View disk and partition info** - Display all disk partitions
2. **View partition type (MBR/GPT)** - Auto-detect partition table type
3. **Create new partition** - Support fdisk/gdisk
   - Auto-detect whether to use fdisk (MBR) or gdisk (GPT)
   - Optional to launch partition tool immediately
4. **Format partition** - Support multiple filesystems
   - ext4 (recommended)
   - xfs (high performance)
   - btrfs (next-gen)
   - ntfs (Windows)
   - exfat (portable)
   - vfat (FAT32)
5. **Mount partition** - Temporarily mount partition
6. **Unmount partition** - Unmount mounted partitions
7. **Create mount point** - Create new mount directory
8. **Configure auto-mount** - Edit /etc/fstab for auto-start
9. **View mount guide** - Complete operation guide

**Execution order guide for three scenarios:**

**Scenario 1️⃣: New unpartitioned disk (complete flow)**
```bash
ant-eyes manage disk
# Step 1: Menu option 1 - View disk info
#         Purpose: Find new disk (e.g., /dev/sdb)
#
# Step 2: Menu option 2 - View partition type
#         Purpose: Detect partition table type (create if missing)
#
# Step 3: Menu option 3 - Create new partition
#         Purpose: Use fdisk/gdisk to partition disk
#         Select disk → Choose to launch tool
#         If launched: n create partition → set size → w save
#
# Step 4: Menu option 1 - View disk info (optional)
#         Purpose: Verify partition created (e.g., /dev/sdb1)
#
# Step 5: Menu option 4 - Format partition
#         Purpose: Choose filesystem (recommend ext4)
#         Confirm partition → Input device name to confirm
#
# Step 6: Menu option 5 - Mount partition
#         Purpose: Temporarily mount to directory (e.g., /mnt/data)
#
# Step 7: Menu option 8 - Configure auto-mount
#         Purpose: Edit /etc/fstab for permanent mounting
#
# Done: 0 - Exit
```

**Scenario 2️⃣: New partitioned but unformatted disk (skip step 3)**
```bash
ant-eyes manage disk
# Step 1: Menu option 1 - View disk info
# Step 5: Menu option 4 - Format partition
# Step 6: Menu option 5 - Mount partition
# Step 7: Menu option 8 - Configure auto-mount
# Done: 0 - Exit
```

**Scenario 3️⃣: Partition exists, only needs mounting (skip steps 3, 4)**
```bash
ant-eyes manage disk
# Step 1: Menu option 1 - View disk info (verify partition)
# Step 6: Menu option 5 - Mount partition
# Step 7: Menu option 8 - Configure auto-mount
# Done: 0 - Exit
```

**⚠️ Critical reminder - Correct execution order:**

1. **Must format before mounting** - Don't reverse order
   - ❌ Wrong: Mount unformatted partition first
   - ✅ Correct: Format → Mount → Configure auto-mount

2. **Step 5 (Format) critical operation:**
   - Select partition to format (e.g., /dev/sdb1)
   - Choose filesystem type
   - **Confirm warning**: Input device name (e.g., sdb1) to confirm
   - This confirmation prevents accidental operations

3. **Step 6 (Mount) may need step 7 (Create mount point) first:**
   - If mount point doesn't exist, run option 7 first
   - Then return to menu and run option 5

4. **Menu option 2 "View partition type" flashes quickly:**
   - This is normal, detection completes and returns to menu
   - Information displays on screen, may need quick viewing

**Important notes:**
- All operations require root permissions (use sudo)
- Creating and formatting partitions are **irreversible**, causes data loss
- Before formatting, confirm you selected the **correct partition**
- Operations **don't exit immediately**, can continue other tasks (select 0 to exit)

#### manage firewall - Firewall Management

**Interactive firewall management tool, supporting both firewalld and ufw engines:**

1. **View Firewall Status** - Display open ports, allowed services, rich rules
2. **Open Port** - Support single port/port range, tcp/udp protocol selection
   - Optional permanent (`--permanent`) or runtime-only
   - Auto-detect if port is already open
   - Display common port service name reference
3. **Close Port** - Interactive selection to close, sync cleanup of permanent rules
4. **Rich Rule Management** - Interactive advanced firewall rule builder
   - Allow/reject specific IP access to port
   - Allow/reject specific IP range (CIDR) access to port
   - Port forwarding
   - Rate limiting (brute force prevention)
   - Manual custom rich rule input
   - Built-in rich rule syntax documentation
5. **Service Management** - Add/remove firewalld services (http, ssh, mysql, etc.)
6. **Reload Rules** - One-click firewall rule reload

**Usage flow:**
```bash
ant-eyes manage firewall
# Select operation by number in the menu
# 0 - Exit
```

**Important notes:**
- Auto-detects firewall type (firewalld / ufw) and provides corresponding management interface
- firewalld supports full features (ports, rich rules, service management)
- ufw supports port open/close and rule viewing
- Port opening allows choosing permanent or temporary effect
- All operations require root permissions

#### manage performance - Disk I/O Performance Check

**Interactive disk performance diagnostic tool with 4 menu options:**

1. **iostat Real-time I/O Monitoring** - View current disk I/O performance
   - Collect 3 samples (2-second intervals)
   - Display throughput, IOPS, etc. for each disk
   - Auto-installs sysstat tool if needed

2. **fio Disk Performance Benchmark** - Test maximum disk performance
   - Sequential read test (128K blocks)
   - Sequential write test (128K blocks)
   - Random read test (4K blocks)
   - Random write test (4K blocks)
   - Mixed read/write test
   - Auto-installs fio tool if needed

3. **Disk SMART Health Check** - Check disk hardware health
   - Display disk temperature
   - Check SMART attributes
   - Predict disk lifespan
   - Auto-installs smartctl tool if needed

4. **I/O Summary Report** - System I/O load analysis
   - Display disk utilization
   - Analyze current I/O pressure
   - Provide performance optimization suggestions

**Usage flow:**
```bash
ant-eyes manage performance
# Option 1: Run iostat monitoring
# Option 2: Run fio benchmark
# Option 3: Run SMART check
# Option 4: View summary report
# 0 - Exit
```

**Important notes:**
- All tools auto-install, no manual configuration needed
- fio benchmark may take time depending on disk performance
- Recommend running tests when system is idle
- Won't exit immediately after operations, can continue with other tasks

### tools - Tools and Utilities

Usage: `ant-eyes <tool> [options]`

Available Tools:
- `certbot` - Install and configure Certbot (Let's Encrypt client)
- `renew-cert` - Update and renew SSL certificates
- `manage-cert` - Manage SSL certificates

Examples:
```bash
ant-eyes certbot              # Install Certbot
ant-eyes renew-cert           # Renew certificates
ant-eyes manage-cert          # Manage certificates
```

## Supported Systems

- CentOS 7.x, 8.x
- Ubuntu 18.04, 20.04, 22.04
- Kylin
- UOS (Uniontech UOS)

## FAQ

### Q: Do I need root permissions?

A: Most features require root privileges to get complete information. It's recommended to use `sudo`:
```bash
sudo ant-eyes check --full
```

### Q: How to view help?

A: Use the `--help` option:
```bash
ant-eyes --help              # Show main help
ant-eyes check --help        # Show check help
ant-eyes install --help      # Show install help
```

### Q: Can I install multiple services at once?

A: Yes. Specify multiple services in a single command:
```bash
ant-eyes install redis mysql nginx
```

### Q: How to use Docker Compose for installation?

A: Use the `--compose` option:
```bash
ant-eyes install --compose redis
```
This will copy Docker Compose configuration files to the current directory, then you can run `docker-compose up -d` to start the services.

### Q: How to uninstall?

A: Use npm to uninstall:
```bash
npm uninstall -g ant-eyes
```

## Directory Structure

```
scripts/
├── check/                # Check module (5 scripts)
│   ├── check_system.sh
│   ├── check_security.sh
│   ├── check_services.sh
│   ├── check_firewall.sh
│   └── check_network.sh
├── manage/               # Management module (5 scripts)
│   ├── manage_cron.sh
│   ├── manage_time.sh
│   ├── manage_disk.sh
│   ├── manage_performance.sh
│   └── manage_firewall.sh
├── install/              # Installation module (9 scripts)
│   ├── install_redis.sh
│   ├── install_mysql.sh
│   ├── install_postgresql.sh
│   ├── install_mongodb.sh
│   ├── install_nginx.sh
│   ├── install_minio.sh
│   ├── install_nvm.sh
│   ├── install_python.sh
│   └── install_docker.sh
├── tools/                # Tools module (3 scripts)
│   ├── install_certbot.sh
│   ├── renew_certificates.sh
│   └── manage_certificates.sh
├── compose/              # Docker Compose configuration
│   ├── redis/
│   ├── mysql/
│   ├── postgresql/
│   ├── mongodb/
│   └── minio/
└── utils/
    └── common.sh         # Shared function library
```

## Development

### Project Structure

This project adopts a modular design where each feature is an independent script file.

### Adding a New Check Module

1. Create a new script in `scripts/check/` directory
2. Load the shared function library: `source "$SCRIPT_DIR/../utils/common.sh"`
3. Use existing print functions: `print_header`, `print_info`, etc.
4. Add route in `bin/install.js`

### Adding a New Management Module

1. Create a new script in `scripts/manage/` directory
2. Follow the same template and naming conventions
3. Maintain consistent interactive menu style

## License

MIT License

## Contributing

Pull requests and issues are welcome!

## Contact

For questions or suggestions, please submit a GitHub issue.
