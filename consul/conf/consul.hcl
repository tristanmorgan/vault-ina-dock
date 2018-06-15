acl_datacenter = "system-internal"
acl_default_policy = "deny"
acl_master_token = "ab1469ec-078c-42cf-bb7b-6ef2a52360ea"
acl_agent_token = "ab1469ec-078c-42cf-bb7b-6ef2a52360ea"
acl_down_policy = "extend-cache"
acl_enforce_version_8 = false
#ca_file = "/certs/ca_cert.pem"
cert_file = "/certs/fullchain.pem"
client_addr = "{{GetPrivateIP}} 127.0.0.1"
bind_addr = "{{GetPrivateIP}}"
data_dir = "/data"
datacenter = "system-internal"
disable_host_node_id = true
disable_update_check = true
encrypt = "3a6nE3qvOSwaPVcg73nxLQ=="
key_file = "/certs/privkey.pem"
leave_on_terminate = true
log_level = "INFO"
ports = {
  dns   = 8600
  https = 8443
}
protocol = 3
raft_protocol = 3
recursors = [
  "8.8.8.8",
  "8.8.4.4",
]
rejoin_after_leave = false
server_name = "consul.service.consul"
ui = true
# verify_incoming_rpc = true
# verify_outgoing = true
