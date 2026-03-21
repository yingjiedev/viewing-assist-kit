#!/bin/bash
# 服务关联自动配置模块

set -e

# 使用 deploy.sh 中已定义的路径
if [ -z "$DEPLOY_SCRIPT_DIR" ]; then
    DEPLOY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
fi

# ========================================
# 通用工具函数
# ========================================

# 等待服务就绪
wait_for_service() {
    local service_name="$1"
    local url="$2"
    local max_wait="${3:-120}"
    local waited=0

    echo "  等待 $service_name 就绪..."
    while [ $waited -lt $max_wait ]; do
        if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "^[23]"; then
            echo "  [OK] $service_name 已就绪"
            return 0
        fi
        sleep 3
        waited=$((waited + 3))
    done

    echo "  [ERROR] $service_name 启动超时 (${max_wait}s)" >&2
    return 1
}

# 安全的 API 调用（带重试）
api_call() {
    local method="$1"
    local url="$2"
    local api_key="$3"
    local data="$4"
    local max_retries="${5:-3}"
    local retry=0
    local response

    while [ $retry -lt $max_retries ]; do
        if [ "$method" = "GET" ]; then
            response=$(curl -s -w "\n%{http_code}" \
                -H "X-Api-Key: $api_key" \
                "$url")
        elif [ "$method" = "POST" ]; then
            response=$(curl -s -w "\n%{http_code}" \
                -X POST \
                -H "X-Api-Key: $api_key" \
                -H "Content-Type: application/json" \
                -d "$data" \
                "$url")
        elif [ "$method" = "PUT" ]; then
            response=$(curl -s -w "\n%{http_code}" \
                -X PUT \
                -H "X-Api-Key: $api_key" \
                -H "Content-Type: application/json" \
                -d "$data" \
                "$url")
        fi

        local http_code
        http_code=$(echo "$response" | tail -n 1)
        local body
        body=$(echo "$response" | sed '$d')

        if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
            echo "$body"
            return 0
        fi

        retry=$((retry + 1))
        if [ $retry -lt $max_retries ]; then
            sleep 2
        fi
    done

    echo "" >&2
    return 1
}

# ========================================
# API Key 获取函数
# ========================================

# 从配置文件获取 API Key（更可靠）
get_api_key_from_config() {
    local config_path="$1"
    local config_xml="$2"

    if [ -f "$config_path/$config_xml" ]; then
        grep -oP '<ApiKey>\K[^<]+' "$config_path/$config_xml" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# 从 API 获取 API Key（首次启动后使用）
get_api_key_from_api() {
    local url="$1"

    # 尝试通过 API 获取（无需认证的端点）
    curl -s "$url" 2>/dev/null | grep -oP '"apiKey"\s*:\s*"\K[^"]+' || echo ""
}

# 获取 Prowlarr API Key
get_prowlarr_api_key() {
    local data_dir="$1"
    local api_key=""

    # 先尝试从配置文件获取
    api_key=$(get_api_key_from_config "$data_dir/config/prowlarr" "config.xml")

    # 如果配置文件不存在，尝试从 API 获取
    if [ -z "$api_key" ]; then
        api_key=$(get_api_key_from_api "http://prowlarr:9696/api/v1/config/host")
    fi

    echo "$api_key"
}

# 获取 Sonarr API Key
get_sonarr_api_key() {
    local data_dir="$1"
    local api_key=""

    api_key=$(get_api_key_from_config "$data_dir/config/sonarr" "config.xml")

    if [ -z "$api_key" ]; then
        api_key=$(get_api_key_from_api "http://sonarr:8989/api/v3/config/host")
    fi

    echo "$api_key"
}

# 获取 Radarr API Key
get_radarr_api_key() {
    local data_dir="$1"
    local api_key=""

    api_key=$(get_api_key_from_config "$data_dir/config/radarr" "config.xml")

    if [ -z "$api_key" ]; then
        api_key=$(get_api_key_from_api "http://radarr:7878/api/v3/config/host")
    fi

    echo "$api_key"
}

# 获取 Jellyfin API Key（需要先创建）
get_jellyfin_api_key() {
    local data_dir="$1"

    # 从配置文件获取已有的 API Key
    if [ -f "$data_dir/config/jellyfin/config/network.xml" ]; then
        grep -oP '<BaseUrl>\K[^<]+' "$data_dir/config/jellyfin/config/network.xml" 2>/dev/null || echo ""
    fi

    # Jellyfin 需要通过 API 创建 API Key
    local response
    response=$(curl -s -X POST "http://jellyfin:8096/api/Auth/Keys" \
        -H "Content-Type: application/json" \
        -d '{"app":"ViewingAssistKit"}' 2>/dev/null)

    echo "$response" | grep -oP '"AccessToken"\s*:\s*"\K[^"]+' || echo ""
}

# ========================================
# 配置检查函数（幂等执行）
# ========================================

# 检查 Prowlarr 是否已配置 Sonarr
prowlarr_has_sonarr() {
    local api_key="$1"
    local response
    response=$(api_call "GET" "http://prowlarr:9696/api/v1/applications" "$api_key")

    echo "$response" | grep -q '"name"\s*:\s*"Sonarr"'
}

# 检查 Prowlarr 是否已配置 Radarr
prowlarr_has_radarr() {
    local api_key="$1"
    local response
    response=$(api_call "GET" "http://prowlarr:9696/api/v1/applications" "$api_key")

    echo "$response" | grep -q '"name"\s*:\s*"Radarr"'
}

# 检查 Sonarr 是否已配置 Transmission
sonarr_has_transmission() {
    local api_key="$1"
    local response
    response=$(api_call "GET" "http://sonarr:8989/api/v3/downloadclient" "$api_key")

    echo "$response" | grep -q '"name"\s*:\s*"Transmission"'
}

# 检查 Radarr 是否已配置 Transmission
radarr_has_transmission() {
    local api_key="$1"
    local response
    response=$(api_call "GET" "http://radarr:7878/api/v3/downloadclient" "$api_key")

    echo "$response" | grep -q '"name"\s*:\s*"Transmission"'
}

# 检查 Jellyseerr 是否已配置 Jellyfin
jellyseerr_has_jellyfin() {
    local url="http://jellyseerr:5055/api/v1/settings/jellyfin"
    local response
    response=$(curl -s "$url" 2>/dev/null)

    echo "$response" | grep -q '"hostname"\s*:'
}

# 检查 Jellyseerr 是否已配置 Sonarr
jellyseerr_has_sonarr() {
    local url="http://jellyseerr:5055/api/v1/service?serviceType=sonarr"
    local response
    response=$(curl -s "$url" 2>/dev/null)

    echo "$response" | grep -q '"name"\s*:\s*"Sonarr"'
}

# 检查 Jellyseerr 是否已配置 Radarr
jellyseerr_has_radarr() {
    local url="http://jellyseerr:5055/api/v1/service?serviceType=radarr"
    local response
    response=$(curl -s "$url" 2>/dev/null)

    echo "$response" | grep -q '"name"\s*:\s*"Radarr"'
}

# ========================================
# 配置执行函数
# ========================================

# 配置 Prowlarr → Sonarr/Radarr
setup_prowlarr_apps() {
    local data_dir="$1"
    local sonarr_api_key="$2"
    local radarr_api_key="$3"
    local prowlarr_api_key="$4"

    echo "--- 配置 Prowlarr 应用 ---"

    # 配置 Sonarr
    if ! prowlarr_has_sonarr "$prowlarr_api_key"; then
        local sonarr_data=$(cat <<EOF
{
    "name": "Sonarr",
    "implementationName": "Sonarr",
    "implementation": "Sonarr",
    "configContract": "SonarrSettings",
    "fields": [
        {"name": "baseUrl", "value": "http://sonarr:8989"},
        {"name": "apiKey", "value": "$sonarr_api_key"},
        {"name": "syncLevel", "value": "fullSync"}
    ],
    "tags": []
}
EOF
        )
        if api_call "POST" "http://prowlarr:9696/api/v1/applications" "$prowlarr_api_key" "$sonarr_data" > /dev/null; then
            echo "  [OK] 已添加 Sonarr 应用"
        else
            echo "  [ERROR] 添加 Sonarr 应用失败" >&2
        fi
    else
        echo "  [SKIP] Sonarr 应用已存在"
    fi

    # 配置 Radarr
    if ! prowlarr_has_radarr "$prowlarr_api_key"; then
        local radarr_data=$(cat <<EOF
{
    "name": "Radarr",
    "implementationName": "Radarr",
    "implementation": "Radarr",
    "configContract": "RadarrSettings",
    "fields": [
        {"name": "baseUrl", "value": "http://radarr:7878"},
        {"name": "apiKey", "value": "$radarr_api_key"},
        {"name": "syncLevel", "value": "fullSync"}
    ],
    "tags": []
}
EOF
        )
        if api_call "POST" "http://prowlarr:9696/api/v1/applications" "$prowlarr_api_key" "$radarr_data" > /dev/null; then
            echo "  [OK] 已添加 Radarr 应用"
        else
            echo "  [ERROR] 添加 Radarr 应用失败" >&2
        fi
    else
        echo "  [SKIP] Radarr 应用已存在"
    fi
}

# 配置 Transmission → Sonarr
setup_sonarr_transmission() {
    local api_key="$1"
    local password="$2"

    echo "--- 配置 Sonarr 下载客户端 ---"

    if ! sonarr_has_transmission "$api_key"; then
        local data=$(cat <<EOF
{
    "enable": true,
    "name": "Transmission",
    "implementationName": "Transmission",
    "implementation": "TransmissionTorrent",
    "configContract": "TransmissionSettings",
    "fields": [
        {"name": "host", "value": "transmission"},
        {"name": "port", "value": 9091},
        {"name": "username", "value": "admin"},
        {"name": "password", "value": "$password"},
        {"name": "tvDirectory", "value": "/downloads"}
    ],
    "tags": []
}
EOF
        )
        if api_call "POST" "http://sonarr:8989/api/v3/downloadclient" "$api_key" "$data" > /dev/null; then
            echo "  [OK] 已添加 Transmission 下载客户端"
        else
            echo "  [ERROR] 添加 Transmission 下载客户端失败" >&2
        fi
    else
        echo "  [SKIP] Transmission 下载客户端已存在"
    fi
}

# 配置 Transmission → Radarr
setup_radarr_transmission() {
    local api_key="$1"
    local password="$2"

    echo "--- 配置 Radarr 下载客户端 ---"

    if ! radarr_has_transmission "$api_key"; then
        local data=$(cat <<EOF
{
    "enable": true,
    "name": "Transmission",
    "implementationName": "Transmission",
    "implementation": "TransmissionTorrent",
    "configContract": "TransmissionSettings",
    "fields": [
        {"name": "host", "value": "transmission"},
        {"name": "port", "value": 9091},
        {"name": "username", "value": "admin"},
        {"name": "password", "value": "$password"},
        {"name": "movieDirectory", "value": "/downloads"}
    ],
    "tags": []
}
EOF
        )
        if api_call "POST" "http://radarr:7878/api/v3/downloadclient" "$api_key" "$data" > /dev/null; then
            echo "  [OK] 已添加 Transmission 下载客户端"
        else
            echo "  [ERROR] 添加 Transmission 下载客户端失败" >&2
        fi
    else
        echo "  [SKIP] Transmission 下载客户端已存在"
    fi
}

# 配置 Jellyfin → Jellyseerr
setup_jellyseerr_jellyfin() {
    local host_ip="$1"
    local jellyfin_port="${2:-8096}"

    echo "--- 配置 Jellyseerr 媒体服务器 ---"

    if ! jellyseerr_has_jellyfin; then
        # Jellyseerr 使用初始化 API
        local data=$(cat <<EOF
{
    "ip": "jellyfin",
    "port": 8096,
    "useSsl": false,
    "urlBase": "",
    "apiKey": ""
}
EOF
        )
        if curl -s -o /dev/null -w "%{http_code}" \
            -X POST "http://jellyseerr:5055/api/v1/settings/jellyfin" \
            -H "Content-Type: application/json" \
            -d "$data" | grep -q "^2"; then
            echo "  [OK] 已配置 Jellyfin 媒体服务器"
        else
            echo "  [WARN] Jellyseerr 需要在 Web UI 中完成 Jellyfin 配置"
        fi
    else
        echo "  [SKIP] Jellyfin 媒体服务器已配置"
    fi
}

# 配置 Sonarr → Jellyseerr
setup_jellyseerr_sonarr() {
    local api_key="$1"
    local quality_profile="${2:-HD-1080p}"
    local root_folder="${3:-/tv}"

    echo "--- 配置 Jellyseerr Sonarr 服务 ---"

    if ! jellyseerr_has_sonarr; then
        local data=$(cat <<EOF
{
    "name": "Sonarr",
    "hostname": "sonarr",
    "port": 8989,
    "apiKey": "$api_key",
    "useSsl": false,
    "baseUrl": "",
    "activeProfileId": 1,
    "activeProfileName": "$quality_profile",
    "activeDirectory": "$root_folder",
    "is4k": false,
    "isDefault": true,
    "syncEnabled": true,
    "preventSearch": false
}
EOF
        )
        if curl -s -o /dev/null -w "%{http_code}" \
            -X POST "http://jellyseerr:5055/api/v1/service/sonarr" \
            -H "Content-Type: application/json" \
            -d "$data" | grep -q "^2"; then
            echo "  [OK] 已添加 Sonarr 服务"
        else
            echo "  [ERROR] 添加 Sonarr 服务失败" >&2
        fi
    else
        echo "  [SKIP] Sonarr 服务已存在"
    fi
}

# 配置 Radarr → Jellyseerr
setup_jellyseerr_radarr() {
    local api_key="$1"
    local quality_profile="${2:-HD-1080p}"
    local root_folder="${3:-/movies}"

    echo "--- 配置 Jellyseerr Radarr 服务 ---"

    if ! jellyseerr_has_radarr; then
        local data=$(cat <<EOF
{
    "name": "Radarr",
    "hostname": "radarr",
    "port": 7878,
    "apiKey": "$api_key",
    "useSsl": false,
    "baseUrl": "",
    "activeProfileId": 1,
    "activeProfileName": "$quality_profile",
    "activeDirectory": "$root_folder",
    "is4k": false,
    "isDefault": true,
    "syncEnabled": true,
    "preventSearch": false
}
EOF
        )
        if curl -s -o /dev/null -w "%{http_code}" \
            -X POST "http://jellyseerr:5055/api/v1/service/radarr" \
            -H "Content-Type: application/json" \
            -d "$data" | grep -q "^2"; then
            echo "  [OK] 已添加 Radarr 服务"
        else
            echo "  [ERROR] 添加 Radarr 服务失败" >&2
        fi
    else
        echo "  [SKIP] Radarr 服务已存在"
    fi
}

# ========================================
# 主配置函数
# ========================================

# 执行所有服务关联配置
setup_all_services() {
    local data_dir="$1"
    local host_ip="$2"
    local transmission_password="$3"
    local sonarr_quality="${SONARR_QUALITY_PROFILE:-HD-1080p}"
    local radarr_quality="${RADARR_QUALITY_PROFILE:-HD-1080p}"
    local sonarr_root="${SONARR_ROOT_FOLDER:-/tv}"
    local radarr_root="${RADARR_ROOT_FOLDER:-/movies}"
    local jellyfin_port="${JELLYFIN_PORT:-8096}"

    echo "=== 自动配置服务关联 ==="
    echo ""

    # 等待核心服务就绪
    echo "等待服务启动..."

    if ! wait_for_service "Prowlarr" "http://prowlarr:9696/ping" 60; then
        echo "错误: Prowlarr 未就绪，跳过关联配置" >&2
        return 1
    fi

    if ! wait_for_service "Sonarr" "http://sonarr:8989/ping" 60; then
        echo "错误: Sonarr 未就绪，跳过关联配置" >&2
        return 1
    fi

    if ! wait_for_service "Radarr" "http://radarr:7878/ping" 60; then
        echo "错误: Radarr 未就绪，跳过关联配置" >&2
        return 1
    fi

    if ! wait_for_service "Transmission" "http://transmission:9091" 30; then
        echo "错误: Transmission 未就绪，跳过关联配置" >&2
        return 1
    fi

    if ! wait_for_service "Jellyseerr" "http://jellyseerr:5055/api/v1/status" 60; then
        echo "错误: Jellyseerr 未就绪，跳过关联配置" >&2
        return 1
    fi

    if ! wait_for_service "Jellyfin" "http://jellyfin:8096/health" 60; then
        echo "错误: Jellyfin 未就绪，跳过关联配置" >&2
        return 1
    fi

    echo ""

    # 获取 API Keys
    echo "获取服务 API Keys..."

    local prowlarr_api_key
    prowlarr_api_key=$(get_prowlarr_api_key "$data_dir")
    if [ -z "$prowlarr_api_key" ]; then
        echo "错误: 无法获取 Prowlarr API Key" >&2
        return 1
    fi
    echo "  [OK] Prowlarr API Key"

    local sonarr_api_key
    sonarr_api_key=$(get_sonarr_api_key "$data_dir")
    if [ -z "$sonarr_api_key" ]; then
        echo "错误: 无法获取 Sonarr API Key" >&2
        return 1
    fi
    echo "  [OK] Sonarr API Key"

    local radarr_api_key
    radarr_api_key=$(get_radarr_api_key "$data_dir")
    if [ -z "$radarr_api_key" ]; then
        echo "错误: 无法获取 Radarr API Key" >&2
        return 1
    fi
    echo "  [OK] Radarr API Key"

    echo ""

    # 配置 Prowlarr → Sonarr/Radarr
    setup_prowlarr_apps "$data_dir" "$sonarr_api_key" "$radarr_api_key" "$prowlarr_api_key"
    echo ""

    # 配置 Transmission → Sonarr/Radarr
    setup_sonarr_transmission "$sonarr_api_key" "$transmission_password"
    setup_radarr_transmission "$radarr_api_key" "$transmission_password"
    echo ""

    # 配置 Jellyfin → Jellyseerr
    setup_jellyseerr_jellyfin "$host_ip" "$jellyfin_port"
    echo ""

    # 配置 Sonarr/Radarr → Jellyseerr
    setup_jellyseerr_sonarr "$sonarr_api_key" "$sonarr_quality" "$sonarr_root"
    setup_jellyseerr_radarr "$radarr_api_key" "$radarr_quality" "$radarr_root"
    echo ""

    echo "=== 服务关联配置完成 ==="
    echo ""
    echo "提示: 部分配置可能需要在 Web UI 中完善:"
    echo "  - Jellyseerr: 首次登录需绑定 Jellyfin 账户"
    echo "  - Prowlarr: 可添加更多索引器"
    echo ""
}
