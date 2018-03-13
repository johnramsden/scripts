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
      SYNC_TIMESTAMP="$(date "+%F_%H_%M_%S" )"

      remote_source="${1}"
      local_destination="${2}"

      mkdir -p "${local_destination}" && chown ${FILES_OWNER}:${FILES_GROUP} "${local_destination}" || return 1

      rsync --recursive \
            --delete \
            -og --chown=${FILES_OWNER}:${FILES_GROUP} \
            -e ssh "${SEEDBOX_USER}@${SEEDBOX_SERVER}:${remote_source}" \
                  "${local_destination}" || \
      echo "rsync ${SYNC_TIMESTAMP} had no changes" && return 0

      echo
      echo "rsync ${SYNC_TIMESTAMP} seccessful from ${SEEDBOX_USER}@${SEEDBOX_SERVER}"
      echo
      echo "Moving files to ${COMPLETED_SYNC_LOCATION}"

      rsync --recursive \
            -og --chown=${FILES_OWNER}:${FILES_GROUP} \
            "${local_destination}/" "${COMPLETED_SYNC_LOCATION}"
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
            -e ssh "${SEEDBOX_USER}@${SEEDBOX_SERVER}:${remote_source}" \
                  "${local_destination}/${SYNC_TIMESTAMP}" || \
      echo "rsync ${SYNC_TIMESTAMP} failed" && return 1

      echo
      echo "rsync ${SYNC_TIMESTAMP} seccessful from ${SEEDBOX_USER}@${SEEDBOX_SERVER}"
      echo
      echo "Moving files to ${COMPLETED_SYNC_LOCATION}"

      rsync --remove-source-files \
            --recursive \
            -og --chown=${FILES_OWNER}:${FILES_GROUP} \
            "${SYNC_LOCATION}/${SYNC_TIMESTAMP}/" ${COMPLETED_SYNC_LOCATION} && \
      rm -rf "${SYNC_LOCATION:?}/${SYNC_TIMESTAMP:?}" || \
      echo "Failed moving ${SYNC_LOCATION}/${SYNC_TIMESTAMP}/" && return 1
}

# Pull downloaded or downloaded seeding files
# remote_source="${1}" - remote location
# local_destination="${2}" - local destination

seedbox_pull_downloaded "${SEEDBOX_DELUGE_ROOT}/${SEEDBOX_DOWNLOADING_DIR}/" "${SYNC_LOCATION}" || \
echo "Failed sync downloaded files" && exit 1

seedbox_pull_seeding "${SEEDBOX_DELUGE_ROOT}/${SEEDBOX_SEEDING_DIR}" "${SYNC_LOCATION}/seeding" || \
echo "Failed sync seeding files" && exit 1

echo "Successful sync from ${SEEDBOX_USER}@${SEEDBOX_SERVER}"
exit 0