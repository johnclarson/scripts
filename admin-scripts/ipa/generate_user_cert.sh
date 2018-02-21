#!/bin/bash
set -x

if [ $# -ne 2 ]; then
  echo "generate_user_cert.sh <username> <top level domain>"
  exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${DIR}/check-for-ipa-admin-tools.sh"

install_ipa_if_needed

USER=$1
TLD=$2

mkdir ${USER}
KEY=${USER}/${USER}.key
CSR=${USER}/${USER}.csr
INF=${USER}/${USER}.inf

INF_FILE=$(cat <<'END_HEREDOC'
[ req ]
prompt = no
encrypt_key = no

distinguished_name = dn
req_extensions = exts

[ dn ]
commonName = "USER"

[ exts ]
subjectAltName=email:USER@TLD

END_HEREDOC
)

echo "$INF_FILE" | sed "s|USER|${USER}|g" | sed "s|TLD|${TLD}|g" > ${INF}

openssl genrsa -out ${KEY} 2048
openssl req -new -key ${KEY} -out ${CSR} -config ${INF}

ipa cert-request ${CSR} --principal ${USER}

echo "Give the server 10 seconds to sign the cert..."
sleep 10

CERT_SERIAL_NUMBER=$(ipa cert-find --users=${USER} | grep -i "Serial number" | grep -v hex | awk '{print $3}')
CREATED_CERT_SN=$(echo $CERT_SERIAL_NUMBER | awk '{print $NF}')
PEM=${USER}/${USER}_${CREATED_CERT_SN}.pem
P12=${USER}/${USER}_${CREATED_CERT_SN}.p12

ipa cert-show ${CREATED_CERT_SN} --out ${PEM}

EXPORT_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)

openssl pkcs12 -export -inkey ${KEY} -in ${PEM} -out ${P12} -password pass:"${EXPORT_PASSWORD}"

echo "${EXPORT_PASSWORD}" > "$USER/p12_export_pw_${CREATED_CERT_SN}.txt"
