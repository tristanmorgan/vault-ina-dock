#!/bin/bash

export VAULT_VERSION=0.6.0

if [ -n $1 ]; then
  export VAULT_VERSION=$1
fi

if [ ! -f vault_${VAULT_VERSION}_linux_amd64.zip ]; then
  curl -OL https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
fi
unzip vault_${VAULT_VERSION}_linux_amd64.zip

docker build -t vault:${VAULT_VERSION} -t vault:latest .

rm vault
