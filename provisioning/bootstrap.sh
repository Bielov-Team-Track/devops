#!/usr/bin/env bash
# Day-0 provisioning for a Spike application server. Idempotent. Run as root.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "must run as root"; exit 1; }

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a          # otherwise needrestart prompts interactively

timedatectl set-timezone Europe/London

# ufw ships on Ubuntu and would sever 80/443/51820. nftables is the only firewall.
apt-get remove --purge -y ufw || true
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg nftables wireguard-tools \
                       postgresql-client-15 rsync jq

systemctl enable --now nftables

# Docker from the official repo (never snap).
if ! command -v docker >/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io \
                         docker-buildx-plugin docker-compose-plugin
fi

# Pin the firewall backend. An unattended flip is what caused the 17-day outage.
mkdir -p /etc/docker
if [ ! -f /etc/docker/daemon.json ]; then
  cat > /etc/docker/daemon.json <<'JSON'
{
  "firewall-backend": "nftables",
  "log-driver": "json-file",
  "log-opts": { "max-size": "50m", "max-file": "3" }
}
JSON
  systemctl restart docker
fi

# Hold docker so unattended-upgrades cannot restart it or change its backend.
apt-mark hold docker-ce docker-ce-cli containerd.io

id -u deploy >/dev/null 2>&1 || useradd -m -s /bin/bash -G docker deploy
install -d -m 0700 -o deploy -g deploy /home/deploy/.ssh
if [ -f /root/.ssh/authorized_keys ] && [ ! -s /home/deploy/.ssh/authorized_keys ]; then
  install -m 0600 -o deploy -g deploy /root/.ssh/authorized_keys \
    /home/deploy/.ssh/authorized_keys
fi

install -d -m 0755 -o deploy -g deploy /opt/volleyspike

# Swap — the box ships with none; the origin runs 2 GiB.
if ! swapon --show | grep -q .; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "bootstrap complete"
