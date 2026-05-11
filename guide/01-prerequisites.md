# Step 1: Prerequisites

## 1.1 Hardware Requirements

### Minimum Node Count

| Node Type | Count | Purpose |
|-----------|-------|---------|
| Bootstrap | 1 | Runs the control plane temporarily during installation |
| Control Plane (Master) | 3 | High-availability cluster management |
| Compute (Worker) | 2+ (optional) | Application workloads |

> **Note:** For a 3-node cluster, set `compute.replicas: 0` and run workloads on master nodes.

### Dell R630 Specifications

| Component | Bootstrap | Master | Worker |
|-----------|-----------|--------|--------|
| CPU | 4 vCPUs min | 4 vCPUs min | 2 vCPUs min |
| RAM | 16 GB min | 16 GB min | 8 GB min |
| Storage | 100 GB min | 100 GB min | 100 GB min |
| IOPS | 300 min | 300 min | 300 min |
| Arch | x86_64 (v2 ISA+) | x86_64 (v2 ISA+) | x86_64 (v2 ISA+) |

**Recommended Dell R630 Config:**
- Processor: Intel Xeon E5-2667 v4 (8-core, 3.3 GHz) — supports AVX2 (x86-64-v2 ISA)
- RAM: 16× 16GB DDR4 ECC RDIMM = 256 GB total
- Storage: 2× 1TB SAS 10K in RAID-1 (OS) + 2× 480GB SSD (pods/containers)
- NIC: PERC H730 mini RAID controller + iDRAC Enterprise for remote management
- Network: 4× 1GbE (embedded LOM) or 2× 10GbE (add-on card)

## 1.2 Software Requirements

### Installer Host

A Linux or macOS machine where you run the OpenShift installer:

- **OS:** RHEL 8.6+, Ubuntu 20.04+, or macOS 10.15+
- **Disk:** 500 MB minimum for installer files
- **Tools:** `jq`, `curl`, `ssh`, `coreos-installer`, `terraform`

```bash
# Install core dependencies on RHEL
sudo dnf install -y jq curl sshpass terraform

# Install OpenShift CLI (oc)
curl -L https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-clis-linux.tar.gz | tar xz
sudo mv oc kubectl /usr/local/bin/

# Install coreos-installer
curl -L https://github.com/coreos/coreos-installer/releases/download/v0.7.0/coreos-installer-0.7.0-linux.amd64.tar.gz | tar xz
sudo mv coreos-installer /usr/local/bin/
```

### Download OpenShift Installer

1. Log in to [Red Hat OpenShift Cluster Manager](https://cloud.redhat.com/openshift)
2. Navigate to **Create cluster** → **Cluster Type** page
3. Download `openshift-install-linux.tar.gz`
4. Extract on the installer host:

```bash
mkdir -p ~/openshift-installer
cd ~/openshift-installer
tar xzf /path/to/openshift-install-linux.tar.gz
ls -la
# openshift-install  kubectl  oc
```

### SSH Key Pair

Generate an Ed25519 key pair (or RSA/ECDSA for FIPS mode):

```bash
ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
# Copy the public key — you'll need it for install-config.yaml
```

### Pull Secret

Download your pull secret from Red Hat Cluster Manager:
1. Go to [Access token](https://cloud.redhat.com/openshift/install/multi-user/pull-secret)
2. Copy the JSON content
3. Save to `~/pull-secret.txt`

```bash
cat > ~/pull-secret.txt << 'EOF'
{"auths": {"registry.connect.redhat.com": {"auth": "..."}, ...}}
EOF
```

## 1.3 Network Requirements

### Network Architecture

```
                          ┌─────────────────────┐
                          │  External Network   │
                          │     10.0.0.0/24     │
                          └──────────┬──────────┘
                                     │


       ┌────────┴────────┐  ┌────────┴────────┐  ┌────────┴────────┐
       │   Provisioner   │  │       DNS       │  │  Load Balancer  │
       │    10.0.0.10    │  │    10.0.0.11    │  │    10.0.0.12    │
       │   (Installer)   │  │     (BIND)      │  │    (HAProxy)    │
       └─────────────────┘  └─────────────────┘  └─────────────────┘


┌────────────────────────────────────────────────────────────────────────┐
│                     Cluster Network  (10.0.1.0/24)                     │
│                                                                        │
│         ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐         │
│         │ Bootstrap│  │ Master0  │  │ Master1  │  │ Master2  │         │
│         │10.0.1.11 │  │10.0.1.12 │  │10.0.1.13 │  │10.0.1.14 │         │
│         └──────────┘  └──────────┘  └──────────┘  └──────────┘         │
│                                                                        │
│                       ┌──────────┐  ┌──────────┐                       │
│                       │ Worker0  │  │ Worker1  │                       │
│                       │10.0.1.21 │  │10.0.1.22 │                       │
│                       └──────────┘  └──────────┘                       │
└────────────────────────────────────────────────────────────────────────┘
```

### Required Ports

| Protocol | Port(s) | Purpose | All Machines |
|----------|---------|---------|:------------:|
| TCP | 22 | SSH | ✓ |
| TCP | 1936 | Metrics | ✓ |
| TCP | 2379-2380 | etcd | Control plane only |
| TCP | 6443 | API server | Control plane only |
| TCP | 8443 | Router | Compute only |
| TCP | 9000-9999 | Host services | ✓ |
| TCP | 10250-10259 | Kubernetes | ✓ |
| TCP | 22623 | Machine config server | ✓ |
| TCP | 30000-32767 | Node ports | ✓ |
| UDP | 123 | NTP | ✓ |
| UDP | 500, 4500 | IPsec | ✓ |
| UDP | 6081 | Geneve (OVN) | ✓ |
| UDP | 9000-9999 | Host services | ✓ |
| ICMP | — | Network reachability | ✓ |

### DNS Requirements

Required DNS records (replace `<cluster>` and `<base_domain>` with your values):

| Component | Record Type | Name | Points To |
|-----------|-------------|------|-----------|
| API (external) | A + AAAA + PTR | `api.<cluster>.<base_domain>` | LB VIP |
| API (internal) | A + AAAA + PTR | `api-int.<cluster>.<base_domain>` | LB VIP |
| Routes | A + AAAA (no PTR) | `*.apps.<cluster>.<base_domain>` | LB VIP |
| Bootstrap | A + AAAA + PTR | `bootstrap.<cluster>.<base_domain>` | Bootstrap IP |
| Master 0-2 | A + AAAA + PTR | `master<0-2>.<cluster>.<base_domain>` | Master IPs |
| Worker 0-N | A + AAAA + PTR | `worker<0-N>.<cluster>.<base_domain>` | Worker IPs |

**Example:**
```
api.mycluster.example.com     → 10.0.0.12
api-int.mycluster.example.com → 10.0.0.12
*.apps.mycluster.example.com  → 10.0.0.12
bootstrap.mycluster.example.com → 10.0.1.11
master0.mycluster.example.com  → 10.0.1.12
master1.mycluster.example.com  → 10.0.1.13
master2.mycluster.example.com  → 10.0.1.14
worker0.mycluster.example.com  → 10.0.1.21
worker1.mycluster.example.com  → 10.0.1.22
```

## 1.4 Dell iDRAC Configuration

For remote management and IPMI/KVM access:

1. Access iDRAC web interface at `https://<iDRAC_IP>`
2. Default credentials: `root` / `calvin` (change immediately)
3. Configure static IP for iDRAC network
4. Enable **Virtual Console** (HTML5 recommended)
5. Enable **Virtual Media** for ISO mounting
6. Set boot mode to **BIOS Legacy** or **UEFI** (consistent across all nodes)

```bash
# Test iDRAC connectivity
ipmitool -H <iDRAC_IP> -U root -P <password> chassis power status

# Check virtual media capability
ipmitool -H <iDRAC_IP> -U root -P <password> chassis bootdev list
```

## 1.5 Verify Readiness

```bash
# Check installer version
./openshift-install version

# Verify SSH key
ssh-keygen -l -f ~/.ssh/id_ed25519.pub

# Verify DNS resolution (example)
dig +noall +answer @10.0.0.11 api.mycluster.example.com

# Verify NTP sync
chronyc tracking

# Verify network connectivity
ping -c 3 10.0.0.12  # Load balancer
ping -c 3 registry.redhat.io

# Verify disk space
df -h ~/openshift-installer
```

> **Next:** [Step 2: Infrastructure Provisioning with Terraform](02-terraform.md)
