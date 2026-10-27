#!/usr/bin/env sh
set -eu

# Run on the future Pelasyn host from the server/ directory. It never deletes
# database rows; old backup files are rotated only after a successful dump.
root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
config_file="$root_dir/.env"

if [ ! -r "$config_file" ]; then
  printf '%s\n' "Missing readable server configuration: $config_file" >&2
  exit 1
fi

# Load the deployment's own values instead of inheriting a caller's shell.
set -a
. "$config_file"
set +a

backup_dir="$root_dir/backups"
retention_days="${BACKUP_RETENTION_DAYS:-30}"
timestamp=$(date -u +%Y-%m-%d_%H%M%S)
temporary="$backup_dir/fjellfisk-postgres-$timestamp.dump.tmp"
target="$backup_dir/fjellfisk-postgres-$timestamp.dump"

mkdir -p "$backup_dir"
cd "$root_dir"

docker compose exec -T postgres pg_dump \
  --username="$POSTGRES_USER" \
  --dbname="$POSTGRES_DB" \
  --format=custom > "$temporary"
mv "$temporary" "$target"
find "$backup_dir" -type f -name 'fjellfisk-postgres-*.dump' -mtime +"$retention_days" -delete
printf '%s\n' "Backup written: $target"
