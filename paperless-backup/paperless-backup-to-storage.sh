#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Backup the volumes
ENV_FILE="$ENV_FILE" "$SCRIPT_DIR/paperless-tar-volumes.sh"

# Send volumes to external storage provider
ENV_FILE="$ENV_FILE" "$SCRIPT_DIR/paperless-backup-to-storage.sh"
vaughnshaun@paperless:~$ cat paperless-backup/paperless-backup-to-storage.sh
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