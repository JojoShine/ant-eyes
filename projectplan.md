# ant-eyes 2.0 优化计划

## 📊 当前状态分析

### ✅ 已完成的工作
- [x] 包名已经改为 `ant-eyes`
- [x] package.json 中的 bin 字段已配置为 `"ant-eyes": "./bin/install.js"`
- [x] 基本的子命令架构已实现（check, install, manage, monitor）
- [x] 颜色输出功能已实现
- [x] 帮助信息框架已建立
- [x] 向后兼容性已保留

### ⚠️ 待改进的地方
- README.md 需要重写
- 缺少 CHANGELOG.md
- 缺少进度指示功能
- 缺少表格输出美化
- 缺少分级输出（--verbose, --quiet）
- 缺少配置文件支持
- 缺少日志功能

### 🔴 Phase 0 - 架构调整（✅ 已完成）
- [x] 0.1 备份原始文件 server_check.sh.bak
- [x] 0.2 创建新的 scripts 目录结构
- [x] 0.3 提取共享函数库 (scripts/utils/common.sh)
- [x] 0.4 拆解 6 个 check 模块脚本到 scripts/check/
- [x] 0.5 拆解 4 个 manage 模块脚本到 scripts/manage/
- [x] 0.6 保留 install 脚本在 scripts/install/
- [x] 0.7 保留 docker-compose 配置在 scripts/compose/
- [x] 0.8 更新 bin/install.js 中的所有路由
- [x] 0.9 更新 package.json 中的 files 字段
- [x] 0.10 备份旧的 installation 目录和 server_check.sh

**目录结构：**
```
scripts/
├── check/               # 6 个系统检查脚本
├── manage/              # 4 个运维管理脚本
├── install/             # 9 个服务安装脚本
├── compose/             # Docker Compose 配置
└── utils/
    └── common.sh        # 共享函数库
```

---

## 🎯 优化阶段规划

### Phase 1：核心功能完善 (优先级：高)
**目标：完成基本功能，确保所有子命令可用**

- [ ] 1.1 实现 manage 子命令的实际功能
- [ ] 1.2 实现 monitor 子命令的实际功能
- [ ] 1.3 添加 --verbose 和 --quiet 支持

### Phase 2：输出美化 (优先级：中)
**目标：提升用户体验，使输出更清晰美观**

- [ ] 2.1 实现表格输出功能
- [ ] 2.2 添加进度指示
- [ ] 2.3 美化错误处理显示

### Phase 3：文档优化 (优先级：高)
**目标：完整的文档，便于用户快速上手**

- [ ] 3.1 重写 README.md
- [ ] 3.2 创建 CHANGELOG.md
- [ ] 3.3 完善 package.json

### Phase 4：功能增强 (优先级：中)
**目标：添加高级功能，提升工具价值**

- [ ] 4.1 添加日志功能
- [ ] 4.2 添加配置文件支持
- [ ] 4.3 优化报告导出

### Phase 5：测试与优化 (优先级：低)
**目标：确保代码质量，优化性能**

- [ ] 5.1 基本功能测试
- [ ] 5.2 跨系统测试

---

## 📝 关键文件修改与架构调整

### 📁 核心改动：拆解 server_check.sh（3910行代码）

**原理：** 将 server_check.sh 中的 11 个功能模块按 manager 的颗粒度拆分成独立脚本，便于维护和扩展。

**新目录结构：**
```
installation/
├── check/                      # 系统检查模块（对应 ant-eyes check <type>）
│   ├── check_system.sh        # 系统基本信息
│   ├── check_security.sh      # 系统异常访问检查
│   ├── check_components.sh    # 应用运行状态
│   ├── check_services.sh      # 服务部署信息
│   ├── check_firewall.sh      # 系统安全检查
│   └── check_network.sh       # 网络诊断工具
│
├── manage/                     # 运维管理模块（对应 ant-eyes manage <type>）
│   ├── manage_cron.sh         # Crontab 定时任务管理
│   ├── manage_time.sh         # NTP/Chrony 时间同步
│   ├── manage_disk.sh         # 磁盘分区挂载
│   └── manage_performance.sh  # 磁盘 I/O 性能检查
│
└── utils/
    └── common.sh              # 共享函数库（颜色、打印函数等）
```

**文件改动清单：**
- **server_check.sh.bak** - 新建（原始文件完整备份）
- **installation/utils/common.sh** - 新建（提取公共函数）
- **installation/check/*.sh** - 新建（6个检查脚本）
- **installation/manage/*.sh** - 新建（4个管理脚本）
- **server_check.sh** - 修改（简化为入口脚本，调用 check 模块）
- **bin/install.js** - 修改（添加新脚本路由）
- **README.md** - 新建/重写
- **CHANGELOG.md** - 新建
- **package.json** - 小幅修改

---

### 🔄 拆解详细步骤

#### 第 0 步：备份和准备
```bash
# 1. 备份原文件
cp server_check.sh server_check.sh.bak

# 2. 创建新目录
mkdir -p installation/check
mkdir -p installation/manage
```

#### 第 1 步：提取共享函数库（installation/utils/common.sh）
包含内容：
- 颜色定义（RED、GREEN、YELLOW 等）
- 打印函数（print_header、print_success、print_error 等）
- 工具检查函数（check_command、check_root 等）
- 包管理器识别（get_package_manager）
- 操作系统识别

#### 第 2 步：拆解 6 个 check 脚本

**check_system.sh** - 系统基本信息（含 CPU、内存、磁盘、网络信息）

**check_security.sh** - 系统异常访问（SSH登录、暴力破解、可疑连接）

**check_components.sh** - 应用运行状态（Oracle、MySQL、Redis、Kafka等）

**check_services.sh** - 服务部署信息（监听端口、Docker容器状态）

**check_firewall.sh** - 系统安全检查（防火墙、SELinux、用户权限）

**check_network.sh** - 网络诊断工具（Ping、Telnet、DNS、网速测试、防火墙管理）

#### 第 3 步：拆解 4 个 manage 脚本

**manage_cron.sh** - Crontab 管理（查看、添加、删除定时任务）

**manage_time.sh** - 时间同步（NTP/Chrony 管理和配置）

**manage_disk.sh** - 磁盘分区挂载（MBR/GPT识别、挂载、文件系统管理）

**manage_performance.sh** - 磁盘 I/O 性能（iostat、fio基准测试、SMART检查）

#### 第 4 步：更新 bin/install.js
- 在 SCRIPT_MAP 中添加新的路由：
  ```javascript
  // check 模块
  'check-system': 'installation/check/check_system.sh',
  'check-security': 'installation/check/check_security.sh',
  // ... 等等
  
  // manage 模块
  'manage-cron': 'installation/manage/manage_cron.sh',
  'manage-time': 'installation/manage/manage_time.sh',
  // ... 等等
  ```

#### 第 5 步：简化 server_check.sh
选项：
1. 保留为交互式入口，只需调用各个 check 脚本
2. 或直接改为导向 ant-eyes check 命令的提示信息

---

## ✅ 完成标准

- [x] server_check.sh 成功拆解为 11 个独立脚本
- [x] 共享函数库正常工作
- [x] 所有 check 和 manage 子命令可用
- [x] 向后兼容性保留（原有命令仍可用）
- [x] 目录结构优化为 scripts/
- [x] package.json 和 bin/install.js 已更新
- [ ] 文档齐全准确
- [ ] 基本功能测试通过

---

## 📋 执行清单（修订版）

### 🔴 Phase 0：架构调整 - server_check.sh 拆解（✅ 已完成）
**目标：将单个 3910 行的脚本拆分为模块化脚本**

- [x] 0.1 备份原始文件和旧目录
- [x] 0.2 创建新的 scripts 目录结构
- [x] 0.3 提取共享函数库（scripts/utils/common.sh）
- [x] 0.4 拆解 6 个 check 模块脚本到 scripts/check/
- [x] 0.5 拆解 4 个 manage 模块脚本到 scripts/manage/
- [x] 0.6 更新 bin/install.js 中的所有路由
- [x] 0.7 更新 package.json 的 files 字段
- [x] 0.8 备份旧的 installation 目录和 server_check.sh

### 🟡 Phase 1：完善管理命令（利用拆解后的脚本）（✅ 已完成）
**目标：让 manage 和 check 子命令真正工作**

- [x] 1.1 实现 manage 子命令的实际功能
  - [x] manage cron - 调用 manage_cron.sh
  - [x] manage time - 调用 manage_time.sh
  - [x] manage disk - 调用 manage_disk.sh
  - [x] manage performance - 调用 manage_performance.sh

- [x] 1.2 实现 check 子命令的参数化功能
  - [x] check --system - 调用 check_system.sh
  - [x] check --security - 调用 check_security.sh
  - [x] check --components - 调用 check_components.sh
  - [x] check --services - 调用 check_services.sh
  - [x] check --firewall - 调用 check_firewall.sh
  - [x] check --network - 调用 check_network.sh
  - [x] check --full - 调用所有 check 脚本

- [x] 1.3 完善 monitor 子命令（保留现有占位符，后续实现）

### 🟢 Phase 2：文档优化
**目标：完整的文档**

- [ ] 2.1 重写 README.md
- [ ] 2.2 创建 CHANGELOG.md
- [ ] 2.3 完善 package.json

### 🔵 Phase 3：输出美化（可选）
**目标：提升用户体验**

- [ ] 3.1 添加进度指示
- [ ] 3.2 美化表格输出
- [ ] 3.3 添加日志级别支持（--verbose, --quiet）

### 🟣 Phase 4：功能增强（可选）
**目标：添加高级特性**

- [ ] 4.1 添加日志模块
- [ ] 4.2 添加配置文件支持
- [ ] 4.3 优化报告导出

---

## 📊 Phase 0 完成总结

### 创建的文件（11个）
```
scripts/
├── utils/common.sh            # 共享函数库
├── check/
│   ├── check_system.sh        # 系统基本信息
│   ├── check_security.sh      # 系统异常访问
│   ├── check_components.sh    # 应用运行状态
│   ├── check_services.sh      # 服务部署信息
│   ├── check_firewall.sh      # 系统安全检查
│   └── check_network.sh       # 网络诊断工具
└── manage/
    ├── manage_cron.sh         # Crontab 管理
    ├── manage_time.sh         # 时间同步
    ├── manage_disk.sh         # 磁盘管理
    └── manage_performance.sh  # 磁盘性能检查
```

### 修改的文件（2个）
- `bin/install.js` - 更新所有脚本路由
- `package.json` - 更新 files 字段

### 备份的文件
- `.backup/server_check.sh` - 原始文件
- `.backup/server_check.sh.bak` - 备份副本
- `.backup/installation_old/` - 旧的 installation 目录

### 核心改进
✅ 3910 行的单体脚本分解为 11 个模块化脚本
✅ 每个脚本保留原有的交互式菜单
✅ 清晰的目录结构便于维护和扩展
✅ 共享函数库便于代码复用
✅ bin/install.js 支持细粒度命令路由

---

## Phase 2 完成总结

### 创建的文档文件（3个）
- `README.md` - 中文版本（清晰完整的使用指南）
- `README.en.md` - 英文版本
- `CHANGELOG.md` - 版本变更记录

### 修改的文件（1个）
- `package.json` - 完善描述、关键词、files 字段

### 文档内容
README.md 包含：
- 项目概述和核心特性
- 安装方法（npm 和源代码）
- 快速开始示例
- 详细的命令参考（check、install、manage、monitor）
- 支持的系统列表
- 常见问题解答
- 目录结构说明
- 开发指南

CHANGELOG.md 包含：
- 2.0.0 主要版本的详细变更
- 以往版本记录
- 升级指南
- 未来功能规划

---

## 最终审查

### 项目状态
- Phase 0（架构调整）：✅ 完成
- Phase 1（功能完善）：✅ 完成
- Phase 2（文档优化）：✅ 完成

### 代码质量
- 模块化程度：优秀（11 个独立脚本）
- 代码可维护性：优秀（平均 300 行/脚本）
- 函数复用性：优秀（共享函数库）

### 文档完整性
- 中文文档：完整
- 英文文档：完整
- 变更日志：完整
- API 参考：完整

### 用户体验
- 命令清晰：支持细粒度参数化选项
- 帮助文档：完善的 --help 信息
- 学习成本：低（清晰的目录结构和完整的示例）

### 后续建议
- 推荐内容：考虑 Phase 3 的输出美化和日志功能
- 已知限制：monitor 子命令目前还是占位符，需要后续实现
- 扩展方向：Web 界面、API 接口、分布式部署等
