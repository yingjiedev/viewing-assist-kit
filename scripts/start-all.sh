#!/bin/bash
# 一键启动所有家庭服务

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SERVICES_DIR="$PROJECT_DIR/services"

# 加载环境变量
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
else
    echo "错误: 未找到 .env 文件，请复制 .env.example 并配置"
    exit 1
fi

# 服务启动顺序（依赖优先）
SERVICES=(
    "jellyfin"
    "sonarr"
    "radarr"
    "prowlarr"
    "transmission"
    "jellyseerr"
    "homepage"
    "caddy"
)

echo "=== 启动家庭服务 ==="

# 确保网络存在
if ! docker network inspect family-network &>/dev/null; then
    echo "创建 family-network (${NETWORK_SUBNET})..."
    docker network create --subnet=${NETWORK_SUBNET} family-network
fi

# 启动各服务
for service in "${SERVICES[@]}"; do
    if [ -f "$SERVICES_DIR/$service/docker-compose.yml" ]; then
        echo "启动 $service..."
        cd "$SERVICES_DIR/$service"
        docker compose up -d
    else
        echo "跳过 $service (配置不存在)"
    fi
done

echo ""
echo "=== 服务状态 ==="
for service in "${SERVICES[@]}"; do
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "^${service}\|^${service}-"; then
        docker ps --format "table {{.Names}}\t{{.Status}}" | grep "^${service}\|^${service}-"
    fi
done

echo ""
echo "完成！访问 https://homepage.${DOMAIN} 查看仪表盘"
