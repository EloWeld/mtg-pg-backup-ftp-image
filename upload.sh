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