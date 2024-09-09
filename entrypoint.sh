#!/bin/sh

# Default to daily if CRON_SCHEDULE is not set
CRON_SCHEDULE="${CRON_SCHEDULE:-0 2 * * *}"

# Create a new crontab file with output redirected to stdout
echo "$CRON_SCHEDULE /scripts/backup.sh >> /proc/1/fd/1 2>&1" > /etc/crontabs/root

echo "Cron job schedule: $CRON_SCHEDULE"
# build the full ftp url
echo "Will upload to ftp://${FTP_USER}:XXXXXX@${FTP_HOST}/${FTP_PATH}/   (password hidden for security)"

# Start cron in the foreground
crond -f