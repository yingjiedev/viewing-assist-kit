#!/bin/bash
# 前置条件检查模块

set -e

# 检查 Docker 是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "错误: Docker 未安装，请先安装 Docker" >&2
        return 1
    fi

    if ! docker info &> /dev/null; then
        echo "错误: Docker 服务未启动或当前用户无权限" >&2
        return 1
    fi

    echo "[OK] Docker 已安装: $(docker --version)"
}

# 检查 Docker Compose 是否可用
check_docker_compose() {
    if ! docker compose version &> /dev/null; then
        echo "错误: Docker Compose V2 未安装，请升级 Docker" >&2
        return 1
    fi

    echo "[OK] Docker Compose 已安装: $(docker compose version --short)"
}

# 检查端口是否被占用
check_ports() {
    local ports=("80" "443")
    local occupied=()

    for port in "${ports[@]}"; do
        if ss -tlnp | grep -q ":${port} "; then
            occupied+=("$port")
        fi
    done

    if [ ${#occupied[@]} -gt 0 ]; then
        echo "错误: 以下端口已被占用: ${occupied[*]}" >&2
        return 1
    fi

    echo "[OK] 端口 80, 443 可用"
}

# 检查硬件加速设备
check_hw_accel() {
    if [ -e /dev/dri ]; then
        echo "[OK] 硬件加速设备 /dev/dri 存在"
        export HAS_HW_ACCEL=true
    else
        echo "[WARN] 硬件加速设备 /dev/dri 不存在，将禁用硬件加速"
        export HAS_HW_ACCEL=false
    fi
}

# 检查磁盘空间
check_disk_space() {
    local data_dir="$1"
    local parent_dir="$(dirname "$data_dir")"

    if [ ! -d "$parent_dir" ]; then
        echo "错误: 目标目录的父目录不存在: $parent_dir" >&2
        return 1
    fi

    local available_kb
    available_kb=$(df -k "$parent_dir" | awk 'NR==2 {print $4}')
    local available_gb=$((available_kb / 1024 / 1024))

    if [ "$available_gb" -lt 10 ]; then
        echo "错误: 磁盘空间不足，需要至少 10GB，当前可用 ${available_gb}GB" >&2
        return 1
    fi

    echo "[OK] 磁盘空间充足: 可用 ${available_gb}GB"
}

# 检查系统架构
check_arch() {
    local arch
    arch=$(uname -m)

    case "$arch" in
        x86_64|amd64)
            echo "[OK] 系统架构: amd64"
            ;;
        aarch64|arm64)
            echo "[OK] 系统架构: arm64"
            ;;
        armv7l|armhf)
            echo "[OK] 系统架构: armhf"
            ;;
        *)
            echo "[WARN] 未知架构: $arch，部分镜像可能不支持"
            ;;
    esac
}

# 执行所有检查
run_all_checks() {
    local data_dir="${1:-/srv/media}"

    echo "=== 环境检查 ==="
    check_docker || return 1
    check_docker_compose || return 1
    check_ports || return 1
    check_hw_accel
    check_disk_space "$data_dir" || return 1
    check_arch
    echo ""
}
