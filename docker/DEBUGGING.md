# Remote Debugging Guide for Dockerized Services

This guide explains how to attach a debugger to your Dockerized .NET services for development.

## Overview

All services are configured with:
- **Hot Reload**: Automatic code reloading using `dotnet watch`
- **Remote Debugging**: VS Debugger (vsdbg) installed in containers
- **Volume Mounts**: Source code synced for live changes
- **Docker Watch**: Automatic file synchronization

## Service Ports

| Service | HTTP Port | Debugger Port | Database |
|---------|-----------|---------------|----------|
| auth-service | 5005 | 10000 | volleyer_auth |
| events-service | 5010 | 10001 | volleyer_events |
| profiles-service | 5170 | 10002 | volleyer_profiles |
| messages-service | 5180 | 10003 | volleyer_messages |
| messages-socketserver | 5181 | 10004 | volleyer_messages |
| clubs-service | 5020 | 10005 | volleyer_clubs |
| notifications-service | 5030 | 10006 | volleyer_notifications |

## Getting Started

### 1. Start Services with Docker Watch

```bash
cd infrastructure/docker

# Start all services with watch mode
docker compose -f docker-compose.Development.yml watch

# Or start specific services
docker compose -f docker-compose.Development.yml up auth-service events-service --watch
```

### 2. Verify Services are Running

```bash
# Check running containers
docker ps

# View logs for a specific service
docker logs -f volleyer-auth-dev

# Check service health
curl http://localhost:5005/health
```

## Remote Debugging Setup

### Visual Studio Code

#### 1. Install Extensions
- C# Dev Kit
- Docker Extension

#### 2. Create/Update `.vscode/launch.json`

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Attach to Auth Service",
            "type": "coreclr",
            "request": "attach",
            "processId": "1",
            "pipeTransport": {
                "pipeProgram": "docker",
                "pipeArgs": ["exec", "-i", "volleyer-auth-dev"],
                "debuggerPath": "/vsdbg/vsdbg",
                "pipeCwd": "${workspaceRoot}",
                "quoteArgs": false
            },
            "sourceFileMap": {
                "/app": "${workspaceFolder}/auth-service"
            }
        },
        {
            "name": "Attach to Events Service",
            "type": "coreclr",
            "request": "attach",
            "processId": "1",
            "pipeTransport": {
                "pipeProgram": "docker",
                "pipeArgs": ["exec", "-i", "volleyer-events-dev"],
                "debuggerPath": "/vsdbg/vsdbg",
                "pipeCwd": "${workspaceRoot}",
                "quoteArgs": false
            },
            "sourceFileMap": {
                "/app": "${workspaceFolder}/events-service"
            }
        },
        {
            "name": "Attach to Profiles Service",
            "type": "coreclr",
            "request": "attach",
            "processId": "1",
            "pipeTransport": {
                "pipeProgram": "docker",
                "pipeArgs": ["exec", "-i", "volleyer-profiles-dev"],
                "debuggerPath": "/vsdbg/vsdbg",
                "pipeCwd": "${workspaceRoot}",
                "quoteArgs": false
            },
            "sourceFileMap": {
                "/app": "${workspaceFolder}/profiles-service"
            }
        },
        {
            "name": "Attach to Messages Service",
            "type": "coreclr",
            "request": "attach",
            "processId": "1",
            "pipeTransport": {
                "pipeProgram": "docker",
                "pipeArgs": ["exec", "-i", "volleyer-messages-dev"],
                "debuggerPath": "/vsdbg/vsdbg",
                "pipeCwd": "${workspaceRoot}",
                "quoteArgs": false
            },
            "sourceFileMap": {
                "/app": "${workspaceFolder}/messages-service"
            }
        },
        {
            "name": "Attach to Messages SocketServer",
            "type": "coreclr",
            "request": "attach",
            "processId": "1",
            "pipeTransport": {
                "pipeProgram": "docker",
                "pipeArgs": ["exec", "-i", "volleyer-messages-socketserver-dev"],
                "debuggerPath": "/vsdbg/vsdbg",
                "pipeCwd": "${workspaceRoot}",
                "quoteArgs": false
            },
            "sourceFileMap": {
                "/app": "${workspaceFolder}/messages-service"
            }
        },
        {
            "name": "Attach to Clubs Service",
            "type": "coreclr",
            "request": "attach",
            "processId": "1",
            "pipeTransport": {
                "pipeProgram": "docker",
                "pipeArgs": ["exec", "-i", "volleyer-clubs-dev"],
                "debuggerPath": "/vsdbg/vsdbg",
                "pipeCwd": "${workspaceRoot}",
                "quoteArgs": false
            },
            "sourceFileMap": {
                "/app": "${workspaceFolder}/clubs-service"
            }
        },
        {
            "name": "Attach to Notifications Service",
            "type": "coreclr",
            "request": "attach",
            "processId": "1",
            "pipeTransport": {
                "pipeProgram": "docker",
                "pipeArgs": ["exec", "-i", "volleyer-notifications-dev"],
                "debuggerPath": "/vsdbg/vsdbg",
                "pipeCwd": "${workspaceRoot}",
                "quoteArgs": false
            },
            "sourceFileMap": {
                "/app": "${workspaceFolder}/notifications-service"
            }
        }
    ]
}
```

#### 3. Debugging Steps

1. Start services with `docker compose watch`
2. Open the "Run and Debug" panel (Ctrl+Shift+D)
3. Select the service you want to debug from the dropdown
4. Click "Start Debugging" (F5)
5. Set breakpoints in your code
6. Make a request to the service

### Visual Studio 2022

#### 1. Open Container Tools Window
- View → Other Windows → Containers

#### 2. Attach to Container
1. Right-click on the running container (e.g., `volleyer-auth-dev`)
2. Select "Attach to Process"
3. Select process type: "Managed (.NET Core for Unix)"
4. Select the dotnet process (usually PID 1)
5. Click "Attach"

#### Alternative: Use Debugger Port Directly
1. Go to Debug → Attach to Process
2. Connection type: "Docker (Linux Container)"
3. Connection target: Select your container
4. Attach to: Managed (.NET Core for Unix) code
5. Select the dotnet process
6. Click "Attach"

## Hot Reload

Hot reload is automatically enabled through `dotnet watch`. Changes to `.cs` files will trigger an automatic rebuild and restart.

### Supported Changes (Hot Reload)
- Method body changes
- Adding new methods
- Adding new properties
- Lambda expression changes

### Requires Restart
- Changes to project structure
- Adding new NuGet packages
- Changes to Startup.cs configuration
- Database migration changes

## Docker Watch Behavior

Docker Compose watch mode automatically syncs files between your host and containers:

- **Synced**: All source files (`.cs`, `.csproj`, etc.)
- **Ignored**: `bin/`, `obj/` directories
- **Action**: File changes trigger `dotnet watch` to rebuild

## Troubleshooting

### Container Won't Start
```bash
# Check container logs
docker logs volleyer-auth-dev

# Rebuild the container
docker compose -f docker-compose.Development.yml build auth-service
docker compose -f docker-compose.Development.yml up auth-service
```

### Debugger Won't Attach
```bash
# Verify vsdbg is installed
docker exec volleyer-auth-dev ls -la /vsdbg

# Check if dotnet process is running
docker exec volleyer-auth-dev ps aux

# Restart container
docker compose -f docker-compose.Development.yml restart auth-service
```

### Hot Reload Not Working
```bash
# Check volume mount
docker inspect volleyer-auth-dev | grep Mounts -A 20

# Verify watch mode is running
docker logs volleyer-auth-dev | grep "watch"

# Try manual restart
docker compose -f docker-compose.Development.yml restart auth-service
```

### Database Connection Issues
```bash
# Check if PostgreSQL is healthy
docker exec volleyer-postgres pg_isready -U volleyer_user

# Test connection from service
docker exec volleyer-auth-dev dotnet ef database --help

# View connection string in container
docker exec volleyer-auth-dev env | grep ConnectionStrings
```

### Permission Issues (Windows)
If you encounter permission issues on Windows:
```bash
# Run Docker Desktop as Administrator
# Or adjust file sharing settings in Docker Desktop:
# Settings → Resources → File Sharing
```

## Performance Tips

1. **Use cached volumes** (already configured):
   ```yaml
   volumes:
     - ../../auth-service:/app:cached
   ```

2. **Exclude unnecessary files** in `.dockerignore`

3. **Start only needed services**:
   ```bash
   docker compose -f docker-compose.Development.yml up postgres auth-service events-service
   ```

4. **Use Docker Desktop with WSL2** backend on Windows for better performance

## Database Management

### Access PostgreSQL
```bash
# Via psql in container
docker exec -it volleyer-postgres psql -U volleyer_user -d volleyer_auth

# Via PgAdmin UI
# Open http://localhost:8080
# Login: admin@volleyer.com / admin123
```

### Run Migrations
```bash
# From host machine
cd auth-service
dotnet ef database update

# Or from container
docker exec volleyer-auth-dev dotnet ef database update
```

## Environment Variables

Configure via `.env` file in `infrastructure/docker/`:

```env
# AWS Credentials (for local development with LocalStack or real AWS)
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
AWS_DEFAULT_REGION=us-east-1
AWS_REGION=us-east-1
```

## Useful Commands

```bash
# Start all services
docker compose -f docker-compose.Development.yml up -d

# Start with watch mode (hot reload)
docker compose -f docker-compose.Development.yml watch

# Stop all services
docker compose -f docker-compose.Development.yml down

# View logs for all services
docker compose -f docker-compose.Development.yml logs -f

# View logs for specific service
docker compose -f docker-compose.Development.yml logs -f auth-service

# Rebuild specific service
docker compose -f docker-compose.Development.yml build auth-service

# Restart specific service
docker compose -f docker-compose.Development.yml restart auth-service

# Shell into container
docker exec -it volleyer-auth-dev bash

# View running processes in container
docker exec volleyer-auth-dev ps aux
```

## Next Steps

1. Start services with `docker compose watch`
2. Configure your IDE for remote debugging
3. Set breakpoints and debug your code
4. Make changes and see them hot-reload automatically

For production deployment, see the `docker-compose.Production.yml` configuration.
