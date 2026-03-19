---
name: home-container-tools
description: 家庭容器管理和工具集合，提供Docker容器维护、网络服务管理、系统监控等功能。用于管理家庭网络中的各种容器化服务，包括Jellyfin、Transmission、Radarr、Sonarr、Mihomo等。
---

# Home Container Tools

## 概述

管理 `/root/family-tools` 下通过 Docker Compose 部署的家庭服务。所有服务使用 `docker compose` 命令管理（现代 V2 语法），YML 文件位于 `/root/family-tools/<服务名>/docker-compose.yml`。

## 网络架构

### 网络拓扑

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              宿主机 (树莓派)                                  │
│                           192.168.31.10                                      │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                     family-network (bridge)                             │ │
│  │                         172.30.0.0/16                                   │ │
│  │                                                                         │ │
│  │   ┌─────────────────────────────────────────────────────────────────┐  │ │
│  │   │                      Caddy (反向代理)                            │  │ │
│  │   │                      172.30.0.11                                │  │ │
│  │   │                      端口: 80, 443                              │  │ │
│  │   │                      default_sni: lb.lan.xyz                    │  │ │
│  │   └──────────────────┬──────────────────────────────────────────────┘  │ │
│  │                      │                                                  │ │
│  │   ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐      │ │
│  │   │  Jellyfin   │ │   Sonarr    │ │   Radarr    │ │  Prowlarr   │      │ │
│  │   │ 172.30.0.5  │ │ 172.30.0.7  │ │ 172.30.0.6  │ │ 172.30.0.8  │      │ │
│  │   └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘      │ │
│  │                                                                          │ │
│  │   ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐      │ │
│  │   │Transmission │ │ Jellyseerr  │ │  Homepage   │ │ Metacubexd  │      │ │
│  │   │ 172.30.0.9  │ │172.30.0.10  │ │ 172.30.0.4  │ │ 172.30.0.3  │      │ │
│  │   └─────────────┘ └─────────────┘ └─────────────┘ └──────┬──────┘      │ │
│  │                                                               │          │ │
│  │   ┌─────────────────────────────────────────────────────────┐         │ │
│  │   │                     Mihomo (代理)                        │◄────────┘│ │
│  │   │                     172.30.0.2                          │          │ │
│  │   │                     端口: 7890, 9090                    │          │ │
│  │   │                     TUN: 已停用                         │          │ │
│  │   └─────────────────────────────────────────────────────────┘          │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  OpenClaw Gateway: 127.0.0.1:18789                                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 域名路由表

| 域名 | 后端服务 | 容器 IP:端口 |
|------|----------|-------------|
| `lb.lan.xyz` | OpenClaw Dashboard | 192.168.31.10:18789 |
| `openclaw.lan.xyz` | OpenClaw Dashboard | 192.168.31.10:18789 |
| `jellyfin.lan.xyz` | Jellyfin | 172.30.0.5:8096 |
| `sonarr.lan.xyz` | Sonarr | 172.30.0.7:8989 |
| `radarr.lan.xyz` | Radarr | 172.30.0.6:7878 |
| `prowlarr.lan.xyz` | Prowlarr | 172.30.0.8:9696 |
| `transmission.lan.xyz` | Transmission | 172.30.0.9:9091 |
| `jellyseerr.lan.xyz` | Jellyseerr | 172.30.0.10:5055 |
| `homepage.lan.xyz` | Homepage | 172.30.0.4:3000 |
| `clash.lan.xyz` | Metacubexd | 172.30.0.3:80 |

### 容器 IP 地址

| 容器名 | IP 地址 |
|--------|---------|
| mihomo | 172.30.0.2 |
| metacubexd | 172.30.0.3 |
| homepage | 172.30.0.4 |
| jellyfin | 172.30.0.5 |
| radarr | 172.30.0.6 |
| sonarr | 172.30.0.7 |
| prowlarr | 172.30.0.8 |
| transmission | 172.30.0.9 |
| jellyseerr | 172.30.0.10 |
| caddy | 172.30.0.11 |

### 关键配置

**Caddy 反向代理** (`/root/family-tools/caddy/`):
- 网络模式: bridge (family-network)
- `default_sni lb.lan.xyz` — 解决 SNI-less 客户端 TLS 问题
- `tls internal` — 自签名证书
- HTTP → HTTPS 自动跳转

**mihomo 代理** (`/root/family-tools/mihomo/`):
- TUN 模式: **已停用** (`tun: enable: false`)
- DNS: **已停用** (`dns: enable: false`)
- 仅提供普通 HTTP/SOCKS 代理 (端口 7890)

## 目录结构

```
/root/family-tools/
├── start-all.sh                      # 一键启动所有服务
├── homepage/         # 仪表盘 (172.30.0.4:3000)
├── jellyfin/         # 媒体服务器 (172.30.0.5:8096)
├── jellyseerr/       # 媒体请求 (172.30.0.10:5055)
├── sonarr/           # 电视剧管理 (172.30.0.7:8989)
├── radarr/           # 电影管理 (172.30.0.6:7878)
├── prowlarr/         # 索引器管理 (172.30.0.8:9696)
├── transmission/     # BT 下载 (172.30.0.9:9091)
├── mihomo/           # 代理服务 (172.30.0.2:7890, :9090)
├── caddy/            # 反向代理 (172.30.0.11:80/:443)
├── xiaomusic/        # 小米音乐 (:58090)
└── backups/          # 停用的服务备份
    ├── adguard/
    ├── jackett/
    └── zeroclaw/
```

## 核心命令

> **注意**: 使用 `docker compose`（V2 语法，无连字符）

### 单个服务操作

```bash
# 进入服务目录
cd /root/family-tools/<服务名>

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
/root/family-tools/start-all.sh

# 查看所有容器状态和 IP
docker network inspect family-network --format '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{"\n"}}{{end}}'

# 健康检查
for dir in /root/family-tools/*/; do
  if [ -f "$dir/docker-compose.yml" ]; then
    echo "=== $(basename "$dir") ==="
    cd "$dir" && docker compose ps
  fi
done
```

### 服务快速测试

```bash
# 测试所有 HTTPS 服务
for domain in lb.lan.xyz openclaw.lan.xyz jellyfin.lan.xyz sonarr.lan.xyz radarr.lan.xyz prowlarr.lan.xyz transmission.lan.xyz jellyseerr.lan.xyz homepage.lan.xyz clash.lan.xyz; do
  echo -n "$domain: "
  curl -sL -k --max-time 5 https://$domain 2>&1 | grep -o '<title>.*</title>' | head -1
done

# 测试 mihomo 代理
curl -sI --proxy http://192.168.31.10:7890 --max-time 10 http://www.google.com | head -1
```

## 服务说明

### Caddy 反向代理

- 配置文件: `/root/family-tools/caddy/Caddyfile`
- 端口: 80 (HTTP), 443 (HTTPS)
- 网络: bridge (family-network)
- 关键配置:
  - `default_sni lb.lan.xyz` — SNI-less 客户端回退
  - `tls internal` — 内部自签名证书

### 代理服务 (mihomo)

- **HTTP/SOCKS 代理**: `192.168.31.10:7890`
- **Dashboard**: `https://clash.lan.xyz` 或 `192.168.31.10:9090`
- **配置文件**: `/root/family-tools/mihomo/config/config.yaml`
- **重要**: TUN 模式已停用，仅提供普通代理

## 故障排查

### Caddy TLS 错误

如果遇到 `tlsv1 alert internal error`：
1. 确认 `default_sni lb.lan.xyz` 在 Caddyfile 全局选项中
2. 确认 lb.lan.xyz 已正确解析到服务器 IP
3. 重新创建容器: `docker compose down -v && docker compose up -d`

### 容器无法启动

```bash
cd /root/family-tools/<服务名>
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

### v2.4.0 (2026-03-19)
- Caddy 改为 bridge 网络模式
- 添加 `default_sni lb.lan.xyz` 解决 SNI-less TLS 问题
- 停用 mihomo TUN 模式和 DNS
- 更新网络拓扑图和 IP 地址表
- 添加域名路由表

### v2.3.0 (2026-03-19)
- 移除 jackett、zeroclaw（移到 backups/）
- 移除 AdGuard Home（路由器接管 DNS）
- 更新 mihomo 为 bridge 模式，端口映射 7890/7891/9090

### v2.2.1 (2026-03-18)
- 移除 AdGuard Home 服务（改用路由器静态 host 功能）
- 更新 jellyfin 端口为 :8096（释放 80/443 给 Caddy）

### v2.1.0 (2026-03-18)
- 新增 Caddy 反向代理服务，提供 OpenClaw Dashboard 的 HTTPS 访问
- Caddy 使用 host 网络模式，自签证书（`tls internal`）
