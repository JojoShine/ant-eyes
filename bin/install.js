#!/usr/bin/env node

/**
 * @ant-eyes/install CLI 工具
 * 用于快速执行运维安装脚本
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
  redis: 'installation/services/install_redis.sh',
  mysql: 'installation/services/install_mysql.sh',
  postgresql: 'installation/services/install_postgresql.sh',
  postgres: 'installation/services/install_postgresql.sh',
  mongodb: 'installation/services/install_mongodb.sh',
  mongo: 'installation/services/install_mongodb.sh',
  nginx: 'installation/services/install_nginx.sh',
  minio: 'installation/services/install_minio.sh',
  nvm: 'installation/services/install_nvm.sh',
  python: 'installation/services/install_python.sh',
  docker: 'installation/services/install_docker.sh',

  // 工具脚本
  certbot: 'installation/utils/certificate/install_certbot.sh',
  'renew-cert': 'installation/utils/certificate/renew_certificates.sh',
  'manage-cert': 'installation/utils/certificate/manage_certificates.sh',
  spark: 'installation/utils/data_governance/install_spark.sh',
  flink: 'installation/utils/data_governance/install_flink.sh',
  doris: 'installation/utils/data_governance/install_doris.sh',

  // 系统检查工具
  check: 'server_check.sh',
  'server-check': 'server_check.sh',
};

// Docker Compose 映射表
const COMPOSE_MAP = {
  redis: 'installation/docker-compose/redis',
  mysql: 'installation/docker-compose/mysql',
  postgresql: 'installation/docker-compose/postgresql',
  postgres: 'installation/docker-compose/postgresql',
  mongodb: 'installation/docker-compose/mongodb',
  mongo: 'installation/docker-compose/mongodb',
  minio: 'installation/docker-compose/minio',
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
function runScript(scriptPath) {
  return new Promise((resolve, reject) => {
    const fullPath = path.join(getPackageRoot(), scriptPath);

    if (!checkScriptExists(scriptPath)) {
      reject(new Error(`脚本不存在: ${scriptPath}`));
      return;
    }

    logInfo(`执行脚本: ${scriptPath}`);

    const child = spawn('bash', [fullPath], {
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
    'spark', 'flink', 'doris', 'check'
  ];
  utils.forEach(u => log(`  • ${u}`));

  log('\nDocker Compose 配置:', 'green');
  const compose = ['redis', 'mysql', 'postgresql', 'mongodb', 'minio'];
  compose.forEach(c => log(`  • --compose ${c}`));

  log('\n使用示例:', 'yellow');
  log('  npx @ant-eyes/install redis');
  log('  npx @ant-eyes/install redis mysql nginx');
  log('  npx @ant-eyes/install check');
  log('  npx @ant-eyes/install --compose redis\n');
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

// 主函数
async function main() {
  const args = process.argv.slice(2);

  // 检查是否为 Linux 系统
  if (process.platform !== 'linux' && !args.includes('--list')) {
    logWarning('警告: 这些脚本主要为 Linux 系统设计');
    logWarning('当前系统: ' + process.platform);
  }

  // 处理 --list 参数
  if (args.includes('--list') || args.includes('-l')) {
    listServices();
    return;
  }

  // 处理 --help 参数
  if (args.includes('--help') || args.includes('-h') || args.length === 0) {
    log('\n@ant-eyes/install - 运维脚本快速安装工具\n', 'cyan');
    log('用法:', 'green');
    log('  npx @ant-eyes/install <service> [service2] [service3] ...');
    log('  npx @ant-eyes/install --compose <service> [service2] ...');
    log('  npx @ant-eyes/install --list\n');
    log('选项:', 'green');
    log('  --list, -l      列出所有可用服务');
    log('  --compose       使用 Docker Compose 模式');
    log('  --help, -h      显示帮助信息\n');
    listServices();
    return;
  }

  // 处理 --compose 模式
  if (args.includes('--compose')) {
    const composeIndex = args.indexOf('--compose');
    const services = args.slice(composeIndex + 1);

    if (services.length === 0) {
      logError('请指定要使用的 Docker Compose 服务');
      logInfo('示例: npx @ant-eyes/install --compose redis mysql');
      process.exit(1);
    }

    await handleCompose(services);
    return;
  }

  // 处理普通安装模式
  const services = args.filter(arg => !arg.startsWith('--'));

  if (services.length === 0) {
    logError('请指定要安装的服务');
    logInfo('使用 --list 查看所有可用服务');
    process.exit(1);
  }

  // 检查是否需要 root 权限
  if (process.getuid && process.getuid() !== 0) {
    logWarning('警告: 大多数安装脚本需要 root 权限');
    logWarning('建议使用: sudo npx @ant-eyes/install ...');
  }

  // 批量执行脚本
  for (const service of services) {
    const scriptPath = SCRIPT_MAP[service];

    if (!scriptPath) {
      logError(`未知的服务: ${service}`);
      logInfo('使用 --list 查看所有可用服务');
      continue;
    }

    try {
      await runScript(scriptPath);
    } catch (err) {
      logError(err.message);
      process.exit(1);
    }
  }

  logSuccess('\n所有脚本执行完成！');
}

// 运行主函数
main().catch(err => {
  logError(`发生错误: ${err.message}`);
  process.exit(1);
});




