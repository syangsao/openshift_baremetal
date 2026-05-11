# Step 8: Three-Node Cluster Configuration

## 8.1 Overview

A three-node cluster is a smaller, resource-efficient deployment that uses **only three control plane (master) machines** with **zero compute (worker) machines**. This configuration is ideal for:

- **Testing and development environments**
- **Small production workloads** where dedicated compute nodes are unnecessary
- **Resource-constrained environments** to optimize hardware utilization

In a three-node OpenShift cluster, the control plane machines are **schedulable**, meaning application workloads are scheduled to run directly on them.

## 8.2 Architecture

```
┌────────────────────────────────────────────────────────────────┐
│              Three-Node Cluster (UPI)                          │
│                                                                │
│         ┌────────────┐  ┌────────────┐  ┌────────────┐         │
│         │  Master 0  │  │  Master 1  │  │  Master 2  │         │
│         │            │  │            │  │            │         │
│         │ Control    │  │ Control    │  │ Control    │         │
│         │ Plane      │  │ Plane      │  │ Plane      │         │
│         │ + Compute  │  │ + Compute  │  │ + Compute  │         │
│         └────────────┘  └────────────┘  └────────────┘         │
│                                                                │
│   • Application workloads run on control plane nodes           │
│   • Ingress Controller pods run on control plane nodes         │
│   • All nodes are both control plane AND compute               │
└───────────────────────────────┬────────────────────────────────┘
                                 │
┌────────────────────────────────────────────────────────────────┐
│                     HAProxy Load Balancer                      │
│                                                                │
│ :6443 → masters:6443                                           │
│ :22623 → nodes:22623                                           │
│ :443 → masters:443 (Ingress traffic)                           │
└────────────────────────────────────────────────────────────────┘
```

## 8.3 Prerequisites

- You have completed Steps 1–7 in the standard UPI installation guide
- You have an existing `install-config.yaml` file
- You have three Dell R630 servers configured for master nodes

## 8.4 Installation Configuration

### 8.4.1 Modify install-config.yaml

Set `compute.replicas: 0` in your `install-config.yaml` file:

```yaml
apiVersion: v1
baseDomain: example.com
compute:
- name: worker
  platform: {}
  replicas: 0
controlPlane:
  name: master
  replicas: 3
metadata:
  name: mycluster
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  networkType: OVNKubernetes
  serviceNetwork:
  - 172.30.0.0/16
platform:
  baremetal: {}
pullSecret: '{"auths": {...}}'
sshKey: 'ssh-ed25519 AAAA... user@host'
```

> **Note:** You must set `replicas: 0` for compute machines in **all** user-provisioned infrastructure installations, regardless of whether you deploy compute machines or not. In installer-provisioned installations, this parameter controls the number of compute machines the cluster creates. In user-provisioned installations, compute machines are deployed manually.

### 8.4.2 Updated Terraform Variables

For a three-node cluster, update `terraform/terraform.tfvars`:

```hcl
cluster_name  = "mycluster"
base_domain   = "example.com"

# Only bootstrap + 3 masters, no workers
bootstrap_ip = "10.0.1.11"
master_ips   = ["10.0.1.12", "10.0.1.13", "10.0.1.14"]
worker_ips   = []  # Empty — no worker nodes

# iDRAC addresses (no worker iDRACs)
iDRAC_bootstrap = "10.0.0.50"
iDRAC_masters   = ["10.0.0.51", "10.0.0.52", "10.0.0.53"]
iDRAC_workers   = []  # Empty — no worker iDRACs
```

### 8.4.3 DNS Records

For a three-node cluster, only create DNS records for the bootstrap and master nodes:

```
api.mycluster.example.com       → 10.0.0.12 (LB VIP)
api-int.mycluster.example.com   → 10.0.0.12 (LB VIP)
*.apps.mycluster.example.com    → 10.0.0.12 (LB VIP)
bootstrap.mycluster.example.com → 10.0.1.11
master0.mycluster.example.com   → 10.0.1.12
master1.mycluster.example.com   → 10.0.1.13
master2.mycluster.example.com   → 10.0.1.14
```

> **No worker DNS records are needed.**

## 8.5 HAProxy Configuration

For a three-node cluster, the HAProxy configuration must route **ingress traffic (port 443)** to the master nodes instead of workers:

```cfg
# Standard API and bootstrap backends
frontend openshift-api
    bind *:6443
    mode tcp
    option tcp-check
    default_backend openshift-api-backend

backend openshift-api-backend
    mode tcp
    balance roundrobin
    option tcp-check
    server master0 10.0.1.12:6443 check fall 3 rise 2
    server master1 10.0.1.13:6443 check fall 3 rise 2
    server master2 10.0.1.14:6443 check fall 3 rise 2

frontend openshift-bootstrap
    bind *:22623
    mode tcp
    option tcp-check
    default_backend openshift-bootstrap-backend

backend openshift-bootstrap-backend
    mode tcp
    balance roundrobin
    option tcp-check
    server bootstrap 10.0.1.11:22623 check fall 3 rise 2
    server master0 10.0.1.12:22623 check fall 3 rise 2
    server master1 10.0.1.13:22623 check fall 3 rise 2
    server master2 10.0.1.14:22623 check fall 3 rise 2

# Ingress router — routes to MASTER nodes (not workers)
frontend openshift-router
    bind *:443
    mode tcp
    option tcp-check
    default_backend openshift-router-backend

backend openshift-router-backend
    mode tcp
    balance roundrobin
    option tcp-check
    server master0 10.0.1.12:443 check fall 3 rise 2
    server master1 10.0.1.13:443 check fall 3 rise 2
    server master2 10.0.1.14:443 check fall 3 rise 2
```

> **Key Difference:** In a standard installation, the ingress router backend points to worker nodes. In a three-node cluster, it points to **master nodes**.

## 8.6 Generating Manifests

### 8.6.1 Create Manifests

```bash
cd ~/openshift-installer
./openshift-install create manifests --dir=~/openshift-baremetal/install
```

### 8.6.2 Enable Masters Schedulable

For a three-node cluster, you **must NOT** set `mastersSchedulable` to `false`. Ensure it is set to `true`:

```bash
# Open the cluster scheduler config
nano ~/openshift-baremetal/install/manifests/cluster-scheduler-02-config.yml
```

Verify the content:

```yaml
apiVersion: config.openshift.io/v1
kind: ClusterScheduler
metadata:
  name: cluster
  annotations:
    include.release.controller: "true"
  namespace: ""
mastersSchedulable: true   # MUST be true for 3-node cluster
```

> **Warning:** If you are installing a standard cluster with worker nodes, skip this step and ensure `mastersSchedulable` is set to `false`. For three-node clusters, control plane nodes must be schedulable to run application workloads.

### 8.6.3 Generate Ignition Configs

```bash
./openshift-install create ignition-configs --dir=~/openshift-baremetal/install
```

## 8.7 Deploying Nodes

### 8.7.1 Nodes to Install

For a three-node cluster, only deploy:

| Node Type | Count | Purpose |
|-----------|-------|---------|
| Bootstrap | 1 | Runs control plane temporarily during installation |
| Master | 3 | Control plane + compute (application workloads) |

> **Do not deploy any compute (worker) nodes.**

### 8.7.2 Follow Steps 4–6

Follow the standard installation procedure from the main guide:
- **Step 4:** Install RHCOS on the bootstrap and three master nodes
- **Step 5:** Wait for bootstrap to complete
- **Step 6:** Approve CSRs for the three master nodes

## 8.8 Verifying the Three-Node Cluster

### 8.8.1 Check Node Status

```bash
export KUBECONFIG=~/openshift-baremetal/install/auth/kubeconfig
oc login -u kubeadmin -p $(cat ~/openshift-baremetal/install/auth/kubeadmin-password)

# Verify only 3 nodes exist (no workers)
oc get nodes
```

Expected output:
```
NAME          STATUS   ROLES                         AGE   VERSION
master-0      Ready    control-plane,master,schedulable   30m   v4.21.x
master-1      Ready    control-plane,master,schedulable   30m   v4.21.x
master-2      Ready    control-plane,master,schedulable   30m   v4.21.x
```

### 8.8.2 Verify Masters Are Schedulable

```bash
# Check the scheduler config
oc get clusterscheduler cluster -o yaml | grep mastersSchedulable

# Verify no taints preventing scheduling
oc describe node master-0 | grep -A 5 Taints
```

For a three-node cluster, the `master-0` node should have **no taints** (or at minimum, no `node-role.kubernetes.io/master:NoSchedule` taint).

### 8.8.3 Test Workload Scheduling

```bash
# Deploy a simple test pod
oc run test-pod --image=registry.redhat.io/ubi8/ubi-minimal --command -- sleep infinity

# Verify it's scheduled on a master node
oc get pods -o wide | grep test-pod

# Clean up
oc delete pod test-pod
```

The pod should be scheduled on one of the master nodes.

## 8.9 Known Considerations

### 8.9.1 Additional Subscriptions

When control plane nodes are schedulable, additional subscriptions are required because they become compute nodes. Ensure your OpenShift subscription covers this.

### 8.9.2 Resource Planning

Since all application workloads run on control plane nodes:

| Resource | Minimum per Master Node |
|----------|------------------------|
| CPU | 8 vCPUs min (vs. 4 vCPUs in standard deployment) |
| RAM | 32 GB min (vs. 16 GB in standard deployment) |
| Storage | 100 GB min |

### 8.9.3 Scaling Limitations

A three-node cluster **cannot** be scaled by adding worker nodes after installation. To add compute capacity:

1. Plan for additional master nodes (must maintain odd number)
2. Or perform a fresh installation with worker nodes included

### 8.9.4 High Availability

With only three master nodes:
- **Control plane:** HA maintained (3-node etcd quorum)
- **Application workloads:** HA depends on pod disruption budgets and anti-affinity rules
- **Rolling updates:** Each master update reduces cluster capacity by ~33%

## 8.10 Post-Installation

After installation, follow Steps 7 (Verification) from the main guide. The only difference is that you only verify three nodes instead of five or more.

```bash
# Verify cluster operators
oc get clusteroperators

# Verify no pending CSRs
oc get csr

# Verify ingress is working
oc get pods -n openshift-ingress

# Verify router pods are on master nodes
oc get pods -n openshift-ingress -o wide
```

> **Next steps:** Configure your storage, networking, and application workloads as needed for your environment.
