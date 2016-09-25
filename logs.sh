#!/bin/sh

cat vault/logs/audit.log | while read line;
do
  echo $line | jq -C -S .;
done

