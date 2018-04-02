#!/bin/sh

# Cloudflare account details CF_Email, CF_Key
. "/mnt/tank/system/local/secrets/le-cert-deploy.auth"

# letsencrypt Jail
le_jail="letsencrypt"
le_user="acme"

cert_db="/mnt/tank/data/database/letsencrypt/certs"
jail_db="/mnt/tank/data/database"

############# MAIN CODE #############

convert_pkcs(){
  server="${1}"
  pass="${2}"
  out_name="${3}"
  key="${4}"
  cert="${5}"
  ca="${6}"

  echo
  echo "Generating pkcs for ${server}"
  echo "to ${cert_db}/${server}/${out_name}"

  openssl pkcs12 -export -out "${cert_db}/${server}/${out_name}" \
                 -inkey ${cert_db}/${server}/${key} \
                 -in ${cert_db}/${server}/${cert} \
                 -certfile ${cert_db}/${server}/${ca} \
                 -passout ${pass}
}

# Install to jail, locations relative to jail db
# eg
# deploy "emby/ssl" "letsencrypt/certs" "media" "media" "660"
deploy(){
  server="${1}"
  deploy_location="${2}"
  owner="${3}"
  group="${4}"
  perms="${5}"
  echo
  echo "Installing certs for: ${server}"
  echo "with deploy location: ${deploy_location}"

  # for cert in ${cert_db}/${server}/*; do
  #   install -b -B ".old-`date +%Y-%m-%d-%H:%M:%S`" -m 660 \
  #            -o ${owner} -g ${group} ${cert} ${deploy_location}
  #   echo "Installed: ${cert}"
  # done

# Install certs to {}
find "${cert_db}/${server}/" -type f \
  -exec install -b -m ${perms} \
            -o ${owner} -g ${group} {} ${deploy_location} \;
}

# Run acme in jail to check if certs need renewing, if so renew
iocage exec --jail_user ${le_user} ${le_jail} /bin/sh -c \
  'acme.sh --cron --force --home "/var/db/acme/.acme.sh"'

# # deploy syncthing's certs
# deploy "syncthing.ramsden.network" \
#       "/mnt/tank/jails/syncthing/var/db/syncthing" \
#       "syncthing" "syncthing" "770"

# # Restart syncthing:
# iocage exec syncthing /bin/sh -c 'service syncthing restart'

# # deploy sickrage's certs
# deploy "sickrage.ramsden.network" \
#     "${jail_db}/sickrage" \
#     "media" "media" "770"

# # Restart sickrage
# iocage exec sickrage /bin/sh -c 'service sickrage restart'

# convert emby's key to pkcs
convert_pkcs "emby.ramsden.network" "pass:" \
    "emby.ramsden.network.pfx" \
    "emby.ramsden.network.key" \
    "emby.ramsden.network.cer" \
    "ca.cer"
# deploy emby's certs
deploy "emby.ramsden.network" \
    "${jail_db}/emby/emby-server/ssl/" \
    "media" "media" "770"

# Restart emby
iocage exec emby /bin/sh -c 'service emby-server restart'

# # deploy couchpotato's certs
# deploy "couchpotato.ramsden.network" \
#     "${jail_db}/couchpotato/ssl" \
#     "media" "media" "770"

# # Restart couchpotato
# iocage exec couchpotato /bin/sh -c 'service couchpotato restart'

# # deploy sabnzbd's certs
# deploy "sabnzbd.ramsden.network" \
#     "${jail_db}/sabnzbd/admin" \
#     "media" "media" "770"
# # Restart sabnzbd
# iocage exec sabnzbd /bin/sh -c 'service sabnzbd restart'

# deploy lilan's certs? Saved in /etc/certificates
#install -b -B ".old-`date +%Y-%m-%d-%H:%M:%S`" -m 400 -o root -g wheel 
#/mnt/tank/data/database/letsencrypt/certs/lilan.ramsden.network/Lilan_s_LetsEncrypt_Certificate.key 
#/etc/certificates
#deploy "lilan.ramsden.network" \
#    "/etc/certificates" \
#    "root" "wheel" "400"

echo
echo "Finished deploying keys"
