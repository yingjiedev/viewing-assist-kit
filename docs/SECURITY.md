# 安全最佳实践

本文档介绍部署本项目时应遵循的安全最佳实践。

## 用户权限

### 避免 root 用户运行

默认配置中部分服务使用 `PUID=0` 和 `PGID=0`（root 用户），这在测试环境中可行，但生产环境建议：

1. 创建专用用户和用户组：
```bash
sudo groupadd -g 1000 media
sudo useradd -u 1000 -g media -s /bin/false media
```

2. 修改 `.env` 文件：
```env
PUID=1000
PGID=1000
```

3. 确保数据目录权限正确：
```bash
chown -R media:media /path/to/media /path/to/downloads
```

## 网络安全

### 内网隔离

- 所有服务仅绑定到内网 IP
- 通过 Caddy 反向代理统一入口
- 建议在路由器层面阻止外网访问

### HTTPS

- Caddy 使用自签名证书，浏览器会警告
- 如需公网访问，建议：
  - 使用 Let's Encrypt（需公网域名）
  - 或使用 Tailscale/ZeroTier 等 VPN

## 密码安全

### Transmission

- 务必修改默认密码
- 使用强密码（至少 12 位，包含大小写字母、数字、符号）

```env
TRANSMISSION_USERNAME=your_username
TRANSMISSION_PASSWORD=your_strong_password_here
```

### Jellyfin

首次启动后立即：
1. 访问 http://HOST_IP:8096 完成初始设置
2. 创建管理员账户
3. 禁用匿名访问

## 资源限制

建议为服务添加资源限制，防止单个服务占用过多资源：

```yaml
services:
  jellyfin:
    # ...
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M
```

## 备份策略

### 需要备份的目录

- `services/*/config/` - 各服务配置
- `.env` - 环境变量

### 不需要备份的目录

- `services/*/cache/` - 缓存数据
- 下载目录（可重新下载）

## 更新维护

定期更新镜像：

```bash
# 拉取最新镜像
docker compose pull

# 重新创建容器
docker compose up -d
```

## 日志审计

查看服务日志：

```bash
# 查看特定服务日志
docker compose logs -f

# 查看所有服务日志
for dir in services/*/; do
  cd "$dir" && docker compose logs --tail=50
done
```
