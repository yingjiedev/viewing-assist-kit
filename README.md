# Viewing Assist Kit

家庭媒体服务和工具链管理项目，运行在树莓派上。

## 概述

本项目整合了家庭媒体服务的 Docker Compose 配置和 OpenClaw 技能，提供一键部署和管理能力。

## 服务列表

| 服务 | 域名 | 容器 IP | 端口 | 功能 |
|------|------|---------|------|------|
| Caddy | *.lan.xyz | 172.30.0.11 | 80, 443 | 反向代理，HTTPS 自签名证书 |
| Mihomo | clash.lan.xyz | 172.30.0.2 | 7890, 9090 | 代理服务 |
| Homepage | homepage.lan.xyz | 172.30.0.4 | 3000 | 服务仪表盘 |
| Jellyfin | jellyfin.lan.xyz | 172.30.0.5 | 8096 | 媒体服务器 |
| Radarr | radarr.lan.xyz | 172.30.0.6 | 7878 | 电影管理 |
| Sonarr | sonarr.lan.xyz | 172.30.0.7 | 8989 | 电视剧管理 |
| Prowlarr | prowlarr.lan.xyz | 172.30.0.8 | 9696 | 索引器管理 |
| Transmission | transmission.lan.xyz | 172.30.0.9 | 9091 | BT 下载 |
| Jellyseerr | jellyseerr.lan.xyz | 172.30.0.10 | 5055 | 媒体请求管理 |

## 网络架构

所有服务使用 `family-network` bridge 网络 (172.30.0.0/16)，通过 Caddy 反向代理统一对外提供服务。

```
┌─────────────────────────────────────────────────────────────────┐
│                        宿主机 (树莓派)                           │
│                      192.168.31.10                              │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                 family-network (bridge)                    │ │
│  │                    172.30.0.0/16                           │ │
│  │                                                           │ │
│  │   ┌─────────────────────────────────────────────────────┐ │ │
│  │   │              Caddy (反向代理) 172.30.0.11            │ │ │
│  │   │              端口: 80, 443                           │ │ │
│  │   └──────────────────────┬──────────────────────────────┘ │ │
│  │                          │                                │ │
│  │    ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐       │ │
│  │    │Jellyfin │ │ Sonarr  │ │ Radarr  │ │Prowlarr │       │ │
│  │    │.0.5:8096│ │.0.7:8989│ │.0.6:7878│ │.0.8:9696│       │ │
│  │    └─────────┘ └─────────┘ └─────────┘ └─────────┘       │ │
│  │                                                           │ │
│  │    ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐       │ │
│  │    │Transmis.│ │Jellyseer│ │Homepage │ │ Mihomo  │       │ │
│  │    │.0.9:9091│ │.0.10:505│ │.0.4:3000│ │.0.2:7890│       │ │
│  │    └─────────┘ └─────────┘ └─────────┘ └─────────┘       │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 快速开始

### 1. 创建网络

```bash
docker network create --subnet=172.30.0.0/16 family-network
```

### 2. 配置环境变量

```bash
cp .env.example .env
# 编辑 .env 填入实际值
```

### 3. 启动服务

```bash
# 启动所有服务
./scripts/start-all.sh

# 或单独启动
cd services/caddy && docker compose up -d
```

## 目录结构

```
viewing-assist-kit/
├── services/              # Docker Compose 配置
│   ├── caddy/             # 反向代理
│   ├── mihomo/            # 代理服务
│   ├── jellyfin/          # 媒体服务器
│   ├── sonarr/            # 电视剧管理
│   ├── radarr/            # 电影管理
│   ├── prowlarr/          # 索引器管理
│   ├── transmission/      # BT 下载
│   ├── jellyseerr/        # 媒体请求
│   └── homepage/          # 仪表盘
├── skills/                # OpenClaw 技能
│   └── home-container-tools/
├── docs/                  # 文档
└── scripts/               # 工具脚本
```

## 域名配置

在本地 DNS 或 /etc/hosts 添加：

```
192.168.31.10  lb.lan.xyz openclaw.lan.xyz
192.168.31.10  jellyfin.lan.xyz sonarr.lan.xyz radarr.lan.xyz
192.168.31.10  prowlarr.lan.xyz transmission.lan.xyz jellyseerr.lan.xyz
192.168.31.10  homepage.lan.xyz clash.lan.xyz
```

## 许可证

MIT License
