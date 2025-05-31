#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Backup the volumes
ENV_FILE="$ENV_FILE" "$SCRIPT_DIR/paperless-tar-volumes.sh"

# Send volumes to external storage provider
ENV_FILE="$ENV_FILE" "$SCRIPT_DIR/paperless-backup-to-storage.sh"