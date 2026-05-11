# Terraform Provider Requirements

## Required Providers

This project uses the following Terraform providers:

| Provider | Purpose |
|----------|---------|
| `hashicorp/null` | Provisioning resources via local/remote exec |
| `hashicorp/local` | Writing generated config files to disk |

## Terraform Version

- **Minimum**: Terraform >= 1.5.0
- **Recommended**: Latest 1.x release

## Setup

```bash
# Initialize Terraform
make init

# Validate configuration
make validate

# Review planned changes
make plan

# Apply configuration
make apply
```

## Dependencies on Target Hosts

### DNS Server (BIND)
- `bind` - DNS server
- `bind-utils` - DNS query tools (dig)
- SSH access as `core` user

### HAProxy Server
- `haproxy` - Load balancer
- `firewalld` - Firewall management
- SSH access as `core` user

### Dell R630 Nodes (via iDRAC)
- `ipmitool` installed on provisioner host
- iDRAC firmware 4.x or later
- iDRAC user with virtual media privileges

## Variables

See `terraform/variables.tf` for all variables. Required variables (no defaults):

- `ssh_public_key` - SSH public key for node access
- `iDRAC_bootstrap` - iDRAC IP for bootstrap node
- `iDRAC_masters` - iDRAC IPs for master nodes (list)
- `iDRAC_workers` - iDRAC IPs for worker nodes (list)
- `iDRAC_password` - iDRAC password (sensitive)

## Terraform State

- State is stored locally by default
- For production, configure remote state (S3, GCS, etc.)
- Never commit `.tfstate` files to version control
