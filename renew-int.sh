#!/bin/sh

export DOMAIN_ROOT=$USER.example.com
export CONSUL_VAULT_FQDN=consul.$DOMAIN_ROOT

export VAULT_SKIP_VERIFY=true

if [ -z "$VAULT_TOKEN" ]
then
    echo "ERROR: missing Vault root token (set VAULT_TOKEN in env)"
    exit 1
fi

# Vault setup script. vault needs to be unsealed first
vault status | fgrep -q "Sealed: true"
if [ $? -eq 0 ]
then
    echo "ERROR: Vault is sealed"
    exit 3
fi


#PKI secret backend mount
if [ -n "$CONSUL_VAULT_FQDN" ]
then
  vault write -format=json intca/intermediate/generate/internal common_name="$USER intermediate CA" ttl=8760h format=pem_bundle key_bits=256 key_type=ec > int.$DOMAIN_ROOT.csr.json

  jq -r .data.csr int.$DOMAIN_ROOT.csr.json > csr.pem
  vault write -format=json rootca/root/sign-intermediate csr=@csr.pem format=pem_bundle use_csr_values=true > int.$DOMAIN_ROOT.json
  jq -r .data.certificate int.$DOMAIN_ROOT.json > intca_cert.pem
  jq -r .data.issuing_ca int.$DOMAIN_ROOT.json > ca_cert.pem

  vault write intca/intermediate/set-signed certificate=@intca_cert.pem
  rm int.$DOMAIN_ROOT.csr.json int.$DOMAIN_ROOT.json csr.pem

  vault write -format=json intca/issue/$DOMAIN_ROOT common_name="$CONSUL_VAULT_FQDN" ip_sans=127.0.0.1 format=pem_bundle > $CONSUL_VAULT_FQDN.json

  jq -r .data.certificate $CONSUL_VAULT_FQDN.json > cert.pem
  jq -r .data.private_key $CONSUL_VAULT_FQDN.json > privkey.pem
  cat cert.pem > fullchain.pem
  cat ca_cert.pem >> fullchain.pem

  cp *.pem consul/certs
  mv *.pem vault/certs

  rm $DOMAIN_ROOT.json $CONSUL_VAULT_FQDN.json

  echo "INFO: created Certificates that can be used to secure communications with the cluster."
  echo "INFO: generate more with 'vault write intca/issue/$DOMAIN_ROOT common_name=test.$DOMAIN_ROOT'"
  # vault write -format=json intca/issue/tristan.example.com common_name=consul.tristan.example.com ip_sans=127.0.0.1 format=pem_bundle
  docker kill -s SIGHUP vaultinadock_vault_1
fi

echo
echo "don't forget to:"
echo "export VAULT_TOKEN=$VAULT_TOKEN "
echo "export CONSUL_HTTP_TOKEN=$CONSUL_HTTP_TOKEN"
echo "export CONSUL_HTTP_ADDR=$CONSUL_HTTP_ADDR"
echo
echo "export VAULT_SKIP_VERIFY=true"
echo " or set "
echo "VAULT_TLS_SERVER_NAME=$CONSUL_VAULT_FQDN"
echo "VAULT_CAPATH=$PWD/vault/certs/ca_cert.pem"
