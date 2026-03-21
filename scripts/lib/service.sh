#!/bin/bash
# 服务管理模块

set -e

# 使用 deploy.sh 中已定义的 SCRIPT_DIR，不再重新定义
# 如果单独运行此文件，则自行定义路径
if [ -z "$DEPLOY_SCRIPT_DIR" ]; then
    DEPLOY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
fi
SERVICES_DIR="$DEPLOY_SCRIPT_DIR/../services"

# 所有服务及其依赖关系
declare -A SERVICE_DEPENDS=(
    ["prowlarr"]=""
    ["jellyfin"]=""
    ["transmission"]=""
    ["sonarr"]="prowlarr transmission"
    ["radarr"]="prowlarr transmission"
    ["jellyseerr"]="sonarr radarr jellyfin"
    ["homepage"]=""
    ["caddy"]="homepage"
)

# 获取启动顺序（按依赖拓扑排序）
get_start_order() {
    local services=()
    local visited=()

    visit() {
        local service="$1"
        # 检查是否已访问
        for v in "${visited[@]}"; do
            if [ "$v" = "$service" ]; then
                return 0
            fi
        done

        visited+=("$service")

        # 先访问依赖
        local deps="${SERVICE_DEPENDS[$service]}"
        if [ -n "$deps" ]; then
            for dep in $deps; do
                visit "$dep"
            done
        fi

        services+=("$service")
    }

    for service in "${!SERVICE_DEPENDS[@]}"; do
        visit "$service"
    done

    echo "${services[@]}"
}

# 获取停止顺序（启动顺序的逆序）
get_stop_order() {
    local start_order
    start_order=$(get_start_order)
    echo "$start_order" | tr ' ' '\n' | tac | tr '\n' ' '
}

# 启动单个服务
start_service() {
    local service="$1"
    local service_dir="$SERVICES_DIR/$service"

    if [ ! -f "$service_dir/docker-compose.yml" ]; then
        echo "[SKIP] $service (配置不存在)"
        return 0
    fi

    echo "启动 $service..."
    cd "$service_dir"
    docker compose up -d

    # 等待服务健康检查通过
    local max_wait=60
    local waited=0

    while [ $waited -lt $max_wait ]; do
        local health
        health=$(docker inspect --format='{{.State.Health.Status}}' "$service" 2>/dev/null || echo "unknown")

        if [ "$health" = "healthy" ]; then
            echo "[OK] $service 启动成功"
            return 0
        elif [ "$health" = "unhealthy" ]; then
            echo "[WARN] $service 健康检查失败，继续..."
            return 0
        fi

        sleep 2
        waited=$((waited + 2))
    done

    echo "[WARN] $service 启动超时，继续..."
}

# 停止单个服务
stop_service() {
    local service="$1"
    local service_dir="$SERVICES_DIR/$service"

    if [ ! -f "$service_dir/docker-compose.yml" ]; then
        return 0
    fi

    echo "停止 $service..."
    cd "$service_dir"
    docker compose down
    echo "[OK] $service 已停止"
}

# 启动所有服务
start_all() {
    local order
    order=$(get_start_order)

    echo "=== 启动服务 ==="
    for service in $order; do
        start_service "$service"
    done
    echo ""
}

# 停止所有服务
stop_all() {
    local order
    order=$(get_stop_order)

    echo "=== 停止服务 ==="
    for service in $order; do
        stop_service "$service"
    done
    echo ""
}

# 启动指定服务列表
start_services() {
    local selected_services=("$@")

    echo "=== 启动选定服务 ==="

    # 按依赖顺序启动
    local order
    order=$(get_start_order)

    for service in $order; do
        # 检查是否在选定列表中
        local found=false
        for selected in "${selected_services[@]}"; do
            if [ "$selected" = "$service" ]; then
                found=true
                break
            fi
        done

        if [ "$found" = true ]; then
            start_service "$service"
        fi
    done
    echo ""
}

# 显示服务状态
show_status() {
    echo "=== 服务状态 ==="
    for service in "${!SERVICE_DEPENDS[@]}"; do
        local service_dir="$SERVICES_DIR/$service"
        if [ -f "$service_dir/docker-compose.yml" ]; then
            cd "$service_dir"
            docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
        fi
    done
    echo ""
}

# 验证所有服务配置
validate_all() {
    echo "=== 验证服务配置 ==="
    local has_error=false

    for service in "${!SERVICE_DEPENDS[@]}"; do
        local service_dir="$SERVICES_DIR/$service"
        if [ -f "$service_dir/docker-compose.yml" ]; then
            cd "$service_dir"
            if docker compose config --quiet 2>/dev/null; then
                echo "[OK] $service"
            else
                echo "[ERROR] $service 配置无效"
                has_error=true
            fi
        fi
    done
    echo ""

    if [ "$has_error" = true ]; then
        return 1
    fi
}
