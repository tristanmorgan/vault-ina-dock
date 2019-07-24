#!/bin/bash

HC_TAGS_FEED="https://releases.hashicorp.com/consul/"
CONSUL_VERSION=$(curl -s "$HC_TAGS_FEED" | awk 'match($0,"consul") {match($0,/[0-9\.]+/); print substr($0,RSTART,RLENGTH); exit}' )

if [ -n "$1" ]; then
  export CONSUL_VERSION=$1
fi

docker build --build-arg CONSUL_VERSION=${CONSUL_VERSION} -t consul:${CONSUL_VERSION} -t consul:latest .
