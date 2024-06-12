# Postgres Backup and FTP Upload

This is an easy-to-use side-car container for backing up a PostgreSQL database and uploading the backup to a FTP server. The container is designed to run as a cron job, with configurable schedules and connection details provided via environment variables.

## Features

- Backs up a PostgreSQL database daily by default, or according to a custom cron schedule.
- Uploads the backup to a specified FTP server.
- Easy configuration via environment variables.
- Simple integration with Docker Compose.

## Environment Variables

The following environment variables can be set to configure the behavior of the backup and upload processes:

- `POSTGRES_USER`: The PostgreSQL user (required).
- `POSTGRES_PASSWORD`: The PostgreSQL password (required).
- `POSTGRES_DB`: The PostgreSQL database name (required).
- `POSTGRES_HOST`: The PostgreSQL host (required).
- `FTP_USER`: The FTP user (required).
- `FTP_PASS`: The FTP password (required).
- `FTP_HOST`: The FTP server host (required).
- `FTP_PATH`: The FTP server path where backups will be uploaded (required).
- `CRON_SCHEDULE`: The cron schedule string (optional, defaults to "0 2 * * *" for daily at 2 AM).
