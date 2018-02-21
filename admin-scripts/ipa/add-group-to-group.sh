#!/bin/bash

if [ $# -ne 2 ]; then
  echo "add-group-to-group.sh <group to add> <group name>"
  exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${DIR}/check-for-ipa-admin-tools.sh"

install_ipa_if_needed

GROUP_TO_ADD=$1
GROUP=$2

ipa group-add-member "${GROUP}" --groups="${GROUP_TO_ADD}"
