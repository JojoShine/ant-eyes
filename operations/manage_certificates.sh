#!/bin/bash

################################################################################
# 证书管理工具脚本
# 用于管理和监控 Let's Encrypt 证书
# 功能:
#   - 列出所有证书及其信息
#   - 查看证书详细信息
#   - 检查证书过期时间
#   - 生成证书监控报告
#   - 显示证书续期状态
#
# 使用方法:
#   sudo bash manage_certificates.sh [选项]
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

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 打印标题
print_header() {
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         Let's Encrypt 证书管理工具 v1.0.0                 ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        exit 1
    fi
}

# 列出所有证书
list_certificates() {
    log_info "列出所有证书..."
    echo ""

    if ! command -v certbot &> /dev/null; then
        log_error "Certbot 未安装"
        return 1
    fi

    certbot certificates
}

# 查看证书详情
show_certificate_details() {
    local cert_name="$1"

    if [[ -z "$cert_name" ]]; then
        read -p "请输入证书名称: " cert_name
    fi

    local cert_path="$CERTBOT_HOME/live/$cert_name/cert.pem"

    if [[ ! -f "$cert_path" ]]; then
        log_error "证书不存在: $cert_name"
        return 1
    fi

    echo ""
    log_info "证书详情: $cert_name"
    echo ""

    openssl x509 -text -noout -in "$cert_path"
}

# 检查证书过期时间
check_expiry() {
    echo ""
    log_info "检查所有证书过期时间..."
    echo ""

    if [[ ! -d "$CERTBOT_HOME/live" ]]; then
        log_error "未找到证书目录: $CERTBOT_HOME/live"
        return 1
    fi

    local today=$(date +%s)
    local found=false

    for domain_dir in "$CERTBOT_HOME/live"/*; do
        if [[ -d "$domain_dir" ]]; then
            local domain=$(basename "$domain_dir")
            local cert_file="$domain_dir/cert.pem"

            if [[ -f "$cert_file" ]]; then
                local expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
                local expiry_epoch=$(date -d "$expiry_date" +%s)
                local days_left=$(( ($expiry_epoch - $today) / 86400 ))

                found=true

                # 根据剩余天数显示不同颜色
                if [[ $days_left -le 7 ]]; then
                    echo -e "${RED}❌ $domain${NC} - 剩余天数: ${RED}$days_left 天${NC} (${RED}即将过期${NC}) - 过期时间: $expiry_date"
                elif [[ $days_left -le 30 ]]; then
                    echo -e "${YELLOW}⚠️  $domain${NC} - 剩余天数: ${YELLOW}$days_left 天${NC} (${YELLOW}需要续期${NC}) - 过期时间: $expiry_date"
                else
                    echo -e "${GREEN}✅ $domain${NC} - 剩余天数: ${GREEN}$days_left 天${NC} (${GREEN}正常${NC}) - 过期时间: $expiry_date"
                fi
            fi
        fi
    done

    if [[ "$found" == false ]]; then
        log_warn "未找到任何证书"
        return 1
    fi

    echo ""
}

# 手动续期证书
renew_certificate() {
    local cert_name="$1"

    if [[ -z "$cert_name" ]]; then
        echo -e "${BLUE}续期选项:${NC}"
        echo "  1) 续期所有证书"
        echo "  2) 续期特定证书"
        read -p "请选择 [1-2, 默认 1]: " renew_choice

        case $renew_choice in
            2)
                read -p "请输入证书名称: " cert_name
                log_info "续期证书: $cert_name"
                certbot renew --cert-name "$cert_name"
                ;;
            *)
                log_info "续期所有证书..."
                certbot renew
                ;;
        esac
    else
        log_info "续期证书: $cert_name"
        certbot renew --cert-name "$cert_name"
    fi
}

# 测试自动续期
test_renewal() {
    log_info "测试自动续期流程 (干运行)..."
    echo ""

    certbot renew --dry-run

    echo ""
    log_success "测试完成。如果没有错误，自动续期应该可以正常工作"
}

# 删除证书
delete_certificate() {
    read -p "请输入要删除的证书名称: " cert_name

    if [[ -z "$cert_name" ]]; then
        log_error "证书名称不能为空"
        return 1
    fi

    read -p "确认删除 $cert_name？(y/n) [n]: " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "删除已取消"
        return
    fi

    certbot delete --cert-name "$cert_name"
    log_success "证书已删除: $cert_name"
}

# 生成监控报告
generate_monitoring_report() {
    local report_file="/tmp/certificates_monitoring_$(date +%Y%m%d_%H%M%S).txt"

    cat > "$report_file" << EOF
╔════════════════════════════════════════════════════════════════╗
║         Let's Encrypt 证书监控报告                           ║
╚════════════════════════════════════════════════════════════════╝

【报告时间】
$(date '+%Y-%m-%d %H:%M:%S')

【证书汇总】
EOF

    if [[ ! -d "$CERTBOT_HOME/live" ]]; then
        echo "未找到任何证书" >> "$report_file"
    else
        local total_certs=0
        local expiring_soon=0
        local expired=0

        for domain_dir in "$CERTBOT_HOME/live"/*; do
            if [[ -d "$domain_dir" ]]; then
                local domain=$(basename "$domain_dir")
                local cert_file="$domain_dir/cert.pem"

                if [[ -f "$cert_file" ]]; then
                    ((total_certs++))

                    local expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
                    local today=$(date +%s)
                    local expiry_epoch=$(date -d "$expiry_date" +%s)
                    local days_left=$(( ($expiry_epoch - $today) / 86400 ))

                    if [[ $days_left -le 0 ]]; then
                        ((expired++))
                    elif [[ $days_left -le 30 ]]; then
                        ((expiring_soon++))
                    fi

                    echo "
域名: $domain
过期时间: $expiry_date
剩余天数: $days_left 天
状态: $(if [[ $days_left -le 0 ]]; then echo "已过期"; elif [[ $days_left -le 30 ]]; then echo "即将过期"; else echo "正常"; fi)" >> "$report_file"
                fi
            fi
        done

        echo "
总证书数: $total_certs
即将过期 (30天内): $expiring_soon
已过期: $expired" >> "$report_file"
    fi

    cat >> "$report_file" << 'EOF'

【常用命令】
1. 查看所有证书
   certbot certificates

2. 查看特定证书详情
   openssl x509 -text -noout -in /etc/letsencrypt/live/domain.com/cert.pem

3. 手动续期
   certbot renew

4. 测试自动续期
   certbot renew --dry-run

5. 查看续期日志
   cat /var/log/letsencrypt/letsencrypt.log

【自动续期检查】
如果配置了自动续期，可以检查 cron 任务:
   cat /etc/cron.d/certbot-renewal

【建议】
- 每月检查一次证书过期时间
- 定期查看 /var/log/letsencrypt/ 日志
- 确保自动续期 cron 任务正确配置
- Let's Encrypt 会在过期前30天发邮件提醒
EOF

    cat "$report_file"
    log_success "报告已生成: $report_file"
}

# 交互式菜单
interactive_menu() {
    while true; do
        echo ""
        echo -e "${BLUE}请选择操作:${NC}"
        echo "  1) 列出所有证书"
        echo "  2) 查看证书详情"
        echo "  3) 检查证书过期时间"
        echo "  4) 手动续期证书"
        echo "  5) 测试自动续期"
        echo "  6) 删除证书"
        echo "  7) 生成监控报告"
        echo "  0) 退出"
        echo ""

        read -p "请选择 [0-7]: " choice

        case $choice in
            1)
                list_certificates
                ;;
            2)
                show_certificate_details
                ;;
            3)
                check_expiry
                ;;
            4)
                renew_certificate
                ;;
            5)
                test_renewal
                ;;
            6)
                delete_certificate
                ;;
            7)
                generate_monitoring_report
                ;;
            0)
                log_info "退出"
                exit 0
                ;;
            *)
                log_error "选择无效"
                ;;
        esac

        read -p "按 Enter 继续..."
    done
}

# 主函数
main() {
    print_header
    check_root

    # 如果有命令行参数，直接执行
    case "${1:-}" in
        list)
            list_certificates
            ;;
        show)
            show_certificate_details "$2"
            ;;
        expiry)
            check_expiry
            ;;
        renew)
            renew_certificate "$2"
            ;;
        test)
            test_renewal
            ;;
        delete)
            delete_certificate
            ;;
        report)
            generate_monitoring_report
            ;;
        *)
            interactive_menu
            ;;
    esac
}

main "$@"
