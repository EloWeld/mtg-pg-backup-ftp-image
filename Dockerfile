FROM alpine:latest

# Install required packages including openssh-client for SFTP
RUN apk add --no-cache postgresql-client curl openssl openssh-client sshpass

# Create directories for scripts, backups, and SSH configuration
RUN mkdir -p /scripts /backups /root/.ssh

# Create SSH config to disable host key checking for automated SFTP connections
RUN echo "Host *\n    StrictHostKeyChecking no\n    UserKnownHostsFile=/dev/null" > /root/.ssh/config
RUN chmod 600 /root/.ssh/config

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