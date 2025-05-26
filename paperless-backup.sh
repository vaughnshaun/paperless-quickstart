#!/bin/bash

set -e  # Exit if any command fails

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
BACKUP_DIR="$(pwd)/paperless-backups"
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

log "🔻 Stopping Paperless containers (with timeout)..."
if ! timeout 60s docker-compose down; then
    log "❌ ERROR: docker-compose down timed out or failed."
    exit 1
fi

log "🔹 Backing up Paperless-ngx data volume..."
if docker run --rm --volumes-from paperless-ngx -v "$BACKUP_DIR":/backup ubuntu \
    tar cf /backup/paperless-ngx-backup-$TIMESTAMP.tar /usr/src/paperless; then
    encrypt_file "$BACKUP_DIR/paperless-ngx-backup-$TIMESTAMP.tar"
else
    log "❌ ERROR: Failed to back up Paperless-ngx."
    exit 1
fi

log "🔹 Backing up Postgres volume (raw)..."
if docker run --rm --volumes-from paperless-db -v "$BACKUP_DIR":/backup ubuntu \
    tar cf /backup/paperless-db-backup-$TIMESTAMP.tar /var/lib/postgresql/data; then
    encrypt_file "$BACKUP_DIR/paperless-db-backup-$TIMESTAMP.tar"
else
    log "❌ ERROR: Failed to back up Postgres volume."
    exit 1
fi

log "🔹 Backing up Redis volume (if exists)..."
if docker run --rm --volumes-from paperless-redis -v "$BACKUP_DIR":/backup ubuntu \
    tar cf /backup/paperless-redis-backup-$TIMESTAMP.tar /data; then
    encrypt_file "$BACKUP_DIR/paperless-redis-backup-$TIMESTAMP.tar"
else
    log "⚠️ WARNING: Redis backup failed or container not found (skipping)."
fi

log "🔼 Restarting Paperless containers..."
if ! timeout 60s docker-compose up -d; then
    log "❌ ERROR: docker-compose up -d timed out or failed."
    exit 1
fi

log "🔍 Checking service health..."
if ! docker-compose ps; then
    log "❌ ERROR: docker-compose ps failed to report service status."
    exit 1
fi

log "✅ All Paperless backups completed and encrypted successfully."
log "📦 Encrypted backup files saved in: $BACKUP_DIR"
