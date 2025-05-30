#!/bin/bash

set -e  # Exit if any command fails

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$ENV_FILE" ]; then
  ENV_FILE="$SCRIPT_DIR/paperless-backup.env"
fi

export $(grep -v '^#' "$ENV_FILE" | xargs)

if [ -z "$BACKUP_DIR" ]; then
  BACKUP_DIR="$(pwd)/paperless-backups"
fi

latest_folder=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d \
  | xargs -n1 basename \
  | grep -E '^[0-9]{8}-[0-9]{6}$' \
  | sort \
  | tail -n1)

echo "Send latest backup $BACKUP_DIR/$latest_folder to storage"

UPLOADED_DIR="$BACKUP_DIR/$latest_folder"
if rclone copy "$BACKUP_DIR/$latest_folder" guru-onedrive:"/paperless-backups/$latest_folder" --config "$RCLONE_CONFIG"; then
  echo "Upload successful cleanup folder $UPLOADED_DIR"
  rm -rf "$UPLOADED_DIR"
else
   echo "Upload failed"
fi