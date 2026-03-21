# AGENTS.md

## Project Overview

Viewing Assist Kit - Docker Compose orchestration for home media services on Raspberry Pi.
8 services: Jellyfin, Sonarr, Radarr, Prowlarr, Transmission, Jellyseerr, Homepage, Caddy.

## Tech Stack

- Docker Compose (YAML)
- Bash scripts
- Caddy reverse proxy

## Commands

### One-Click Deploy (Recommended)

```bash
./scripts/deploy.sh                    # Interactive deployment
./scripts/deploy.sh -q 192.168.1.100   # Quick deployment (only need host IP)
./scripts/deploy.sh --dry-run          # Dry run (generate config only)
```

### Service Management

```bash
./scripts/start-all.sh                                # Start all services (dependency order)
./scripts/stop-all.sh                                 # Stop all services
cd services/<service-name> && docker compose up -d    # Start individual service
cd services/<service-name> && docker compose down     # Stop individual service
cd services/<service-name> && docker compose logs -f  # View logs
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

# Validate shell scripts syntax
bash -n scripts/deploy.sh
for f in scripts/lib/*.sh; do bash -n "$f"; done
```

### Environment Setup

```bash
cp .env.example .env
docker network create family-network
```

## Code Style

### YAML (docker-compose.yml)

- Use 4-space indentation
- Environment variables: `UPPER_SNAKE_CASE`
- Service names: `lowercase-kebab-case`
- Always specify image version tags, avoid `latest`
- Use environment variables from `.env`, never hardcode secrets
- Format: `key: value` (space after colon)
- Include `healthcheck` for all services
- Use `depends_on` with `condition: service_started` for dependencies

### Bash Scripts

- Start with `#!/bin/bash` and `set -e`
- Use `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` for path resolution
- Quote all variables: `"$VAR"`
- Use arrays for ordered lists: `SERVICES=("a" "b" "c")`
- Error messages: `echo "错误: description" >&2`
- Exit with `exit 1` on failure
- Load modules via `source "$SCRIPT_DIR/lib/module.sh"`

### Imports

- Main script sources all modules from `scripts/lib/`
- Modules use `SCRIPT_DIR` relative paths
- No circular dependencies between modules

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
3. **Service order**: Start dependencies first (prowlarr, transmission), then (sonarr, radarr), then jellyseerr, caddy last
4. **Secrets**: Never commit `.env` or config files with credentials
5. **Volumes**: Use relative paths or environment variables for host mounts
6. **User permissions**: Default PUID=1000, PGID=1000 (non-root)

## Error Handling

- Use `set -e` to exit on first error
- Validate all user inputs before processing
- Check prerequisites (Docker, disk space, ports) before deployment
- Provide clear error messages in Chinese: `echo "错误: ..." >&2`

## Git Workflow

- Main branch: `main`
- Commit messages: `type: description` (e.g., `fix:`, `feat:`, `refactor:`)
- No force push to main
- Run validation before committing changes to docker-compose files
- PRs require review before merge
