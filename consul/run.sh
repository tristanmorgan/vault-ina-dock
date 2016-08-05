#!/bin/sh

docker run --rm -d \
    -p "8500:8500" \
    -h "consul" \
    consul -server -bootstrap -ui -data-dir=/
