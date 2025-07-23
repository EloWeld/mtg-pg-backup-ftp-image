#!/bin/sh

# Function to create SFTP batch commands file
create_sftp_batch() {
  local batch_file="$1"
  local remote_file="$2"
  local local_file="$3"
  
  cat > "$batch_file" << EOF
put "$local_file" "$SFTP_PATH/$remote_file"
quit
EOF
}

# Function to create SFTP delete batch commands
create_delete_batch() {
  local batch_file="$1"
  local file_to_delete="$2"
  
  cat > "$batch_file" << EOF
rm "$SFTP_PATH/$file_to_delete"
quit
EOF
}

# Function to create SFTP list batch commands
create_list_batch() {
  local batch_file="$1"
  
  cat > "$batch_file" << EOF
ls "$SFTP_PATH/"
quit
EOF
}

# The backup file to be transferred
BACKUP_FILE=$1
echo "Starting SFTP upload of $BACKUP_FILE"

# Extract filename from full path
BACKUP_FILENAME=$(basename "$BACKUP_FILE")

# Set default port if not specified
SFTP_PORT="${SFTP_PORT:-22}"

# Create temporary directory for SFTP batch files
TEMP_DIR="/tmp/sftp_$$"
mkdir -p "$TEMP_DIR"

# Setup SFTP connection options
SFTP_OPTIONS=""
if [ -n "$SFTP_PRIVATE_KEY" ]; then
  # If private key is provided, save it to a file
  echo "$SFTP_PRIVATE_KEY" > "$TEMP_DIR/private_key"
  chmod 600 "$TEMP_DIR/private_key"
  SFTP_OPTIONS="-i $TEMP_DIR/private_key"
elif [ -n "$SFTP_PASSWORD" ]; then
  # For password authentication, we'll use sshpass if available
  if command -v sshpass >/dev/null 2>&1; then
    SFTP_CMD="sshpass -p '$SFTP_PASSWORD' sftp"
  else
    echo "Warning: sshpass not available and no private key provided. You may need to enter password manually."
    SFTP_CMD="sftp"
  fi
else
  SFTP_CMD="sftp"
fi

# Set default SFTP command if not set above
SFTP_CMD="${SFTP_CMD:-sftp}"

# Create batch file for upload
UPLOAD_BATCH="$TEMP_DIR/upload_batch"
create_sftp_batch "$UPLOAD_BATCH" "$BACKUP_FILENAME" "$BACKUP_FILE"

# Debug: Print connection info (hide sensitive data)
echo "$SFTP_CMD $SFTP_OPTIONS -P $SFTP_PORT -b \"$UPLOAD_BATCH\" $SFTP_USER@$SFTP_HOST"

# Create remote directory if it doesn't exist
MKDIR_BATCH="$TEMP_DIR/mkdir_batch"
cat > "$MKDIR_BATCH" << EOF
mkdir "$SFTP_PATH"
quit
EOF

# Try to create directory (ignore errors if it already exists)
$SFTP_CMD $SFTP_OPTIONS -P "$SFTP_PORT" -b "$MKDIR_BATCH" "$SFTP_USER@$SFTP_HOST" 2>/dev/null

# SFTP upload
$SFTP_CMD $SFTP_OPTIONS -P "$SFTP_PORT" -b "$UPLOAD_BATCH" "$SFTP_USER@$SFTP_HOST"

# Check if the upload was successful
if [ $? -eq 0 ]; then
  echo "Upload successful: $BACKUP_FILE"
else
  echo "Upload failed"
  # Cleanup temp files
  rm -rf "$TEMP_DIR"
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

  # Create batch file for listing
  LIST_BATCH="$TEMP_DIR/list_batch"
  create_list_batch "$LIST_BATCH"

  # List all backups via SFTP
  BACKUPS_LIST="$TEMP_DIR/backups_list"
  $SFTP_CMD $SFTP_OPTIONS -P "$SFTP_PORT" -b "$LIST_BATCH" "$SFTP_USER@$SFTP_HOST" > "$BACKUPS_LIST" 2>/dev/null

  # Parse the output and extract filenames
  BACKUPS=$(grep "^db_backup_" "$BACKUPS_LIST" 2>/dev/null | awk '{print $NF}' | grep "^db_backup_")

  for BACKUP in $BACKUPS; do
    # Extract the date string from the backup filename
    # Supports multiple formats: db_backup_YYYYMMDDHHMMSS.sql, db_backup_YYYYMMDDHHMMSS.sql.tar.gz, db_backup_YYYYMMDDHHMMSS.sql.tar.gz.enc, etc.
    BACKUP_DATE_STR=$(echo "$BACKUP" | sed -n 's/^.*db_backup_\([0-9]\{14\}\)\..*$/\1/p')

    # Skip if the filename doesn't match the expected format
    if [ -z "$BACKUP_DATE_STR" ]; then
      continue
    fi

    # Convert the date string to timestamp
    # Extract components: YYYYMMDDHHMMSS
    YEAR=$(echo "$BACKUP_DATE_STR" | cut -c1-4)
    MONTH=$(echo "$BACKUP_DATE_STR" | cut -c5-6)
    DAY=$(echo "$BACKUP_DATE_STR" | cut -c7-8)
    HOUR=$(echo "$BACKUP_DATE_STR" | cut -c9-10)
    MIN=$(echo "$BACKUP_DATE_STR" | cut -c11-12)
    SEC=$(echo "$BACKUP_DATE_STR" | cut -c13-14)
    
    # Create a date string that 'date' can understand
    DATE_STR="$YEAR-$MONTH-$DAY $HOUR:$MIN:$SEC"
    BACKUP_TIMESTAMP=$(date -d "$DATE_STR" +%s 2>/dev/null)

    # Skip if date conversion failed (try alternative format for different systems)
    if [ -z "$BACKUP_TIMESTAMP" ]; then
      BACKUP_TIMESTAMP=$(date -j -f "%Y-%m-%d %H:%M:%S" "$DATE_STR" +%s 2>/dev/null)
    fi

    # Skip if date conversion still failed
    if [ -z "$BACKUP_TIMESTAMP" ]; then
      continue
    fi

    # Compare timestamps
    if [ "$BACKUP_TIMESTAMP" -lt "$CUTOFF_TIMESTAMP" ]; then
      echo "Deleting old backup: $BACKUP"
      DELETE_BATCH="$TEMP_DIR/delete_$BACKUP"
      create_delete_batch "$DELETE_BATCH" "$BACKUP"
      $SFTP_CMD $SFTP_OPTIONS -P "$SFTP_PORT" -b "$DELETE_BATCH" "$SFTP_USER@$SFTP_HOST" 2>/dev/null
    fi
  done
}

# Check if AUTO_DELETE_ENABLED is set to true
if [ "$AUTO_DELETE_ENABLED" = "true" ]; then
  delete_old_backups
else
  echo "Automatic deletion is disabled."
fi

# Cleanup temporary files
rm -rf "$TEMP_DIR"