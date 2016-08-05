#!/bin/sh

#add a default policy for consul
export CONSUL_MASTER_TOKEN=ab1469ec-078c-42cf-bb7b-6ef2a52360ea

curl -X PUT -d @consul/anonymous_acl.json "http://127.0.0.1:8500/v1/acl/update?token=$CONSUL_MASTER_TOKEN"

#initialise  Vault
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true

vault init -check
if [ $? -ne 0 ]
then
    VAULT_INIT_OUT=$( vault init -key-shares=3 -key-threshold=2 )
    echo "SUCCESS: Vault initialised"

    for key in $(echo "$VAULT_INIT_OUT" | awk '/hex/ {print $NF}'); do
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

#upload some SSH keys to the secret backen
ssh-keygen -q -t rsa -N $PASSWORD -C temp@vault -f id_temp

vault write secret/$USER/id_temp private=@id_temp public=@id_temp.pub
rm -f id_temp id_temp.pub

echo "INFO: uploaded a dummy ssh key pair to secret/$USER/id_temp"
echo "INFO: retrieve with 'vault read -field=private secret/$USER/id_temp'"

#Consul secret backend mount
if [ -n "$CONSUL_MASTER_TOKEN" ]
then
  vault mount -description="Access Consul tokens" consul

  vault write consul/config/access address=consula:8500 token=$CONSUL_MASTER_TOKEN

  POLICY='key "" { policy = "read" }'
  echo $POLICY | base64 | vault write consul/roles/readonly policy=-
fi

#AWS secret backend mount
if [ -n "$AWS_ACCESS_KEY_ID" ]
then
  vault mount -description="Access AWS Credentials" aws

  vault write aws/config/root access_key=$AWS_ACCESS_KEY_ID secret_key=$AWS_SECRET_ACCESS_KEY region=$AWS_DEFAULT_REGION

  vault write aws/roles/readonly arn=arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess
fi

echo
echo "don't forget to "
echo "export VAULT_ADDR=$VAULT_ADDR "
echo "export VAULT_SKIP_VERIFY=true"
echo "export VAULT_TOKEN=$VAULT_TOKEN "
