# 贡献指南

感谢你对 ant-eyes 项目的关注！我们欢迎任何形式的贡献，包括 bug 报告、功能建议、代码改进等。

## 如何贡献

### 报告 Bug

如果发现了 bug，请在 [GitHub Issues](https://github.com/JojoShine/ant-eyes/issues) 中创建一个新 issue，并包含以下信息：

- 清晰的 bug 描述
- 复现步骤
- 当前行为与预期行为
- 系统环境信息（OS、Node.js 版本等）
- 相关日志或错误信息

### 提出功能建议

欢迎提出新功能建议，请在 [GitHub Issues](https://github.com/JojoShine/ant-eyes/issues) 中创建一个新 issue，并说明：

- 功能的目的和用途
- 预期的使用场景
- 可能的实现方式

### 提交代码

1. **Fork** 项目仓库
2. 创建你的功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交你的更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开一个 Pull Request

#### 代码风格要求

- Bash 脚本：遵循现有的代码风格
- JavaScript：遵循现有的代码风格
- 提交信息：清晰、简洁，说明改动的目的

#### 测试要求

在提交 PR 之前，请确保：

- 新增功能已经在相应的 Linux 发行版上测试过
- 现有功能仍然正常工作
- 脚本没有语法错误

### 文档改进

文档改进也是很重要的贡献：

- 修正拼写错误或语法错误
- 改进文档的清晰度
- 添加缺失的文档内容
- 提供更好的示例

## 项目结构

```
ant-eyes/
├── bin/                 # CLI 入口
├── scripts/
│   ├── check/          # 系统检查模块（6个脚本）
│   ├── manage/         # 运维管理模块（4个脚本）
│   ├── install/        # 服务安装模块（9个脚本）
│   ├── tools/          # 工具模块（3个脚本）
│   ├── compose/        # Docker Compose 配置
│   └── utils/          # 共享函数库
├── package.json        # npm 包定义
├── README.md           # 中文文档
├── README.en.md        # 英文文档
├── CHANGELOG.md        # 变更日志
└── LICENSE             # MIT 协议
```

## 开发流程

### 安装开发环境

```bash
git clone https://github.com/JojoShine/ant-eyes.git
cd ant-eyes
npm install
```

### 测试脚本

```bash
# 查看帮助
ant-eyes --help

# 运行系统检查
ant-eyes check --system

# 完整检查（需要 sudo）
sudo ant-eyes check --full
```

### 修改后的测试

修改脚本后，建议：

```bash
# 语法检查
bash -n scripts/check/check_system.sh

# 运行脚本
bash scripts/check/check_system.sh -q
```

## 版本管理

- 使用 [Semantic Versioning](https://semver.org/lang/zh-CN/) 进行版本管理
- 主版本号：不兼容的 API 改动
- 次版本号：新增功能（向下兼容）
- 修订版本号：bug 修复

## 行为准则

- 尊重他人，有建设性的讨论
- 避免人身攻击或骚扰
- 报告不当行为到项目维护者

## 许可证

通过提交代码，你同意将代码贡献在 MIT 许可证下。

## 联系方式

- 📧 GitHub Issues: [ant-eyes Issues](https://github.com/JojoShine/ant-eyes/issues)
- 📍 GitHub Discussions: [ant-eyes Discussions](https://github.com/JojoShine/ant-eyes/discussions)

感谢你的贡献！🎉
