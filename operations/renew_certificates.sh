#!/bin/bash

################################################################################
# Let's Encrypt 证书强制续期脚本
# 用于手动或自动续期所有证书，并重新加载相关服务
# 功能:
#   - 手动触发所有证书续期
#   - 只续期即将过期的证书 (默认)
#   - 强制续期所有证书 (测试用)
#   - 自动重新加载 Nginx/Apache/其他服务
#   - 记录续期日志
#   - 发送邮件通知 (可选)
#
# 使用方法:
#   bash renew_certificates.sh [选项]
#   选项:
#     --all          续期所有证书
#     --force        强制续期 (用于测试)
#     --dry-run      测试续期流程
#     --mail EMAIL   续期后发送邮件通知
#
# 作者: Shell Collections Team
# 版本: 1.0.0
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置
CERTBOT_HOME="/etc/letsencrypt"
LOG_DIR="/var/log/certbot-renewal"
LOG_FILE="$LOG_DIR/renewal_$(date +%Y%m%d_%H%M%S).log"
RENEW_ALL=false
FORCE_RENEW=false
DRY_RUN=false
NOTIFY_EMAIL=""

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }

# 打印标题
print_header() {
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║    Let's Encrypt 证书续期脚本 v1.0.0                     ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 初始化日志
init_log() {
    mkdir -p "$LOG_DIR"
    chmod 755 "$LOG_DIR"

    {
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║       Let's Encrypt 证书续期日志                         ║"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo ""
        echo "续期时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "日志文件: $LOG_FILE"
        echo ""
    } >> "$LOG_FILE"
}

# 检查是否安装了 Certbot
check_certbot() {
    if ! command -v certbot &> /dev/null; then
        log_error "Certbot 未安装"
        exit 1
    fi

    log_success "检测到 Certbot"
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                RENEW_ALL=true
                log_info "选择: 续期所有证书"
                shift
                ;;
            --force)
                FORCE_RENEW=true
                log_info "选择: 强制续期"
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                log_info "选择: 测试续期流程"
                shift
                ;;
            --mail)
                NOTIFY_EMAIL="$2"
                log_info "将发送邮件通知到: $NOTIFY_EMAIL"
                shift 2
                ;;
            *)
                log_warn "未知参数: $1"
                shift
                ;;
        esac
    done
}

# 续期证书
renew_certificates() {
    log_info "开始续期证书..."
    echo ""

    local certbot_cmd="certbot renew"

    # 构建 Certbot 命令
    if [[ "$DRY_RUN" == "true" ]]; then
        certbot_cmd="$certbot_cmd --dry-run"
        log_warn "测试模式: 不会实际续期证书"
    fi

    if [[ "$RENEW_ALL" == "true" ]]; then
        certbot_cmd="$certbot_cmd --renew-all-domains"
        log_info "续期所有证书"
    fi

    if [[ "$FORCE_RENEW" == "true" ]]; then
        certbot_cmd="$certbot_cmd --force-renewal"
        log_warn "强制续期模式"
    fi

    # 执行续期
    if eval "$certbot_cmd" 2>&1 | tee -a "$LOG_FILE"; then
        if [[ "$DRY_RUN" != "true" ]]; then
            log_success "证书续期成功"
            return 0
        else
            log_info "测试续期完成 (未实际续期)"
            return 0
        fi
    else
        log_error "证书续期失败"
        return 1
    fi
}

# 重新加载服务
reload_services() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "测试模式: 跳过服务重新加载"
        return
    fi

    log_info "重新加载相关服务..."

    # 重新加载 Nginx
    if systemctl is-active --quiet nginx 2>/dev/null; then
        log_info "重新加载 Nginx..."
        if systemctl reload nginx 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Nginx 已重新加载"
        else
            log_warn "Nginx 重新加载失败"
        fi
    fi

    # 重新加载 Apache
    if systemctl is-active --quiet apache2 2>/dev/null || systemctl is-active --quiet httpd 2>/dev/null; then
        log_info "重新加载 Apache..."
        if systemctl reload apache2 2>&1 || systemctl reload httpd 2>&1; then
            log_success "Apache 已重新加载" | tee -a "$LOG_FILE"
        else
            log_warn "Apache 重新加载失败"
        fi
    fi

    # 重新加载其他常见服务
    for service in haproxy dovecot exim4 postfix; do
        if systemctl is-active --quiet $service 2>/dev/null; then
            log_info "重新加载 $service..."
            if systemctl reload $service 2>&1; then
                log_success "$service 已重新加载" | tee -a "$LOG_FILE"
            else
                log_warn "$service 重新加载失败"
            fi
        fi
    done
}

# 检查证书状态
check_certificate_status() {
    log_info "检查证书状态..."
    echo ""

    if [[ ! -d "$CERTBOT_HOME/live" ]]; then
        log_warn "未找到证书目录"
        return
    fi

    local today=$(date +%s)
    local total_certs=0
    local healthy_certs=0
    local expiring_certs=0

    for domain_dir in "$CERTBOT_HOME/live"/*; do
        if [[ -d "$domain_dir" ]]; then
            local domain=$(basename "$domain_dir")
            local cert_file="$domain_dir/cert.pem"

            if [[ -f "$cert_file" ]]; then
                ((total_certs++))

                local expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
                local expiry_epoch=$(date -d "$expiry_date" +%s)
                local days_left=$(( ($expiry_epoch - $today) / 86400 ))

                if [[ $days_left -le 0 ]]; then
                    echo -e "  ${RED}❌ $domain${NC} - 已过期" | tee -a "$LOG_FILE"
                elif [[ $days_left -le 7 ]]; then
                    echo -e "  ${RED}❌ $domain${NC} - 剩余 $days_left 天" | tee -a "$LOG_FILE"
                    ((expiring_certs++))
                elif [[ $days_left -le 30 ]]; then
                    echo -e "  ${YELLOW}⚠️  $domain${NC} - 剩余 $days_left 天" | tee -a "$LOG_FILE"
                    ((expiring_certs++))
                else
                    echo -e "  ${GREEN}✅ $domain${NC} - 剩余 $days_left 天" | tee -a "$LOG_FILE"
                    ((healthy_certs++))
                fi
            fi
        fi
    done

    echo "" | tee -a "$LOG_FILE"
    log_info "证书统计："
    log_info "  总数: $total_certs"
    log_info "  正常: $healthy_certs"
    log_info "  即将过期: $expiring_certs"
}

# 发送邮件通知
send_email_notification() {
    if [[ -z "$NOTIFY_EMAIL" ]]; then
        return
    fi

    if ! command -v mail &> /dev/null && ! command -v sendmail &> /dev/null; then
        log_warn "未找到邮件工具 (mail/sendmail)"
        return
    fi

    log_info "发送邮件通知到: $NOTIFY_EMAIL"

    local subject="Let's Encrypt 证书续期通知 - $(date '+%Y-%m-%d')"
    local body="证书续期任务已完成。\n\n详细日志请参考: $LOG_FILE"

    echo -e "$body" | mail -s "$subject" "$NOTIFY_EMAIL"

    log_success "邮件已发送"
}

# 生成摘要报告
generate_summary() {
    echo "" | tee -a "$LOG_FILE"
    echo "╔════════════════════════════════════════════════════════════╗" | tee -a "$LOG_FILE"
    echo "║         续期任务完成摘要                                  ║" | tee -a "$LOG_FILE"
    echo "╚════════════════════════════════════════════════════════════╝" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "续期模式: $(if [[ "$DRY_RUN" == "true" ]]; then echo "测试"; else echo "实际"; fi)" | tee -a "$LOG_FILE"
    echo "强制续期: $(if [[ "$FORCE_RENEW" == "true" ]]; then echo "是"; else echo "否"; fi)" | tee -a "$LOG_FILE"
    echo "完成时间: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
    echo "日志位置: $LOG_FILE" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

# 主函数
main() {
    print_header

    if [[ $EUID -ne 0 ]]; then
        # 如果不是 root，提示需要 sudo
        log_warn "此脚本需要 root 权限"
        echo "请运行: sudo bash renew_certificates.sh $@"
        exit 1
    fi

    init_log
    parse_arguments "$@"
    check_certbot

    echo "" | tee -a "$LOG_FILE"
    log_info "开始证书续期任务"
    echo "" | tee -a "$LOG_FILE"

    if renew_certificates; then
        reload_services
        check_certificate_status
        generate_summary
        send_email_notification

        log_success "证书续期任务完成"
        exit 0
    else
        generate_summary
        log_error "证书续期任务失败"
        exit 1
    fi
}

main "$@"
