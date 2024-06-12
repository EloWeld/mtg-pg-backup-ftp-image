#!/bin/sh

# Function to URL-encode input
urlencode() {
  local length="${#1}"
  for (( i = 0; i < length; i++ )); do
    local c="${1:i:1}"
    case $c in
      [a-zA-Z0-9.~_-]) printf "$c" ;;
      *) printf '%%%02X' "'$c" ;;
    esac
  done
}

# The backup file to be transferred
BACKUP_FILE=$1
echo "Starting upload of $BACKUP_FILE"

# URL-encode the password
ENCODED_FTP_PASS=$(urlencode "$FTP_PASS")

# Debug: Print full path with obscure password
echo "curl -T \"$BACKUP_FILE\" \"ftp://$FTP_USER:***@$FTP_HOST/$FTP_PATH/\" --ftp-create-dirs"

# FTP upload
curl -T "$BACKUP_FILE" "ftp://$FTP_USER:$ENCODED_FTP_PASS@$FTP_HOST/$FTP_PATH/" --ftp-create-dirs

# Check if the upload was successful
if [ $? -eq 0 ]; then
  echo "Upload successful: $BACKUP_FILE"
else
  echo "Upload failed"
  exit 1
fi