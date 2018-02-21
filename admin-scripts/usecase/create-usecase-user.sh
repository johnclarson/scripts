#!/bin/bash
BASE_SIGMA_USECASE_GROUP="sigma"

if [ $# -ne 4 ]; then
  echo "create-usecase.sh <username> <user firstname> <user lastname> <usecase name>"
  exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

USER=$1
USER_FIRST_NAME=$2
USER_LAST_NAME=$3
USECASE_NAME=$4

# allow sigma to be prepended (or not) onto the usecase name
BASE_USECASE_NAME=$(echo "${USECASE_NAME}" | sed "s|${BASE_SIGMA_USECASE_GROUP}\.||g")
UPDATED_USECASE_NAME="${BASE_SIGMA_USECASE_GROUP}"."${BASE_USECASE_NAME}"

# allow the username to be username.usecase or just usecase, and append the
# usecase onto the end
UPDATED_USER=$(echo "${USER}" | sed "s|\.${BASE_USECASE_NAME}||g")."${BASE_USECASE_NAME}"

"${DIR}/../ipa/create-user.sh" "${UPDATED_USER}" "${USER_FIRST_NAME}" "${USER_LAST_NAME}"
"${DIR}/../ipa/add-user-to-group.sh" "${UPDATED_USER}" "${UPDATED_USECASE_NAME}"
