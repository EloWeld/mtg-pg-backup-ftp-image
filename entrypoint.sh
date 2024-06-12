#!/bin/sh

# Default to daily if CRON_SCHEDULE is not set
CRON_SCHEDULE="${CRON_SCHEDULE:-0 2 * * *}"

# Create a new crontab file
echo "$CRON_SCHEDULE /scripts/backup.sh >> /var/log/cron.log 2>&1" > /etc/crontabs/root

# Start cron in the foreground
crond -f