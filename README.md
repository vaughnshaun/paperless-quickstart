# Paperless Quickstart
This is to get you up and running with Paperless-ngx fast. It is as simple as downloading the scripts and running them.

## Prerequisites
This script uses three dependencies that might not be available on most systems.

1. docker (obviously required for this project since it installs Paperless-ngx using Docker).
2. rclone for interacting with external storage providers. Data is backed up to cloud but remains private due to encryption.
3. openssl used for encrypting the backups. So we get to use the power of the cloud, but keep our privacy.

Update the package manager index
```bash
sudo apt update
```

Install dependencies
```bash
sudo apt install rclone
sudo apt install openssl
```

### RClone and External Storage Providers
RClone is used to interact with many external storage providers in a seamless way. The steps are simple.

1. Create remote reference.
2. Run commands to move, copy, list, delete, etc. files.

### Create remote

```bash
rclone config
```

1. `n` for new remote.
2. select storage type, for me one drive is `21`.
3. Leave client_id and client_secret blank.
4. `n` No to advanced config.
5. If in headless enter `n` no for headless machine.
6. Go to a computer that has a web browser.
7. Run `rclone authorize "onedrive"`.
8. Copy the whole json that is generated in the console and past to the main machine.

Prints /home/username
```bash
echo ~
```

After the config has been updated, view it at the below
```bash
ls -a ~/.config/rclone
```

DON'T HAVE TO RUN. THE CREATE USER SCRIPT RUNS THIS. After confirming location copy the cofing to the paperless-backup-user folder
```bash
sudo cp ~/.config/rclone/rclone.conf /etc/paperless-backup-user/rclone.conf
```

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

View location of rclone config file in paperless-backup-user
```bash
sudo ls -a /etc/paperless-backup-user/
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