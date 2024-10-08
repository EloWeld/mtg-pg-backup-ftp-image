FROM alpine:latest

# Install required packages
RUN apk add --no-cache postgresql-client curl openssl

# Create directories for scripts and backups
RUN mkdir -p /scripts /backups

# Copy the scripts
COPY backup.sh /scripts/backup.sh
COPY upload.sh /scripts/upload.sh
COPY entrypoint.sh /scripts/entrypoint.sh
COPY restore.sh /scripts/restore.sh

# Set execution permissions for the scripts
RUN chmod +x /scripts/backup.sh /scripts/upload.sh /scripts/entrypoint.sh /scripts/restore.sh

# Set the working directory
WORKDIR /scripts

# Set the entrypoint to our custom script
ENTRYPOINT ["./entrypoint.sh"]