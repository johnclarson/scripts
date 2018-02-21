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

if ! variable_check "USERNAME" $USERNAME ; then
  exit 1
fi

if ! variable_check "USECASENAME" $USECASENAME ; then
  exit 1
fi

#create user directories in HDFS and set permissions
hdfs-kinit
hdfs dfs -mkdir /user/"${USERNAME}"
hdfs dfs -chown "${USERNAME}":"${USERNAME}" /user/"${USERNAME}"
hdfs dfs -chmod 750 /user/"${USERNAME}"
kdestroy
