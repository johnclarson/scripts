#!/bin/bash

function install_ipa_if_needed {
  # install ipa admintools if they are not yet installed
  if ! hash ipa 2>/dev/null; then
    sudo yum install -y ipa-installtools
  fi
}
