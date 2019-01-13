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

time_sleep="150"

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

check_for_unfinished() {
    sync_timestamp="$(date "+%F_%H_%M_%S" )"
    local_destination="${1}"
    pull_location="${SYNC_LOCATION}/${sync_timestamp}"
    
    if [ -n "$(ssh_command "ls -A ${SEEDBOX_TEMP_TRANSFER_ROOT}")" ]; then
        
        mkdir -p "${pull_location}" || return 1

        for i in 1 2 3 4 5; do
            /usr/bin/lockf -s -t 0 -k "${pull_location}" \
            /usr/local/bin/rsync \
                --times \
                --delete \
                --verbose \
                --compress \
                --recursive \
                --human-readable \
                -og --chown=${FILES_OWNER}:${FILES_GROUP} \
                "${SEEDBOX_USER}@${SEEDBOX_SERVER}:${SEEDBOX_TEMP_TRANSFER_ROOT}" "${pull_location}"
            s=${?}
            if [ ${s} -eq 0 ]; then
                break
            fi
            echo "Rsync attempt ${i} broke"
            if [ ${i} -ne 5 ]; then
                sleep "${time_sleep}";
                time_sleep=$((time_sleep * 2))
                echo "retrying in ${time_sleep} seconds..."
            fi
        done
        
        if [ ${s} -ne 0 ]; then
            echo "rsync ${remote_source} failed"; echo
            return 1
        fi
        
        mv "${pull_location}" "${local_destination}"
        
        echo "Cleaning up directories under ${SEEDBOX_TEMP_TRANSFER_ROOT}"
        ssh_command "find """""${SEEDBOX_TEMP_TRANSFER_ROOT}/'*'""""" -delete" || return 1
    fi
    
    return 0
}

seedbox_pull_downloads() {
    sync_timestamp="$(date "+%F_%H_%M_%S" )"
    day_date="$(date +%F)"
    
    remote_source="${1}"
    local_destination="${2}"
    
    # Check remote dir exists, and isn't empty
    if ! ssh_command "[ -d ${remote_source} ]"; then
        echo "Remote directory ${remote_source} doesn't exist";
        return 1
    fi
    
    remote_temp_directory="${SEEDBOX_TEMP_TRANSFER_ROOT}/${day_date}/${sync_timestamp}"
    local_temp_root="${SYNC_LOCATION}/${sync_timestamp}"
    
    if [ -z "$(ssh_command "ls -A ${remote_source}")" ]; then
        echo "Remote ${remote_source} is empty, skipping sync"; echo
    else
        if ! move_to_temp "${remote_source}" "${remote_temp_directory}"; then
            echo "Failed to move ${remote_source} --> ${remote_temp_directory}"; echo
            return 1
        fi
        
        mkdir -p "${local_temp_root}" || return 1
        for i in 1 2 3 4 5; do
            /usr/bin/lockf -s -t 0 -k "${local_temp_root}" \
            /usr/local/bin/rsync \
                --times \
                --delete \
                --verbose \
                --compress \
                --recursive \
                --human-readable \
                -og --chown=${FILES_OWNER}:${FILES_GROUP} \
                "${SEEDBOX_USER}@${SEEDBOX_SERVER}:${remote_temp_directory}" "${local_temp_root}"
            
            s=${?}
            if [ ${s} -eq 0 ]; then
                break
            fi

            echo "Rsync attempt ${i} broke"
            if [ ${i} -ne 5 ]; then
                sleep "${time_sleep}";
                time_sleep=$((time_sleep * 2))
                echo "retrying in ${time_sleep} seconds..."
            fi
            
        done

        if [ ${s} -ne 0 ]; then
            echo "rsync ${remote_source} failed"; echo
            return 1
        fi
        
    fi
    
    echo "rsync ${remote_source} --> ${local_temp_root} successful from ${SEEDBOX_USER}@${SEEDBOX_SERVER}"
    echo
    if [ -n "$(ls -A ${local_temp_root})" ]; then
        echo "Moving ${local_temp_root} --> ${local_destination}"
        
        if ! mkdir -p "${local_destination}" && mv "${local_temp_root}" "${local_destination}"; then
            echo "Move failed!"
            return 1
        fi
    fi
    
    if ! ssh_command "rm -rf ${remote_temp_directory}"; then
        echo "Failed to delete ${remote_temp_directory} during cleanup"; echo
        return 1
    fi
    
    echo "Cleaning up empty directories under ${SEEDBOX_TEMP_TRANSFER_ROOT}"
    if [ -n "$(ssh_command "ls -A ${SEEDBOX_TEMP_TRANSFER_ROOT}")" ]; then
        ssh_command "find """""${SEEDBOX_TEMP_TRANSFER_ROOT}/'*'""""" -type d -empty -delete"
    fi
    
    return 0
}

# Pull downloaded or downloaded seeding files
# remote_source="${1}" - remote location
# local_destination="${2}" - local destination

downloaded_success=0
seeding_success=0

if ! check_for_unfinished "${PROCESSING_LOCATION}"; then
    echo "Failed check for unfinished downloads"
    exit 1
fi

if [ "${1}" = "download" ] || [ "${1}" = "all" ]; then
    echo "Running sync of downloaded ${SEEDBOX_DELUGE_ROOT}/${SEEDBOX_DOWNLOADING_DIR}"
    seedbox_pull_downloads "${SEEDBOX_DELUGE_ROOT}/${SEEDBOX_DOWNLOADING_DIR}/" "${PROCESSING_LOCATION}"
    downloaded_success=$?
    echo
fi

if [ "${1}" = "seeding" ] || [ "${1}" = "all" ]; then
    echo "Running sync of seeding ${SEEDBOX_DELUGE_ROOT}/${SEEDBOX_SEEDING_DIR}"
    seedbox_pull_seeding "${SEEDBOX_DELUGE_ROOT}/${SEEDBOX_SEEDING_DIR}" "${SYNC_LOCATION}"
    seeding_success=$?
    echo
fi

if [ -n "$(ls -A ${PROCESSING_LOCATION})" ]; then
    echo "Cleaning up empty directories in ${PROCESSING_LOCATION}"
    find "${PROCESSING_LOCATION}/"* -type d -empty -delete
fi

chown -R "${FILES_OWNER}:${FILES_GROUP}" "${PROCESSING_LOCATION}"

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
