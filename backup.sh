#!/bin/sh

echo "Starting backup process..."

# Variables
BACKUP_DIR="/backups"
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
BACKUP_FILE="$BACKUP_DIR/db_backup_$TIMESTAMP.sql"

# Set default port if not specified
POSTGRES_PORT="${POSTGRES_PORT:-5432}"

# Ensure the backup directory exists
mkdir -p $BACKUP_DIR

# Set the environment variables for the database connection
export PGPASSWORD=$POSTGRES_PASSWORD

# Perform the backup
echo "Creating backup file..."
echo "Connecting to: $POSTGRES_HOST:$POSTGRES_PORT/$POSTGRES_DB as $POSTGRES_USER"
pg_dump -U $POSTGRES_USER -h $POSTGRES_HOST -p $POSTGRES_PORT -F p -b -v -f $BACKUP_FILE $POSTGRES_DB

# Check if the backup was successful
if [ $? -eq 0 ]; then
  echo "Backup successful: $BACKUP_FILE"
else
  echo "Backup failed"
  exit 1
fi

# Check if compression is enabled
if [ "$COMPRESSION_ENABLED" = "true" ]; then
  echo "Compressing the backup file..."
  COMPRESSED_FILE="${BACKUP_FILE}.tar.gz"
  
  # Create tar.gz archive
  tar -czf "$COMPRESSED_FILE" -C "$BACKUP_DIR" "$(basename "$BACKUP_FILE")"
  
  if [ $? -eq 0 ]; then
    echo "Compression successful: $COMPRESSED_FILE"
    # Remove the uncompressed backup file
    rm "$BACKUP_FILE"
    # Update BACKUP_FILE to point to the compressed file
    BACKUP_FILE="$COMPRESSED_FILE"
  else
    echo "Compression failed"
    exit 1
  fi
fi

# Check if encryption is enabled
if [ "$ENCRYPTION_ENABLED" = "true" ]; then
  if [ -z "$ENCRYPTION_PASSWORD" ]; then
    echo "Encryption password is not set. Please set ENCRYPTION_PASSWORD."
    exit 1
  fi

  echo "Encrypting the backup file..."
  openssl enc -aes-256-cbc -salt -pbkdf2 -in "$BACKUP_FILE" -out "${BACKUP_FILE}.enc" -k "$ENCRYPTION_PASSWORD"
  
  if [ $? -eq 0 ]; then
    echo "Encryption successful: ${BACKUP_FILE}.enc"
    # Remove the unencrypted backup file
    rm "$BACKUP_FILE"
    # Update BACKUP_FILE to point to the encrypted file
    BACKUP_FILE="${BACKUP_FILE}.enc"
  else
    echo "Encryption failed"
    exit 1
  fi
fi

# Call the upload script
/scripts/upload.sh "$BACKUP_FILE"