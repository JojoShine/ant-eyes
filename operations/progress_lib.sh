#!/bin/bash

################################################################################
# 进度显示库 (Progress Display Library)
# 为所有安装脚本提供统一的进度显示功能
#
# 用法:
#   source ./progress_lib.sh
#   progress_init "应用名称" "总步数"
#   progress_step "当前步骤描述"
#   progress_complete
#
# 作者: Shell Collections Team
# 版本: 1.0.0
################################################################################

# 进度条颜色定义
PROGRESS_GREEN='\033[0;32m'
PROGRESS_BLUE='\033[0;34m'
PROGRESS_YELLOW='\033[1;33m'
PROGRESS_RED='\033[0;31m'
PROGRESS_CYAN='\033[0;36m'
PROGRESS_NC='\033[0m'

# 进度全局变量
PROGRESS_CURRENT=0
PROGRESS_TOTAL=0
PROGRESS_APP_NAME=""
PROGRESS_START_TIME=0

################################################################################
# 初始化进度显示
# 参数: $1 应用名称, $2 总步数
################################################################################
progress_init() {
    local app_name="$1"
    local total_steps="$2"

    PROGRESS_APP_NAME="$app_name"
    PROGRESS_TOTAL="${total_steps:-1}"
    PROGRESS_CURRENT=0
    PROGRESS_START_TIME=$(date +%s)

    # 显示启动横幅
    echo -e "${PROGRESS_CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    printf "║  %-57s ║\n" "⚙️  $PROGRESS_APP_NAME 安装进程"
    echo "║  总步数: $PROGRESS_TOTAL                                      ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${PROGRESS_NC}"
    echo ""
}

################################################################################
# 显示进度条
# 参数: 无
################################################################################
show_progress_bar() {
    local current="$1"
    local total="$2"
    local percent=$((current * 100 / total))
    local bar_length=40
    local filled=$((percent * bar_length / 100))
    local empty=$((bar_length - filled))

    # 构建进度条
    printf "["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %3d%%" "$percent"
}

################################################################################
# 更新进度到指定步骤
# 参数: $1 步骤数, $2 步骤描述
################################################################################
progress_step() {
    local step_num="$1"
    local step_desc="$2"

    PROGRESS_CURRENT="$step_num"

    # 计算百分比
    local percent=$((PROGRESS_CURRENT * 100 / PROGRESS_TOTAL))

    # 清除上一行（可选，取决于终端）
    echo -ne "\r"

    # 显示进度信息
    echo -e "${PROGRESS_BLUE}[进度]${PROGRESS_NC} 步骤 $PROGRESS_CURRENT/$PROGRESS_TOTAL"
    echo -ne "${PROGRESS_CYAN}"
    show_progress_bar "$PROGRESS_CURRENT" "$PROGRESS_TOTAL"
    echo -e "${PROGRESS_NC}"

    # 显示步骤描述
    if [ -n "$step_desc" ]; then
        echo -e "${PROGRESS_GREEN}✓${PROGRESS_NC} $step_desc"
    fi

    echo ""
}

################################################################################
# 显示当前进度（用于长时间操作）
# 参数: $1 步骤描述
################################################################################
progress_status() {
    local status="$1"
    echo -e "${PROGRESS_CYAN}⟳${PROGRESS_NC} $status"
}

################################################################################
# 显示进度完成
# 参数: 无
################################################################################
progress_complete() {
    local elapsed=$(($(date +%s) - PROGRESS_START_TIME))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))

    echo ""
    echo -e "${PROGRESS_CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                     安装完成! ✓                           ║"
    printf "║  应用: %-48s ║\n" "$PROGRESS_APP_NAME"
    printf "║  耗时: %d分%d秒%-41s ║\n" "$minutes" "$seconds" ""
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${PROGRESS_NC}"
}

################################################################################
# 显示进度失败
# 参数: $1 失败信息
################################################################################
progress_fail() {
    local fail_msg="$1"

    echo ""
    echo -e "${PROGRESS_RED}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                   安装失败! ✗                             ║"
    printf "║  应用: %-48s ║\n" "$PROGRESS_APP_NAME"
    printf "║  错误: %-48s ║\n" "$fail_msg"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${PROGRESS_NC}"
}

################################################################################
# 显示任务列表（初始化时调用）
# 参数: $1 $2 ... 任务名称列表
################################################################################
progress_show_tasks() {
    echo -e "${PROGRESS_BLUE}📋 安装步骤:${PROGRESS_NC}"
    local step=1
    for task in "$@"; do
        printf "   %2d. %s\n" "$step" "$task"
        ((step++))
    done
    echo ""
}

################################################################################
# 简化版进度更新（用于快速步骤）
# 参数: $1 当前步骤数, $2 步骤描述
################################################################################
progress_quick() {
    local current="$1"
    local desc="$2"

    printf "\r${PROGRESS_BLUE}[%2d/%2d]${PROGRESS_NC} %-50s" "$current" "$PROGRESS_TOTAL" "$desc"
}

################################################################################
# 进度更新完成（用于quick版本的结束）
################################################################################
progress_quick_done() {
    echo ""
}

################################################################################
# 显示子任务进度（带缩进）
# 参数: $1 子任务描述
################################################################################
progress_subtask() {
    local subtask="$1"
    echo -e "  ${PROGRESS_YELLOW}→${PROGRESS_NC} $subtask"
}

################################################################################
# 显示进度信息（纯文本）
# 参数: $1 信息内容
################################################################################
progress_info() {
    local info="$1"
    echo -e "${PROGRESS_CYAN}ℹ${PROGRESS_NC} $info"
}

################################################################################
# 显示进度警告
# 参数: $1 警告内容
################################################################################
progress_warning() {
    local warning="$1"
    echo -e "${PROGRESS_YELLOW}⚠${PROGRESS_NC} $warning"
}

################################################################################
# 显示进度错误
# 参数: $1 错误内容
################################################################################
progress_error() {
    local error="$1"
    echo -e "${PROGRESS_RED}✗${PROGRESS_NC} $error"
}

################################################################################
# 显示进度成功
# 参数: $1 成功内容
################################################################################
progress_success() {
    local success="$1"
    echo -e "${PROGRESS_GREEN}✓${PROGRESS_NC} $success"
}
