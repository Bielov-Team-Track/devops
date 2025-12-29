# Infrastructure

This directory contains Docker Compose configurations and related infrastructure setup for the Spike application.

## Development Environment

Start all services:

```bash
cd docker
docker-compose -f docker-compose.Development.yml up -d
```

Stop all services:

```bash
docker-compose -f docker-compose.Development.yml down
```

## Services

### PostgreSQL Database

PostgreSQL provides the primary data store for all microservices.

-   **Port:** localhost:5432
-   **User:** volleyer_user
-   **Password:** volleyer_password_dev
-   **Logical Replication:** Enabled (for Debezium CDC)

### PgAdmin

Web-based PostgreSQL administration tool.

-   **URL:** http://localhost:8080
-   **Email:** admin@volleyer.com
-   **Password:** admin123

### Redis

In-memory data store for caching and session management.

-   **Port:** localhost:6379
-   **Persistence:** AOF (append-only file) enabled

### Message Queue (RabbitMQ)

RabbitMQ provides asynchronous messaging between microservices.

-   **AMQP Port:** localhost:5672
-   **Management UI:** http://localhost:15672
-   **User:** volleyer_user
-   **Password:** volleyer_password_dev

#### Exchanges

-   `events.outbox` - Events from events-service
-   `profiles.outbox` - Events from profiles-service
-   `messages.outbox` - Events from messages-service

### Change Data Capture (Debezium)

Debezium captures database changes and publishes to RabbitMQ using the outbox pattern.

-   Monitors `outbox_messages` tables in each service database
-   Publishes changes to RabbitMQ exchanges
-   Uses Debezium Server standalone mode (no Kafka dependency)

#### Configuration

Configuration files are located in `docker/debezium/` directory.

### Microservices

| Service               | Port | Description                               |
| --------------------- | ---- | ----------------------------------------- |
| auth-service          | 5005 | Authentication & authorization            |
| events-service        | 5010 | Event management                          |
| profiles-service      | 5170 | User profiles                             |
| clubs-service         | 5020 | Club management                           |
| messages-service      | 5180 | Messaging API                             |
| messages-socketserver | 5181 | WebSocket/SignalR for real-time messaging |
| notifications-service | 5030 | Push notifications                        |

### Nginx

Reverse proxy and API gateway.

-   **Port:** localhost:8000
-   Routes requests to appropriate microservices

## Volumes

| Volume        | Purpose                      |
| ------------- | ---------------------------- |
| postgres_data | PostgreSQL data persistence  |
| pgadmin_data  | PgAdmin configuration        |
| redis_data    | Redis AOF persistence        |
| rabbitmq_data | RabbitMQ queues and messages |
| debezium_data | Debezium offset tracking     |
| nginx_logs    | Nginx access and error logs  |

## Network

All services communicate over the `volleyer_network` bridge network.
