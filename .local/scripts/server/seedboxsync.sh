#!/bin/sh

SEEDBOX_USER="cacheline"
SEEDBOX_SERVER="polyphemus.feralhosting.com"

SEEDBOX_DELUGE_ROOT="/media/sdl1/cacheline/private/deluge"
SEEDBOX_SEEDING_DIR="complete/seeding"
SEEDBOX_DOWNLOADING_DIR="complete/downloading"

SYNC_LOCATION="/mnt/tank/media/Downloads/Incomplete/box"
COMPLETED_SYNC_LOCATION="/mnt/tank/media/Downloads/Complete"

FILES_OWNER="media"
FILES_GROUP="media"

seedbox_pull_seeding() {

      remote_source="${1}"
      local_destination="${2}"

      mkdir -p "${local_destination}" && chown ${FILES_OWNER}:${FILES_GROUP} "${local_destination}" || return 1

      rsync --recursive \
            --verbose \
            --delete \
            -og --chown=${FILES_OWNER}:${FILES_GROUP} \
            "${SEEDBOX_USER}@${SEEDBOX_SERVER}:${remote_source}/" "${local_destination}"

      if [ ${?} -ne 0 ]; then
            echo "rsync ${remote_source} had no changes" && return 1
      fi

      echo
      echo "rsync ${remote_source} seccessful from ${SEEDBOX_USER}@${SEEDBOX_SERVER}"
      echo
      echo "Moving files to ${COMPLETED_SYNC_LOCATION}"

      rsync --recursive \
            -og --chown=${FILES_OWNER}:${FILES_GROUP} \
            "${local_destination}/" "${COMPLETED_SYNC_LOCATION}"

      if [ ${?} -ne 0 ]; then
            echo "Failed moving files to ${COMPLETED_SYNC_LOCATION}" && return 1
      fi      
}

seedbox_pull_downloaded() {
      SYNC_TIMESTAMP="$(date "+%F_%H_%M_%S" )"

      remote_source="${1}"
      local_destination="${2}"

      mkdir -p "${local_destination}" && chown ${FILES_OWNER}:${FILES_GROUP} "${local_destination}" || return 1

      rsync --recursive \
            --verbose \
            --delete \
            -og --chown=${FILES_OWNER}:${FILES_GROUP} \
            --remove-source-files \
            "${SEEDBOX_USER}@${SEEDBOX_SERVER}:${remote_source}" "${local_destination}/${SYNC_TIMESTAMP}"

      if [ ${?} -ne 0 ]; then
            echo "rsync ${SYNC_TIMESTAMP} failed" && return 1
      fi      

      echo
      echo "rsync ${SYNC_TIMESTAMP} seccessful from ${SEEDBOX_USER}@${SEEDBOX_SERVER}"
      echo
      echo "Moving files to ${COMPLETED_SYNC_LOCATION}"

      rsync --remove-source-files \
            --recursive \
            -og --chown=${FILES_OWNER}:${FILES_GROUP} \
            "${SYNC_LOCATION}/${SYNC_TIMESTAMP}/" ${COMPLETED_SYNC_LOCATION} && \
      rm -rf "${SYNC_LOCATION:?}/${SYNC_TIMESTAMP:?}"

      if [ ${?} -ne 0 ]; then
            echo "Failed moving ${SYNC_LOCATION}/${SYNC_TIMESTAMP}/" && return 1
      fi      
     
}

# Pull downloaded or downloaded seeding files
# remote_source="${1}" - remote location
# local_destination="${2}" - local destination

echo "Running sync of downloaded ${SEEDBOX_DELUGE_ROOT}/${SEEDBOX_DOWNLOADING_DIR}"
seedbox_pull_downloaded "${SEEDBOX_DELUGE_ROOT}/${SEEDBOX_DOWNLOADING_DIR}/" "${SYNC_LOCATION}"
downloaded_success=$?

echo
echo "Running sync of seeding ${SEEDBOX_DELUGE_ROOT}/${SEEDBOX_SEEDING_DIR}"
seedbox_pull_seeding "${SEEDBOX_DELUGE_ROOT}/${SEEDBOX_SEEDING_DIR}" "${SYNC_LOCATION}/seeding"
seeding_success=$?

echo

if [ ${downloaded_success} -eq 0 ] && [ ${seeding_success} -eq 0 ]; then
      echo "Successful sync from ${SEEDBOX_USER}@${SEEDBOX_SERVER}"
      exit 0
else
      if [ ${downloaded_success} -ne 0 ]; then
            echo "Failed sync downloaded files, or no changes on source"
      fi

      if [ ${seeding_success} -ne 0 ]; then
            echo "Failed sync seeding files, or no changes on source"
      fi

      exit 1
fi