#!/bin/bash

export CONSUL_VERSION=1.3.0

if [ -n "$1" ]; then
  export CONSUL_VERSION=$1
fi

#if [ ! -f consul_${CONSUL_VERSION}_linux_amd64.zip ]; then
#  curl -OL https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
#fi
#unzip consul_${CONSUL_VERSION}_linux_amd64.zip

docker build --build-arg CONSUL_VERSION=${CONSUL_VERSION} -t consul:${CONSUL_VERSION} -t consul:latest .

rm consul
