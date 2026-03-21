#!/bin/bash
# Viewing Assist Kit 一键部署脚本
# 用法: ./deploy.sh [选项]

set -e

DEPLOY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载模块
source "$DEPLOY_SCRIPT_DIR/lib/check.sh"
source "$DEPLOY_SCRIPT_DIR/lib/config.sh"
source "$DEPLOY_SCRIPT_DIR/lib/network.sh"
source "$DEPLOY_SCRIPT_DIR/lib/service.sh"

# 默认值
DEFAULT_HOST_IP=""
DEFAULT_DATA_DIR="/srv/media"
DEFAULT_DOMAIN="home.local"
DEFAULT_PUID=1000
DEFAULT_PGID=1000
DEFAULT_TZ="Asia/Shanghai"
DEFAULT_DEPLOY_MODE="port"  # port 或 domain

# 可用服务列表（不含 caddy，根据模式决定是否添加）
ALL_APP_SERVICES=("jellyfin" "prowlarr" "sonarr" "radarr" "transmission" "jellyseerr" "homepage")
ALL_SERVICES=("${ALL_APP_SERVICES[@]}" "caddy")

# 显示帮助
show_help() {
    cat << EOF
Viewing Assist Kit 一键部署脚本

用法: $0 [选项]

选项:
  -i, --interactive        交互式配置（默认）
  -q, --quick <ip>         快速部署（仅需宿主机IP）
  -c, --config <file>      使用指定配置文件
  -d, --data <path>        数据根目录（默认: /srv/media）
  -D, --domain <domain>    域名后缀（默认: home.local）
  -u, --user <uid>:<gid>   运行用户（默认: 1000:1000）
  -m, --mode <mode>        部署模式: port（端口映射）或 domain（域名反代）
  --dry-run                仅生成配置，不启动服务
  --skip-check             跳过前置检查
  -h, --help               显示此帮助信息

示例:
  $0                              # 交互式部署
  $0 -q 192.168.1.100             # 快速部署（端口模式）
  $0 -q 192.168.1.100 -m domain   # 快速部署（域名模式）
  $0 -i 192.168.1.100 -d /data    # 指定 IP 和数据目录
  $0 -c production.conf           # 使用配置文件
  $0 --dry-run                    # 仅生成配置文件

EOF
    exit 0
}

# 交互式收集配置
interactive_config() {
    echo "=== Viewing Assist Kit 部署向导 ==="
    echo ""

    # 宿主机 IP
    read -p "宿主机 IP 地址: " HOST_IP
    if [ -z "$HOST_IP" ]; then
        echo "错误: 宿主机 IP 不能为空" >&2
        exit 1
    fi

    # 部署模式
    echo ""
    echo "部署模式:"
    echo "  1) 端口模式 (port)   - 直接通过 IP:端口 访问，无需域名解析"
    echo "  2) 域名模式 (domain) - 通过 Caddy 反向代理，需要配置 DNS/hosts"
    read -p "选择模式 [1]: " mode_choice
    case "${mode_choice:-1}" in
        1|port) DEPLOY_MODE="port" ;;
        2|domain) DEPLOY_MODE="domain" ;;
        *) DEPLOY_MODE="port" ;;
    esac

    # 数据目录
    read -p "数据根目录 [${DEFAULT_DATA_DIR}]: " DATA_DIR
    DATA_DIR="${DATA_DIR:-$DEFAULT_DATA_DIR}"

    # 域名后缀（仅域名模式需要）
    if [ "$DEPLOY_MODE" = "domain" ]; then
        read -p "域名后缀 [${DEFAULT_DOMAIN}]: " DOMAIN
        DOMAIN="${DOMAIN:-$DEFAULT_DOMAIN}"
    else
        DOMAIN="${DEFAULT_DOMAIN}"
    fi

    # 用户 ID
    read -p "运行用户 UID [${DEFAULT_PUID}]: " PUID
    PUID="${PUID:-$DEFAULT_PUID}"

    # 组 ID
    read -p "运行用户 GID [${DEFAULT_PGID}]: " PGID
    PGID="${PGID:-$DEFAULT_PGID}"

    # 时区
    read -p "时区 [${DEFAULT_TZ}]: " TZ
    TZ="${TZ:-$DEFAULT_TZ}"

    # Transmission 密码
    read -sp "Transmission 密码: " TRANSMISSION_PASSWORD
    echo ""
    if [ -z "$TRANSMISSION_PASSWORD" ]; then
        echo "错误: Transmission 密码不能为空" >&2
        exit 1
    fi

    # 选择服务
    echo ""
    echo "请选择要部署的服务（输入服务编号，空格分隔）:"
    local i=1
    for service in "${ALL_APP_SERVICES[@]}"; do
        echo "  $i) $service"
        ((i++))
    done
    echo ""
    read -p "服务编号（默认全部）: " service_input

    if [ -z "$service_input" ]; then
        SELECTED_SERVICES=("${ALL_APP_SERVICES[@]}")
    else
        SELECTED_SERVICES=()
        for num in $service_input; do
            if [ "$num" -ge 1 ] && [ "$num" -le ${#ALL_APP_SERVICES[@]} ]; then
                SELECTED_SERVICES+=("${ALL_APP_SERVICES[$((num-1))]}")
            fi
        done
    fi

    # 域名模式自动添加 caddy
    if [ "$DEPLOY_MODE" = "domain" ]; then
        SELECTED_SERVICES+=("caddy")
        echo "[INFO] 域名模式已自动添加 caddy（反向代理）"
    fi
}

# 快速模式配置
quick_config() {
    local ip="$1"

    HOST_IP="$ip"
    DATA_DIR="$DEFAULT_DATA_DIR"
    DOMAIN="$DEFAULT_DOMAIN"
    DEPLOY_MODE="${DEPLOY_MODE:-$DEFAULT_DEPLOY_MODE}"
    PUID="$DEFAULT_PUID"
    PGID="$DEFAULT_PGID"
    TZ="$DEFAULT_TZ"
    SELECTED_SERVICES=("${ALL_APP_SERVICES[@]}")

    # 域名模式自动添加 caddy
    if [ "$DEPLOY_MODE" = "domain" ]; then
        SELECTED_SERVICES+=("caddy")
    fi

    # 生成随机密码
    TRANSMISSION_PASSWORD=$(openssl rand -base64 12)
    echo "[INFO] 已生成随机 Transmission 密码: $TRANSMISSION_PASSWORD"
}

# 解析命令行参数
parse_args() {
    local mode="interactive"

    while [ $# -gt 0 ]; do
        case "$1" in
            -i|--interactive)
                mode="interactive"
                shift
                ;;
            -q|--quick)
                mode="quick"
                HOST_IP="$2"
                shift 2
                ;;
            -c|--config)
                mode="config"
                CONFIG_FILE="$2"
                shift 2
                ;;
            -d|--data)
                DATA_DIR="$2"
                shift 2
                ;;
            -D|--domain)
                DOMAIN="$2"
                shift 2
                ;;
            -m|--mode)
                DEPLOY_MODE="$2"
                shift 2
                ;;
            -u|--user)
                PUID="${2%%:*}"
                PGID="${2##*:}"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-check)
                SKIP_CHECK=true
                shift
                ;;
            -h|--help)
                show_help
                ;;
            *)
                # 第一个非选项参数作为 IP（兼容模式）
                if [ -z "$HOST_IP" ] && [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    HOST_IP="$1"
                    mode="quick"
                fi
                shift
                ;;
        esac
    done

    case "$mode" in
        interactive)
            interactive_config
            ;;
        quick)
            if [ -z "$HOST_IP" ]; then
                echo "错误: 快速模式需要指定宿主机 IP" >&2
                exit 1
            fi
            quick_config "$HOST_IP"
            ;;
        config)
            if [ ! -f "$CONFIG_FILE" ]; then
                echo "错误: 配置文件不存在: $CONFIG_FILE" >&2
                exit 1
            fi
            source "$CONFIG_FILE"
            SELECTED_SERVICES=("${ALL_APP_SERVICES[@]}")
            # 域名模式自动添加 caddy
            if [ "${DEPLOY_MODE:-port}" = "domain" ]; then
                SELECTED_SERVICES+=("caddy")
            fi
            ;;
    esac
}

# 主函数
main() {
    echo "╔══════════════════════════════════════════╗"
    echo "║     Viewing Assist Kit 部署工具          ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    # 解析参数
    parse_args "$@"

    # 设置默认值
    DATA_DIR="${DATA_DIR:-$DEFAULT_DATA_DIR}"
    DOMAIN="${DOMAIN:-$DEFAULT_DOMAIN}"
    DEPLOY_MODE="${DEPLOY_MODE:-$DEFAULT_DEPLOY_MODE}"
    PUID="${PUID:-$DEFAULT_PUID}"
    PGID="${PGID:-$DEFAULT_PGID}"
    TZ="${TZ:-$DEFAULT_TZ}"
    SELECTED_SERVICES=("${SELECTED_SERVICES[@]:-${ALL_APP_SERVICES[@]}}")

    # 前置检查
    if [ "$SKIP_CHECK" != true ]; then
        run_all_checks "$DATA_DIR" || exit 1
    fi

    # 生成配置
    echo "=== 生成配置 ==="
    generate_env "$HOST_IP" "$DOMAIN" "$DEPLOY_MODE" "$DATA_DIR" "$PUID" "$PGID" "$TZ" "$TRANSMISSION_PASSWORD"
    validate_config
    echo ""

    # 创建目录
    create_directories "$DATA_DIR" "$PUID" "$PGID"
    echo ""

    # 仅生成配置模式
    if [ "$DRY_RUN" = true ]; then
        echo "=== Dry Run 完成 ==="
        echo "配置文件已生成: $DEPLOY_SCRIPT_DIR/../.env"
        echo "数据目录已创建: $DATA_DIR"
        echo ""
        echo "要启动服务，请运行:"
        echo "  cd $DEPLOY_SCRIPT_DIR && ./start-all.sh"
        exit 0
    fi

    # 创建网络
    echo "=== 配置网络 ==="
    create_network
    echo ""

    # 启动服务
    start_services "${SELECTED_SERVICES[@]}"

    # 显示状态
    show_status

    # 完成
    echo "╔══════════════════════════════════════════╗"
    echo "║            部署完成！                     ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    if [ "$DEPLOY_MODE" = "port" ]; then
        echo "访问地址（端口模式）:"
        echo "  - Homepage:     http://${HOST_IP}:3000"
        echo "  - Jellyfin:     http://${HOST_IP}:8096"
        echo "  - Sonarr:       http://${HOST_IP}:8989"
        echo "  - Radarr:       http://${HOST_IP}:7878"
        echo "  - Prowlarr:     http://${HOST_IP}:9696"
        echo "  - Transmission: http://${HOST_IP}:9091"
        echo "  - Jellyseerr:   http://${HOST_IP}:5055"
    else
        echo "访问地址（域名模式）:"
        echo "  请确保已配置 DNS 或 /etc/hosts:"
        echo "  ${HOST_IP}  homepage.${DOMAIN} jellyfin.${DOMAIN} sonarr.${DOMAIN}"
        echo "  ${HOST_IP}  radarr.${DOMAIN} prowlarr.${DOMAIN} transmission.${DOMAIN} jellyseerr.${DOMAIN}"
        echo ""
        echo "  - Homepage:    https://homepage.${DOMAIN}"
        echo "  - Jellyfin:    https://jellyfin.${DOMAIN}"
        echo "  - Sonarr:      https://sonarr.${DOMAIN}"
        echo "  - Radarr:      https://radarr.${DOMAIN}"
        echo "  - Prowlarr:    https://prowlarr.${DOMAIN}"
        echo "  - Transmission: https://transmission.${DOMAIN}"
        echo "  - Jellyseerr:  https://jellyseerr.${DOMAIN}"
    fi
    echo ""
    echo "Transmission 登录:"
    echo "  - 用户名: admin"
    echo "  - 密码: ${TRANSMISSION_PASSWORD}"
    echo ""
    echo "管理命令:"
    echo "  - 停止服务: ./scripts/stop-all.sh"
    echo "  - 查看状态: docker ps"
    echo "  - 查看日志: cd services/<服务名> && docker compose logs -f"
    echo ""
}

# 执行主函数
main "$@"
