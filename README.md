# Pokémon Showdown on a Raspberry Pi (Docker)

Builds the Pokémon Showdown **server** from source (upstream or your fork) into a
local Docker image. Nothing is pushed anywhere — the image only exists on the machine
that builds it. The official web client at `psim.us` connects to your server; you
don't host the client or the login server (upstream says they won't support that).

## Requirements

- Raspberry Pi 4/5 running a **64-bit** OS (`uname -m` → `aarch64`). The `node`
  images don't ship 32-bit ARMv7 for current versions.
- Docker + Docker Compose plugin (`docker compose version`).
- ~1.5 GB free for the build.

## First run

```bash
git clone <this-folder-or-your-repo> ~/showdown && cd ~/showdown
# (optional) edit docker-compose.yml → PS_REPO to point at your fork
docker compose build          # 5–15 min on a Pi 4 the first time
docker compose up -d
docker compose logs -f        # wait for "Worker 1 now listening on 0.0.0.0:8000"
```

Then open `http://<pi-ip>:8000` from any machine on your network. It redirects to
`http://<pi-ip>.insecure.psim.us` — that's the official client pointed at your server.

## Configure

After the first start, `./data/` contains:

| File | Purpose |
|---|---|
| `data/config.js` | Server config (seeded from upstream `config-example.js`). Edit `serverid`, `servername`, etc. |
| `data/usergroups.csv` | Admins/mods. Put `yourname,~` (no space) to make yourself admin. Name must be a registered Showdown account. |
| `data/logs/` | Chat/mod logs |
| `data/databases/` | SQLite files |

Apply config changes with `docker compose restart`.

## Update to the latest upstream/fork commit

```bash
docker compose build --build-arg CACHE_BUST=$(date +%s)
docker compose up -d
```

## Let friends in

Pick one:

- **Tailscale (recommended, nothing exposed publicly):** install Tailscale on the Pi
  and friends' machines; they use `http://<tailscale-ip>:8000`.
- **Port forward** TCP 8000 on your router to the Pi (some ISPs block this; the
  upstream docs warn about it).
- **HTTPS:** only if you own a domain — put a reverse proxy (Caddy/Traefik) in front
  and set `proxyip` in `config.js` so the server sees real client IPs.

## Notes

- Build is done from a shallow `git clone` of `PS_REPO`@`PS_REF` inside the image —
  the Pi never needs Node or the repo checked out on the host.
- `--skip-build` is passed at start because `dist/` is compiled at image build time.
- If the build fails while compiling `better-sqlite3`/`sqlite3`, it's usually memory:
  add swap or build on a beefier box with `docker buildx build --platform linux/arm64`
  and `docker save`/`docker load` the image over to the Pi.
