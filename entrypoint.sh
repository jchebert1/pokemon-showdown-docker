#!/bin/sh
# Seed the persistent /data volume that Pokémon Showdown's config/logs/databases point at.
#
# Persisted under /data:
#   config.js        server config (seeded from config-example.js on first run)
#   usergroups.csv   admin/mod ranks, e.g. "yourname,~"
#   logs/            chat logs, modlogs, etc.
#   databases/       sqlite files (*.db) — repo migrations/schemas are merged in non-destructively
#
# Optional env vars (handy when deploying from Portainer with no shell):
#   PS_ADMIN         comma-separated registered usernames to grant admin (~)
set -eu

DATA=/data
APP=/app

mkdir -p "$DATA/logs" "$DATA/databases"

# --- config.js -------------------------------------------------------------
if [ ! -f "$DATA/config.js" ]; then
  echo "[entrypoint] No $DATA/config.js found — seeding from config-example.js"
  cp "$APP/config/config-example.js" "$DATA/config.js"
fi

# --- usergroups.csv (admin list) -------------------------------------------
[ -f "$DATA/usergroups.csv" ] || : > "$DATA/usergroups.csv"
if [ -n "${PS_ADMIN:-}" ]; then
  old_ifs=$IFS; IFS=','
  for name in $PS_ADMIN; do
    id=$(printf '%s' "$name" | tr -d ' ' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')
    [ -n "$id" ] || continue
    grep -qi "^$id," "$DATA/usergroups.csv" || { echo "[entrypoint] Granting admin (~) to $id"; echo "$id,~" >> "$DATA/usergroups.csv"; }
  done
  IFS=$old_ifs
fi

# --- logs / databases ------------------------------------------------------
# /app/logs and /app/databases are symlinks to /data (set up in the Dockerfile).
# Copy the repo's skeleton (READMEs, migrations, schemas) into the volume WITHOUT
# overwriting anything already there.
cp -rn "$APP/.skel-logs/." "$DATA/logs/" 2>/dev/null || true
cp -rn "$APP/.skel-databases/." "$DATA/databases/" 2>/dev/null || true

echo "[entrypoint] Built from commit $(cat "$APP/.build-commit" 2>/dev/null || echo unknown)"
exec "$@"
