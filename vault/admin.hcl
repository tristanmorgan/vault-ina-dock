path "secret/*" {
  policy = "write"
}

path "auth/token/lookup-self" {
  policy = "read"
}

path "auth/token/renew-self" {
  policy = "write"
}

path "aws/config/root" {
  policy = "write"
}

path "aws/sts/*" {
  policy = "read"
}

path "consul/creds/*" {
  policy = "read"
}

path "sys/mounts" {
  policy = "write"
}

path "sys/auth" {
  policy = "write"
}
