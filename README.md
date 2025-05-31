# Paperless Quickstart
This is to get you up and running with Paperless-ngx fast. It is as simple as downloading the scripts and running them.

## Backup Paperless
Before backing up paperless, a dedicated system user should be used for making backups. There is a quick script that creates the proper folder structure and permissions for the user `paperless-backup-user`.

### Create System User for Backups
Grant execute permissions (Only needs to be run once)
```bash
chmod +x ./create-paperless-backup-user.sh
```

Create the dedicated user for the backup script (Only needs to be run once)
```bash
./create-paperless-backup-user.sh
```

View user to verify creation
```bash
# user id
id -u paperless-backup-user

# group id
id -g paperless-backup-user

# check group membership
groups paperless-backup-user
```

### Run Backup Script
Grant execute permissions (Only needs to be run once)
```bash
chmod +x ./paperless-backup/paperless-backup.sh
```

Run backup script under system user
```bash
sudo -u paperless-backup-user ENV_FILE="/home/vaughnshaun/paperless-ngx/paperless-backup.env" BACKUP_ENCRYPTION_PASSWORD="your-encryption-password" paperless-backup/paperless-backup.sh
```