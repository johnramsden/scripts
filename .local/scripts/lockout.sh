#!/bin/sh

users_checking="${1:-""}"
timeout="${2:-"1m"}"
users_locking=""

check_users() {
    u_locking=""
    for u in ${1}; do
        if grep ${u} /etc/passwd >/dev/null 2>&1; then
            users_locking="${u_locking} ${u}"
        fi
    done
    echo "${users_locking}"
}

unlock_users() {
    for u in ${users_locking}; do
        echo "RUNNING: passwd --unlock ${u}"
        passwd --unlock ${u}
    done
}

lock_users() {
    for u in ${users_locking}; do
        echo "RUNNING: passwd --lock ${u}"
        passwd --lock ${u}
    done
}

users_locking=$(check_users "${users_checking}")
trap unlock_users 1 2 3 6 9

echo "Locking ${users_locking} for ${timeout}"
lock_users && sleep "${timeout}"

unlock_users
echo "Unlocked: ${users_locking}"
