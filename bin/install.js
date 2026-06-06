#!/usr/bin/env node

/**
 * ant-eyes CLI 工具
 * Linux 服务器健康检查和运维管理工具
 * 版本: 2.0.0
 */

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

// 颜色输出
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function logError(message) {
  log(`✗ ${message}`, 'red');
}

function logSuccess(message) {
  log(`✓ ${message}`, 'green');
}

function logInfo(message) {
  log(`ℹ ${message}`, 'blue');
}

function logWarning(message) {
  log(`⚠ ${message}`, 'yellow');
}

// 脚本映射表
const SCRIPT_MAP = {
  // 服务安装脚本
  redis: 'scripts/install/install_redis.sh',
  mysql: 'scripts/install/install_mysql.sh',
  postgresql: 'scripts/install/install_postgresql.sh',
  postgres: 'scripts/install/install_postgresql.sh',
  mongodb: 'scripts/install/install_mongodb.sh',
  mongo: 'scripts/install/install_mongodb.sh',
  nginx: 'scripts/install/install_nginx.sh',
  minio: 'scripts/install/install_minio.sh',
  nvm: 'scripts/install/install_nvm.sh',
  python: 'scripts/install/install_python.sh',
  docker: 'scripts/install/install_docker.sh',

  // 工具脚本 - SSL 证书管理
  certbot: 'scripts/tools/install_certbot.sh',
  'renew-cert': 'scripts/tools/renew_certificates.sh',
  'manage-cert': 'scripts/tools/manage_certificates.sh',

  // 系统检查工具（向后兼容）
  check: 'server_check.sh',
  'server-check': 'server_check.sh',

  // check 模块脚本
  'check-system': 'scripts/check/check_system.sh',
  'check-security': 'scripts/check/check_security.sh',
  'check-components': 'scripts/check/check_components.sh',
  'check-services': 'scripts/check/check_services.sh',
  'check-firewall': 'scripts/check/check_firewall.sh',
  'check-network': 'scripts/check/check_network.sh',

  // manage 模块脚本
  'manage-cron': 'scripts/manage/manage_cron.sh',
  'manage-time': 'scripts/manage/manage_time.sh',
  'manage-disk': 'scripts/manage/manage_disk.sh',
  'manage-performance': 'scripts/manage/manage_performance.sh',
};

// Docker Compose 映射表
const COMPOSE_MAP = {
  redis: 'scripts/compose/redis',
  mysql: 'scripts/compose/mysql',
  postgresql: 'scripts/compose/postgresql',
  postgres: 'scripts/compose/postgresql',
  mongodb: 'scripts/compose/mongodb',
  mongo: 'scripts/compose/mongodb',
  minio: 'scripts/compose/minio',
};

// 获取脚本根目录（npm 包安装位置）
function getPackageRoot() {
  return path.resolve(__dirname, '..');
}

// 检查脚本是否存在
function checkScriptExists(scriptPath) {
  const fullPath = path.join(getPackageRoot(), scriptPath);
  return fs.existsSync(fullPath);
}

// 执行 shell 脚本
function runScript(scriptPath, scriptArgs = []) {
  return new Promise((resolve, reject) => {
    const fullPath = path.join(getPackageRoot(), scriptPath);

    if (!checkScriptExists(scriptPath)) {
      reject(new Error(`脚本不存在: ${scriptPath}`));
      return;
    }

    logInfo(`执行脚本: ${scriptPath}`);

    // 组合所有参数（脚本路径 + 传递的参数）
    const allArgs = [fullPath, ...scriptArgs];

    const child = spawn('bash', allArgs, {
      stdio: 'inherit',
      cwd: process.cwd(),
    });

    child.on('close', (code) => {
      if (code === 0) {
        logSuccess(`脚本执行成功: ${scriptPath}`);
        resolve();
      } else {
        reject(new Error(`脚本执行失败，退出码: ${code}`));
      }
    });

    child.on('error', (err) => {
      reject(new Error(`无法执行脚本: ${err.message}`));
    });
  });
}

// 列出所有可用服务
function listServices() {
  log('\n可用的服务安装脚本:', 'cyan');
  log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'cyan');

  log('\n服务安装:', 'green');
  const services = [
    'redis', 'mysql', 'postgresql', 'mongodb',
    'nginx', 'minio', 'nvm', 'python', 'docker'
  ];
  services.forEach(s => log(`  • ${s}`));

  log('\n工具脚本:', 'green');
  const utils = [
    'certbot', 'renew-cert', 'manage-cert',
    'spark', 'flink', 'doris', 'check',
    'monitor', 'monitor-config'
  ];
  utils.forEach(u => log(`  • ${u}`));

  log('\nDocker Compose 配置:', 'green');
  const compose = ['redis', 'mysql', 'postgresql', 'mongodb', 'minio'];
  compose.forEach(c => log(`  • --compose ${c}`));

  log('\n使用示例:', 'yellow');
  log('  ant-eyes install redis');
  log('  ant-eyes install redis mysql nginx');
  log('  ant-eyes check');
  log('  ant-eyes install --compose redis\n');
}

// 显示主帮助信息
function showMainHelp() {
  log('\n╔══════════════════════════════════════════╗', 'cyan');
  log('║     ant-eyes - Linux 运维管理工具 v2.0   ║', 'cyan');
  log('╚══════════════════════════════════════════╝\n', 'cyan');

  log('用法: ant-eyes <command> [options]\n', 'green');

  log('命令:', 'cyan');
  log('  check       系统健康检查（6大模块）');
  log('  install     安装服务（Redis/MySQL/Nginx等）');
  log('  manage      运维管理（定时任务/磁盘/时间等）\n');

  log('全局选项:', 'cyan');
  log('  -v, --verbose   详细输出');
  log('  -q, --quiet     安静模式');
  log('  --version       显示版本');
  log('  -h, --help      显示帮助');
  log('  -l, --list      列出所有可用服务\n');

  log('示例:', 'yellow');
  log('  ant-eyes check                    # 系统检查');
  log('  ant-eyes install redis            # 安装 Redis');
  log('  ant-eyes install redis mysql      # 批量安装');
  log('  ant-eyes check --system -q        # 系统信息(安静模式)');
  log('  ant-eyes --help                   # 查看帮助\n');

  log('提示:', 'blue');
  log('  • 大多数命令需要 root 权限，请使用 sudo');
  log('  • 使用 ant-eyes <command> --help 查看子命令帮助\n');
}

// 显示 check 帮助
function showCheckHelp() {
  log('\n用法: ant-eyes check [options]\n', 'green');

  log('描述:', 'cyan');
  log('  系统健康检查工具，提供6大检查模块\n');

  log('选项:', 'cyan');
  log('  --full          完整检查（所有模块）');
  log('  --system        系统信息检查');
  log('  --security      安全审计');
  log('  --components    组件运行状态');
  log('  --services      服务部署信息');
  log('  --firewall      防火墙安全检查');
  log('  --network       网络诊断\n');

  log('全局选项:', 'cyan');
  log('  -v, --verbose   详细输出');
  log('  -q, --quiet     安静模式（仅输出必要信息）\n');

  log('示例:', 'yellow');
  log('  ant-eyes check              # 交互式菜单');
  log('  ant-eyes check --full       # 完整检查');
  log('  ant-eyes check --system     # 系统信息');
  log('  ant-eyes check --system -q  # 系统信息(安静模式)\n');
}

// 显示 install 帮助
function showInstallHelp() {
  log('\n用法: ant-eyes install <service> [services...] [options]\n', 'green');
  
  log('描述:', 'cyan');
  log('  安装各种服务和工具\n');
  
  log('选项:', 'cyan');
  log('  --compose       使用 Docker Compose 模式');
  log('  --list, -l      列出所有可用服务\n');
  
  log('示例:', 'yellow');
  log('  ant-eyes install redis                # 安装 Redis');
  log('  ant-eyes install mysql nginx          # 批量安装');
  log('  ant-eyes install --compose redis      # Docker Compose 模式');
  log('  ant-eyes install --list               # 查看服务列表\n');
}

// 显示 manage 帮助
function showManageHelp() {
  log('\n用法: ant-eyes manage <subcommand> [options]\n', 'green');

  log('描述:', 'cyan');
  log('  运维管理工具集\n');

  log('子命令:', 'cyan');
  log('  cron          定时任务管理');
  log('  disk          磁盘分区管理');
  log('  time          时间同步管理');
  log('  performance   磁盘 I/O 性能检查\n');

  log('全局选项:', 'cyan');
  log('  -v, --verbose   详细输出');
  log('  -q, --quiet     安静模式\n');

  log('示例:', 'yellow');
  log('  ant-eyes manage cron          # 管理定时任务');
  log('  ant-eyes manage disk          # 磁盘分区挂载');
  log('  ant-eyes manage time          # NTP 时间同步');
  log('  ant-eyes manage performance   # 磁盘性能检查');
  log('  ant-eyes manage cron -q       # 定时任务(安静模式)\n');
}

// 处理 Docker Compose 模式
async function handleCompose(services) {
  logInfo('Docker Compose 模式');

  for (const service of services) {
    const composeDir = COMPOSE_MAP[service];
    if (!composeDir) {
      logError(`不支持的 Docker Compose 服务: ${service}`);
      continue;
    }

    const sourcePath = path.join(getPackageRoot(), composeDir);
    const targetPath = path.join(process.cwd(), path.basename(composeDir));

    if (!fs.existsSync(sourcePath)) {
      logError(`Docker Compose 配置不存在: ${composeDir}`);
      continue;
    }

    // 复制目录
    try {
      fs.cpSync(sourcePath, targetPath, { recursive: true });
      logSuccess(`已复制 Docker Compose 配置到: ${targetPath}`);
      logInfo(`请进入目录并执行: cd ${path.basename(composeDir)} && docker compose up -d`);
    } catch (err) {
      logError(`复制失败: ${err.message}`);
    }
  }
}

// 主函数 - 支持子命令结构
async function main() {
  const args = process.argv.slice(2);

  // 检查是否为 Linux 系统
  if (process.platform !== 'linux' && !args.includes('--list') && !args.includes('-l')) {
    logWarning('警告: 这些脚本主要为 Linux 系统设计');
    logWarning('当前系统: ' + process.platform);
  }

  // 如果没有参数，显示帮助
  if (args.length === 0) {
    showMainHelp();
    return;
  }

  // 提取全局选项 (--verbose, --quiet)
  const globalArgs = [];
  const filteredArgs = args.filter(arg => {
    if (arg === '--verbose' || arg === '-v' && args.length > 1) {
      globalArgs.push('-v');
      return false;
    } else if (arg === '--quiet' || arg === '-q') {
      globalArgs.push('-q');
      return false;
    }
    return true;
  });

  // 获取第一个参数作为子命令
  const subCommand = filteredArgs[0];
  const subArgs = filteredArgs.slice(1).concat(globalArgs);

  // 处理全局参数（在任何位置）
  if (filteredArgs.includes('--help') || filteredArgs.includes('-h')) {
    if (subCommand === 'check') {
      showCheckHelp();
    } else if (subCommand === 'install') {
      showInstallHelp();
    } else if (subCommand === 'manage') {
      showManageHelp();
    } else {
      showMainHelp();
    }
    return;
  }

  if (filteredArgs.includes('--list') || filteredArgs.includes('-l')) {
    listServices();
    return;
  }

  if (filteredArgs.includes('--version') || (filteredArgs.includes('-v') && !globalArgs.includes('-v'))) {
    const pkg = require('../package.json');
    log(`\nant-eyes v${pkg.version}\n`, 'cyan');
    return;
  }

  // 子命令路由
  switch (subCommand) {
    case 'check':
      await handleCheck(subArgs);
      break;
    case 'install':
      await handleInstall(subArgs);
      break;
    case 'manage':
      await handleManage(subArgs);
      break;
    // 向后兼容：直接调用旧命令
    case 'redis':
    case 'mysql':
    case 'postgresql':
    case 'postgres':
    case 'mongodb':
    case 'mongo':
    case 'nginx':
    case 'minio':
    case 'nvm':
    case 'python':
    case 'docker':
    case 'certbot':
    case 'renew-cert':
    case 'manage-cert':
      // 向后兼容：直接执行脚本
      await runScript(SCRIPT_MAP[subCommand], globalArgs);
      break;
    default:
      // 尝试作为服务名处理（向后兼容）
      if (SCRIPT_MAP[subCommand]) {
        await runScript(SCRIPT_MAP[subCommand], globalArgs);
      } else {
        logError(`未知命令: ${subCommand}`);
        logInfo('使用 ant-eyes --help 查看可用命令');
        process.exit(1);
      }
  }
}

// 处理 check 子命令
async function handleCheck(args) {
  // 分离全局选项和检查选项
  const globalArgs = args.filter(arg => arg === '-v' || arg === '-q');
  const checkArgs = args.filter(arg => arg !== '-v' && arg !== '-q');

  if (checkArgs.length === 0) {
    // 默认运行交互式检查
    await runScript(SCRIPT_MAP.check, globalArgs);
    return;
  }

  // 支持参数化检查 - 映射到新的拆解脚本
  try {
    if (checkArgs.includes('--system')) {
      await runScript(SCRIPT_MAP['check-system'], globalArgs);
    } else if (checkArgs.includes('--security')) {
      await runScript(SCRIPT_MAP['check-security'], globalArgs);
    } else if (checkArgs.includes('--components')) {
      await runScript(SCRIPT_MAP['check-components'], globalArgs);
    } else if (checkArgs.includes('--services')) {
      await runScript(SCRIPT_MAP['check-services'], globalArgs);
    } else if (checkArgs.includes('--firewall')) {
      await runScript(SCRIPT_MAP['check-firewall'], globalArgs);
    } else if (checkArgs.includes('--network')) {
      await runScript(SCRIPT_MAP['check-network'], globalArgs);
    } else if (checkArgs.includes('--full')) {
      // 执行所有检查
      logInfo('执行完整系统检查...');
      const checkScripts = [
        SCRIPT_MAP['check-system'],
        SCRIPT_MAP['check-security'],
        SCRIPT_MAP['check-components'],
        SCRIPT_MAP['check-services'],
        SCRIPT_MAP['check-firewall'],
        SCRIPT_MAP['check-network']
      ];

      for (const script of checkScripts) {
        await runScript(script, globalArgs);
      }
    } else {
      // 默认运行交互式检查
      await runScript(SCRIPT_MAP.check, globalArgs);
    }
  } catch (err) {
    logError(err.message);
    process.exit(1);
  }
}

// 处理 install 子命令
async function handleInstall(args) {
  // 分离全局选项
  const globalArgs = args.filter(arg => arg === '-v' || arg === '-q');
  const installArgs = args.filter(arg => arg !== '-v' && arg !== '-q');

  if (installArgs.length === 0) {
    logError('请指定要安装的服务');
    logInfo('示例: ant-eyes install redis mysql nginx');
    logInfo('使用 ant-eyes install --list 查看所有可用服务');
    process.exit(1);
  }

  // 处理 --compose 模式
  if (installArgs.includes('--compose')) {
    const composeIndex = installArgs.indexOf('--compose');
    const services = installArgs.slice(composeIndex + 1);

    if (services.length === 0) {
      logError('请指定要使用的 Docker Compose 服务');
      logInfo('示例: ant-eyes install --compose redis mysql');
      process.exit(1);
    }

    await handleCompose(services);
    return;
  }

  // 处理 --list
  if (installArgs.includes('--list') || installArgs.includes('-l')) {
    listServices();
    return;
  }

  // 过滤出服务名
  const services = installArgs.filter(arg => !arg.startsWith('--'));

  if (services.length === 0) {
    logError('请指定要安装的服务');
    process.exit(1);
  }

  // 检查 root 权限
  if (process.getuid && process.getuid() !== 0) {
    logWarning('警告: 大多数安装脚本需要 root 权限');
    logWarning('建议使用: sudo ant-eyes install ...');
  }

  // 批量执行脚本
  for (const service of services) {
    const scriptPath = SCRIPT_MAP[service];

    if (!scriptPath) {
      logError(`未知的服务: ${service}`);
      logInfo('使用 ant-eyes install --list 查看所有可用服务');
      continue;
    }

    try {
      await runScript(scriptPath, globalArgs);
    } catch (err) {
      logError(err.message);
      process.exit(1);
    }
  }

  logSuccess('\n所有脚本执行完成！');
}

// 处理 manage 子命令
async function handleManage(args) {
  // 分离全局选项
  const globalArgs = args.filter(arg => arg === '-v' || arg === '-q');
  const manageArgs = args.filter(arg => arg !== '-v' && arg !== '-q');

  if (manageArgs.length === 0) {
    showManageHelp();
    return;
  }

  const subCmd = manageArgs[0];

  try {
    switch (subCmd) {
      case 'cron':
        await runScript(SCRIPT_MAP['manage-cron'], globalArgs);
        break;
      case 'disk':
        await runScript(SCRIPT_MAP['manage-disk'], globalArgs);
        break;
      case 'time':
        await runScript(SCRIPT_MAP['manage-time'], globalArgs);
        break;
      case 'performance':
        await runScript(SCRIPT_MAP['manage-performance'], globalArgs);
        break;
      case 'cert':
        logInfo('证书管理功能开发中...');
        break;
      default:
        logError(`未知管理命令: ${subCmd}`);
        showManageHelp();
    }
  } catch (err) {
    logError(err.message);
    process.exit(1);
  }
}

// 运行主函数
main().catch(err => {
  logError(`发生错误: ${err.message}`);
  process.exit(1);
});




