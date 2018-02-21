#!/bin/bash

if [ $# -ne 3 ]; then
  echo "create-user.sh <uid> <firstname> <lastname>"
  exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${DIR}/check-for-ipa-admin-tools.sh"

install_ipa_if_needed

USERNAME=$1
FIRST_NAME=$2
LAST_NAME=$3

output=`ipa user-add "${USERNAME}" --shell /bin/bash --first="${FIRST_NAME}" --last=${LAST_NAME}`

if [ "$?" -ne 0 ]; then
  echo "Creating user ${USERNAME} failed"
  exit 1
fi

TLD=`echo "${output}" | grep -i email | awk '{print $3}' | sed "s|.*@||g"`
echo $TLD

"${DIR}/generate_user_cert.sh" "${USERNAME}" "${TLD}"
