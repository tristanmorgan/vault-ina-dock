#!/bin/bash

export CONSUL_VERSION=0.6.4

if [ -n $1 ]; then
  export CONSUL_VERSION=$1
fi

if [ ! -f consul_${CONSUL_VERSION}_linux_amd64.zip ]; then
  curl -OL https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
fi
unzip consul_${CONSUL_VERSION}_linux_amd64.zip

docker build -t consul:${CONSUL_VERSION} -t consul:latest .

rm consul
