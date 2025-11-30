#!/bin/sh
set -eu

# ----------------------------
# Environment defaults
# ----------------------------
BACKUP_DIR="${BACKUP_DIR:-/backup}"
SERVERS_FILE="${SERVERS_FILE:-/config/pfsense_backup}"
SCRIPT_NAME="${SCRIPT_NAME:-pfsense-backup.sh}"
KEEP_DAYS="${KEEP_DAYS:-30}"

# ----------------------------
# Backup a single pfSense host
# ----------------------------
pfsense_backup() {
    fqdn="$1"
    user="$2"
    pass="$3"
    timestamp=$(date +%Y%m%d%H%M%S)
    backup_file="$BACKUP_DIR/${fqdn}-${timestamp}.xml"

    mkdir -p "$BACKUP_DIR"

    tempdir=$(mktemp -d)
    cookiejar="$tempdir/cookies.txt"
    csrf1="$tempdir/csrf1"
    csrf2="$tempdir/csrf2"

    echo "[$(date +%Y-%m-%d_%H:%M:%S)] Starting backup for $fqdn"

    # Fetch initial CSRF token
    curl -sk -L -c "$cookiejar" "https://${fqdn}/diag_backup.php" \
        | sed -n 's/.*name=["'"'"']__csrf_magic["'"'"'] value=["'"'"']\([^"'"'"']*\)["'"'"'].*/\1/p' > "$csrf1"

    [ -s "$csrf1" ] || { echo "ERROR: CSRF #1 not found for $fqdn"; rm -rf "$tempdir"; return 1; }

    # Login and retrieve second CSRF token
    curl -sk -L -b "$cookiejar" -c "$cookiejar" \
        --data "login=Login&usernamefld=${user}&passwordfld=${pass}&__csrf_magic=$(cat "$csrf1")" \
        "https://${fqdn}/diag_backup.php" \
        | sed -n 's/.*name=["'"'"']__csrf_magic["'"'"'] value=["'"'"']\([^"'"'"']*\)["'"'"'].*/\1/p' > "$csrf2"

    [ -s "$csrf2" ] || { echo "ERROR: Login failed or CSRF #2 not found for $fqdn"; rm -rf "$tempdir"; return 1; }

    # Download backup
    curl -sk -L -b "$cookiejar" \
        --data "download=download&donotbackuprrd=yes&__csrf_magic=$(cat "$csrf2")" \
        "https://${fqdn}/diag_backup.php" -o "$backup_file"

    [ -s "$backup_file" ] || { echo "ERROR: Backup failed for $fqdn"; rm -rf "$tempdir"; return 1; }

    chmod 600 "$backup_file"

    # Set owner if PUID/PGID provided
    [ -n "${PUID:-}" ] && [ -n "${PGID:-}" ] && chown "$PUID:$PGID" "$backup_file"

    echo "[$(date +%Y-%m-%d_%H:%M:%S)] Backup saved: $backup_file"

    rm -rf "$tempdir"

    # Remove old backups
    find "$BACKUP_DIR" -type f -name "*${fqdn}*" -mtime +"$KEEP_DAYS" -delete
}

# ----------------------------
# Backup pfSense hosts
# ----------------------------
[ -f "$SERVERS_FILE" ] || { echo "ERROR: Servers file not found: $SERVERS_FILE"; exit 1; }

while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue

    fqdn=$(printf "%s" "$line" | awk -F: '{print $1}')
    user=$(printf "%s" "$line" | awk -F: '{print $2}')
    pass=$(printf "%s" "$line" | awk -F: '{print $3}')

    if [ -z "$fqdn" ] || [ -z "$user" ] || [ -z "$pass" ]; then
        echo "Skipping malformed line: $line"
        continue
    fi

    pfsense_backup "$fqdn" "$user" "$pass"
done < "$SERVERS_FILE"
