# Viewing Assist Kit

家庭媒体服务和工具链管理项目，运行在树莓派上。

## 概述

本项目整合了家庭媒体服务的 Docker Compose 配置和 OpenClaw 技能，提供一键部署和管理能力。

## 服务列表

| 服务 | 域名 | 端口 | 功能 |
|------|------|------|------|
| Caddy | *.${DOMAIN} | 80, 443 | 反向代理，HTTPS 自签名证书 |
| Homepage | homepage.${DOMAIN} | 3000 | 服务仪表盘 |
| Jellyfin | jellyfin.${DOMAIN} | 8096 | 媒体服务器 |
| Radarr | radarr.${DOMAIN} | 7878 | 电影管理 |
| Sonarr | sonarr.${DOMAIN} | 8989 | 电视剧管理 |
| Prowlarr | prowlarr.${DOMAIN} | 9696 | 索引器管理 |
| Transmission | transmission.${DOMAIN} | 9091 | BT 下载 |
| Jellyseerr | jellyseerr.${DOMAIN} | 5055 | 媒体请求管理 |

## 网络架构

所有服务使用 `family-network` bridge 网络，通过 Docker 内置 DNS 实现服务间通信（直接使用容器名称），Caddy 反向代理统一对外提供服务。

```
┌─────────────────────────────────────────────────────────────────┐
│                        宿主机 (树莓派)                           │
│                      ${HOST_IP}                                 │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                 family-network (bridge)                    │ │
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
│  │    ┌─────────┐ ┌─────────┐ ┌─────────┐                    │ │
│  │    │Transmis.│ │Jellyseer│ │Homepage │                    │ │
│  │    └─────────┘ └─────────┘ └─────────┘                    │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 快速开始

### 一键部署（推荐）

```bash
# 交互式部署（可选择模式）
./scripts/deploy.sh

# 端口模式部署（默认，无需域名）
./scripts/deploy.sh -q 192.168.1.100

# 域名模式部署（需要配置 DNS）
./scripts/deploy.sh -q 192.168.1.100 -m domain

# 仅生成配置，不启动服务
./scripts/deploy.sh --dry-run
```

### 部署模式说明

| 模式 | 说明 | 访问方式 | 需要配置 |
|------|------|----------|----------|
| **port** (默认) | 端口映射模式 | `http://IP:端口` | 无 |
| **domain** | 域名反向代理模式 | `https://域名` | DNS 或 /etc/hosts |

#### 端口模式访问地址

| 服务 | 访问地址 |
|------|----------|
| Homepage | `http://192.168.1.100:3000` |
| Jellyfin | `http://192.168.1.100:8096` |
| Sonarr | `http://192.168.1.100:8989` |
| Radarr | `http://192.168.1.100:7878` |
| Prowlarr | `http://192.168.1.100:9696` |
| Transmission | `http://192.168.1.100:9091` |
| Jellyseerr | `http://192.168.1.100:5055` |

#### 域名模式配置

在本地 DNS 或 /etc/hosts 添加：
```
192.168.1.100  homepage.home.local jellyfin.home.local sonarr.home.local
192.168.1.100  radarr.home.local prowlarr.home.local transmission.home.local jellyseerr.home.local
```

部署脚本会自动：
- 检查前置条件（Docker、端口、磁盘空间等）
- 生成配置文件和目录结构
- 创建 Docker 网络
- 按依赖顺序启动服务
- 验证服务状态

### 手动部署

```bash
# 1. 创建网络
docker network create family-network

# 2. 配置环境变量
cp .env.example .env
# 编辑 .env 填入实际值（特别是 DEPLOY_MODE）

# 3. 启动服务
./scripts/start-all.sh
```

### 命令行参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-q, --quick <ip>` | 快速部署 | - |
| `-m, --mode <mode>` | 部署模式: port 或 domain | `port` |
| `-d, --data <path>` | 数据根目录 | `/srv/media` |
| `-D, --domain <domain>` | 域名后缀 | `home.local` |
| `-u, --user <uid>:<gid>` | 运行用户 | `1000:1000` |
| `--dry-run` | 仅生成配置 | - |

部署脚本会自动：
- 检查前置条件（Docker、端口、磁盘空间等）
- 生成配置文件和目录结构
- 创建 Docker 网络
- 按依赖顺序启动服务
- 验证服务状态

### 手动部署

```bash
# 1. 创建网络
docker network create family-network

# 2. 配置环境变量
cp .env.example .env
# 编辑 .env 填入实际值

# 3. 启动服务
./scripts/start-all.sh
```

### 命令行参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-q, --quick <ip>` | 快速部署 | - |
| `-d, --data <path>` | 数据根目录 | `/srv/media` |
| `-D, --domain <domain>` | 域名后缀 | `home.local` |
| `-u, --user <uid>:<gid>` | 运行用户 | `1000:1000` |
| `--dry-run` | 仅生成配置 | - |

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
├── scripts/               # 工具脚本
│   ├── deploy.sh          # 一键部署脚本
│   ├── start-all.sh       # 启动所有服务
│   ├── stop-all.sh        # 停止所有服务
│   └── lib/               # 工具库
├── skills/                # OpenClaw 技能
│   └── home-container-tools/
└── docs/                  # 文档
```

## 域名配置

在本地 DNS 或 /etc/hosts 添加：

```
192.168.1.100  jellyfin.home.local sonarr.home.local radarr.home.local
192.168.1.100  prowlarr.home.local transmission.home.local jellyseerr.home.local
192.168.1.100  homepage.home.local
```

## 许可证

GNU General Public License v3.0
