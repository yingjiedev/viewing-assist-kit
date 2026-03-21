# Viewing Assist Kit

家庭媒体服务和工具链管理项目，运行在树莓派上。

## 概述

本项目整合了家庭媒体服务的 Docker Compose 配置和 OpenClaw 技能，提供一键部署和管理能力。

## 服务列表

| 服务 | 域名 | 容器 IP | 端口 | 功能 |
|------|------|---------|------|------|
| Caddy | *.${DOMAIN} | ${CADDY_IP} | 80, 443 | 反向代理，HTTPS 自签名证书 |
| Homepage | homepage.${DOMAIN} | ${HOMEPAGE_IP} | 3000 | 服务仪表盘 |
| Jellyfin | jellyfin.${DOMAIN} | ${JELLYFIN_IP} | 8096 | 媒体服务器 |
| Radarr | radarr.${DOMAIN} | ${RADARR_IP} | 7878 | 电影管理 |
| Sonarr | sonarr.${DOMAIN} | ${SONARR_IP} | 8989 | 电视剧管理 |
| Prowlarr | prowlarr.${DOMAIN} | ${PROWLARR_IP} | 9696 | 索引器管理 |
| Transmission | transmission.${DOMAIN} | ${TRANSMISSION_IP} | 9091 | BT 下载 |
| Jellyseerr | jellyseerr.${DOMAIN} | ${JELLYSEERR_IP} | 5055 | 媒体请求管理 |

## 网络架构

所有服务使用 `family-network` bridge 网络，通过 Caddy 反向代理统一对外提供服务。

```
┌─────────────────────────────────────────────────────────────────┐
│                        宿主机 (树莓派)                           │
│                      ${HOST_IP}                                 │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                 family-network (bridge)                    │ │
│  │                    ${NETWORK_SUBNET}                       │ │
│  │                                                           │ │
│  │   ┌─────────────────────────────────────────────────────┐ │ │
│  │   │              Caddy (反向代理)                        │ │ │
│  │   │              端口: 80, 443                           │ │ │
│  │   └──────────────────────┬──────────────────────────────┘ │ │
│  │                          │                                │ │
│  │    ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐       │ │
│  │    │Jellyfin │ │ Sonarr  │ │ Radarr  │ │Prowlarr │       │ │
│  │    └─────────┘ └─────────┘ └─────────┘ └─────────┘       │ │
│  │                                                           │ │
│  │    ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐       │ │
│  │    │Transmis.│ │Jellyseer│ │Homepage │ │ Mihomo  │       │ │
│  │    └─────────┘ └─────────┘ └─────────┘ └─────────┘       │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 快速开始

### 1. 创建网络

```bash
docker network create --subnet=${NETWORK_SUBNET} family-network
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
${HOST_IP}  lb.${DOMAIN} openclaw.${DOMAIN}
${HOST_IP}  jellyfin.${DOMAIN} sonarr.${DOMAIN} radarr.${DOMAIN}
${HOST_IP}  prowlarr.${DOMAIN} transmission.${DOMAIN} jellyseerr.${DOMAIN}
${HOST_IP}  homepage.${DOMAIN}
```

## 许可证

GNU General Public License v3.0
