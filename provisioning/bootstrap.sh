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
                       rsync jq

# Install and apply the real ruleset before enabling the unit. Safe to do
# before wg0 exists: `iifname "wg0"` is a plain string match, not an
# interface lookup, so it loads fine with no such interface yet. Skipping
# this and only enabling the service would leave /etc/nftables.conf at the
# distro default (no policy = accept, no Cloudflare gate) until first apply.
install -m 0755 "$(dirname "$0")/nftables.conf" /etc/nftables.conf
systemctl enable nftables
nft -f /etc/nftables.conf

# Cloudflare IP-range refresh: keeps the nftables allowlist sets current so a
# stale list doesn't silently reject legitimate edge traffic. Wired in after
# the nftables table above so its first run (or an early catch-up run under
# the timer's Persistent=true) always finds `inet volleyspike` already there.
install -m 0755 "$(dirname "$0")/scripts/refresh-cloudflare-nft.sh" \
  /usr/local/sbin/refresh-cloudflare-nft.sh
install -m 0644 "$(dirname "$0")/systemd/cloudflare-nft-refresh.service" \
  /etc/systemd/system/cloudflare-nft-refresh.service
install -m 0644 "$(dirname "$0")/systemd/cloudflare-nft-refresh.timer" \
  /etc/systemd/system/cloudflare-nft-refresh.timer
systemctl daemon-reload
systemctl enable --now cloudflare-nft-refresh.timer

# Docker refuses to create its default bridge network when IPv4 forwarding is
# off, and the runtime value it sets does not survive a reboot. Persisting it
# also stops Docker from setting the filter-FORWARD policy to DROP, which it
# only does when it has to enable forwarding itself.
mkdir -p /etc/sysctl.d
if [ ! -f /etc/sysctl.d/99-docker-ip-forward.conf ]; then
  echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-docker-ip-forward.conf
  sysctl --system >/dev/null
fi

# Container port publishes bind WireGuard addresses. If Docker starts before
# wg0 exists, every wg-bound port publish fails at container start — placed
# before Docker's own install/first-start below so it's respected immediately.
install -d /etc/systemd/system/docker.service.d
install -m 0644 "$(dirname "$0")/systemd/10-wireguard-ordering.conf" \
  /etc/systemd/system/docker.service.d/10-wireguard-ordering.conf

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

# PGDG for postgresql-client-15: noble's own repos only ship client 16, but
# the server runs postgres:15-alpine (15.17) — the host client must match.
if ! dpkg -s postgresql-client-15 >/dev/null 2>&1; then
  install -d /usr/share/postgresql-common/pgdg
  curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc
  echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] \
https://apt.postgresql.org/pub/repos/apt $(. /etc/os-release && echo "$VERSION_CODENAME")-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list
  apt-get update -qq
  apt-get install -y -qq postgresql-client-15
fi

# Pin the firewall backend. An unattended flip is what caused the 17-day outage.
# ip-forward-no-drop: belt-and-braces so Docker cannot reintroduce a policy-drop
# filter-FORWARD chain even if the sysctl drop-in above is ever lost.
mkdir -p /etc/docker
if [ ! -f /etc/docker/daemon.json ]; then
  cat > /etc/docker/daemon.json <<'JSON'
{
  "firewall-backend": "nftables",
  "ip-forward-no-drop": true,
  "log-driver": "json-file",
  "log-opts": { "max-size": "50m", "max-file": "3" }
}
JSON
  systemctl restart docker
fi

# Hold docker so unattended-upgrades cannot restart it or change its backend.
apt-mark hold docker-ce docker-ce-cli containerd.io

# 00- sorts before cloud-init's 50-cloud-init.conf (sshd takes the first
# value per keyword); cloud-init rewrites that file with PasswordAuthentication
# yes on every boot. Without this, password SSH stays open on the one
# world-reachable port.
install -m 0644 "$(dirname "$0")/ssh/00-hardening.conf" /etc/ssh/sshd_config.d/00-hardening.conf

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
