# Step 2: Infrastructure Provisioning with Terraform

This guide provisions the networking, DNS, and load balancer infrastructure needed for the OpenShift bare metal cluster using Terraform.

## 2.1 Terraform Project Structure

```
terraform/
├── main.tf           # Provider and resource definitions
├── variables.tf      # Input variables
├── outputs.tf        # Output values
├── providers.tf      # Provider configurations
├── network.tf        # Network bridge and VLAN configuration
├── haproxy.tf        # HAProxy load balancer provisioning
├── dns.tf            # BIND DNS server configuration
├── terraform.tfvars  # Variable values
└── haproxy/          # HAProxy configuration templates
    └── haproxy.cfg   # Load balancer config template
```

## 2.2 Initialize Terraform

```bash
cd ~/openshift-baremetal/terraform
terraform init
```

Expected output:
```
Terraform has been successfully initialized!
```

## 2.3 Variables Configuration

Edit `terraform.tfvars` with your environment values:

```hcl
# terraform.tfvars
cluster_name    = "mycluster"
base_domain     = "example.com"

# Network configuration
cluster_network_cidr = "10.0.1.0/24"
cluster_network_gw   = "10.0.1.1"
provisioner_ip       = "10.0.0.10"

# Node IPs
bootstrap_ip = "10.0.1.11"
master_ips   = ["10.0.1.12", "10.0.1.13", "10.0.1.14"]
worker_ips   = ["10.0.1.21", "10.0.1.22"]

# Load balancer
lb_ip       = "10.0.0.12"
lb_server   = "10.0.0.12"  # Can be same as LB or separate VM

# DNS
dns_server_ip = "10.0.0.11"

# SSH
ssh_public_key = "ssh-ed25519 AAAA... user@host"

# Dell R630 iDRAC addresses (for remote ISO mount)
iDRAC_bootstrap = "10.0.0.50"
iDRAC_masters   = ["10.0.0.51", "10.0.0.52", "10.0.0.53"]
iDRAC_workers   = ["10.0.0.54", "10.0.0.55"]
iDRAC_username  = "root"
iDRAC_password  = "your_password"
```

## 2.4 Network Configuration

The Terraform provisioner creates a Linux bridge on each Dell R630 node:

```hcl
# network.tf — Network bridge configuration for Dell R630
resource "null_resource" "network_config" {
  for_each = setunion(
    [var.bootstrap_ip],
    set(var.master_ips),
    set(var.worker_ips)
  )

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = each.value
      user        = "core"
      private_key = "~/.ssh/id_ed25519"
    }

    inline = [
      # Create NetworkManager bridge for cluster network
      <<-EOT
        cat > /etc/NetworkManager/system-connections/cluster-bridge.nmconnection << 'CONN'
[connection]
id=cluster-bridge
uuid=$(uuidgen)
type=bridge
interface-name=br0

[bridge]
stp=false

[ipv4]
method=manual
address1=${each.value}/24,${var.cluster_network_gw}
dns=${var.dns_server_ip};

[ipv6]
method=disabled
CONN

        # Configure physical interface as bridge slave
        nmcli con add type ethernet slave-type bridge ifname eno1 con-name br0-en1 master br0
        nmcli con mod br0-en1 connection.interface-name eno1

        # Activate
        nmcli con up cluster-bridge
      EOT
    ]
  }
}
```

## 2.5 HAProxy Load Balancer

Terraform provisions and configures HAProxy to load balance the API and machine-config-server ports.

### HAProxy Configuration Template

```cfg
# haproxy/haproxy.cfg
global
    log     /dev/log local0
    log     /dev/log local1 notice
    chroot  /var/lib/haproxy
    stats   socket /run/haproxy/admin.sock mode 660 level admin
    stats   timeout 30s
    user    haproxy
    group   haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    timeout connect 5s
    timeout client  50s
    timeout server  50s

# API server load balancer
frontend openshift-api
    bind *:6443
    mode tcp
    option tcp-check
    default_backend openshift-api-backend

backend openshift-api-backend
    mode tcp
    balance roundrobin
    option tcp-check
    server master0 ${var.master_ips[0]}:6443 check fall 3 rise 2
    server master1 ${var.master_ips[1]}:6443 check fall 3 rise 2
    server master2 ${var.master_ips[2]}:6443 check fall 3 rise 2

# API server (bootstrap + masters) — used during installation
frontend openshift-api-bootstrap
    bind *:22623
    mode tcp
    option tcp-check
    default_backend openshift-bootstrap-backend

backend openshift-bootstrap-backend
    mode tcp
    balance roundrobin
    option tcp-check
    server bootstrap ${var.bootstrap_ip}:22623 check fall 3 rise 2
    server master0 ${var.master_ips[0]}:22623 check fall 3 rise 2
    server master1 ${var.master_ips[1]}:22623 check fall 3 rise 2
    server master2 ${var.master_ips[2]}:22623 check fall 3 rise 2

# Router (after installation)
frontend openshift-router
    bind *:443
    mode tcp
    option tcp-check
    default_backend openshift-router-backend

backend openshift-router-backend
    mode tcp
    balance roundrobin
    option tcp-check
    server worker0 ${var.worker_ips[0]}:443 check fall 3 rise 2
    server worker1 ${var.worker_ips[1]}:443 check fall 3 rise 2
```

### Provisioning HAProxy

```bash
# On the load balancer server
sudo dnf install -y haproxy
sudo cp haproxy.cfg /etc/haproxy/haproxy.cfg
sudo systemctl enable --now haproxy
sudo firewall-cmd --permanent --add-port=6443/tcp
sudo firewall-cmd --permanent --add-port=22623/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload

# Verify
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
sudo systemctl status haproxy
```

## 2.6 DNS Server (BIND)

Terraform configures a BIND DNS server for cluster DNS records.

### Zone File

```bind
# dns/forward.zone
$ORIGIN ${var.cluster_name}.${var.base_domain}.
$TTL 300

@       IN SOA  ns1 admin.${var.base_domain}. (
                    2026051101  ; serial
                    3600        ; refresh
                    1800        ; retry
                    604800      ; expire
                    300         ; minimum
)

@       IN NS   ns1.${var.base_domain}.

; API servers
api         IN A    ${var.lb_ip}
api-int     IN A    ${var.lb_ip}

; Wildcard for routes
*.apps      IN A    ${var.lb_ip}

; Bootstrap
bootstrap   IN A    ${var.bootstrap_ip}

; Master nodes
master0     IN A    ${var.master_ips[0]}
master1     IN A    ${var.master_ips[1]}
master2     IN A    ${var.master_ips[2]}

; Worker nodes
worker0     IN A    ${var.worker_ips[0]}
worker1     IN A    ${var.worker_ips[1]}
```

### Named Configuration

```bind
# dns/named.conf
options {
    directory "/var/named";
    listen-on port 53 { any; };
    listen-on-v6 port 53 { none; };
    allow-query { any; };
    recursion no;
};

zone "${var.cluster_name}.${var.base_domain}." IN {
    type master;
    file "forward.zone";
};

zone "1.0.10.in-addr.arpa." IN {
    type master;
    file "reverse.zone";
};
```

### Installing BIND

```bash
sudo dnf install -y bind bind-utils
sudo cp named.conf /etc/named.conf
sudo cp forward.zone /var/named/${var.cluster_name}.${var.base_domain}.zone
sudo cp reverse.zone /var/named/1.0.10.in-addr.arpa.zone
sudo chown named:named /var/named/*.zone
sudo systemctl enable --now named

# Verify
dig @localhost api.${var.cluster_name}.${var.base_domain}
dig @localhost bootstrap.${var.cluster_name}.${var.base_domain}
```

## 2.7 Apply Terraform

```bash
# Plan first
terraform plan -var-file=terraform.tfvars

# Apply (review carefully!)
terraform apply -var-file=terraform.tfvars
```

## 2.8 Verify Infrastructure

```bash
# Check HAProxy is running and listening
curl -s http://localhost:8080  # if stats enabled
ss -tlnp | grep -E '6443|22623'

# Verify DNS resolution
dig +short api.${cluster_name}.${base_domain} @${dns_server_ip}
dig +short api-int.${cluster_name}.${base_domain} @${dns_server_ip}
dig +short bootstrap.${cluster_name}.${base_domain} @${dns_server_ip}

# Test API endpoint (will fail pre-install, but confirms LB routing)
nc -zv ${lb_ip} 6443

# Verify SSH to all nodes
for ip in ${bootstrap_ip} ${master_ips[@]} ${worker_ips[@]}; do
  ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no core@$ip 'hostname'
done
```

> **Next:** [Step 3: OpenShift Installation Configuration](03-install-config.md)
