FROM alpine:latest

# Build-time script name
ARG SCRIPT_NAME=pfsense-backup.sh

# Runtime environment defaults
ENV BACKUP_DIR=/backup
ENV SERVERS_FILE=/config/servers
ENV TZ=America/Chicago
ENV SCRIPT_NAME=${SCRIPT_NAME}

# Install required packages
RUN apk add --no-cache \
        curl \
        tzdata \
        shadow \
        ca-certificates \
        su-exec \
    && update-ca-certificates

# Create backup user
RUN addgroup -g 3000 backup \
    && adduser -D -u 3000 -G backup -s /bin/sh backup

# Scripts live in /config
WORKDIR /config

# Copy scripts using build ARG
COPY ${SCRIPT_NAME} /config/${SCRIPT_NAME}
COPY entrypoint.sh /config/entrypoint.sh

# Make scripts executable
RUN chmod +x /config/${SCRIPT_NAME} /config/entrypoint.sh

# Entry point executes script
ENTRYPOINT ["sh", "/config/entrypoint.sh"]
