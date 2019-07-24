#!/bin/bash

HC_TAGS_FEED="https://releases.hashicorp.com/vault/"
VAULT_VERSION=$(curl -s "$HC_TAGS_FEED" | awk 'match($0,"vault") {match($0,/[0-9\.]+/); print substr($0,RSTART,RLENGTH); exit}' )

if [ -n "$1" ]; then
  VAULT_VERSION=$1
fi

docker build --build-arg VAULT_VERSION=${VAULT_VERSION} -t vault:${VAULT_VERSION} -t vault:latest .
