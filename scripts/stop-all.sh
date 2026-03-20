#!/bin/bash
# 停止所有家庭服务

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SERVICES_DIR="$PROJECT_DIR/services"

# 服务停止顺序（依赖反向）
SERVICES=(
    "caddy"
    "homepage"
    "jellyseerr"
    "transmission"
    "prowlarr"
    "radarr"
    "sonarr"
    "jellyfin"
    "mihomo"
)

echo "=== 停止家庭服务 ==="

# 停止各服务
for service in "${SERVICES[@]}"; do
    if [ -f "$SERVICES_DIR/$service/docker-compose.yml" ]; then
        echo "停止 $service..."
        cd "$SERVICES_DIR/$service"
        docker compose down
    fi
done

echo ""
echo "完成！所有服务已停止"
