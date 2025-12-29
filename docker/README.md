# Docker Infrastructure Setup

This directory contains Docker Compose configurations for running the Spike microservices.

## Prerequisites

-   Docker Desktop installed and running
-   AWS account with credentials (for S3 and SES services)

## Development Setup

### 1. Configure AWS Credentials

Create a `.env` file from the template:

```bash
cd infrastructure/docker
cp .env.example .env
```

Edit `.env` and add your AWS credentials:

```env
AWS_ACCESS_KEY_ID=your_actual_access_key
AWS_SECRET_ACCESS_KEY=your_actual_secret_key
AWS_DEFAULT_REGION=us-east-1
AWS_REGION=us-east-1
```

**Security Note:** The `.env` file is gitignored and will never be committed to version control.

### 2. Required AWS Services

The microservices use these AWS services:

-   **Amazon S3** - File storage (user avatars, event images)
-   **Amazon SES** - Email service (notifications, password resets)

Ensure your AWS IAM user has permissions for:

-   `s3:PutObject`, `s3:GetObject`, `s3:DeleteObject`
-   `ses:SendEmail`, `ses:SendRawEmail`

### 3. Start Services

```bash
# Start all services
docker-compose -f docker-compose.Development.yml up -d

# View logs
docker-compose -f docker-compose.Development.yml logs -f

# Stop services
docker-compose -f docker-compose.Development.yml down
```

## Services

### Running in Development

-   **postgres** - PostgreSQL database (port 5432)
-   **pgadmin** - Database admin UI (port 8080)
-   **auth-service** - Authentication microservice (port 5005)
-   **nginx** - API Gateway (port 8000)

### Commented Out (Run on Host)

-   **profiles-service** - User profiles (port 5170)
-   **messages-service** - Messaging/chat (port 5180)

To enable these services, uncomment them in `docker-compose.Development.yml` and ensure their Dockerfiles exist.

## Accessing Services

-   **API Gateway**: http://localhost:8000
    -   Auth API: http://localhost:8000/auth/
    -   Events API: http://localhost:8000/events/
    -   Profile API: http://localhost:8000/profile/
    -   Message API: http://localhost:8000/message/
    -   Message Hub: ws://localhost:8000/message/hubs/
-   **PgAdmin**: http://localhost:8080
    -   Email: admin@volleyer.com
    -   Password: admin123

## Production Deployment

Production uses pre-built Docker images from DigitalOcean Container Registry:

```bash
docker-compose -f docker-compose.Production.yml up -d
```

Production requires these environment variables:

-   `DO_REGISTRY_NAME` - DigitalOcean registry name
-   `AUTH_AWS_ACCESS_KEY_ID` / `AUTH_AWS_SECRET_ACCESS_KEY`
-   `EVENTS_AWS_ACCESS_KEY_ID` / `EVENTS_AWS_SECRET_ACCESS_KEY`
-   `PROFILE_AWS_ACCESS_KEY_ID` / `PROFILE_AWS_SECRET_ACCESS_KEY`
-   `MESSAGE_AWS_ACCESS_KEY_ID` / `MESSAGE_AWS_SECRET_ACCESS_KEY`
-   `AWS_DEFAULT_REGION` / `AWS_REGION`

## Database Initialization

The postgres service automatically creates databases on first run using scripts in `./init/` directory.

## Troubleshooting

### AWS Credentials Not Working

Ensure your `.env` file is in the same directory as the docker-compose file and contains valid credentials.

### Service Health Checks Failing

Wait for the service to fully start (check logs). Health checks have a 40-second start period.

### Connection Issues

Ensure Docker network is properly configured and services are on the same network (`volleyer_network`).
