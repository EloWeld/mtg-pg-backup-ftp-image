#!/bin/sh

echo "Starting restore process..."

# Variables
BACKUP_DIR="/downloaded-backups"

# URL-encode function
urlencode() {
  local input="$1"
  local output=""
  local i
  local c

  for i in $(seq 0 $((${#input} - 1))); do
    c=$(printf "%s" "${input:$i:1}")
    case "$c" in
      [a-zA-Z0-9.~_-]) output="$output$c" ;;
      *) output="$output$(printf '%%%02X' "'$c")" ;;
    esac
  done

  echo "$output"
}

# Build the FTP URL
ENCODED_FTP_USER=$(urlencode "$FTP_USER")
ENCODED_FTP_PASS=$(urlencode "$FTP_PASS")
ENCODED_FTP_HOST=$(urlencode "$FTP_HOST")

FTP_URL="ftp://$ENCODED_FTP_USER:$ENCODED_FTP_PASS@$ENCODED_FTP_HOST/$FTP_PATH/"

echo "Will attempt download from: $FTP_URL"

# Check if FTP_SSL is set to "true"
FTP_SSL_OPTION=""
if [ "$FTP_SSL" = "true" ]; then
  FTP_SSL_OPTION="--ftp-ssl"
fi

# List and sort backups, get the latest one
LATEST_BACKUP=$(curl -s $FTP_SSL_OPTION --list-only "$FTP_URL" | sort | tail -n 1)
BACKUP_FILE="$BACKUP_DIR/$LATEST_BACKUP"

# Confirm with user
echo "The latest backup is: $LATEST_BACKUP"
read -p "Do you want to restore this backup? WARNING: This will overwrite your database! (yes/N): " CONFIRMATION

if [ "$CONFIRMATION" != "yes" ]; then
  echo "Restore cancelled."
  exit 0
fi

# Ensure the backup directory exists
mkdir -p $BACKUP_DIR

# Download the latest backup
echo "Downloading the latest backup: $LATEST_BACKUP"
curl -o "$BACKUP_FILE" "$FTP_URL$LATEST_BACKUP" $FTP_SSL_OPTION

# Check if the download was successful
if [ $? -eq 0 ]; then
  echo "Download successful: $BACKUP_FILE"
else
  echo "Download failed"
  exit 1
fi

# Set the environment variables for the database connection
export PGPASSWORD=$POSTGRES_PASSWORD

# Restore the backup
echo "Restoring the backup..."
pg_restore -U $POSTGRES_USER -h $POSTGRES_HOST -d $POSTGRES_DB -v $BACKUP_FILE

# Check if the restore was successful
if [ $? -eq 0 ]; then
  echo "Restore successful"
else
  echo "Restore failed"
  exit 1
fi