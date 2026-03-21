# AGENTS.md

## Project Overview

Viewing Assist Kit - Docker Compose orchestration for home media services on Raspberry Pi.

## Tech Stack

- Docker Compose (YAML)
- Bash scripts
- Caddy reverse proxy
- Multiple media services (Jellyfin, Sonarr, Radarr, Prowlarr, Transmission, Jellyseerr)

## Commands

### One-Click Deploy (Recommended)

```bash
# Interactive deployment
./scripts/deploy.sh

# Quick deployment (only need host IP)
./scripts/deploy.sh -q 192.168.1.100

# Dry run (generate config only)
./scripts/deploy.sh --dry-run
```

### Service Management

```bash
# Start all services (order matters: dependencies first)
./scripts/start-all.sh

# Stop all services
./scripts/stop-all.sh

# Start individual service
cd services/<service-name> && docker compose up -d

# Stop individual service
cd services/<service-name> && docker compose down

# View logs
cd services/<service-name> && docker compose logs -f

# Restart a service
cd services/<service-name> && docker compose restart
```

### Validation

```bash
# Validate all docker-compose files
for dir in services/*/; do
  docker compose -f "$dir/docker-compose.yml" config --quiet
done

# Validate Caddyfile syntax
docker run --rm -v ./services/caddy/Caddyfile:/etc/caddy/Caddyfile caddy:latest caddy validate --config /etc/caddy/Caddyfile

# Check container status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Environment Setup

```bash
# Create .env from template
cp .env.example .env

# Create Docker network
docker network create --subnet=${NETWORK_SUBNET} family-network
```

## Code Style

### YAML (docker-compose.yml)

- Use 4-space indentation
- Environment variables: `UPPER_SNAKE_CASE`
- Service names: `lowercase-kebab-case`
- Always specify image version tags, avoid `latest`
- Use environment variables from `.env`, never hardcode secrets
- Format: `key: value` (space after colon)

### Bash Scripts

- Start with `#!/bin/bash` and `set -e`
- Use `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` for path resolution
- Quote all variables: `"$VAR"`
- Use arrays for ordered lists
- Include error messages: `echo "错误: description" >&2`
- Exit with `exit 1` on failure

### Caddy Configuration

- Use `{$ENV_VAR}` syntax for environment variables
- One site block per service
- Use `tls internal` for self-signed certificates
- Group related directives together

## Directory Structure

```
services/          # Each service has its own directory
  <service>/
    docker-compose.yml
scripts/           # Shell scripts for batch operations
  deploy.sh        # One-click deployment script
  lib/             # Utility modules (check, config, network, service)
  templates/       # Configuration templates
docs/              # Documentation
skills/            # OpenClaw skill definitions
```

## Key Conventions

1. **Network**: All services use `family-network` bridge
2. **Environment**: Load from `.env` file, template in `.env.example`
3. **Service order**: Start dependencies first (jellyfin, etc.), Caddy last
4. **Secrets**: Never commit `.env` or config files with credentials
5. **Volumes**: Use relative paths or environment variables for host mounts

## Git Workflow

- Main branch: `main`
- Commit messages: `type: description` (e.g., `fix:`, `feat:`, `refactor:`)
- No force push to main
- Run validation before committing changes to docker-compose files
