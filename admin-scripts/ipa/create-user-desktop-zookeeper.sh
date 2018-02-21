#!/bin/bash

#show output as script is running
set -e

#exit when there is an error
set -x

#function to check for valid variables
function variable_check () {
if [ -z "${2+1}" ] ; then
  echo "${1} is not set"
  return 1
else
  echo "${1} is set to ${2}"
fi
}

#variables
USERNAME="${1}"
USECASENAME="${2}"
SERVERNAME="${2}"

if ! variable_check "USERNAME" $USERNAME ; then
  exit 1
fi

if ! variable_check "USECASENAME" $USECASENAME ; then
  exit 1
fi

if ! variable_check "SERVERNAME" $SERVERNAME ; then
  exit 1
fi

zookeeper-client -server "${SERVERNAME}" create /sigma/sigma-manager/desktop/"${USECASENAME}"/"${USERNAME}"
