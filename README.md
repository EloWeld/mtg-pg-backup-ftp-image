# Postgres Backup and SFTP Upload with Optional Encryption and Compression

This is an easy-to-use side-car container for backing up a PostgreSQL database and uploading the backup to a SFTP server. The container is designed to run as a cron job, with configurable schedules and connection details provided via environment variables. Manual backups can also be triggered by running the backup script inside the container. Even restoring from the latest backup is possible.

## Features

- Backs up a PostgreSQL database daily by default, or according to a custom cron schedule.
- Uploads the backup to a specified SFTP server with SSH key or password authentication.
- Optional compression using tar.gz format to reduce backup file size.
- Optional encryption using AES-256-CBC for enhanced security.
- Easy configuration via environment variables.
- Simple integration with Docker Compose.

## Using Compression

To reduce the size of backup files, you can enable compression. This will compress the SQL dump using tar.gz format before upload.

### Enabling Compression

Set the following environment variable:

```sh
COMPRESSION_ENABLED=true
```

When compression is enabled, the backup process will:
1. Create the SQL dump file
2. Compress it using tar.gz format
3. Optionally encrypt the compressed file if encryption is also enabled

## Using Encryption

To enhance the security of your backups, especially when the SFTP server is not fully trusted, you can enable encryption. This will encrypt the backup file using AES-256-CBC encryption before uploading it to the SFTP server.

### Enabling Encryption

Set the following environment variables:

```sh
ENCRYPTION_ENABLED=true
ENCRYPTION_PASSWORD=your_encryption_password
```

## Environment Variables

The following environment variables can be set to configure the behavior of the backup and upload processes:

### PostgreSQL Settings
- `POSTGRES_USER`: The PostgreSQL user (required).
- `POSTGRES_PASSWORD`: The PostgreSQL password (required).
- `POSTGRES_DB`: The PostgreSQL database name (required).
- `POSTGRES_HOST`: The PostgreSQL host (required).
- `POSTGRES_PORT`: The PostgreSQL port (optional, defaults to 5432).

### SFTP Settings
- `SFTP_USER`: The SFTP user (required).
- `SFTP_PASSWORD`: The SFTP password (optional, required if SFTP_PRIVATE_KEY is not provided).
- `SFTP_PRIVATE_KEY`: The SSH private key for SFTP authentication (optional, preferred over password).
- `SFTP_HOST`: The SFTP server host (required).
- `SFTP_PORT`: The SFTP server port (optional, defaults to 22).
- `SFTP_PATH`: The SFTP server path where backups will be uploaded (required).

### Backup Settings
- `CRON_SCHEDULE`: The cron schedule string (optional, defaults to "0 2 * * *" for daily at 2 AM).
- `BACKUP_RETENTION_DAYS`: The number of days to keep backups on the SFTP server (optional, defaults to 30).
- `AUTO_DELETE_ENABLED`: Enable/disable auto deletion of old backups (optional, defaults to true).
- `COMPRESSION_ENABLED`: Enable compression of the backup file using tar.gz format (optional, defaults to false).
- `ENCRYPTION_ENABLED`: Enable encryption of the backup file before uploading (optional, defaults to false).
- `ENCRYPTION_PASSWORD`: The password used to encrypt/decrypt the backup file (required if `ENCRYPTION_ENABLED` is true).
- `RUN_BACKUP_NOW`: Run backup immediately and exit container instead of using cron schedule (optional, defaults to false).

## Authentication Methods

### SSH Key Authentication (Recommended)

For better security, use SSH key authentication:

```sh
SFTP_USER=your_sftp_user
SFTP_PRIVATE_KEY="-----BEGIN OPENSSH PRIVATE KEY-----
your_private_key_content_here
-----END OPENSSH PRIVATE KEY-----"
SFTP_HOST=your_sftp_host
SFTP_PATH=/path/to/backups
```

### Password Authentication

Alternatively, you can use password authentication:

```sh
SFTP_USER=your_sftp_user
SFTP_PASSWORD=your_sftp_password
SFTP_HOST=your_sftp_host
SFTP_PATH=/path/to/backups
```

## Usage

### Building the Container

Build the Docker container:

```sh
docker build -t postgres-backup-sftp .
```

### Running the Container

To run the Docker container with your configuration, create an env.list file with the required environment variables:

```sh
POSTGRES_USER=your_postgres_user
POSTGRES_PASSWORD=your_postgres_password
POSTGRES_DB=your_database_name
POSTGRES_HOST=your_postgres_host
# Optional: POSTGRES_PORT=5432
SFTP_USER=your_sftp_user
# Either use password or private key authentication:
SFTP_PASSWORD=your_sftp_password
# OR
SFTP_PRIVATE_KEY="-----BEGIN OPENSSH PRIVATE KEY-----
your_private_key_content
-----END OPENSSH PRIVATE KEY-----"
SFTP_HOST=your_sftp_host
SFTP_PORT=22
SFTP_PATH=/path/to/backups
# Optional: CRON_SCHEDULE="0 2 * * *"
# Optional: BACKUP_RETENTION_DAYS=30
# Optional: AUTO_DELETE_ENABLED=true
# Optional: COMPRESSION_ENABLED=true
# Optional: RUN_BACKUP_NOW=true
```

Then run the container with the following command:

```sh
docker run --env-file ./env.list postgres-backup-sftp
```

### Using Docker Compose

You can also use Docker Compose to manage the container. Below is an example docker-compose.yml file:

```yaml
services:
  db:
    image: postgres:latest
    container_name: postgres_db
    restart: always
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB} || exit 1"]
      interval: 20s
      timeout: 7s
      retries: 3
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - ./db_data:/var/lib/postgresql/data
    networks:
      - internal_network

  backup:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: postgres_backup_sftp
    depends_on:
      db:
        condition: service_healthy
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_HOST: db
      POSTGRES_PORT: ${POSTGRES_PORT:-5432} # Optional: Custom port
      SFTP_USER: ${SFTP_USER}
      SFTP_PASSWORD: ${SFTP_PASSWORD}
      SFTP_PRIVATE_KEY: ${SFTP_PRIVATE_KEY}
      SFTP_HOST: ${SFTP_HOST}
      SFTP_PORT: ${SFTP_PORT:-22}
      SFTP_PATH: ${SFTP_PATH}
      CRON_SCHEDULE: ${CRON_SCHEDULE:-"0 2 * * *"} # Default schedule: daily at 2 AM
      BACKUP_RETENTION_DAYS: ${BACKUP_RETENTION_DAYS:-30} # Optional: Number of days to keep backups
      AUTO_DELETE_ENABLED: ${AUTO_DELETE_ENABLED:-true} # Optional: Enable/disable auto deletion of old backups
      COMPRESSION_ENABLED: ${COMPRESSION_ENABLED:-false} # Optional: Enable compression using tar.gz
      # RUN_BACKUP_NOW: true # Optional: Uncomment to run backup immediately and exit
      ENCRYPTION_ENABLED: true
      ENCRYPTION_PASSWORD: ${ENCRYPTION_PASSWORD}
    volumes:
      - ./backups:/backups
    networks:
      - internal_network

networks:
  internal_network:
    driver: bridge
```

## Customizing the Cron Schedule
The CRON_SCHEDULE environment variable allows you to specify a custom cron schedule. For example, to run the backup every day at 3 AM, set CRON_SCHEDULE to 0 3 * * *. If CRON_SCHEDULE is not set, the default schedule is daily at 2 AM (0 2 * * *).

## Manual Backup

### Option 1: Immediate Backup
To run a one-time backup immediately, you can set the `RUN_BACKUP_NOW` environment variable:

```sh
docker run --env-file ./env.list -e RUN_BACKUP_NOW=true postgres-backup-sftp
```

This will run the backup once and exit the container.

### Option 2: Manual Execution Inside Running Container
### Ensure that `ENCRYPTION_ENABLED` and `ENCRYPTION_PASSWORD` are set correctly in the environment variables when performing manual operations.
You can log in to the container and manually run the backup script using the following command:

```sh
docker exec -it $(docker ps -q -f ancestor=postgres-backup-sftp) /scripts/backup.sh
```

or if you know the container id:

```sh
docker exec -it ed227abb8783 ./backup.sh
```

## Restore from Backup

### Warning: Restoring a database will overwrite the existing data. Make sure you know the consequences before proceeding.

Take a look at the [restore script](./restore.sh) if you are not sure what it does.

To restore the database from the latest backup file found on the SFTP server, you can use the following command:

```sh
docker exec -it $(docker ps -q -f ancestor=postgres-backup-sftp) /scripts/restore.sh
```
or if you know the container id:

```sh
docker exec -it ed227abb8783 ./restore.sh
```

## Security Considerations

- **SSH Key Authentication**: Always prefer SSH key authentication over password authentication for better security.
- **Private Key Protection**: Store your SSH private keys securely and never commit them to version control.
- **Network Security**: Consider using VPN or other secure network connections when accessing remote SFTP servers.
- **Encryption**: Enable backup encryption when storing sensitive data on external servers.
- **Access Control**: Configure appropriate file permissions and user access on your SFTP server.

## Troubleshooting

### Common Issues

1. **SSH Connection Refused**: Check if the SFTP server is running and accessible on the specified port.
2. **Authentication Failed**: Verify your credentials, SSH keys, and user permissions.
3. **Permission Denied**: Ensure the SFTP user has write permissions to the specified path.
4. **Host Key Verification**: The container is configured to skip host key verification for automated operations.

### Debug Mode

To enable verbose output for debugging SFTP connections, you can modify the scripts to add `-v` flag to SFTP commands.

## Migration from FTP Version

If you're migrating from the FTP version of this container, update your environment variables:

- `FTP_USER` → `SFTP_USER`
- `FTP_PASS` → `SFTP_PASSWORD`
- `FTP_HOST` → `SFTP_HOST`
- `FTP_PATH` → `SFTP_PATH`
- `FTP_SSL` → (removed, SFTP uses SSH encryption by default)
- Add `SFTP_PORT` (defaults to 22)
- Add `SFTP_PRIVATE_KEY` (optional, for SSH key authentication)
