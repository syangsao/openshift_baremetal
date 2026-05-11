# Step 4: RHCOS Installation via boot.iso on Dell R630

This step installs Red Hat CoreOS (RHCOS) on each Dell R630 node using the boot.iso method with iDRAC virtual media.

## 4.1 Overview

```
┌────────────────────────────────────────────────────────────────────────┐
│          ┌──────────────────┐      ┌────────────────────┐              │
│          │   Provisioner    │      │     Dell R630      │              │
│          │                  │      │                    │              │
│          │  HTTP Server     │      │      iDRAC         │              │
│          │                  │      │                    │              │
│          │  :8080/*.ign ──┐ │      │ (Virtual Media)  │ │              │
│          │  :8081/*.iso ──┤ │      │                  │ │              │
└─────────────────────────────────────────────────────────┬──────────────┘
                                                          │
                                    ┌────────────────────┐
                                    │    R630 Server     │
                                    │                    │
                                    │     Boot ISO       │
                                    │    Configure       │
                                    │    Network         │
                                    │    Install         │
                                    │    RHCOS            │
                                    └────────────────────┘
```

## 4.2 Prepare Dell iDRAC

### Access iDRAC Web Interface

1. Open browser to `https://<iDRAC_IP>`
2. Log in with iDRAC credentials
3. Navigate to **Virtual Console** → **Launch Console**

### Mount ISO via Virtual Media

1. Go to **Virtual Media** → **CD/DVD** → **Mount Image**
2. Choose **HTTP URL** method
3. Enter: `http://<provisioner_ip>:8081/rhcos-live.x86_64.iso`
4. Click **Mount**

### Alternative: Mount via ipmitool

```bash
# From the provisioner
ipmitool -H <iDRAC_IP> -U root -P <password>   channel setcap 1 user 4

ipmitool -H <iDRAC_IP> -U root -P <password>   ispset name "VirtualMedia.CDROM.ImageName"   value "http://<provisioner_ip>:8081/rhcos-live.x86_64.iso"

ipmitool -H <iDRAC_IP> -U root -P <password>   raw 0x3a 0x01 0x04 0x02 0x00
```

### Set Boot Order

1. iDRAC → **Server** → **Boot Sequence**
2. Set **Virtual Media CD/DVD** as first boot device
3. Or use IPMI:
```bash
ipmitool -H <iDRAC_IP> -U root -P <password>   chassis bootdev cdrom
ipmitool -H <iDRAC_IP> -U root -P <password>   chassis power cycle
```

## 4.3 Boot and Configure Each Node

Repeat this process for **each node** (bootstrap, masters, workers).

### Access the Console

1. Open iDRAC Virtual Console (HTML5 KVM)
2. Wait for the RHCOS live system to boot
3. You'll see a `core@localhost ~ $` prompt

### Configure Network

The installer needs a working network to fetch the Ignition config.

**Option A: Static IP (Recommended for Bare Metal)**

```bash
# Create a NetworkManager connection for the primary interface
nmcli con add type ethernet ifname eno1 con-name system-connection ipv4.method manual   ipv4.addresses 10.0.1.11/24   ipv4.gateway 10.0.1.1   ipv4.dns 10.0.0.11

nmcli con up system-connection

# Verify
ip addr show eno1
ip route show
ping -c 3 10.0.0.10
```

**Option B: DHCP**

```bash
nmcli con modify system-connection ipv4.method auto
nmcli con up system-connection
ip addr show eno1
```

### Install RHCOS with coreos-installer

```bash
# Identify the installation disk
lsblk
# Look for the physical disk (e.g., /dev/sda or /dev/nvme0n1)
# Dell R630 with PERC: /dev/sda (RAID virtual disk)

# Install RHCOS with Ignition config
coreos-installer install   --copy-network   --ignition-url=http://<provisioner_ip>:8080/<node_type>.ign   /dev/sda

# Where <node_type> is:
#   bootstrap.ign  — for the bootstrap node
#   master.ign     — for master nodes (0, 1, 2)
#   worker.ign     — for worker nodes (0, 1, ...)
```

**Example for Bootstrap Node:**
```bash
coreos-installer install   --copy-network   --ignition-url=http://10.0.0.10:8080/bootstrap.ign   /dev/sda
```

**Example for Master0:**
```bash
coreos-installer install   --copy-network   --ignition-url=http://10.0.0.10:8080/master.ign   /dev/sda
```

### Installation Flags Explained

| Flag | Purpose |
|------|---------|
| `--copy-network` | Copies NetworkManager config from live system to installed system |
| `--ignition-url` | URL to the Ignition config (pulled during first boot) |
| `/dev/sda` | Target disk for installation |

### Verify Installation

```bash
# After coreos-installer completes, unmount and reboot
ipmitool -H <iDRAC_IP> -U root -P <password>   chassis power reset
```

## 4.4 Dell R630-Specific BIOS Settings

Access the BIOS (F2 during POST) and verify:

| Setting | Value | Reason |
|---------|-------|--------|
| **Processor C-States** | Enabled | Power management |
| **Turbo Mode** | Enabled | Performance |
| **Hyper-Threading** | Enabled | Match OpenShift hyperthreading config |
| **Boot Mode** | UEFI (recommended) or BIOS | Consistent across all nodes |
| **Secure Boot** | Disabled | Required for RHCOS |
| **Serial Port** | Disabled | Not needed |
| **iDRAC Lifecycle Controller** | Enabled | For remote management |

### PERC RAID Configuration

Access PERC configuration (Ctrl+R during POST) or via Lifecycle Controller:

1. Create RAID-1 (mirrored) for the OS drive (2× 1TB SAS)
2. Create RAID-1 for container/pod storage (2× 480GB SSD)
3. Verify virtual disks are **Online**
4. Set cache policy to **Write Back** with battery backup

```bash
# Verify after RHCOS boots
lsblk
# Expected:
# sda  (RAID-1, 1TB)  — OS
# sdb  (RAID-1, 480GB) — containers
```

## 4.5 Verify All Nodes Boot

After installing RHCOS on all nodes:

```bash
# From the provisioner, SSH to each node
for ip in 10.0.1.11 10.0.1.12 10.0.1.13 10.0.1.14 10.0.1.21 10.0.1.22; do
  echo "=== Checking $ip ==="
  ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no core@$ip     'hostname && ip addr show eno1 | grep inet && systemctl status coreos-installer-firstboot-complete'
done
```

Each node should show:
- RHCOS hostname (`bootstrap`, `master-0`, `worker-0`, etc.)
- Correct IP address
- Ignition firstboot completed

> **Next:** [Step 5: Bootstrap and Installation](05-bootstrap.md)
