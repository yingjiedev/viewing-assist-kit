---
name: home-container-tools
description: 家庭容器管理和工具集合，提供Docker容器维护、网络服务管理、系统监控等功能。用于管理家庭网络中的各种容器化服务，包括Jellyfin、Transmission、Radarr、Sonarr、Mihomo等。
---

# Home Container Tools

## 概述

管理通过 Docker Compose 部署的家庭服务。所有服务使用 `docker compose` 命令管理（现代 V2 语法）。

## 网络架构

### 网络拓扑

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              宿主机 (树莓派)                                  │
│                           ${HOST_IP}                                         │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                     family-network (bridge)                             │ │
│  │                         ${NETWORK_SUBNET}                               │ │
│  │                                                                         │
│  │   ┌─────────────────────────────────────────────────────────────────┐  │ │
│  │   │                      Caddy (反向代理)                            │  │ │
│  │   │                      端口: 80, 443                              │  │ │
│  │   │                      default_sni: lb.${DOMAIN}                  │  │ │
│  │   └──────────────────┬──────────────────────────────────────────────┘  │ │
│  │                      │                                                  │ │
│  │   ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐      │ │
│  │   │  Jellyfin   │ │   Sonarr    │ │   Radarr    │ │  Prowlarr   │      │ │
│  │   └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘      │ │
│  │                                                                          │ │
│  │   ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐      │ │
│  │   │Transmission │ │ Jellyseerr  │ │  Homepage   │ │ Metacubexd  │      │ │
│  │   └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘      │ │
│  │                                                               │          │ │
│  │   ┌─────────────────────────────────────────────────────────┐         │ │
│  │   │                     Mihomo (代理)                        │◄────────┘│ │
│  │   │                     端口: 7890, 9090                    │          │ │
│  │   │                     TUN: 已停用                         │          │ │
│  │   └─────────────────────────────────────────────────────────┘          │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  OpenClaw Gateway: ${HOST_IP}:${OPENCLAW_PORT}                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 域名路由表

| 域名 | 后端服务 |
|------|----------|
| `lb.${DOMAIN}` | OpenClaw Dashboard |
| `openclaw.${DOMAIN}` | OpenClaw Dashboard |
| `jellyfin.${DOMAIN}` | Jellyfin |
| `sonarr.${DOMAIN}` | Sonarr |
| `radarr.${DOMAIN}` | Radarr |
| `prowlarr.${DOMAIN}` | Prowlarr |
| `transmission.${DOMAIN}` | Transmission |
| `jellyseerr.${DOMAIN}` | Jellyseerr |
| `homepage.${DOMAIN}` | Homepage |
| `clash.${DOMAIN}` | Metacubexd |

### 关键配置

**Caddy 反向代理**:
- 网络模式: bridge (family-network)
- `default_sni lb.${DOMAIN}` — 解决 SNI-less 客户端 TLS 问题
- `tls internal` — 自签名证书
- HTTP → HTTPS 自动跳转

**mihomo 代理**:
- TUN 模式: **已停用** (`tun: enable: false`)
- DNS: **已停用** (`dns: enable: false`)
- 仅提供普通 HTTP/SOCKS 代理 (端口 7890)

## 核心命令

> **注意**: 使用 `docker compose`（V2 语法，无连字符）

### 单个服务操作

```bash
# 进入服务目录
cd services/<服务名>

# 启动
docker compose up -d

# 停止
docker compose down

# 重启
docker compose restart

# 查看日志
docker compose logs -f

# 拉取最新镜像并重启（升级）
docker compose pull && docker compose up -d
```

### 一键操作

```bash
# 启动所有服务
./scripts/start-all.sh

# 查看所有容器状态
docker network inspect family-network --format '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{"\n"}}{{end}}'

# 健康检查
for dir in services/*/; do
  if [ -f "$dir/docker-compose.yml" ]; then
    echo "=== $(basename "$dir") ==="
    cd "$dir" && docker compose ps
  fi
done
```

### 服务快速测试

```bash
# 测试 mihomo 代理
curl -sI --proxy http://${HOST_IP}:7890 --max-time 10 http://www.google.com | head -1
```

## 故障排查

### Caddy TLS 错误

如果遇到 `tlsv1 alert internal error`：
1. 确认 `default_sni lb.${DOMAIN}` 在 Caddyfile 全局选项中
2. 确认域名已正确解析到服务器 IP
3. 重新创建容器: `docker compose down -v && docker compose up -d`

### 容器无法启动

```bash
cd services/<服务名>
docker compose logs --tail=50    # 查看最近日志
docker compose config            # 验证配置语法
```

### 网络不通

```bash
# 检查网络
docker network inspect family-network

# 测试容器间连通性
docker exec <容器名> ping <目标容器名>
```

## 版本历史

### v2.4.0
- Caddy 改为 bridge 网络模式
- 添加 `default_sni` 解决 SNI-less TLS 问题
- 停用 mihomo TUN 模式和 DNS
- 配置脱敏处理
