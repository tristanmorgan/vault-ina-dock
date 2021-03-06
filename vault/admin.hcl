# List, create, update, and delete key/value secrets
path "aws/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "consul/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "transform/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "totp/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# List existing policies
path "sys/policies" {
  capabilities = ["read", "list"]
}

# Create and manage ACL policies broadly across Vault
path "sys/policies/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage and manage secret backends broadly across Vault.
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Read health checks
path "sys/health" {
  capabilities = ["read", "sudo"]
}

# Manage auth backends broadly across Vault
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List, create, update, and delete auth backends
path "sys/auth/*" {
  capabilities = ["create", "read", "update", "delete", "sudo"]
}
