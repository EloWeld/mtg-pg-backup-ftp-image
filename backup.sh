#!/bin/bash

# Variables
BACKUP_DIR="/backups"
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
BACKUP_FILE="$BACKUP_DIR/db_backup_$TIMESTAMP.sql"

# Ensure the backup directory exists
mkdir -p $BACKUP_DIR

# Set the environment variables for the database connection
export PGPASSWORD=$POSTGRES_PASSWORD

# Perform the backup
pg_dump -U $POSTGRES_USER -h $POSTGRES_HOST -F p -b -v -f $BACKUP_FILE $POSTGRES_DB

# Check if the backup was successful
if [ $? -eq 0 ]; then
  echo "Backup successful: $BACKUP_FILE"
else
  echo "Backup failed"
  exit 1
fi

# Call the upload script
/scripts/upload.sh $BACKUP_FILE