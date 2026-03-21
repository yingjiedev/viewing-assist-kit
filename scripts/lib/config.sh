#!/bin/bash
# 配置生成模块

set -e

# 使用 deploy.sh 中已定义的路径
if [ -z "$DEPLOY_SCRIPT_DIR" ]; then
    DEPLOY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
fi
TEMPLATE_DIR="$DEPLOY_SCRIPT_DIR/templates"

# 生成 .env 文件
generate_env() {
    local host_ip="$1"
    local domain="$2"
    local network_subnet="$3"
    local data_dir="$4"
    local puid="$5"
    local pgid="$6"
    local tz="$7"
    local transmission_password="$8"
    local env_file="$DEPLOY_SCRIPT_DIR/../.env"

    cat > "$env_file" << EOF
# Viewing Assist Kit 环境变量配置
# 自动生成于 $(date)

# ========================================
# 网络配置
# ========================================

# 宿主机 IP
HOST_IP=${host_ip}

# 内网域名后缀
DOMAIN=${domain}

# Docker 网络子网
NETWORK_SUBNET=${network_subnet}

# ========================================
# 服务 IP (按需分配，保持唯一)
# ========================================

CADDY_IP=172.30.0.11
HOMEPAGE_IP=172.30.0.4
JELLYFIN_IP=172.30.0.5
RADARR_IP=172.30.0.6
SONARR_IP=172.30.0.7
PROWLARR_IP=172.30.0.8
TRANSMISSION_IP=172.30.0.9
JELLYSEERR_IP=172.30.0.10

# ========================================
# 服务账户
# ========================================

# Transmission
TRANSMISSION_USERNAME=admin
TRANSMISSION_PASSWORD=${transmission_password}

# ========================================
# 数据目录
# ========================================

DATA_DIR=${data_dir}

# ========================================
# 用户权限
# ========================================

PUID=${puid}
PGID=${pgid}

# ========================================
# 其他配置
# ========================================

# 时区
TZ=${tz}

# OpenClaw Gateway 端口
OPENCLAW_PORT=18789
EOF

    echo "[OK] 已生成配置文件: $env_file"
}

# 创建目录结构
create_directories() {
    local data_dir="$1"
    local puid="$2"
    local pgid="$3"

    echo "=== 创建目录结构 ==="

    local dirs=(
        "$data_dir/config/jellyfin"
        "$data_dir/config/sonarr"
        "$data_dir/config/radarr"
        "$data_dir/config/prowlarr"
        "$data_dir/config/transmission"
        "$data_dir/config/jellyseerr"
        "$data_dir/config/homepage/data"
        "$data_dir/config/homepage/config"
        "$data_dir/config/caddy"
        "$data_dir/media/movies"
        "$data_dir/media/tv"
        "$data_dir/downloads/complete"
        "$data_dir/downloads/incomplete"
        "$data_dir/watch"
        "$data_dir/cache/jellyfin"
        "$data_dir/cache/sonarr"
        "$data_dir/backup"
    )

    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            echo "  创建: $dir"
        fi
    done

    # 设置目录权限
    chown -R "$puid:$pgid" "$data_dir" 2>/dev/null || {
        echo "[WARN] 无法修改目录权限，可能需要 sudo"
    }

    echo "[OK] 目录结构创建完成"
}

# 验证配置
validate_config() {
    local env_file="$DEPLOY_SCRIPT_DIR/../.env"

    if [ ! -f "$env_file" ]; then
        echo "错误: 配置文件不存在: $env_file" >&2
        return 1
    fi

    # 检查必要的变量
    local required_vars=("HOST_IP" "DOMAIN" "NETWORK_SUBNET" "DATA_DIR" "TRANSMISSION_PASSWORD")
    local missing=()

    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" "$env_file"; then
            missing+=("$var")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "错误: 配置文件缺少以下变量: ${missing[*]}" >&2
        return 1
    fi

    echo "[OK] 配置验证通过"
}
