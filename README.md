# Postgres Backup and FTP Upload

This is an easy-to-use side-car container for backing up a PostgreSQL database and uploading the backup to a FTP server. The container is designed to run as a cron job, with configurable schedules and connection details provided via environment variables.

- Github Repository: [jannikhst/postgres-backup-ftp](https://github.com/jannikhst/postgres-backup-ftp)
- Docker Hub Image: [jannikhst/postgres-backup-ftp](https://hub.docker.com/r/jannikhst/postgres-backup-ftp)

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

## Usage
You can use the Docker image available at Docker Hub:

```sh
docker pull jannikhst/postgres-backup-ftp
```

### Running the Container

To run the Docker container with your configuration, create an env.list file with the required environment variables:

```sh
POSTGRES_USER=your_postgres_user
POSTGRES_PASSWORD=your_postgres_password
POSTGRES_DB=your_database_name
POSTGRES_HOST=your_postgres_host
FTP_USER=your_ftp_user
FTP_PASS=your_ftp_password
FTP_HOST=your_ftp_host
FTP_PATH=your_ftp_path
# Optional: CRON_SCHEDULE="0 2 * * *"
```

Then run the container with the following command:

```sh
docker run --env-file ./env.list jannikhst/postgres-backup-ftp
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
    image: jannikhst/postgres-backup-ftp
    container_name: postgres_backup
    depends_on:
      db:
        condition: service_healthy
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_HOST: db
      FTP_USER: ${FTP_USER}
      FTP_PASS: ${FTP_PASS}
      FTP_HOST: ${FTP_HOST}
      FTP_PATH: ${FTP_PATH}
      CRON_SCHEDULE: ${CRON_SCHEDULE:-"0 2 * * *"} # Default schedule: daily at 2 AM
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
You can log in to the container and manually run the backup script using the following command:

```sh
docker exec -it $(docker ps -q -f ancestor=jannikhst/postgres-backup-ftp) /scripts/backup.sh
```

or if you know the container id:

```sh
docker exec -it ed227abb8783 /bin/sh ./backup.sh
```
