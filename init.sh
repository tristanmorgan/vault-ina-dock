#!/bin/sh

#add a default policy for consul
export DOMAIN_ROOT=consul
export CONSUL_FQDN=consul.service.$DOMAIN_ROOT
export VAULT_FQDN=vault.service.$DOMAIN_ROOT
export CONSUL_HTTP_TOKEN=$(awk '/master/ {print substr($3,2,36)}' consul/conf/consul.hcl)
export CONSUL_DC=$(awk '/primary_datacenter/ {print $3}' consul/conf/consul.hcl)
export CONSUL_HTTP_ADDR=127.0.0.1:8500

consul acl policy create -name "anonymous" -description "Anonymous Policy" -rules @consul/anonymous_acl.hcl
consul acl token update -id 00000000-0000-0000-0000-000000000002 -policy-name "anonymous"

#initialise Vault
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true

echo
vault operator init -status
if [ $? -ne 0 ]
then
    VAULT_INIT_OUT=$( vault operator init -key-shares=3 -key-threshold=2 )
    echo "SUCCESS: Vault initialised"

    for key in $(echo "$VAULT_INIT_OUT" | awk '/Key/ {print $NF}'); do
      vault operator unseal $key > /dev/null
    done

    export VAULT_TOKEN=$(echo "$VAULT_INIT_OUT" | awk '/Token/ {print $NF}')

    vault login $VAULT_TOKEN

    echo "WARN: don't loose these unseal keys nor token"
    echo "$VAULT_INIT_OUT" | grep 'Key'
    echo "$VAULT_INIT_OUT" | grep 'Token'
else
    echo "WARN: Cannot reinitialise the Vault"
fi
echo

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

#Enable logging
rm vault/logs/audit.log
vault audit enable -description="Audit logs to a file" file file_path="/logs/audit.log" log_raw=true

#Add Vault policies from files
for policy in $(ls vault/*.hcl); do
  vault policy write $(basename $policy .hcl) $policy
done

#Userpass authentication backend
PASSWORD=$(echo $USER:salt | base64 | head -c 10)
vault auth enable -description="User/password based credentials" userpass

vault write auth/userpass/users/$USER password=$PASSWORD policies=admin

echo "INFO: created a user with a dummy password, not secure"
echo "INFO: login with 'vault login -method=userpass username=$USER password=$PASSWORD'"

#GitHub authentication backend
vault auth enable -description="Authenticate using GitHub" github
vault write auth/github/config organization=vibrato
vault write auth/github/map/teams/vibrato-engineers value=admin

echo "INFO: you can provide your personal access token with VAULT_AUTH_GITHUB_TOKEN or"
echo "INFO: login with 'vault login -method=github token=000000905b381e723b3d6a7d52f148a5d43c4b45'"

#upload some SSH keys to the secret backend
vault secrets enable -path=secret kv
ssh-keygen -q -t ed25519 -N $PASSWORD -C temp@vault -f id_temp

vault write secret/$USER/id_temp private=@id_temp public=@id_temp.pub
rm -f id_temp

echo "INFO: uploaded a dummy ssh key pair to secret/$USER/id_temp"
echo "INFO: retrieve with 'vault read -field=private secret/$USER/id_temp'"

#TOTP Time-based One Time Passcodes
vault secrets enable -description="Time-based One Time Passcodes" totp
vault write -format=json totp/keys/$USER generate=true account_name=$USER issuer=Vault > $USER.totp.json

jq -r .data.barcode $USER.totp.json | base64 -D | open -f -a Preview
MFAKEY=$(jq -r .data.url $USER.totp.json)
rm $USER.totp.json

echo "INFO: generated an OTP secret"
echo "INFO: add to your authenticator the following code"
echo "INFO: '$MFAKEY'"
echo "INFO: validate with 'vault write totp/code/$USER code=<T-OTP-Code>'"

#Consul secret backend mount
if [ -n "$CONSUL_HTTP_TOKEN" ]
then
  vault secrets enable -description="Access Consul tokens" consul

  vault write consul/config/access address=consula:8500 token=$CONSUL_HTTP_TOKEN

  POLICY='key "" { policy = "read" }'
  echo $POLICY | base64 | vault write consul/roles/readonly policy=-

  consul kv put $USER @id_temp.pub

  echo
  echo "INFO: created a readonly role within Consul"
  echo "INFO: retrieve with 'vault read consul/creds/readonly'"
  echo "INFO: test with 'consul kv get $USER'"
fi
rm -f id_temp.pub

#AWS secret backend mount
if [ -n "$AWS_ACCESS_KEY_ID" ]
then
  vault secrets enable -description="Access AWS Credentials" aws

  vault write aws/config/root access_key=$AWS_ACCESS_KEY_ID secret_key=$AWS_SECRET_ACCESS_KEY region=$AWS_DEFAULT_REGION

  vault write aws/roles/readonly policy_arns=arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess

  echo "INFO: created a readonly role within AWS"
  echo "INFO: retrieve with 'vault read aws/creds/readonly'"
fi

#PKI secret (Root and Intermediate CA) backend mount
if [ -n "$CONSUL_FQDN" ]
then
  vault secrets enable -description="Host a Root CA" -path=rootca pki
  vault secrets tune -max-lease-ttl=87600h rootca
  vault write rootca/config/urls issuing_certificates="https://$VAULT_FQDN:8200/v1/rootca/ca" crl_distribution_points="https://$VAULT_FQDN:8200/v1/rootca/crl"
  vault write rootca/roles/$DOMAIN_ROOT allowed_domains="$DOMAIN_ROOT" allow_subdomains="true" allow_localhost="true" ttl="8760h" max_ttl="87600h" key_bits=521 key_type=ec

  vault write -format=json rootca/root/generate/internal common_name="$USER self-signed Root CA" ttl=8760h format=pem_bundle key_bits=521 key_type=ec > $DOMAIN_ROOT.json

  vault secrets enable -description="Host an Intermediate CA" -path=intca pki
  vault secrets tune -max-lease-ttl=8760h intca
  vault write intca/config/urls issuing_certificates="https://$VAULT_FQDN/v1/intca/ca" crl_distribution_points="https://$VAULT_FQDN/v1/intca/crl"
  vault write intca/roles/$DOMAIN_ROOT allowed_domains="$DOMAIN_ROOT" allow_subdomains="true" allow_localhost="true" ttl="72h" max_ttl="72h" key_bits=256 key_type=ec

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

  jq -r .data.ca_chain[0] $VAULT_FQDN.json > ca_cert.pem
  jq -r .data.certificate $VAULT_FQDN.json > fullchain.pem
  cat ca_cert.pem >> fullchain.pem
  jq -r .data.private_key $VAULT_FQDN.json > privkey.pem

  mv *.pem vault/certs

  # request a cert for Consul
  vault write -format=json intca/issue/$DOMAIN_ROOT common_name="$CONSUL_FQDN" alt_names="server.$CONSUL_DC.$DOMAIN_ROOT" ip_sans=127.0.0.1 format=pem_bundle > $CONSUL_FQDN.json

  jq -r .data.ca_chain[0] $CONSUL_FQDN.json > ca_cert.pem
  jq -r .data.certificate $CONSUL_FQDN.json > fullchain.pem
  cat ca_cert.pem >> fullchain.pem
  jq -r .data.private_key $CONSUL_FQDN.json > privkey.pem

  mv *.pem consul/certs

  rm int.$DOMAIN_ROOT.json $VAULT_FQDN.json $CONSUL_FQDN.json

  echo "INFO: created Certificates that can be used to secure communications with the cluster."
  echo "INFO: generate more with 'vault write intca/issue/$DOMAIN_ROOT common_name=test.$DOMAIN_ROOT'"
  docker kill -s SIGHUP vault-ina-dock_vault_1
  docker kill -s SIGHUP vault-ina-dock_consula_1
fi

echo
echo "don't forget to:"
echo "export VAULT_TOKEN=$VAULT_TOKEN "
echo "export CONSUL_HTTP_TOKEN=$CONSUL_HTTP_TOKEN"
echo "export CONSUL_HTTP_ADDR=$CONSUL_HTTP_ADDR"
echo
echo "export VAULT_SKIP_VERIFY=true"
echo " or set "
echo "export VAULT_TLS_SERVER_NAME=$VAULT_FQDN"
echo "export VAULT_CAPATH=$PWD/vault/certs/ca_cert.pem"
echo
echo "and for secure comms with Consul"
echo "export CONSUL_HTTP_ADDR=127.0.0.1:8443"
echo "export CONSUL_CACERT=$PWD/consul/certs/ca_cert.pem"
echo "export CONSUL_HTTP_SSL=true"
echo "export CONSUL_TLS_SERVER_NAME=$CONSUL_FQDN"
