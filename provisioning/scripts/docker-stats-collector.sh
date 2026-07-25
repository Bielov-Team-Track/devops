#!/bin/bash
# Collects Docker container CPU and memory stats via Docker stats API
# Outputs Prometheus textfile format for node-exporter
# Runs as a systemd timer or cron job every 15s

set -euo pipefail

OUTPUT_FILE="/var/lib/node_exporter/docker_container_stats.prom"
TMP_FILE="${OUTPUT_FILE}.tmp"

# Get stats for all running containers in one shot
docker stats --no-stream --format '{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}' 2>/dev/null | while IFS=$'\t' read -r name cpu_pct mem_usage mem_pct; do
  # Strip % sign from CPU and memory percentages
  cpu="${cpu_pct//%/}"
  mem_pct_val="${mem_pct//%/}"

  # Parse memory usage (e.g., "213.5MiB / 7.581GiB")
  mem_used_raw=$(echo "$mem_usage" | awk -F'/' '{print $1}' | xargs)
  mem_limit_raw=$(echo "$mem_usage" | awk -F'/' '{print $2}' | xargs)

  # Convert memory to bytes
  to_bytes() {
    local val unit
    val=$(echo "$1" | grep -oP '[\d.]+')
    unit=$(echo "$1" | grep -oP '[A-Za-z]+')
    case "$unit" in
      B)   echo "$val" ;;
      KiB) awk "BEGIN {printf \"%.0f\", $val * 1024}" ;;
      MiB) awk "BEGIN {printf \"%.0f\", $val * 1048576}" ;;
      GiB) awk "BEGIN {printf \"%.0f\", $val * 1073741824}" ;;
      *)   echo "0" ;;
    esac
  }

  mem_used=$(to_bytes "$mem_used_raw")
  mem_limit=$(to_bytes "$mem_limit_raw")

  # Derive service name from container name (volleyspike-auth-service-1 -> auth-service)
  service=""
  if [[ "$name" =~ ^volleyspike-(.+)-1$ ]]; then
    service="${BASH_REMATCH[1]}"
  else
    service="$name"
  fi

  # Convert to human-readable MB for labels
  used_mb=$(awk "BEGIN {printf \"%.0f\", $mem_used / 1048576}")
  limit_mb=$(awk "BEGIN {printf \"%.0f\", $mem_limit / 1048576}")

  echo "docker_container_cpu_usage_percent{container=\"$name\",service=\"$service\"} $cpu"
  echo "docker_container_memory_usage_bytes{container=\"$name\",service=\"$service\"} $mem_used"
  echo "docker_container_memory_limit_bytes{container=\"$name\",service=\"$service\"} $mem_limit"
  echo "docker_container_memory_usage_percent{container=\"$name\",service=\"$service\",limit_mb=\"$limit_mb\"} $mem_pct_val"
done > "$TMP_FILE"

# Atomic move
mv "$TMP_FILE" "$OUTPUT_FILE"
