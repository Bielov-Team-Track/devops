# Server Provisioning

Tracks the previously-untracked `/opt/volleyspike/setup.sh` (SPI-5711) plus the
day-0 OS setup and firewall it always depended on but never version-controlled.

## Run order

1. **`bootstrap.sh`** (as root) — day-0 OS setup: purges `ufw`, installs
   nftables/Docker/WireGuard tools, pins Docker's firewall backend to
   nftables, creates the `deploy` user, provisions swap. Idempotent — safe to
   re-run.
2. **`nftables.conf`** — apply with `nft -f nftables.conf` (or `nft -c -f
   nftables.conf` to check syntax without applying). Not loaded by
   `bootstrap.sh` automatically; apply it once WireGuard's `wg0` interface
   exists, since the input chain references it.
3. **WireGuard** — bring up `wg0` before or alongside the firewall step; the
   ruleset's SSH-over-VPN and `iifname "wg0" accept` rules assume it's
   present.
4. **`setup.sh`** — interactive script (run on the box at
   `/opt/volleyspike/setup.sh`) that prompts for credentials, writes the
   per-service `.env.*` files, and starts the Docker stack.

## Migrating an existing environment

When provisioning a **replacement** server for an environment that already
has live secrets, copy the existing `.env*` files into `/opt/volleyspike/`
first, then run:

```bash
SKIP_SECRET_GENERATION=1 ./setup.sh --force
```

**Both flags are required, and neither substitutes for the other — they gate
two independent checks:**

- `--force` bypasses `setup.sh`'s top-of-file guard, which otherwise exits 1
  as soon as it sees `$DEPLOY_PATH/.env` already present (which it will be,
  since you just copied it there).
- `SKIP_SECRET_GENERATION=1` bypasses the actual secret/env-file **write**
  steps (10, 11, 12, 12b, 13, 13b) further down the script, so the copied
  files are left alone instead of being regenerated.

**`--force` alone is the dangerous case.** It only clears the guard; without
`SKIP_SECRET_GENERATION=1` the script proceeds straight into regenerating
`POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `RABBITMQ_PASSWORD`, and `JWT_SECRET`
and overwriting every per-service env file — desyncing from a restored
database (still using the old Postgres password) and invalidating every
issued JWT. This is exactly what the guard's own error text warns about if
you hit it without `SKIP_SECRET_GENERATION=1` set.

Every write step guarded by `SKIP_SECRET_GENERATION=1` logs that it's
reusing the copied file instead of overwriting it.

## Firewall

- `ufw` must stay purged. `bootstrap.sh` removes it
  (`apt-get remove --purge -y ufw`); nftables is the only firewall on this
  box. Reinstalling `ufw` enables `default deny incoming` and severs
  80/443/51820.
- `nftables.conf`'s forward chain is deliberately empty with `policy accept`
  — Docker's own `docker-bridges` table already enforces container
  isolation. Do not add "defensive" rules there: a second forward chain at
  `policy drop` is what silently blackholed every Prometheus scrape for 17
  days on the previous iptables-based setup. See the comments in the file.
- `net.ipv4.ip_forward=1` **must be persisted before Docker's first start** —
  `bootstrap.sh` writes `/etc/sysctl.d/99-docker-ip-forward.conf` ahead of
  the Docker install for exactly this reason. Do not remove that file. If
  forwarding isn't already enabled when Docker starts, two things go wrong:
  Docker refuses to create its default bridge network at all (confirmed by
  rebooting the target box: `dockerd` fails outright with "IPv4 forwarding
  is disabled"), and on any run where Docker *does* enable forwarding itself,
  it also sets the legacy `filter-FORWARD` chain to `policy drop` — the exact
  failure mode this task exists to eliminate. `daemon.json`'s
  `ip-forward-no-drop: true` is a second, independent layer against that same
  policy-drop chain in case this sysctl file is ever lost.

## WireGuard IPs

- `10.10.0.2` — production
- `10.10.0.3` — staging
- `docker-compose.production.yml` binds its monitoring/debug ports to
  `${WG_BIND_IP:-10.10.0.2}` rather than the literal address, so the stack
  can start on a host that doesn't (yet) own `10.10.0.2`. Set `WG_BIND_IP` in
  that server's `.env` to override the default.

## Telemetry exporters

`docker/docker-compose.exporters.yml` runs the host-network telemetry agents
— `node-exporter`, `postgres-exporter`, `redis-exporter`, `alloy` — alongside
the main stack. Start it with both env files:

```bash
docker compose -f docker-compose.exporters.yml --env-file .env --env-file .env.monitoring up -d
```

Its four bind addresses (`--web.listen-address` on the three exporters,
`--server.http.listen-addr` on `alloy`) use the same
`${WG_BIND_IP:-10.10.0.2}` convention as `docker-compose.production.yml`, for
the same reason: this file previously hardcoded `10.10.0.2` and crash-looped
on any host that isn't the origin server (`bind: cannot assign requested
address`).
