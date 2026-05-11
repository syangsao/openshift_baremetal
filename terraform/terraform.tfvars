# Cluster configuration
cluster_name = "mycluster"
base_domain  = "example.com"

# Network configuration
cluster_network_cidr = "10.0.1.0/24"
cluster_network_gw   = "10.0.1.1"
provisioner_ip       = "10.0.0.10"

# Node IPs
bootstrap_ip = "10.0.1.11"
master_ips   = ["10.0.1.12", "10.0.1.13", "10.0.1.14"]
worker_ips   = ["10.0.1.21", "10.0.1.22"]

# Load balancer
lb_ip   = "10.0.0.12"
lb_server = "10.0.0.12"

# DNS
dns_server_ip = "10.0.0.11"

# SSH
ssh_public_key = "ssh-ed25519 AAAA... user@host"

# Dell iDRAC
iDRAC_bootstrap = "10.0.0.50"
iDRAC_masters   = ["10.0.0.51", "10.0.0.52", "10.0.0.53"]
iDRAC_workers   = ["10.0.0.54", "10.0.0.55"]
iDRAC_username  = "root"
iDRAC_password  = "your_password"
