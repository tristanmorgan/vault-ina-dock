#!/bin/sh

mkdir -p vault/ssl
security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain > vault/ssl/ca-bundle.pem
