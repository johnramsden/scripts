#!/bin/sh

SEEDBOX_USER="cacheline"
SEEDBOX_SERVER="polyphemus.feralhosting.com"

SEEDBOX_DELUGE_ROOT="/media/sdl1/cacheline/private/deluge"
SEEDBOX_SEEDING_DIR="complete/seeding"
SEEDBOX_DOWNLOADING_DIR="complete/downloading"

SYNC_LOCATION="/mnt/tank/media/Downloads/Incomplete/box"
COMPLETED_SYNC_LOCATION="/mnt/tank/media/Downloads/Complete"

FILE_PERMISSIONS="760"
FILES_OWNER="media"
FILES_GROUP="media"

# Pull downloaded or downloaded seeding files
# type_download="${1}" - downloaded or seeding
# remote_source="${2}" - remote location
# local_destination="${3}" - local destination
seedbox_pull() {
      SYNC_TIMESTAMP="$(date "+%F_%H_%M_%S" )"

      type_download="${1}"
      remote_source="${2}"
      local_destination="${3}"

      mkdir -p "${local_destination}" && chown ${FILES_OWNER}:${FILES_GROUP} "${local_destination}" || exit 1

      if [ "${type_download}" = "downloaded" ]; then

            rsync --recursive \
                  --verbose \
                  -og --chown=${FILES_OWNER}:${FILES_GROUP} \
                  --remove-source-files \
                  -e ssh "${SEEDBOX_USER}@${SEEDBOX_SERVER}:${remote_source}" \
                        "${local_destination}/${SYNC_TIMESTAMP}"

            rsync_success=$?

      elif [ "${type_download}" = "seeding" ]; then

            rsync --recursive \
                  -og --chown=${FILES_OWNER}:${FILES_GROUP} \
                  -e ssh "${SEEDBOX_USER}@${SEEDBOX_SERVER}:${remote_source}" \
                        "${local_destination}"

            rsync_success=$?
      fi

      if [ ${rsync_success} -eq 0 ]; then
            echo
            echo "rsync ${SYNC_TIMESTAMP} seccessful from ${SEEDBOX_USER}@${SEEDBOX_SERVER}"
            echo
            echo "Moving files to ${COMPLETED_SYNC_LOCATION}"

            # Move and cleanup
            if [ "${type_download}" = "downloaded" ]; then
                  rsync --remove-source-files \
                        --recursive \
                        -og --chown=${FILES_OWNER}:${FILES_GROUP} \
                        "${SYNC_LOCATION}/${SYNC_TIMESTAMP}/" ${COMPLETED_SYNC_LOCATION} && \
                  rm -rf "${SYNC_LOCATION:?}/${SYNC_TIMESTAMP:?}"

                  if [ ! ${?} -eq 0 ]; then
                        echo "Failed moving ${SYNC_LOCATION}/${SYNC_TIMESTAMP}/"
                        return 1
                  fi

            elif [ "${type_download}" = "seeding" ]; then
                  rsync --recursive \
                  -og --chown=${FILES_OWNER}:${FILES_GROUP} \
                  "${local_destination}/" "${COMPLETED_SYNC_LOCATION}"
            else
                  return 1
            fi

      else
            if [ "${type_download}" = "downloaded" ]; then
                  echo "rsync ${SYNC_TIMESTAMP} failed"
                  return 1
            elif [ "${type_download}" = "seeding" ]; then
                  echo "rsync ${SYNC_TIMESTAMP} had no changes"
                  return 0
            else
                  return 1
            fi
      fi

      echo
      return 0
}

seedbox_pull downloaded "${SEEDBOX_DELUGE_ROOT}/${SEEDBOX_DOWNLOADING_DIR}/" "${SYNC_LOCATION}" && \
seedbox_pull seeding "${SEEDBOX_DELUGE_ROOT}/${SEEDBOX_SEEDING_DIR}" "${SYNC_LOCATION}/seeding" && \
echo "Successful sync" && exit 0 || echo "Failed sync" && exit 1