# Pokémon Showdown server — self-hosted, built from source.
#
# Build args let you point at YOUR fork (or upstream) and a branch/tag/commit:
#   docker compose build --build-arg PS_REPO=https://github.com/<you>/pokemon-showdown.git --build-arg PS_REF=master
#
# Multi-arch: node official images ship linux/arm64 (Pi 4/5 on 64-bit OS) and linux/amd64.

ARG NODE_VERSION=22

# ---------- build stage ----------
FROM node:${NODE_VERSION}-bookworm AS build

ARG PS_REPO=https://github.com/smogon/pokemon-showdown.git
ARG PS_REF=master

# python3/make/g++ are only needed if an optional native dep (better-sqlite3 / sqlite3)
# has no prebuilt binary for this arch and falls back to compiling. Cheap insurance.
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates python3 make g++ \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Shallow clone of the requested ref. Bust the cache by changing CACHE_BUST when you want a fresh pull.
ARG CACHE_BUST=0
RUN git clone --depth 1 --branch "${PS_REF}" "${PS_REPO}" . \
 && git rev-parse HEAD > /app/.build-commit

# Production deps only (dev deps are lint/test tooling). Optional deps are installed if they succeed.
RUN npm ci --omit=dev

# Compile TypeScript -> ./dist so the container starts without building at runtime.
RUN node build

# ---------- runtime stage ----------
FROM node:${NODE_VERSION}-bookworm-slim

ENV NODE_ENV=production
WORKDIR /app

COPY --from=build --chown=node:node /app /app
COPY --chown=node:node entrypoint.sh /entrypoint.sh
# Persistent state lives in /data. Wire the symlinks here (as root) so the non-root
# runtime user never needs to modify /app itself; the entrypoint only seeds /data.
RUN chmod +x /entrypoint.sh \
 && mkdir -p /data && chown node:node /data /app \
 && mv /app/logs /app/.skel-logs && mv /app/databases /app/.skel-databases \
 && ln -s /data/logs /app/logs && ln -s /data/databases /app/databases \
 && ln -s /data/config.js /app/config/config.js \
 && ln -s /data/usergroups.csv /app/config/usergroups.csv

USER node
VOLUME ["/data"]
EXPOSE 8000

ENTRYPOINT ["/entrypoint.sh"]
# --skip-build: ./dist was produced at image build time (see the launcher's `pokemon-showdown start [--skip-build] [PORT]`)
CMD ["node", "pokemon-showdown", "start", "--skip-build"]
