# ant-eyes

Linux Server Health Check and Operations Management Tool

[简体中文](./README.md) | English

## Overview

ant-eyes is a comprehensive Linux server operations tool set that provides system checking, service management, and operations tools. It supports multiple Linux distributions including CentOS, Ubuntu, Kylin, and UOS.

### Core Features

- System Health Check: CPU, memory, disk, network and other critical information
- Security Audit: SSH login failure detection, brute force attack detection
- Operations Management: Cron jobs, time synchronization, disk management, performance checking
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

Examples:
```bash
ant-eyes manage cron           # Manage cron jobs
ant-eyes manage time           # Manage time sync
ant-eyes manage disk           # Disk partition mounting
ant-eyes manage performance    # Disk performance check
```

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
- UOS (Unified Operating System)

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
├── manage/               # Management module (4 scripts)
│   ├── manage_cron.sh
│   ├── manage_time.sh
│   ├── manage_disk.sh
│   └── manage_performance.sh
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
