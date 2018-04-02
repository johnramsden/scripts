#!/bin/sh

# on arch install duplicity, python2-boto

# Place auth variables: PASSPHRASE, GS_ACCESS_KEY_ID, GS_SECRET_ACCESS_KEY
. "/mnt/tank/system/scripts/local/secrets/duplicitybak.auth"

# Folders to backup
BACKUP_DATA_REGEXP='Workspace|Computer|Personal|Pictures|University'

# GS configuration variables
GS_BUCKET="johnramsdenbackup"

# Remove files older than 60 days from GS
duplicity remove-older-than 60D  --allow-source-mismatch --force gs://${GS_BUCKET}

# Sync everything to GS
duplicity --allow-source-mismatch --include-regexp "${BACKUP_DATA_REGEXP}" \
          --exclude='**' \
          ${HOME} gs://${GS_BUCKET}

# Cleanup failures
duplicity cleanup --allow-source-mismatch --force gs://${GS_BUCKET}

unset PASSPHRASE
unset GS_ACCESS_KEY_ID
unset GS_SECRET_ACCESS_KEY
