#!/usr/bin/env sh
set -eu

# Deliberately does not run database-destroying Compose commands. Migrations are
# applied by the backend container before it starts serving requests.
root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root_dir"

docker compose build
docker compose up -d
docker compose ps
curl --fail --silent --show-error http://127.0.0.1:8080/health
printf '\nFjellfisk backend is healthy.\n'
