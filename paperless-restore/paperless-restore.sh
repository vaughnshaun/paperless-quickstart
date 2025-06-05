#!/bin/bash
set -e  # Exit on any error

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use passed ENV_FILE or default path
if [ -z "$ENV_FILE" ]; then
  ENV_FILE="$SCRIPT_DIR/paperless-backup.env"
fi

# Expand ~ in ENV_FILE if needed
if [[ "$ENV_FILE" == ~* ]]; then
    EXPANDED_ENV_FILE=$(eval echo "$ENV_FILE")
else
    EXPANDED_ENV_FILE="$ENV_FILE"
fi

# Load environment variables
export $(grep -v '^#' "$EXPANDED_ENV_FILE" | xargs)

# Use BACKUP_DIR from env or fallback to current directory
if [ -z "$BACKUP_DIR" ]; then
  BACKUP_DIR="$(pwd)/paperless-backups"
fi

# Assume you want to restore from the latest backup directory, not a timestamped new one
# So pick the most recent timestamped backup directory inside BACKUP_DIR
LATEST_BACKUP_DIR=$(ls -dt "$BACKUP_DIR"/*/ 2>/dev/null | head -n 1)
if [[ -z "$LATEST_BACKUP_DIR" ]]; then
    echo "❌ ERROR: No backup directories found inside $BACKUP_DIR"
    exit 1
fi

LOG_FILE="$LATEST_BACKUP_DIR/restore-$TIMESTAMP.log"

mkdir -p "$LATEST_BACKUP_DIR"

# Check encryption password present
if [ -z "$BACKUP_ENCRYPTION_PASSWORD" ]; then
    echo "❌ ERROR: Environment variable BACKUP_ENCRYPTION_PASSWORD is not set."
    exit 1
fi

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

decrypt_file() {
    local file=$1
    log "🔓 Decrypting $file..."
    local decrypted="${file%.enc}"
    openssl enc -d -aes-256-cbc -salt -pbkdf2 -in "$file" -out "$decrypted" -pass pass:"$BACKUP_ENCRYPTION_PASSWORD"
    log "✅ Decrypted $file → $decrypted"
}

log "Restore Docker config files"
cp "$LATEST_BACKUP_DIR/docker-compose.env" "$PAPERLESS_DIR/docker-compose.env"
cp "$LATEST_BACKUP_DIR/docker-compose.yml" "$PAPERLESS_DIR/docker-compose.yml"
cp "$LATEST_BACKUP_DIR/paperless-backup.env" "$PAPERLESS_DIR/paperless-backup.env"

log "🔻 Stopping Paperless containers (with timeout)..."
if ! timeout 60s docker compose --project-directory "$PAPERLESS_DIR" stop; then
    log "❌ ERROR: docker compose stop timed out or failed."
    exit 1
fi

# Decrypt backup files first
PAPERLESS_BACKUP_ENC="$LATEST_BACKUP_DIR/paperless-ngx-backup-*.tar.gz.enc"
POSTGRES_BACKUP_ENC="$LATEST_BACKUP_DIR/paperless-db-backup-*.tar.gz.enc"
REDIS_BACKUP_ENC="$LATEST_BACKUP_DIR/paperless-redis-backup-*.tar.gz.enc"

decrypt_file $(ls -1 $PAPERLESS_BACKUP_ENC | head -n 1)
decrypt_file $(ls -1 $POSTGRES_BACKUP_ENC | head -n 1)

# Redis backup might be optional
REDIS_BACKUP_FILE=$(ls -1 $REDIS_BACKUP_ENC 2>/dev/null | head -n 1)
if [[ -n "$REDIS_BACKUP_FILE" ]]; then
    decrypt_file "$REDIS_BACKUP_FILE"
else
    log "⚠️ Redis backup file not found, skipping Redis restore."
fi

# Restore Paperless data volume
PAPERLESS_BACKUP="${LATEST_BACKUP_DIR}/paperless-ngx-backup-*.tar.gz"
PAPERLESS_BACKUP=$(ls -1 $PAPERLESS_BACKUP | head -n 1)
log "🔹 Restoring Paperless-ngx data volume from $PAPERLESS_BACKUP ..."
docker run --rm --volumes-from "$CONTAINER_PAPERLESS" -v "$LATEST_BACKUP_DIR":/backup ubuntu \
    tar xfz "/backup/$(basename "$PAPERLESS_BACKUP")" -C "$PAPERLESS_VOLUME"

# Restore Postgres data volume
POSTGRES_BACKUP="${LATEST_BACKUP_DIR}/paperless-db-backup-*.tar.gz"
POSTGRES_BACKUP=$(ls -1 $POSTGRES_BACKUP | head -n 1)
log "🔹 Restoring Postgres volume from $POSTGRES_BACKUP ..."
docker run --rm --volumes-from "$CONTAINER_DB" -v "$LATEST_BACKUP_DIR":/backup ubuntu \
    tar xfz "/backup/$(basename "$POSTGRES_BACKUP")" -C "$DB_VOLUME"

# Restore Redis volume if available
if [[ -n "$REDIS_BACKUP_FILE" ]]; then
    REDIS_BACKUP="${LATEST_BACKUP_DIR}/paperless-redis-backup-*.tar.gz"
    REDIS_BACKUP=$(ls -1 $REDIS_BACKUP | head -n 1)
    log "🔹 Restoring Redis volume from $REDIS_BACKUP ..."
    docker run --rm --volumes-from "$CONTAINER_REDIS" -v "$LATEST_BACKUP_DIR":/backup ubuntu \
        tar xfz "/backup/$(basename "$REDIS_BACKUP")" -C "$REDIS_VOLUME"
fi

log "🔼 Restarting Paperless containers..."
if ! timeout 60s docker compose --project-directory "$PAPERLESS_DIR" up -d; then
    log "❌ ERROR: docker compose up -d timed out or failed."
    exit 1
fi

log "🔍 Checking service health..."
if ! docker compose --project-directory "$PAPERLESS_DIR" ps; then
    log "❌ ERROR: docker compose ps failed to report service status."
    exit 1
fi

log "✅ Restore completed successfully."
log "📦 Restored backup files from: $LATEST_BACKUP_DIR"
