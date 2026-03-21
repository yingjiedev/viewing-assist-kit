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
    local deploy_mode="$3"
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
# 部署模式
# ========================================

# port = 端口模式（直接 IP:端口 访问）
# domain = 域名模式（Caddy 反向代理，需配置 DNS）
DEPLOY_MODE=${deploy_mode}

# ========================================
# 网络配置
# ========================================

# 宿主机 IP
HOST_IP=${host_ip}

# 内网域名后缀（域名模式必填）
DOMAIN=${domain}

# ========================================
# 服务端口（端口模式使用）
# ========================================

JELLYFIN_PORT=8096
SONARR_PORT=8989
RADARR_PORT=7878
PROWLARR_PORT=9696
TRANSMISSION_PORT=9091
JELLYSEERR_PORT=5055
HOMEPAGE_PORT=3000

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
# 服务关联配置（可选，有默认值）
# ========================================

# Sonarr 默认质量配置文件
# 可选值: SD, HD-720p, HD-1080p, Ultra-HD, Any
SONARR_QUALITY_PROFILE=HD-1080p

# Radarr 默认质量配置文件
# 可选值: SD, HD-720p, HD-1080p, Ultra-HD, Any
RADARR_QUALITY_PROFILE=HD-1080p

# Sonarr 媒体根目录（容器内路径）
SONARR_ROOT_FOLDER=/tv

# Radarr 媒体根目录（容器内路径）
RADARR_ROOT_FOLDER=/movies

# Transmission 下载目录（容器内路径）
TRANSMISSION_DOWNLOAD_DIR=/downloads

# ========================================
# 其他配置
# ========================================

# 时区
TZ=${tz}
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
    local required_vars=("HOST_IP" "DOMAIN" "DATA_DIR" "TRANSMISSION_PASSWORD")
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
