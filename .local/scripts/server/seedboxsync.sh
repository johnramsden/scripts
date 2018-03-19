#!/bin/sh

SEEDBOX_USER="cacheline"
SEEDBOX_SERVER="polyphemus.feralhosting.com"

SEEDBOX_DELUGE_ROOT="/media/sdl1/cacheline/private/deluge"
SEEDBOX_TEMP_TRANSFER_ROOT="/media/sdl1/cacheline/private/transfer"

SEEDBOX_SEEDING_DIR="complete/seeding"
SEEDBOX_DOWNLOADING_DIR="complete/downloading"

SYNC_LOCATION="/mnt/tank/media/Downloads/Incomplete/seedbox"
COMPLETED_SYNC_LOCATION="/mnt/tank/media/Downloads/Complete/downloading"

FILES_OWNER="media"
FILES_GROUP="media"

ssh_command(){
      OUTPUT=$(ssh "${SEEDBOX_USER}@${SEEDBOX_SERVER}" "${1}")
      return_val="${?}"
      echo "${OUTPUT}"
      return "${return_val}"
}

move_to_temp(){
      remote_source="${1}"
      remote_tempdir="${2}"

      ssh_command "mkdir -p ${remote_tempdir} && mv """""${remote_source}'*'""""" ${remote_tempdir}"
      return ${?}
}

seedbox_pull_downloaded() {
      sync_timestamp="$(date "+%F_%H_%M_%S" )"
      day_date="$(date +%F)"

      remote_source="${1}"
      local_destination="${2}"

      ssh_command "[ -d ${remote_source} ]"

      # Check remote dir exists, and isn't empty
      if ! [ "${?}" -eq 0 ]; then
            echo "Remote directory ${remote_source} doesn't exist"; 
            return 1
      fi

      if [ -z "$(ssh_command "ls -A ${remote_source}")" ]; then
            echo "Remote ${remote_source} is empty, skipping sync"; 
            return 0
      fi

      remote_temp_directory="${SEEDBOX_TEMP_TRANSFER_ROOT}/${day_date}/${sync_timestamp}"

      if move_to_temp "${remote_source}" "${remote_temp_directory}"; then
            mkdir -p "${local_destination}/${sync_timestamp}" && \
            chown ${FILES_OWNER}:${FILES_GROUP} "${local_destination}/${sync_timestamp}" && \
            /usr/bin/lockf -s -t 0 -k "${local_destination}/${sync_timestamp}" \
                  /usr/local/bin/rsync \
                        --times \
                        --verbose \
                        --compress \
                        --recursive \
                        --human-readable \
                        -og --chown=${FILES_OWNER}:${FILES_GROUP} \
                              "${SEEDBOX_USER}@${SEEDBOX_SERVER}:${remote_temp_directory}" "${local_destination}/${sync_timestamp}"

            if [ ${?} -ne 0 ]; then
                  echo "rsync ${sync_timestamp} failed" && return 1
            fi

            echo "Transfer successful, deleting tempdir ${remote_temp_directory} on remote"
            ssh_command "rm -rf ${SEEDBOX_TEMP_TRANSFER_ROOT}/${day_date}/${sync_timestamp}"
            if [ ${?} -ne 0 ]; then
                  echo "Deleting ${SEEDBOX_TEMP_TRANSFER_ROOT}/${day_date}/${sync_timestamp} failed"
            fi
            
            echo
            echo "rsync ${remote_source} --> ${local_destination}/${sync_timestamp} successful from ${SEEDBOX_USER}@${SEEDBOX_SERVER}"
            echo
      fi
      
      return 0     
}

seedbox_pull_seeding() {

      remote_source="${1}"
      local_destination="${2}"

      /usr/bin/lockf -s -t 0 -k "${local_destination}" \
            /usr/local/bin/rsync \
                  --times \
                  --delete \
                  --verbose \
                  --compress \
                  --recursive \
                  --human-readable \
                  -og --chown=${FILES_OWNER}:${FILES_GROUP} \
                        "${SEEDBOX_USER}@${SEEDBOX_SERVER}:${remote_source}" "${local_destination}"

      if [ ${?} -ne 0 ]; then
            echo "rsync ${remote_source} failed" && return 1
      fi

      echo
      echo "rsync ${remote_source} --> ${local_destination} successful from ${SEEDBOX_USER}@${SEEDBOX_SERVER}"
      echo

      return 0
}

# Pull downloaded or downloaded seeding files
# remote_source="${1}" - remote location
# local_destination="${2}" - local destination

downloaded_success=0
seeding_success=0

if [ "${1}" = "download" ] || [ "${1}" = "all" ]; then
      echo "Running sync of downloaded ${SEEDBOX_DELUGE_ROOT}/${SEEDBOX_DOWNLOADING_DIR}"
      seedbox_pull_downloaded "${SEEDBOX_DELUGE_ROOT}/${SEEDBOX_DOWNLOADING_DIR}/" "${COMPLETED_SYNC_LOCATION}"
      downloaded_success=$?
      echo
fi

if [ "${1}" = "seeding" ] || [ "${1}" = "all" ]; then
      echo "Running sync of seeding ${SEEDBOX_DELUGE_ROOT}/${SEEDBOX_SEEDING_DIR}"
      seedbox_pull_seeding "${SEEDBOX_DELUGE_ROOT}/${SEEDBOX_SEEDING_DIR}" "${SYNC_LOCATION}"
      seeding_success=$?
      echo
fi

echo

if [ ${downloaded_success} -eq 0 ] && [ ${seeding_success} -eq 0 ]; then
      echo "Successful sync from ${SEEDBOX_USER}@${SEEDBOX_SERVER}"
      exit 0
else
      if [ ${downloaded_success} -ne 0 ]; then
            echo "Failed sync downloaded files, or no files on source"
      fi

      if [ ${seeding_success} -ne 0 ]; then
            echo "Failed sync seeding files, or no changes on source"
      fi

      exit 1
fi