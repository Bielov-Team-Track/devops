#!/usr/bin/env bash
# Docker container health monitor with Telegram alerts
# Watches for container deaths, unhealthy transitions, and OOM kills.
# Runs as a systemd service — see docker-monitor.service.
#
# Required env vars (from /opt/volleyspike/.env.monitor):
#   TELEGRAM_BOT_TOKEN  - Telegram bot API token
#   TELEGRAM_CHAT_ID    - Chat/group ID to send alerts to
#
# Optional:
#   MONITOR_COMPOSE_PROJECT - Docker Compose project name (default: volleyspike)
#   MONITOR_COOLDOWN        - Seconds between duplicate alerts (default: 300)
set -euo pipefail

# --- Configuration ---
COMPOSE_PROJECT="${MONITOR_COMPOSE_PROJECT:-volleyspike}"
COOLDOWN="${MONITOR_COOLDOWN:-300}"
HOSTNAME_LABEL=$(hostname -s)
ENVIRONMENT="${ENVIRONMENT:-unknown}"

# --- Validate ---
if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
  echo "ERROR: TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID must be set."
  echo "Create /opt/volleyspike/.env.monitor with these values."
  exit 1
fi

# --- State ---
declare -A LAST_ALERT  # tracks last alert time per container+event

send_telegram() {
  local message="$1"
  curl -sf -X POST \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d parse_mode="HTML" \
    -d text="${message}" \
    -d disable_notification=false \
    > /dev/null 2>&1 || echo "WARNING: Failed to send Telegram message"
}

should_alert() {
  local key="$1"
  local now
  now=$(date +%s)
  local last="${LAST_ALERT[$key]:-0}"
  if (( now - last >= COOLDOWN )); then
    LAST_ALERT[$key]=$now
    return 0
  fi
  return 1
}

format_alert() {
  local emoji="$1" title="$2" container="$3" details="$4"
  echo "${emoji} <b>${title}</b>
<b>Host:</b> ${HOSTNAME_LABEL} (${ENVIRONMENT})
<b>Container:</b> ${container}
${details}
<b>Time:</b> $(date '+%Y-%m-%d %H:%M:%S %Z')"
}

handle_event() {
  local event_type="$1" container="$2" attributes="$3"

  # Only monitor containers from our compose project
  if ! echo "$attributes" | grep -q "com.docker.compose.project=${COMPOSE_PROJECT}"; then
    return
  fi

  # Extract service name from compose labels
  local service
  service=$(echo "$attributes" | grep -oP 'com.docker.compose.service=\K[^,]+' || echo "$container")

  local key="${service}:${event_type}"

  case "$event_type" in
    die)
      local exit_code
      exit_code=$(echo "$attributes" | grep -oP 'exitCode=\K[^,]+' || echo "?")
      if [ "$exit_code" = "0" ]; then
        return  # graceful stop, not an alert
      fi
      if should_alert "$key"; then
        local msg
        msg=$(format_alert "🔴" "Container Died" "$service" "<b>Exit code:</b> ${exit_code}")
        send_telegram "$msg"
        echo "[ALERT] $service died with exit code $exit_code"
      fi
      ;;
    oom)
      if should_alert "$key"; then
        local msg
        msg=$(format_alert "💀" "Out of Memory Kill" "$service" "Container was killed by the OOM killer.")
        send_telegram "$msg"
        echo "[ALERT] $service OOM killed"
      fi
      ;;
    health_status:\ unhealthy)
      if should_alert "$key"; then
        local msg
        msg=$(format_alert "🟡" "Unhealthy" "$service" "Health check is failing.")
        send_telegram "$msg"
        echo "[ALERT] $service unhealthy"
      fi
      ;;
    health_status:\ healthy)
      # Send recovery notification if we previously alerted
      local unhealthy_key="${service}:health_status: unhealthy"
      if [ "${LAST_ALERT[$unhealthy_key]:-0}" -gt 0 ]; then
        local msg
        msg=$(format_alert "🟢" "Recovered" "$service" "Container is healthy again.")
        send_telegram "$msg"
        echo "[RECOVERY] $service healthy again"
        LAST_ALERT[$unhealthy_key]=0
      fi
      ;;
  esac
}

# --- Startup ---
echo "Docker Monitor started for project '${COMPOSE_PROJECT}' on ${HOSTNAME_LABEL} (${ENVIRONMENT})"
echo "Cooldown: ${COOLDOWN}s between duplicate alerts"

# Send startup notification
send_telegram "$(format_alert "👁" "Monitor Started" "all" "Docker health monitoring is active.")"

# --- Main loop: watch docker events ---
docker events \
  --filter "type=container" \
  --filter "event=die" \
  --filter "event=oom" \
  --filter "event=health_status" \
  --format '{{.Action}}|{{.Actor.Attributes.name}}|{{range $k,$v := .Actor.Attributes}}{{$k}}={{$v}},{{end}}' \
| while IFS='|' read -r action container attributes; do
    handle_event "$action" "$container" "$attributes" || true
done
