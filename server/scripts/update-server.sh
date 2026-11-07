#!/usr/bin/env sh
set -eu

# Deliberately does not run database-destroying Compose commands. Migrations are
# applied by the backend container before it starts serving requests.
root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
config_file="$root_dir/.env"

if [ ! -r "$config_file" ]; then
  printf '%s\n' "Missing readable server configuration: $config_file" >&2
  exit 1
fi

# Ensure Compose uses this deployment's configuration rather than caller state.
set -a
. "$config_file"
set +a

cd "$root_dir"

docker compose build
docker compose up -d
docker compose ps
curl --fail --silent --show-error http://127.0.0.1:8080/health
printf '\nFjellfisk backend is healthy.\n'
