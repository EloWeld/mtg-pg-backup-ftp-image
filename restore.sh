#!/bin/sh

echo "Starting restore process..."

# Variablen
BACKUP_DIR="/downloaded-backups"

# Set default port if not specified
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
SFTP_PORT="${SFTP_PORT:-22}"

# Function to create SFTP batch commands file
create_sftp_batch() {
  local batch_file="$1"
  local command="$2"
  
  cat > "$batch_file" << EOF
$command
quit
EOF
}

# Create temporary directory for SFTP batch files
TEMP_DIR="/tmp/sftp_restore_$$"
mkdir -p "$TEMP_DIR"

# Setup SFTP connection options
SFTP_OPTIONS=""
if [ -n "$SFTP_PRIVATE_KEY" ]; then
  # If private key is provided, save it to a file
  echo "$SFTP_PRIVATE_KEY" > "$TEMP_DIR/private_key"
  chmod 600 "$TEMP_DIR/private_key"
  SFTP_OPTIONS="-i $TEMP_DIR/private_key"
  SFTP_CMD="sftp"
elif [ -n "$SFTP_PASSWORD" ]; then
  # For password authentication, use sshpass
  SFTP_CMD="sshpass -p '$SFTP_PASSWORD' sftp"
else
  SFTP_CMD="sftp"
fi

echo "Will attempt download from: $SFTP_USER@$SFTP_HOST:$SFTP_PATH/"

# Create batch file for listing files
LIST_BATCH="$TEMP_DIR/list_batch"
create_sftp_batch "$LIST_BATCH" "ls \"$SFTP_PATH/\""

# Liste der Backups abrufen und das neueste auswählen
BACKUPS_LIST="$TEMP_DIR/backups_list"
$SFTP_CMD $SFTP_OPTIONS -P "$SFTP_PORT" -b "$LIST_BATCH" "$SFTP_USER@$SFTP_HOST" > "$BACKUPS_LIST" 2>/dev/null

# Extract and sort backup filenames
LATEST_BACKUP=$(grep "^db_backup_" "$BACKUPS_LIST" 2>/dev/null | awk '{print $NF}' | grep "^db_backup_" | sort | tail -n 1)

if [ -z "$LATEST_BACKUP" ]; then
  echo "No backups found on the SFTP server."
  rm -rf "$TEMP_DIR"
  exit 1
fi

BACKUP_FILE="$BACKUP_DIR/$LATEST_BACKUP"

# Bestätigung vom Benutzer einholen
echo "The latest backup is: $LATEST_BACKUP"
read -p "Do you want to restore this backup? WARNING: This will DROP and RECREATE your database! (yes/N): " CONFIRMATION

if [ "$CONFIRMATION" != "yes" ]; then
  echo "Restore cancelled."
  rm -rf "$TEMP_DIR"
  exit 0
fi

# Sicherstellen, dass das Backup-Verzeichnis existiert
mkdir -p $BACKUP_DIR

# Create batch file for download
DOWNLOAD_BATCH="$TEMP_DIR/download_batch"
create_sftp_batch "$DOWNLOAD_BATCH" "get \"$SFTP_PATH/$LATEST_BACKUP\" \"$BACKUP_FILE\""

# Neuestes Backup herunterladen
echo "Downloading the latest backup: $LATEST_BACKUP"
$SFTP_CMD $SFTP_OPTIONS -P "$SFTP_PORT" -b "$DOWNLOAD_BATCH" "$SFTP_USER@$SFTP_HOST"

# Überprüfen, ob der Download erfolgreich war
if [ $? -eq 0 ] && [ -f "$BACKUP_FILE" ]; then
  echo "Download successful: $BACKUP_FILE"
else
  echo "Download failed"
  rm -rf "$TEMP_DIR"
  exit 1
fi

# Überprüfung, ob Verschlüsselung aktiviert ist
if [ "$ENCRYPTION_ENABLED" = "true" ]; then
  if [ -z "$ENCRYPTION_PASSWORD" ]; then
    echo "Encryption password is not set. Please set ENCRYPTION_PASSWORD."
    rm -rf "$TEMP_DIR"
    exit 1
  fi

  echo "Decrypting the backup file..."
  DECRYPTED_BACKUP_FILE="${BACKUP_FILE%.enc}"

  openssl enc -d -aes-256-cbc -pbkdf2 -in "$BACKUP_FILE" -out "$DECRYPTED_BACKUP_FILE" -k "$ENCRYPTION_PASSWORD"

  if [ $? -eq 0 ]; then
    echo "Decryption successful: $DECRYPTED_BACKUP_FILE"
    # Aktualisiere BACKUP_FILE auf die entschlüsselte Datei
    BACKUP_FILE="$DECRYPTED_BACKUP_FILE"
  else
    echo "Decryption failed"
    rm -rf "$TEMP_DIR"
    exit 1
  fi
fi

# Check if the backup file is compressed (tar.gz)
if echo "$BACKUP_FILE" | grep -q "\.tar\.gz$"; then
  echo "Decompressing the backup file..."
  DECOMPRESSED_DIR="$BACKUP_DIR/extracted"
  mkdir -p "$DECOMPRESSED_DIR"
  
  # Extract tar.gz file
  tar -xzf "$BACKUP_FILE" -C "$DECOMPRESSED_DIR"
  
  if [ $? -eq 0 ]; then
    echo "Decompression successful"
    # Find the SQL file in the extracted directory
    SQL_FILE=$(find "$DECOMPRESSED_DIR" -name "*.sql" | head -n 1)
    if [ -n "$SQL_FILE" ]; then
      BACKUP_FILE="$SQL_FILE"
      echo "Found SQL file: $BACKUP_FILE"
    else
      echo "No SQL file found in the archive"
      rm -rf "$TEMP_DIR"
      exit 1
    fi
  else
    echo "Decompression failed"
    rm -rf "$TEMP_DIR"
    exit 1
  fi
fi

# Setze die Umgebungsvariable für die Datenbankverbindung
export PGPASSWORD=$POSTGRES_PASSWORD

# Die Datenbank droppen und neu erstellen
echo "Dropping and recreating the database..."
echo "Connecting to: $POSTGRES_HOST:$POSTGRES_PORT as $POSTGRES_USER"

psql -U $POSTGRES_USER -h $POSTGRES_HOST -p $POSTGRES_PORT -d postgres -c "DROP DATABASE $POSTGRES_DB;"
if [ $? -ne 0 ]; then
  echo "Failed to drop the database."
  rm -rf "$TEMP_DIR"
  exit 1
fi

psql -U $POSTGRES_USER -h $POSTGRES_HOST -p $POSTGRES_PORT -d postgres -c "CREATE DATABASE $POSTGRES_DB WITH OWNER $POSTGRES_USER;"
if [ $? -ne 0 ]; then
  echo "Failed to create the database."
  rm -rf "$TEMP_DIR"
  exit 1
fi

echo "Database dropped and recreated successfully."

# Backup wiederherstellen
echo "Restoring the backup..."
psql -U $POSTGRES_USER -h $POSTGRES_HOST -p $POSTGRES_PORT -d $POSTGRES_DB -f "$BACKUP_FILE"

# Überprüfen, ob die Wiederherstellung erfolgreich war
if [ $? -eq 0 ]; then
  echo "Restore successful"
else
  echo "Restore failed"
  rm -rf "$TEMP_DIR"
  exit 1
fi

# Cleanup temporary files
rm -rf "$TEMP_DIR"