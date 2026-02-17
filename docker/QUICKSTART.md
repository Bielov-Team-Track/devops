# Docker Development - Quick Start Guide

Get all your Bielov Spike microservices running in Docker with hot reload and remote debugging in under 5 minutes.

## Prerequisites

-   Docker Desktop installed and running
-   Docker Compose v2.22+ (for watch feature)
-   8GB+ RAM allocated to Docker
-   VS Code or Visual Studio 2022

## Quick Start

### 1. Start All Services

```bash
cd infrastructure/docker

# Start everything with hot reload
docker compose -f docker-compose.Development.yml watch
```

This will start:

-   PostgreSQL (port 5432)
-   PgAdmin (http://localhost:8080)
-   7 microservices with hot reload + debugging
-   Nginx reverse proxy (port 8000)

### 2. Verify Services

```bash
# Check all containers are running
docker ps

# Test a service
curl http://localhost:5005/health  # auth-service
curl http://localhost:5010/health  # events-service
```

### 3. Attach Debugger

**VS Code:**

1. Press F5
2. Select "Attach to [Service Name]"
3. Set breakpoints and debug

**Visual Studio:**

1. Debug → Attach to Process
2. Connection: Docker (Linux Container)
3. Select container and dotnet process

See [DEBUGGING.md](./DEBUGGING.md) for detailed instructions.

## Service URLs

| Service            | URL                   | Debugger Port |
| ------------------ | --------------------- | ------------- |
| Auth               | http://localhost:5005 | 10000         |
| Events             | http://localhost:5010 | 10001         |
| Profiles           | http://localhost:5170 | 10002         |
| Messages           | http://localhost:5180 | 10003         |
| Messages WebSocket | http://localhost:5181 | 10004         |
| Clubs              | http://localhost:5020 | 10005         |
| Notifications      | http://localhost:5030 | 10006         |
| PgAdmin            | http://localhost:8080 | -             |
| Nginx Gateway      | http://localhost:8000 | -             |

## Database Access

**PgAdmin UI:** http://localhost:8080

-   Email: `admin@volleyer.com`
-   Password: `admin123`

**Direct Connection:**

```bash
# Via psql
docker exec -it volleyer-postgres psql -U volleyer_user -d volleyer_auth

# Connection string for tools
Host=localhost;Port=5432;Database=volleyer_auth;Username=volleyer_user;Password=volleyer_password_dev
```

## Hot Reload

Just edit your code and save. `dotnet watch` will automatically:

-   Detect changes
-   Rebuild the project
-   Restart the service

No need to restart containers manually.

## Common Commands

```bash
# View logs for all services
docker compose -f docker-compose.Development.yml logs -f

# View logs for one service
docker compose -f docker-compose.Development.yml logs -f auth-service

# Restart a service
docker compose -f docker-compose.Development.yml restart auth-service

# Stop everything
docker compose -f docker-compose.Development.yml down

# Rebuild a service
docker compose -f docker-compose.Development.yml build auth-service

# Start only specific services
docker compose -f docker-compose.Development.yml up postgres auth-service events-service
```

## Environment Setup

Create `.env` file in `infrastructure/docker/` if needed:

```env
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
AWS_DEFAULT_REGION=us-east-1
```

## Troubleshooting

**Services won't start?**

```bash
# Check Docker is running
docker ps

# Check logs
docker compose -f docker-compose.Development.yml logs

# Clean rebuild
docker compose -f docker-compose.Development.yml down -v
docker compose -f docker-compose.Development.yml build --no-cache
docker compose -f docker-compose.Development.yml watch
```

**Can't attach debugger?**

```bash
# Verify vsdbg is installed
docker exec volleyer-auth-dev ls -la /vsdbg

# Check dotnet process is running
docker exec volleyer-auth-dev ps aux
```

**Hot reload not working?**

-   Check volume mounts: `docker inspect volleyer-auth-dev | grep Mounts -A 20`
-   Ensure files aren't in bin/ or obj/ (these are ignored)
-   Try restarting the service

**Port conflicts?**

```bash
# Find what's using the port
netstat -ano | findstr :5005  # Windows
lsof -i :5005                 # Mac/Linux

# Edit docker-compose.Development.yml to use different ports
```

## Architecture

```
┌─────────────────────────────────────────────┐
│           Docker Network                    │
│                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │  Auth    │  │ Events   │  │ Profiles │ │
│  │  :5005   │  │ :5010    │  │ :5170    │ │
│  └──────────┘  └──────────┘  └──────────┘ │
│                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │ Messages │  │  Clubs   │  │  Notify  │ │
│  │ :5180    │  │ :5020    │  │ :5030    │ │
│  └──────────┘  └──────────┘  └──────────┘ │
│                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │ Socket   │  │Postgres  │  │ PgAdmin  │ │
│  │ :5181    │  │ :5432    │  │ :8080    │ │
│  └──────────┘  └──────────┘  └──────────┘ │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │          Nginx :8000                 │  │
│  └──────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

## What's Configured

-   **Hot Reload**: `dotnet watch` running in each service
-   **Remote Debugging**: vsdbg installed on port 10000+
-   **Volume Mounts**: Source code synced for live editing
-   **Docker Watch**: Automatic file sync from host to container
-   **Health Checks**: PostgreSQL monitored for service startup
-   **Networking**: All services in shared bridge network

## Next Steps

1. Read [DEBUGGING.md](./DEBUGGING.md) for detailed debugging setup
2. Configure your IDE's launch.json for remote debugging
3. Start developing with hot reload
4. Deploy to production using docker-compose.Production.yml

## Development Workflow

1. **Start services**: `docker compose watch`
2. **Edit code**: Make changes in your IDE
3. **Auto-reload**: Watch mode detects and rebuilds
4. **Debug**: Attach debugger when needed
5. **Test**: Services run with full database access
6. **Commit**: All changes persist to your host

That's it! Happy coding!
