#!/bin/bash
# Viewing Assist Kit 服务关联配置脚本
# 用法: ./setup-services.sh [选项]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载模块
source "$SCRIPT_DIR/lib/setup.sh"

# 显示帮助
show_help() {
    cat << EOF
Viewing Assist Kit 服务关联配置脚本

用法: $0 [选项]

选项:
  -d, --data <path>        数据根目录（默认: 从 .env 读取或 /srv/media）
  -h, --help               显示此帮助信息

示例:
  $0                       # 使用 .env 配置
  $0 -d /mnt/media         # 指定数据目录

EOF
    exit 0
}

# 从 .env 文件读取配置
load_env() {
    local env_file="$SCRIPT_DIR/../.env"

    if [ ! -f "$env_file" ]; then
        echo "错误: 配置文件不存在: $env_file" >&2
        echo "请先运行 ./scripts/deploy.sh 生成配置" >&2
        exit 1
    fi

    # 读取必要变量
    export $(grep -E "^(DATA_DIR|HOST_IP|TRANSMISSION_PASSWORD|JELLYFIN_PORT)=" "$env_file" | xargs)
}

# 解析参数
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -d|--data)
                DATA_DIR="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                ;;
            *)
                shift
                ;;
        esac
    done
}

# 主函数
main() {
    echo "╔══════════════════════════════════════════╗"
    echo "║     Viewing Assist Kit 服务配置工具      ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    # 加载环境配置
    load_env

    # 解析参数（覆盖 .env 中的配置）
    parse_args "$@"

    # 使用默认值
    DATA_DIR="${DATA_DIR:-/srv/media}"
    HOST_IP="${HOST_IP:-127.0.0.1}"
    TRANSMISSION_PASSWORD="${TRANSMISSION_PASSWORD:-}"
    JELLYFIN_PORT="${JELLYFIN_PORT:-8096}"

    # 验证必要参数
    if [ -z "$TRANSMISSION_PASSWORD" ]; then
        echo "错误: TRANSMISSION_PASSWORD 未配置" >&2
        exit 1
    fi

    if [ ! -d "$DATA_DIR" ]; then
        echo "错误: 数据目录不存在: $DATA_DIR" >&2
        exit 1
    fi

    # 检查 Docker 容器是否运行
    echo "检查服务状态..."
    local running_services
    running_services=$(docker ps --format "{{.Names}}" | grep -E "^(prowlarr|sonarr|radarr|transmission|jellyseerr|jellyfin)$" | wc -l)

    if [ "$running_services" -lt 6 ]; then
        echo "错误: 部分服务未运行" >&2
        echo "请先启动所有服务: ./scripts/start-all.sh" >&2
        echo ""
        echo "当前运行的服务:"
        docker ps --format "{{.Names}}" | grep -E "^(prowlarr|sonarr|radarr|transmission|jellyseerr|jellyfin)$" || echo "  无"
        exit 1
    fi
    echo "  [OK] 所有服务已运行"
    echo ""

    # 执行配置
    setup_all_services \
        "$DATA_DIR" \
        "$HOST_IP" \
        "$TRANSMISSION_PASSWORD"
}

# 执行主函数
main "$@"
