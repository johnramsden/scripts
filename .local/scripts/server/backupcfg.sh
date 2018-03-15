#!/bin/sh

SYNC_LOCATION_USER="syncthing"
SYNC_LOCATION_GROUP="syncthing"

SYNC_ROOT="/mnt/tank/data/syncthing/sync"
BACKUP_DIR="${SYNC_ROOT}/Computer/Server/Lilan/Config/Backup"

rsync -og --chown="${SYNC_LOCATION_USER}:${SYNC_LOCATION_GROUP}" \
    /data/freenas-v1.db \
    ${BACKUP_DIR}/freenas-config-$(date +"%m-%d-%y").db

echo "Created backup of FreeNAS config ${BACKUP_DIR}/freenas-config-$(date +"%m-%d-%y").db"

find "${BACKUP_DIR}" -type f -mtime +30 -exec rm {} +