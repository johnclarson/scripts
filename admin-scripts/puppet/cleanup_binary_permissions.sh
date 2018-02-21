#!/bin/bash


binaries_path=$1
if [ "${binaries_path}" == "" ]; then
    binaries_path=/data/puppetlabs/binaries
fi

chown -R root:root ${binaries_path}
find ${binaries_path} -type d -exec chmod 755 {} \;
find ${binaries_path} -type f -exec chmod 644 {} \;

