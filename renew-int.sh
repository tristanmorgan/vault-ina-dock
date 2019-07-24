#!/bin/sh

export DOMAIN_ROOT=consul
export CONSUL_FQDN=consul.service.$DOMAIN_ROOT
export VAULT_FQDN=vault.service.$DOMAIN_ROOT
export CONSUL_DC=$(awk '/datacenter/ {print $3}' consul/conf/consul.hcl)

export VAULT_SKIP_VERIFY=true

vault token lookup > /dev/null
if [ $? -ne 0 ]
then
    echo "ERROR: missing Vault root token (set VAULT_TOKEN in env)"
    exit 1
fi

# Vault setup script. vault needs to be unsealed first
vault status | fgrep "Sealed" | fgrep -q "true"
if [ $? -eq 0 ]
then
    echo "ERROR: Vault is sealed"
    exit 3
fi


#PKI secret backend mount
if [ -n "$CONSUL_FQDN" ]
then
  # start a CSR
  vault write -format=json intca/intermediate/generate/internal common_name="$USER intermediate CA" ttl=8760h format=pem_bundle key_bits=256 key_type=ec > int.$DOMAIN_ROOT.csr.json

  # Approve the CSR with the Root CA
  jq -r .data.csr int.$DOMAIN_ROOT.csr.json > csr.pem
  vault write -format=json rootca/root/sign-intermediate csr=@csr.pem format=pem_bundle use_csr_values=true > int.$DOMAIN_ROOT.json
  jq -r .data.certificate int.$DOMAIN_ROOT.json > intca_cert.pem

  # config with the response
  vault write intca/intermediate/set-signed certificate=@intca_cert.pem
  rm int.$DOMAIN_ROOT.csr.json csr.pem

  # request a cert for Vault
  vault write -format=json intca/issue/$DOMAIN_ROOT common_name="$VAULT_FQDN" ip_sans=127.0.0.1 format=pem_bundle > $VAULT_FQDN.json

  jq -r .data.issuing_ca int.$DOMAIN_ROOT.json > ca_cert.pem
  jq -r .data.certificate $VAULT_FQDN.json > fullchain.pem
#  cat ca_cert.pem >> fullchain.pem
  jq -r .data.private_key $VAULT_FQDN.json > privkey.pem

  mv *.pem vault/certs

  # request a cert for Consul
  vault write -format=json intca/issue/$DOMAIN_ROOT common_name="$CONSUL_FQDN" alt_names="server.$CONSUL_DC.$DOMAIN_ROOT" ip_sans=127.0.0.1 format=pem_bundle > $CONSUL_FQDN.json

  jq -r .data.issuing_ca int.$DOMAIN_ROOT.json > ca_cert.pem
  jq -r .data.certificate $CONSUL_FQDN.json > fullchain.pem
#  cat ca_cert.pem >> fullchain.pem
  jq -r .data.private_key $CONSUL_FQDN.json > privkey.pem

  mv *.pem consul/certs

  rm int.$DOMAIN_ROOT.json $VAULT_FQDN.json $CONSUL_FQDN.json

  echo "INFO: created Certificates that can be used to secure communications with the cluster."
  echo "INFO: generate more with 'vault write intca/issue/$DOMAIN_ROOT common_name=test.$DOMAIN_ROOT'"
  docker kill -s SIGHUP vault-ina-dock_vault_1
  docker kill -s SIGHUP vault-ina-dock_consula_1
fi

