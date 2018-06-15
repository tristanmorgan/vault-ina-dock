# manage auth methods
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# manage secret mounts
path "aws/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "consul/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "intca/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "rootca/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "totp/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# System config.
path "sys/*" {
  capabilities = ["list"]
}

path "sys/audit/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "sys/auth" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "sys/auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "sys/mounts" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "sys/policies" {
  capabilities = ["list"]
}

path "sys/policies/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
