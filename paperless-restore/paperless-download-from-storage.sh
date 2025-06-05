#!/bin/bash

set -e  # Exit if any command fails

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load env file
if [ -z "$ENV_FILE" ]; then
  ENV_FILE="$SCRIPT_DIR/paperless-backup.env"
fi

# Expand ~ in path if present
if [[ "$ENV_FILE" == ~* ]]; then
    EXPANDED_ENV_FILE=$(eval echo "$ENV_FILE")
else
    EXPANDED_ENV_FILE="$ENV_FILE"
fi

# Export env vars
export $(grep -v '^#' "$EXPANDED_ENV_FILE" | xargs)

# Default backup dir if not defined
if [ -z "$BACKUP_DIR" ]; then
  BACKUP_DIR="$(pwd)/paperless-backups"
fi

# Create local backup dir if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Ensure RCLONE_REMOTE_NAME is defined
if [ -z "$RCLONE_REMOTE_NAME" ]; then
  echo "❌ ERROR: Environment variable RCLONE_REMOTE_NAME is not set."
  exit 1
fi

echo "🔍 Checking remote backups on storage..."
REMOTE_BACKUPS=$(rclone lsf "$RCLONE_REMOTE_NAME:/paperless-backups/" --config "$RCLONE_CONFIG" | grep -E '^[0-9]{8}-[0-9]{6}/$' | sort)

if [ -z "$REMOTE_BACKUPS" ]; then
  echo "❌ No backups found on remote storage."
  exit 1
fi

LATEST_REMOTE_BACKUP=$(echo "$REMOTE_BACKUPS" | tail -n 1 | sed 's:/$::')

echo "⬇️ Downloading latest backup: $LATEST_REMOTE_BACKUP"

LOCAL_BACKUP_PATH="$BACKUP_DIR/$LATEST_REMOTE_BACKUP"

if rclone copy "$RCLONE_REMOTE_NAME:/paperless-backups/$LATEST_REMOTE_BACKUP" "$LOCAL_BACKUP_PATH" --config "$RCLONE_CONFIG"; then
  echo "✅ Successfully downloaded backup to: $LOCAL_BACKUP_PATH"
else
  echo "❌ Failed to download backup."
  exit 1
fi
