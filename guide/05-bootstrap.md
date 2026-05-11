# Step 5: Bootstrap and Installation

## 5.1 Bootstrap Process Overview

```
┌──────────────────────────────────────────────────────────────┐
│                      Bootstrap Process                       │
│                                                              │
│  1. Bootstrap node starts                                    │
│  2. Bootstrap runs control plane (API + etcd + kube-apiserver)│
│  3. Bootstrap provisions master nodes                        │
│  4. Master nodes join the cluster                            │
│  5. Control plane transitions to masters                     │
│  6. Bootstrap completes and can be decommissioned            │
│  7. Worker nodes join (if configured)                        │
└──────────────────────────────────────────────────────────────┘

Timeline: ~30-45 minutes total
  - Bootstrap: 10-15 minutes
  - Cluster operators: 15-20 minutes
  - Worker join: 5-10 minutes
```

## 5.2 Wait for Bootstrap Completion

```bash
cd ~/openshift-baremetal/install

# Monitor bootstrap progress
./openshift-install --dir=. wait-for bootstrap-complete --log-level=info
```

### Monitoring During Bootstrap

Open another terminal to watch cluster events:

```bash
export KUBECONFIG=~/openshift-baremetal/install/auth/kubeconfig

# Watch cluster operators
watch -n5 oc get clusteroperators

# Watch nodes
watch -n5 oc get nodes

# Watch pod creation in openshift namespaces
watch -n5 oc get pods -A --no-headers | wc -l
```

### Expected Events

```
INFO Consuming Install Config from target directory
INFO Waiting up to 30m0s for the Bootstrap to complete...
INFO Timeout of 0m15s is now reached
INFO Waiting up to 30m0s for the cluster to initialize...
INFO Waiting up to 30m0s for bootstrapping the new cluster...
INFO It is now safe to remove the bootstrap resources
```

## 5.3 Bootstrap Troubleshooting

### Bootstrap Fails to Start

```bash
# SSH to bootstrap node
ssh core@10.0.1.11

# Check ignition firstboot
journalctl -u coreos-firstboot.service

# Check API service
journalctl -u kube-apiserver

# Check etcd
journalctl -u etcd
```

### API Server Not Responding

```bash
# Check if API is listening
curl -k https://10.0.1.11:6443/healthz

# Check HAProxy backend
ss -tlnp | grep 6443

# Verify DNS resolution from bootstrap
dig @10.0.0.11 api-int.mycluster.example.com
```

### etcd Not Starting

```bash
# Check etcd logs
journalctl -u etcd --since "10 minutes ago"

# Verify etcd ports
ss -tlnp | grep 2379
ss -tlnp | grep 2380
```

## 5.4 After Bootstrap Completes

### Remove Bootstrap from HAProxy

Edit `/etc/haproxy/haproxy.cfg` and comment out the bootstrap server:

```cfg
backend openshift-api-backend
    mode tcp
    balance roundrobin
    option tcp-check
    # server bootstrap ${var.bootstrap_ip}:6443 check fall 3 rise 2
    server master0 ${var.master_ips[0]}:6443 check fall 3 rise 2
    server master1 ${var.master_ips[1]}:6443 check fall 3 rise 2
    server master2 ${var.master_ips[2]}:6443 check fall 3 rise 2
```

```bash
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
sudo systemctl reload haproxy
```

### Remove Bootstrap from DNS

Remove the `bootstrap` DNS record from your BIND zone file and reload:

```bash
# Remove bootstrap entry from zone file
sed -i '/^bootstrap/d' /var/named/mycluster.example.com.zone
sudo rndc reload
```

## 5.5 Wait for Cluster Completion

```bash
# Wait for full installation to complete
./openshift-install --dir=. wait-for install-complete --log-level=info
```

This monitors all cluster operators. Expected output:

```
INFO Waiting up to 30m0s for the cluster to initialize...
INFO Install complete!
INFO To access the cluster, set the KUBECONFIG environment variable:
    export KUBECONFIG=/home/user/openshift-baremetal/install/auth/kubeconfig
INFO Then log in:
    oc login -u kubeadmin -p <password> https://api.mycluster.example.com:6443
INFO Access the OpenShift Web Console here:
    https://console-openshift-console.apps.mycluster.example.com
```

## 5.6 Get kubeadmin Credentials

```bash
# kubeconfig
export KUBECONFIG=~/openshift-baremetal/install/auth/kubeconfig

# kubeadmin password
cat ~/openshift-baremetal/install/auth/kubeadmin-password
# Save this password — you'll need it for initial login

# Login
oc login -u kubeadmin -p <password> https://api.mycluster.example.com:6443
```

> **Next:** [Step 6: CSR Approval](06-csr-approval.md)
