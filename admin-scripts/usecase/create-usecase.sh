#!/bin/bash

BASE_SIGMA_USECASE_GROUP="sigma"

if [ $# -ne 2 ]; then
  echo "create-usecase.sh <usecase name> <use case description>"
  exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

USECASE_NAME=$1
USECASE_DESCRIPTION=$2

UPDATED_USECASE_NAME=${BASE_SIGMA_USECASE_GROUP}.$(echo "${USECASE_NAME}" | sed "s|${BASE_SIGMA_USECASE_GROUP}\.||g")

"${DIR}/../ipa/create-user-group.sh" "${UPDATED_USECASE_NAME}" "${USECASE_DESCRIPTION}"
"${DIR}/../ipa/add-group-to-group.sh" "${UPDATED_USECASE_NAME}" "${BASE_SIGMA_USECASE_GROUP}"
