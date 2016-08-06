backend "consul" {
  address = "consula:8500"
  path = "vault"
  scheme = "http"
  token = "ab1469ec-078c-42cf-bb7b-6ef2a52360ea"
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = 1
}
