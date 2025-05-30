# create system account
sudo useradd --system --no-create-home --shell /usr/sbin/nologin paperless-backup-user

# create directories for
sudo mkdir -p /var/app-backups/paperless
sudo mkdir -p /etc/paperless-backup-user

# Set Folder Permissions

# Change owner of folders to the user:group
sudo chown -R paperless-backup-user:paperless-backup-user /var/app-backups/paperless
sudo chown -R paperless-backup-user:paperless-backup-user /etc/paperless-backup-user

# 700 = read, write, and execute
sudo chmod 700 /var/app-backups/paperless
sudo chmod 700 /etc/paperless-backup-user

# Copy rclone config to user folder
sudo cp ~/.config/rclone/rclone.conf /etc/paperless-backup-user/rclone.conf

# Make rclone.conf read only
sudo chown paperless-backup-user:paperless-backup-user /etc/paperless-backup-user/rclone.conf
sudo chmod 400 /etc/paperless-backup-user/rclone.conf

# Give user permission to docker
sudo usermod -aG docker paperless-backup-user