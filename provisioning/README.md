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
first, then run `setup.sh` with `SKIP_SECRET_GENERATION=1` set in the
environment. **This is mandatory, not optional**: without it, `setup.sh`
regenerates `POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `RABBITMQ_PASSWORD`, and
`JWT_SECRET`, and rewrites every per-service env file — desyncing from a
restored database (still using the old Postgres password) and invalidating
every issued JWT. Every write step guarded by this flag logs that it's
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

## WireGuard IPs

- `10.10.0.2` — production
- `10.10.0.3` — staging
- `docker-compose.production.yml` binds its monitoring/debug ports to
  `${WG_BIND_IP:-10.10.0.2}` rather than the literal address, so the stack
  can start on a host that doesn't (yet) own `10.10.0.2`. Set `WG_BIND_IP` in
  that server's `.env` to override the default.
