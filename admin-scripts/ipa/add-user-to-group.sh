#!/bin/bash

if [ $# -ne 2 ]; then
  echo "add-user-to-group.sh <UID> <group name>"
  exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${DIR}/check-for-ipa-admin-tools.sh"

install_ipa_if_needed

USER=$1
GROUP=$2

ipa group-add-member "${GROUP}" --users="${USER}"
