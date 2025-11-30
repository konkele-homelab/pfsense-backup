# pfSense Backup Docker Container

This repository contains a minimal Docker image to automate **pfSense configuration backups** using a shell script. The container supports environment-based configuration, UID/GID assignment, and Swarm secrets for credentials.

---

## Features

- Back up multiple pfSense instances from a single container.
- Configurable backup directory and backup retention.
- Swarm secret support for storing credentials.
- Configurable UID/GID for the backup process.
- Lightweight Alpine base image.
- Minimal production-ready shell scripts.

---

## Environment Variables

| Variable       | Default                       | Description |
|----------------|-------------------------------|-------------|
| BACKUP_DIR     | `/backup`                     | Directory where backups are stored inside the container |
| SERVERS_FILE   | `/config/pfsense_backup`      | Path to file or secret containing pfSense credentials (`FQDN:USERNAME:PASSWORD`) |
| TZ             | `America/Chicago`             | Timezone for timestamps |
| USER_UID       | `3000`                        | UID of backup user |
| USER_GID       | `3000`                        | GID of backup user |
| KEEP_DAYS      | `30`                          | Number of days to retain backups |

---

## Swarm Secret Format

The servers file (used as a Swarm secret) should have one line per pfSense host:
```
FQDN:USERNAME:PASSWORD
```
For example:
```
pfsense.example.com:backupuser:securepass123
192.168.1.1:backupuser:anotherpass
```

---

## Docker Compose Example (Swarm)

```yaml
version: "3.9"

services:
  pfsense_backup:
    image: registry.lab.konkel.us/pfsense-backup:latest
    volumes:
      - /backup:/backup
    environment:
      BACKUP_DIR: /backup
      SERVERS_FILE: /run/secrets/pfsense_backup
      TZ: America/Chicago
      USER_UID: 3000
      USER_GID: 3000
      KEEP_DAYS: 30
    secrets:
      - pfsense_backup
    deploy:
      mode: replicated
      replicas: 1
      restart_policy:
        condition: none

secrets:
  pfsense_backup:
    external: true
```

### Usage

1. Create the Swarm secret:
```bash
docker secret create pfsense_backup ./servers
```
2. Deploy the stack:
```bash
docker stack deploy -c docker-compose.yml pfsense_backup_stack
```

---

## Local Testing

For testing without Swarm, you can mount the servers file and run the container directly:
```bash
docker run -it --rm \
  -v /mnt/archive/pfsense:/backup \
  -v ./servers:/config/pfsense_backup \
  -e SCRIPT_NAME=pfsense-backup.sh \
  registry.lab.konkel.us/pfsense-backup:latest
```

---

## Notes

- UID/GID customization ensures that backup files match host file ownership.
- Backup retention is controlled via `KEEP_DAYS`.
- The container uses `su-exec` to drop privileges to the backup user.

---
