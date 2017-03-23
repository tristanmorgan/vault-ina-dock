#!/bin/sh

#add a default policy for consul
export DOMAIN_ROOT=$USER.example.com
export CONSUL_VAULT_FQDN=consul.$DOMAIN_ROOT
export CONSUL_HTTP_TOKEN=$(jq -r .acl_master_token consul/conf/consul.json)
export CONSUL_HTTP_ADDR=127.0.0.1:8500

curl -X PUT -d @consul/anonymous_acl.json "http://$CONSUL_HTTP_ADDR/v1/acl/update?token=$CONSUL_HTTP_TOKEN"

#initialise  Vault
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true

echo
vault init -check
if [ $? -ne 0 ]
then
    VAULT_INIT_OUT=$( vault init -key-shares=3 -key-threshold=2 )
    echo "SUCCESS: Vault initialised"

    for key in $(echo "$VAULT_INIT_OUT" | awk '/Key/ {print $NF}'); do
      vault unseal $key > /dev/null
    done

    export VAULT_TOKEN=$(echo "$VAULT_INIT_OUT" | awk '/Token/ {print $NF}')

    echo "WARN: don't loose these unseal keys nor token"
    echo "$VAULT_INIT_OUT" | grep 'Key'
    echo "$VAULT_INIT_OUT" | grep 'Token'
else
    echo "WARN: Cannot reinitialise the Vault"
fi
echo

VAULT_TOKEN=${VAULT_TOKEN:-$(cat ~/.vault-token)}

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

#Enable logging
rm vault/logs/audit.log
vault audit-enable -description="Audit logs to a file" file file_path="/logs/audit.log" log_raw=true

#Add Vault policies from files
for policy in $(ls vault/*.hcl); do
  vault policy-write $(basename $policy .hcl) $policy
done

#Userpass authentication backend
PASSWORD=$(echo $USER:salt | base64 | head -c 10)
vault auth-enable -description="User/password based credentials" userpass

vault write auth/userpass/users/$USER password=$PASSWORD policies=admin

echo "INFO: created a user with a dummy password, not secure"
echo "INFO: login with 'vault auth -method=userpass username=$USER password=$PASSWORD'"

#GitHub authentication backend
vault auth-enable -description="Authenticate using GitHub" github
vault write auth/github/config organization=vibrato
vault write auth/github/map/teams/vibrato-engineers value=admin

echo "INFO: you can provide your personal access token with VAULT_AUTH_GITHUB_TOKEN or"
echo "INFO: login with 'vault auth -method=github token=000000905b381e723b3d6a7d52f148a5d43c4b45'"

#upload some SSH keys to the secret backend
ssh-keygen -q -t ed25519 -N $PASSWORD -C temp@vault -f id_temp

vault write secret/$USER/id_temp private=@id_temp public=@id_temp.pub
rm -f id_temp

echo "INFO: uploaded a dummy ssh key pair to secret/$USER/id_temp"
echo "INFO: retrieve with 'vault read -field=private secret/$USER/id_temp'"

#TOTP Time-based One Time Passcodes
vault mount -description="Time-based One Time Passcodes" totp
vault write totp/keys/tristan generate=true account_name=$USER issuer=Vault

MFAKEY=$(vault read -field=url totp/keys/$USER)

echo "INFO: generated an OTP secret"
echo "INFO: add to your authenticator the following code"
echo "INFO: '$MFAKEY'"
echo "INFO: validate with 'vault write totp/code/$USER code=<T-OTP-Code>'"

#Consul secret backend mount
if [ -n "$CONSUL_HTTP_TOKEN" ]
then
  vault mount -description="Access Consul tokens" consul

  vault write consul/config/access address=consula:8500 token=$CONSUL_HTTP_TOKEN

  POLICY='key "" { policy = "read" }'
  echo $POLICY | base64 | vault write consul/roles/readonly policy=-

  curl -X PUT -d @id_temp.pub http://$CONSUL_HTTP_ADDR/v1/kv/$USER?token=$CONSUL_HTTP_TOKEN

  echo
  echo "INFO: created a readonly role within Consul"
  echo "INFO: retrieve with 'vault read consul/creds/readonly'"
  echo "INFO: test with 'consul kv get $USER'"
fi
rm -f id_temp.pub

#AWS secret backend mount
if [ -n "$AWS_ACCESS_KEY_ID" ]
then
  vault mount -description="Access AWS Credentials" aws

  vault write aws/config/root access_key=$AWS_ACCESS_KEY_ID secret_key=$AWS_SECRET_ACCESS_KEY region=$AWS_DEFAULT_REGION

  vault write aws/roles/readonly arn=arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess

  echo "INFO: created a readonly role within AWS"
  echo "INFO: retrieve with 'vault read aws/creds/readonly'"
fi

#PKI secret backend mount
if [ -n "$CONSUL_VAULT_FQDN" ]
then
  vault mount -description="Host a Root CA" -path=rootca pki
  vault mount-tune -max-lease-ttl=87600h rootca
  vault write rootca/config/urls issuing_certificates="$VAULT_ADDR/v1/rootca/ca" crl_distribution_points="$VAULT_ADDR/v1/rootca/crl"
  vault write rootca/roles/$DOMAIN_ROOT allowed_domains="$DOMAIN_ROOT" allow_subdomains="true" allow_localhost="true" max_ttl="8760h" key_bits=521 key_type=ec

  vault write -format=json rootca/root/generate/internal common_name="$USER self-signed Root CA" ttl=8760h format=pem_bundle key_bits=521 key_type=ec > $DOMAIN_ROOT.json

  vault mount -description="Host an Intermediate CA" -path=intca pki
  vault mount-tune -max-lease-ttl=8760h intca
  vault write -format=json intca/intermediate/generate/internal common_name="$USER intermediate CA" ttl=8760h format=pem_bundle key_bits=256 key_type=ec > int.$DOMAIN_ROOT.csr.json
  jq -r .data.csr int.$DOMAIN_ROOT.csr.json > csr.pem
  vault write -format=json rootca/root/sign-intermediate csr=@csr.pem format=pem_bundle use_csr_values=true > int.$DOMAIN_ROOT.json
  jq -r .data.certificate int.$DOMAIN_ROOT.json > intca.cert.pem

  vault write intca/intermediate/set-signed certificate=@intca.cert.pem
  rm int.$DOMAIN_ROOT.csr.json int.$DOMAIN_ROOT.json csr.pem intca.cert.pem

  vault write intca/config/urls issuing_certificates="$VAULT_ADDR/v1/intca/ca" crl_distribution_points="$VAULT_ADDR/v1/intca/crl"
  vault write intca/roles/$DOMAIN_ROOT allowed_domains="$DOMAIN_ROOT" allow_subdomains="true" allow_localhost="true" max_ttl="72h" key_bits=256 key_type=ec
  vault write -format=json intca/issue/$DOMAIN_ROOT common_name="$CONSUL_VAULT_FQDN" format=pem_bundle > $CONSUL_VAULT_FQDN.json

  jq -r .data.issuing_ca $DOMAIN_ROOT.json > ca_cert.pem
  jq -r .data.certificate $CONSUL_VAULT_FQDN.json > cert.pem
  jq -r .data.private_key $CONSUL_VAULT_FQDN.json > privkey.pem
  cat cert.pem > fullchain.pem
  cat ca_cert.pem >> fullchain.pem

  cp *.pem consul/certs
  mv *.pem vault/certs

  rm $DOMAIN_ROOT.json $CONSUL_VAULT_FQDN.json

  echo "INFO: created Certificates that can be used to secure communications with the cluster."
  echo "INFO: generate more with 'vault write intca/issue/$DOMAIN_ROOT common_name=test.$DOMAIN_ROOT'"
fi

echo
echo "don't forget to:"
echo "export VAULT_ADDR=$VAULT_ADDR "
echo "export VAULT_SKIP_VERIFY=true"
echo "export VAULT_TOKEN=$VAULT_TOKEN "
echo "export CONSUL_HTTP_TOKEN=$CONSUL_HTTP_TOKEN"
echo "export CONSUL_HTTP_ADDR=$CONSUL_HTTP_ADDR"
