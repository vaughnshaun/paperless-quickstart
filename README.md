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

## Setup paperless-backup.env file
Change the variables in the env file to fit your needs. It is recommended to keep this file in your paperless-ngx folder. This file will get bundled in the backup when the backup runs.

## Run Backup Script
Run backup script under system user
```bash
sudo -u paperless-backup-user ENV_FILE="/home/vaughnshaun/paperless-ngx/paperless-backup.env" BACKUP_ENCRYPTION_PASSWORD="your-encryption-password" paperless-backup/paperless-backup.sh
```

## Run Backup Script System Wide
Move script to a system wide local and make executable
```bash
# Create myscripts directory (myscripts is where you should keep all custom scripts).
sudo mkdir -p /opt/myscripts

# Inside of the main repo directory, copy paperless-backup to the myscripts folder 
sudo cp -r paperless-backup /opt/myscripts/paperless-backup

# Verfiy path
which paperless-backup/paperless-backup.sh

# Set dir permissions (traversable)
sudo find /opt/myscripts/paperless-backup -type d -exec chmod 755 {} \;

# Set script file permissions (only .sh or known scripts)
sudo find /opt/myscripts/paperless-backup -type f -name "*.sh" -exec chmod 755 {} \;
```

Run the backup
```bash
sudo -u paperless-backup-user ENV_FILE="/home/vaughnshaun/paperless-ngx/paperless-backup.env" BACKUP_ENCRYPTION_PASSWORD="your-password" paperless-backup/paperless-backup.sh
```