#!/bin/bash

if [ $# -ne 2 ]; then
  echo "create-user-group.sh <groupname> <description>"
  exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${DIR}/check-for-ipa-admin-tools.sh"

install_ipa_if_needed

NAME=$1
DESCRIPTION=$2

ipa group-add "${NAME}" --desc="${DESCRIPTION}"
