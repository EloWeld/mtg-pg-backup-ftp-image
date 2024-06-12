#!/bin/sh

# The backup file to be transferred
BACKUP_FILE=$1
echo "Starting upload of $BACKUP_FILE"

# Debug: Print full path with obsure password
echo "curl -T \"$BACKUP_FILE\" \"ftp://$FTP_USER:***@$FTP_HOST/$FTP_PATH/\" --ftp-create-dirs"

# FTP upload
curl -T "$BACKUP_FILE" "ftp://$FTP_USER:$FTP_PASS@$FTP_HOST/$FTP_PATH/" --ftp-create-dirs

# Check if the upload was successful
if [ $? -eq 0 ]; then
  echo "Upload successful: $BACKUP_FILE"
else
  echo "Upload failed"
  exit 1
fi