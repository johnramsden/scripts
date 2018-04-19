#!/bin/sh

podcast_src='/mnt/tank/media/Downloads/Complete/processing/Podcasts'
podcast_dst='/mnt/tank/media/Series/Podcasts/Audio'

POD_USER="media"
POD_GROUP="media"

# Get all podcasts dirs, remove base and spaces
get_podnames(){
    find "${1}" -type d -exec sh -c '
    for file do
        echo "${file}"
    done
    ' sh {} +
}

check_if_pod_match(){
    for pod in ${2}; do
        if [ "${pod}" = "${1}" ]; then
            return 0
        fi
    done
    return 1
}

# Transfer any MP3s matching and removed their parent directories if empty
transfer_downloaded_podcast(){
    find "${1}" -type f -name '*.mp3' | while IFS= read -r pod_to_transfer; do
        echo "Transferring ${pod_to_transfer}"
        install -v -m 770 -o ${POD_USER} -g ${POD_GROUP} "${pod_to_transfer}" "${2}" && \
        rm "${pod_to_transfer}"
    done && \
    find "${1}" -empty -exec rm -r {} +
   
    return ${?}
}

move_podcasts(){
    ORIG_IFS=${IFS}
    match_list=$(get_podnames "${2}")
    echo "Running compare on podcasts"

    # Find source podcasts
    find "${1}" -type d -mindepth 1 -maxdepth 2 | \
        while IFS= read -r line; do
            WHILE_IFS=${IFS}
            # remove base and spaces
            pod_name=$(echo "${line}" | sed -e 's#.*/##' -e 's/ //g')
            echo "Checking for match for ${pod_name}"

            IFS=$'\n'
            for pod_dst_tmp in ${match_list}; do
                pod_dst_no_space=$(echo "${pod_dst_tmp}" | sed -e 's#.*/##' -e 's/ //g')
                if [ "${pod_dst_no_space}" = "${pod_name}" ]; then
                    echo "Found match for ${pod_name}"
                    transfer_downloaded_podcast "${line}" "${pod_dst_tmp}" || \
                    echo "Failed to transfer ${pod_name}" && exit 1
                fi
            done

            IFS=${WHILE_IFS}
        done

    IFS=${ORIG_IFS}

    return 0
}

echo "Moving any downloaded podcasts"
move_podcasts "${podcast_src}" "${podcast_dst}"
