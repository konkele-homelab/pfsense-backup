#!/bin/sh
set -eu

SCRIPT_USER=backup
USER_UID="${USER_UID:-3000}"
USER_GID="${USER_GID:-3000}"
SCRIPT_NAME="${SCRIPT_NAME:?SCRIPT_NAME not set}"
SCRIPT_PATH="/config/${SCRIPT_NAME}"

# Create or adjust user and group
if ! id "$SCRIPT_USER" >/dev/null 2>&1; then
    addgroup -g "$USER_GID" "$SCRIPT_USER"
    adduser -D -u "$USER_UID" -G "$SCRIPT_USER" -s /bin/sh "$SCRIPT_USER"
else
    # Adjust GID if different
    CURRENT_GID=$(id -g "$SCRIPT_USER")
    [ "$CURRENT_GID" != "$USER_GID" ] && delgroup "$SCRIPT_USER" && addgroup -g "$USER_GID" "$SCRIPT_USER"

    # Adjust UID if different
    CURRENT_UID=$(id -u "$SCRIPT_USER")
    [ "$CURRENT_UID" != "$USER_UID" ] && deluser "$SCRIPT_USER" && adduser -D -u "$USER_UID" -G "$USER_GID" -s /bin/sh "$SCRIPT_USER"
fi

# Run the backup script as backup user
exec su-exec "$USER_UID:$USER_GID" "$SCRIPT_PATH"
