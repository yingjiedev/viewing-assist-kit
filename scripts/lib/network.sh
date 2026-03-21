#!/bin/bash
# 网络管理模块

set -e

# 创建 Docker 网络
create_network() {
    local network_name="family-network"
    local subnet="$1"

    if docker network inspect "$network_name" &>/dev/null; then
        echo "[OK] 网络 $network_name 已存在"
        return 0
    fi

    echo "创建 Docker 网络: $network_name ($subnet)"
    docker network create --subnet="$subnet" "$network_name"
    echo "[OK] 网络创建成功"
}

# 删除 Docker 网络
remove_network() {
    local network_name="family-network"

    if ! docker network inspect "$network_name" &>/dev/null; then
        echo "[OK] 网络 $network_name 不存在，无需删除"
        return 0
    fi

    echo "删除 Docker 网络: $network_name"
    docker network rm "$network_name"
    echo "[OK] 网络删除成功"
}

# 检查网络是否存在
check_network() {
    local network_name="family-network"

    if docker network inspect "$network_name" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# 显示网络信息
show_network_info() {
    local network_name="family-network"

    if ! check_network; then
        echo "网络 $network_name 不存在"
        return 1
    fi

    echo "=== 网络信息 ==="
    docker network inspect "$network_name" --format '{{.Name}}: {{.IPAM.Config}}'
    echo ""

    echo "=== 已连接的容器 ==="
    docker network inspect "$network_name" --format '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{"\n"}}{{end}}'
}
