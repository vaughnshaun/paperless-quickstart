#!/bin/bash

set -e  # Exit if any command fails

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$ENV_FILE" ]; then
  ENV_FILE="$SCRIPT_DIR/paperless-backup.env"
fi

# Assume ENV_FILE is already set or passed in
if [[ "$ENV_FILE" == ~* ]]; then
    # Only expand if it starts with ~
    EXPANDED_ENV_FILE=$(eval echo "$ENV_FILE")
else
    EXPANDED_ENV_FILE="$ENV_FILE"
fi

export $(grep -v '^#' "$EXPANDED_ENV_FILE" | xargs)

if [ -z "$BACKUP_DIR" ]; then
  BACKUP_DIR="$(pwd)/paperless-backups"
fi

BACKUP_DIR="$BACKUP_DIR/$TIMESTAMP"

echo "Backup directory set to $BACKUP_DIR"
echo "$BACKUP_DIR"

LOG_FILE="$BACKUP_DIR/backup-$TIMESTAMP.log"

mkdir -p "$BACKUP_DIR"

# Check for encryption password env variable
if [ -z "$BACKUP_ENCRYPTION_PASSWORD" ]; then
    echo "❌ ERROR: Environment variable BACKUP_ENCRYPTION_PASSWORD is not set."
    exit 1
fi

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

encrypt_file() {
    local file=$1
    log "🔐 Encrypting $file..."
    openssl enc -aes-256-cbc -salt -pbkdf2 -in "$file" -out "$file.enc" -pass pass:"$BACKUP_ENCRYPTION_PASSWORD"
    rm "$file"
    log "✅ Encrypted $file → $file.enc"
}

log "Backup Docker config files"
cp "$PAPERLESS_DIR/docker-compose.env" "$BACKUP_DIR/docker-compose.env"
cp "$PAPERLESS_DIR/docker-compose.yml" "$BACKUP_DIR/docker-compose.yml"

log "🔻 Stopping Paperless containers (with timeout)..."
if ! timeout 60s docker compose --project-directory "$PAPERLESS_DIR"  stop; then
    log "❌ ERROR: doker composestop timed out or failed."
    exit 1
fi

log "🔹 Backing up Paperless-ngx data volume..."
if docker run --rm --volumes-from "$CONTAINER_PAPERLESS" -v "$BACKUP_DIR":/backup ubuntu \
    tar cfz /backup/paperless-ngx-backup-$TIMESTAMP.tar.gz /usr/src/paperless; then
    yes | encrypt_file "$BACKUP_DIR/paperless-ngx-backup-$TIMESTAMP.tar.gz"
else
    log "❌ ERROR: Failed to back up Paperless-ngx."
    exit 1
fi

log "🔹 Backing up Postgres volume (raw)..."
if docker run --rm --volumes-from "$CONTAINER_DB" -v "$BACKUP_DIR":/backup ubuntu \
    tar cfz /backup/paperless-db-backup-$TIMESTAMP.tar.gz /var/lib/postgresql/data; then
    yes | encrypt_file "$BACKUP_DIR/paperless-db-backup-$TIMESTAMP.tar.gz"
else
    log "❌ ERROR: Failed to back up Postgres volume."
    exit 1
fi

log "🔹 Backing up Redis volume (if exists)..."
if docker run --rm --volumes-from "$CONTAINER_REDIS" -v "$BACKUP_DIR":/backup ubuntu \
    tar cfz /backup/paperless-redis-backup-$TIMESTAMP.tar.gz /data; then
    yes | encrypt_file "$BACKUP_DIR/paperless-redis-backup-$TIMESTAMP.tar.gz"
else
    log "⚠️ WARNING: Redis backup failed or container not found (skipping)."
fi

log "🔼 Restarting Paperless containers..."
if ! timeout 60s docker compose --project-directory "$PAPERLESS_DIR" up -d; then
    log "❌ ERROR: dockr compose up -d timed out or failed."
    exit 1
fi

log "🔍 Checking service health..."
if ! docker compose --project-directory "$PAPERLESS_DIR" ps; then
    log "❌ ERROR: doker compose ps failed to report service status."
    exit 1
fi

log "✅ All Paperless backups completed and encrypted successfully."
log "📦 Encrypted backup files saved in: $BACKUP_DIR"