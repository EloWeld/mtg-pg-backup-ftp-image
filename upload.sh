#!/bin/sh

# Function to URL-encode input
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

# The backup file to be transferred
BACKUP_FILE=$1
echo "Starting upload of $BACKUP_FILE"

# URL-encode the password
ENCODED_FTP_PASS=$(urlencode "$FTP_PASS")

# Check if FTP_SSL is set to "true"
FTP_SSL_OPTION=""
if [ "$FTP_SSL" = "true" ]; then
  FTP_SSL_OPTION="--ftp-ssl"
fi

# Debug: Print full path with obscure password
echo "curl -T \"$BACKUP_FILE\" \"ftp://$FTP_USER:***@$FTP_HOST/$FTP_PATH/\" --ftp-create-dirs $FTP_SSL_OPTION"

# FTP upload
curl -T "$BACKUP_FILE" "ftp://$FTP_USER:$ENCODED_FTP_PASS@$FTP_HOST/$FTP_PATH/" --ftp-create-dirs $FTP_SSL_OPTION

# Check if the upload was successful
if [ $? -eq 0 ]; then
  echo "Upload successful: $BACKUP_FILE"
else
  echo "Upload failed"
  exit 1
fi

# Set default value for BACKUP_RETENTION_DAYS if not set
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"  # Default to 30 days

# Set default value for AUTO_DELETE_ENABLED if not set
AUTO_DELETE_ENABLED="${AUTO_DELETE_ENABLED:-true}"  # Default to true

# Delete old backups based on BACKUP_RETENTION_DAYS
delete_old_backups() {
  echo "Checking for backups older than $BACKUP_RETENTION_DAYS days to delete..."

  # Calculate the cutoff date in seconds since epoch
  CURRENT_TIMESTAMP=$(date +%s)
  RETENTION_PERIOD_SECONDS=$(expr $BACKUP_RETENTION_DAYS \* 86400)
  CUTOFF_TIMESTAMP=$(expr $CURRENT_TIMESTAMP - $RETENTION_PERIOD_SECONDS)

  # List all backups
  BACKUPS=$(curl -s $FTP_SSL_OPTION --list-only "ftp://$FTP_USER:$ENCODED_FTP_PASS@$FTP_HOST/$FTP_PATH/")

  for BACKUP in $BACKUPS; do
    # Extract the date string from the backup filename
    # Supports multiple formats: db_backup_YYYYMMDDHHMMSS.sql, db_backup_YYYYMMDDHHMMSS.sql.tar.gz, db_backup_YYYYMMDDHHMMSS.sql.tar.gz.enc, etc.
    BACKUP_DATE_STR=$(echo "$BACKUP" | sed -n 's/^.*db_backup_\([0-9]\{14\}\)\..*$/\1/p')

    # Skip if the filename doesn't match the expected format
    if [ -z "$BACKUP_DATE_STR" ]; then
      continue
    fi

    # Convert the date string to timestamp
    # BusyBox date might not support this directly, so we use a workaround
    # Note: This requires that the system's 'date' command supports parsing the date format
    BACKUP_TIMESTAMP=$(date -u -D "%Y%m%d%H%M%S" "$BACKUP_DATE_STR" +%s 2>/dev/null)

    # Skip if date conversion failed
    if [ -z "$BACKUP_TIMESTAMP" ]; then
      continue
    fi

    # Compare timestamps
    if [ "$BACKUP_TIMESTAMP" -lt "$CUTOFF_TIMESTAMP" ]; then
      echo "Deleting old backup: $BACKUP"
      curl -s -X "DELE $BACKUP" "ftp://$FTP_USER:$ENCODED_FTP_PASS@$FTP_HOST/$FTP_PATH/$BACKUP" $FTP_SSL_OPTION
    fi
  done
}

# Check if AUTO_DELETE_ENABLED is set to true
if [ "$AUTO_DELETE_ENABLED" = "true" ]; then
  delete_old_backups
else
  echo "Automatic deletion is disabled."
fi