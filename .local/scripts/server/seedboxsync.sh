#!/bin/sh

SEEDBOX_USER="cacheline"
SEEDBOX_SERVER="polyphemus.feralhosting.com"

SEEDBOX_DELUGE_ROOT="/media/sdl1/cacheline/private/deluge"

SYNC_LOCATION="/mnt/tank/media/Downloads/Incomplete/box"

COMPLETED_SYNC_LOCATION="/mnt/tank/media/Downloads/Complete"

FILE_PERMISSIONS="760"
FILES_OWNER="media"
FILES_GROUP="media"

seedbox_pull(){
      SYNC_TIMESTAMP="$(date "+%F_%H_%M_%S" )"

      rsync --recursive \
            --verbose \
            -og --chown=media:media \
            --remove-source-files \
            -e ssh ${SEEDBOX_USER}@${SEEDBOX_SERVER}:${SEEDBOX_DELUGE_ROOT}/complete/downloading/ \
                  ${SYNC_LOCATION}/${SYNC_TIMESTAMP}
                  
      if [ $? -eq 0 ]; then
            echo
            echo "rsync ${SYNC_TIMESTAMP} seccessful from:"
            echo "    ${SEEDBOX_USER}@${SEEDBOX_SERVER}:${SEEDBOX_DELUGE_ROOT}/complete/downloading/"
            echo
            echo "Moving files to ${COMPLETED_SYNC_LOCATION}"

            install -m ${FILE_PERMISSIONS} -o ${FILES_OWNER} -g ${FILES_GROUP} \
                    -D ${SYNC_LOCATION}/${SYNC_TIMESTAMP} ${COMPLETED_SYNC_LOCATION} && return 0 || return 1

      else
            echo
            echo "rsync ${SYNC_TIMESTAMP} failed"
            return 1
      fi
}

seedbox_pull