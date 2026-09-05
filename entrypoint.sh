#!/bin/sh
# Wire the persistent /data volume into the places Pokémon Showdown expects.
#
# Persisted under /data:
#   config.js        server config (seeded from config-example.js on first run)
#   usergroups.csv   admin/mod ranks, e.g. "yourname,~"
#   logs/            chat logs, modlogs, etc.
#   databases/       sqlite files (*.db) — repo migrations/schemas are merged in non-destructively
set -eu

DATA=/data
APP=/app

mkdir -p "$DATA/logs" "$DATA/databases"

# --- config.js -------------------------------------------------------------
if [ ! -f "$DATA/config.js" ]; then
  echo "[entrypoint] No $DATA/config.js found — seeding from config-example.js"
  cp "$APP/config/config-example.js" "$DATA/config.js"
fi
ln -sfn "$DATA/config.js" "$APP/config/config.js"

# --- usergroups.csv (admin list) -------------------------------------------
[ -f "$DATA/usergroups.csv" ] || : > "$DATA/usergroups.csv"
ln -sfn "$DATA/usergroups.csv" "$APP/config/usergroups.csv"

# --- logs / databases ------------------------------------------------------
# Copy the repo's skeleton (READMEs, migrations, schemas) into the volume WITHOUT
# overwriting anything already there, then point the app at the volume.
cp -rn "$APP/logs/." "$DATA/logs/" 2>/dev/null || true
cp -rn "$APP/databases/." "$DATA/databases/" 2>/dev/null || true
rm -rf "$APP/logs" "$APP/databases"
ln -sfn "$DATA/logs" "$APP/logs"
ln -sfn "$DATA/databases" "$APP/databases"

echo "[entrypoint] Built from commit $(cat "$APP/.build-commit" 2>/dev/null || echo unknown)"
exec "$@"
