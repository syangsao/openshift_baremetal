# OpenShift Bare Metal — Dell R630 UPI Installation Guide

Step-by-step instructions for installing **OpenShift Container Platform 4.21** on bare-metal Dell R630 servers using the **User-Provisioned Infrastructure (UPI)** method with **Terraform** for infrastructure provisioning.

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                       Dell R630 Servers                        │
│                                                                │
│         ┌────────────┐  ┌────────────┐  ┌────────────┐         │
│         │ Bootstrap  │  │ Master 0-2 │  │ Worker 0-N │         │
│         │  (RHCOS)   │  │  (RHCOS)   │  │  (RHCOS)   │         │
│         └────────────┘  └────────────┘  └────────────┘         │
└───────────────────────────────┬────────────────────────────────┘
                                 │
┌────────────────────────────────────────────────────────────────┐
│                     HAProxy Load Balancer                      │
│                                                                │
│ :6443 → masters:6443                                           │
│ :22623 → nodes:22623                                           │
└────────────────────────────────────────────────────────────────┘
```

## Quick Start

1. **[Prerequisites](guide/01-prerequisites.md)** — Hardware, software, and network requirements
2. **[Infrastructure Provisioning](guide/02-terraform.md)** — Terraform for networking, DNS, and load balancer
3. **[OpenShift Configuration](guide/03-install-config.md)** — Generate manifests and Ignition configs
4. **[RHCOS Installation](guide/04-boot-iso.md)** — Mount boot.iso and install RHCOS on Dell R630 nodes
5. **[Bootstrap & Installation](guide/05-bootstrap.md)** — Wait for bootstrap completion
6. **[CSR Approval](guide/06-csr-approval.md)** — Approve node certificates
7. **[Verification](guide/07-verification.md)** — Post-installation checks
8. **[Three-Node Cluster](guide/08-three-node-cluster.md)** — Configure a 3-node cluster (no workers)

## Minimum Hardware Requirements

| Role | CPUs | RAM | Storage | Dell R630 Config |
|------|------|-----|---------|------------------|
| Bootstrap | 4 | 16 GB | 100 GB | 1× E5-2667 v4, 1× 16GB DIMM, 1× 1TB SAS |
| Master | 4 | 16 GB | 100 GB | 1× E5-2667 v4, 1× 16GB DIMM, 1× 1TB SAS |
| Worker | 2 | 8 GB | 100 GB | 1× E5-2667 v4, 1× 8GB DIMM, 1× 480GB SSD |

## Terraform Structure

```
terraform/
├── main.tf              # Modules and providers
├── variables.tf         # Input variables
├── outputs.tf           # Outputs
├── terraform.tfvars     # Sample variable values
├── Makefile             # Common operations
├── haproxy/
│   ├── main.tf
│   └── haproxy.cfg.tpl  # Load balancer template
├── dns/
│   ├── main.tf
│   └── forward.zone.tpl # DNS zone template
├── idrac/
│   └── main.tf          # iDRAC virtual media
└── network/
    └── main.tf          # Network config
```

## License

MIT License — see [LICENSE](LICENSE) for details.

## References

- [Red Hat OpenShift 4.21 UPI Documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html/installing_on_bare_metal/user-provisioned-infrastructure)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [CoreOS Installer Documentation](https://coreos.github.io/coreos-installer/)
