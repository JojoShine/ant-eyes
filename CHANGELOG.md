# Changelog

所有对 ant-eyes 项目的重要变更都记录在此文件中。

## 格式约定

本文档遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/) 规范。

- Added - 新增功能
- Changed - 功能变更
- Deprecated - 废弃功能
- Removed - 移除功能
- Fixed - 修复的 Bug
- Security - 安全相关修复

---

## [2.0.0] - 2026-06-06

### Major Release: 架构重构和功能优化

#### Added
- 创建 `scripts/` 新目录结构，清晰分类功能模块
- 拆解原 `server_check.sh`（3910 行）为 11 个模块化脚本
  - 6 个检查模块（check_system, check_security, check_components, check_services, check_firewall, check_network）
  - 4 个管理模块（manage_cron, manage_time, manage_disk, manage_performance）
  - 1 个共享函数库（common.sh）
- 添加 `--system`、`--security` 等参数化选项支持 check 子命令
- 添加 `manage performance` 子命令用于磁盘性能检查
- 创建共享函数库，统一管理颜色定义和打印函数
- 创建英文版本 README（README.en.md）
- 创建 CHANGELOG 记录版本变更

#### Changed
- 重构目录结构：`installation/` → `scripts/`
  - `installation/services/` → `scripts/install/`
  - `installation/docker-compose/` → `scripts/compose/`
  - `installation/utils/certificate/` → `scripts/tools/`
  - 新建 `scripts/check/` 和 `scripts/manage/`
- 更新 `bin/install.js` 中所有脚本路由指向新目录
- 更新 `package.json` 的 `files` 字段，只包含必要的目录
- 简化并重写 README.md 和 README.en.md，更清晰的使用说明
- 移除大数据工具（spark、flink、doris）的相关代码

#### Removed
- 备份原 `server_check.sh` 和旧的 `installation/` 目录到 `.backup/`

#### Improved
- 代码可维护性：从单个 3910 行脚本分解为平均 300 行的模块脚本
- 项目结构清晰性：按功能模块分类，易于理解和扩展
- 代码复用性：提取公共函数到 `scripts/utils/common.sh`
- 文档完整性：添加英文版本和变更日志

---

## [1.2.1] - 2026-01-04

### Fixed
- 优化 server_check.sh 交互体验
- 修复 DNS 配置管理中的部分问题

### Added
- 新增 DNS 配置管理功能

---

## [1.2.0] - 2025-12-15

### Changed
- PostgreSQL 改为源码编译安装 18.2
- 所有数据库数据目录迁移到 `/data`

### Added
- 添加防火墙配置管理

---

## [1.1.0] - 2025-11-20

### Added
- 新增监控预警功能

---

## [1.0.6] - 2025-10-30

### Fixed
- 修复 NVM 安装兼容性问题

---

## [1.0.5] - 2025-09-15

### Fixed
- 修复 NVM 国内安装说明

---

## [1.0.4] 及更早版本

基础功能实现和持续优化。

---

## 版本升级指南

### 从 1.x 升级到 2.0.0

1. 卸载旧版本：
   ```bash
   npm uninstall -g ant-eyes
   ```

2. 安装新版本：
   ```bash
   npm install -g ant-eyes
   ```

3. 验证安装：
   ```bash
   ant-eyes --version
   ```

### 命令变更

不支持的旧命令已被新命令替代。大多数功能通过新的参数化选项仍然可用：

- `ant-eyes check --system` - 系统信息检查（原 check）
- `ant-eyes check --security` - 安全检查
- `ant-eyes manage cron` - Crontab 管理
- `ant-eyes manage time` - 时间同步
- `ant-eyes manage disk` - 磁盘管理
- `ant-eyes manage performance` - 磁盘性能检查

---

## 计划中的功能 (Roadmap)

### 2.1.0（计划中）

- 添加日志模块和日志轮转
- 支持配置文件自定义
- 添加进度指示和等待动画
- 优化表格输出格式

### 2.2.0（计划中）

- 实现完整的 monitor 子命令
- 添加报告导出功能（JSON、HTML、PDF）
- 实现 --verbose 和 --quiet 日志级别

### 3.0.0（远期规划）

- 图形化 Web 界面
- API 接口支持
- 分布式部署支持
- 多服务器统一管理

---

## 反馈和建议

如有功能建议或问题反馈，请在 GitHub 上提交 Issue。
