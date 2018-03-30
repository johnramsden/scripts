#!/bin/sh

SEEDBOX_USER="cacheline"
SEEDBOX_SERVER="polyphemus.feralhosting.com"

SEEDBOX_DELUGE_ROOT="/media/sdl1/cacheline/private/deluge"
SEEDBOX_TEMP_TRANSFER_ROOT="/media/sdl1/cacheline/private/transfer"

SEEDBOX_SEEDING_DIR="complete/seeding"
SEEDBOX_DOWNLOADING_DIR="complete/downloading"

SYNC_LOCATION="/mnt/tank/media/Downloads/Incomplete/seedbox"
COMPLETED_SYNC_LOCATION="/mnt/tank/media/Downloads/Complete/downloading"
PROCESSING_LOCATION="/mnt/tank/media/Downloads/Complete/processing"

FILES_OWNER="media"
FILES_GROUP="media"

ssh_command(){
      OUTPUT=$(ssh "${SEEDBOX_USER}@${SEEDBOX_SERVER}" "${1}")
      return_val="${?}"
      echo "${OUTPUT}"
      return "${return_val}"
}

move_to_temp(){
      remote_origin="${1}"
      remote_tempdir="${2}"

      ssh_command "mkdir -p ${remote_tempdir} && mv """""${remote_origin}'*'""""" ${remote_tempdir}"
      return ${?}
}

move_remote_files_back(){
      remote_tempdir="${1}"
      remote_origin="${2}"
      
      echo "Moving file(s) back to ${remote_origin}"
      ssh_command "mv ${remote_origin} ${remote_tempdir}"
      return ${?}
}

seedbox_pull_downloaded() {
      sync_timestamp="$(date "+%F_%H_%M_%S" )"
      day_date="$(date +%F)"

      remote_source="${1}"
      local_destination="${2}"

      # Check remote dir exists, and isn't empty
      if ! ssh_command "[ -d ${remote_source} ]"; then
            echo "Remote directory ${remote_source} doesn't exist"; 
            return 1
      fi

      remote_temp_root="${SEEDBOX_TEMP_TRANSFER_ROOT}/${day_date}"
      remote_temp_directory="${remote_temp_root}/${sync_timestamp}"

      local_sync_root="${local_destination}/${sync_timestamp}"

      if [ -z "$(ssh_command "ls -A ${remote_source}")" ]; then
            echo "Remote ${remote_source} is empty, skipping sync";
            echo
      elif move_to_temp "${remote_source}" "${remote_temp_directory}"; then

            remote_archive="${SEEDBOX_TEMP_TRANSFER_ROOT}/${day_date}/${sync_timestamp}.tar"

            if ! ssh_command \
                   "tar -cvf ${remote_archive} --directory=${remote_temp_root} ${sync_timestamp}"; then
                echo "Failed to create archive ${remote_archive}"
                move_remote_files_back "${remote_temp_directory}" "${remote_source}"
                return 1
            fi

            mkdir -p "${local_sync_root}/${sync_timestamp}-extracted" && \
            /usr/bin/lockf -s -t 0 -k "${local_sync_root}" \
                  /usr/local/bin/rsync \
                        --verbose \
                        --human-readable \
                              "${SEEDBOX_USER}@${SEEDBOX_SERVER}:${remote_archive}" \
                              "${local_sync_root}/${sync_timestamp}.tar"

            if [ ${?} -ne 0 ]; then
                  echo "rsync ${sync_timestamp} failed"
                  move_remote_files_back "${remote_temp_directory}" "${remote_source}"
                  return 1
            fi

            echo "rsync ${remote_source} -->"
            echo "${local_destination}/${sync_timestamp}"
            echo "successful from ${SEEDBOX_USER}@${SEEDBOX_SERVER}"
            echo

            echo "Extracting archive and moving files to processing"
            if ! tar -xvf "${local_sync_root}/${sync_timestamp}.tar" \
                     --directory="${local_sync_root}/${sync_timestamp}-extracted"; then
                  echo "Failed to extract transferred file"
                  echo
                  return 1
            else
                  mv "${local_sync_root}/${sync_timestamp}-extracted" \
                     "${PROCESSING_LOCATION}" && \
                  chown -R ${FILES_OWNER}:${FILES_GROUP} \
                     "${PROCESSING_LOCATION}/${sync_timestamp}-extracted" && \
                  rm -rf "${local_sync_root}" || return 1
            fi

            echo "Transfer successful, deleting tempdir ${remote_temp_directory} on remote"
            echo
                       
            echo "Moved synced files to destination -->"
            echo "${local_sync_root}/${sync_timestamp}-extracted"
            echo
      fi
      
      echo "Cleaning up old directories under ${SEEDBOX_TEMP_TRANSFER_ROOT}"
      if ! ssh_command \
      "find """""${SEEDBOX_TEMP_TRANSFER_ROOT}/'*'""""" -maxdepth 0 -type d -not -name ${day_date} -exec rm -rv {} + ;"; then
            echo "Deleting ${SEEDBOX_TEMP_TRANSFER_ROOT}/* failed"
            echo
            return 1
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
            echo "rsync ${remote_source} failed"
            echo
            return 1
      fi

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
