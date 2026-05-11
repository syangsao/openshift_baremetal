# Step 6: CSR (Certificate Signing Request) Approval

In UPI mode, you must manually approve Certificate Signing Requests (CSRs) for your nodes. The Machine Config Operator does not auto-approve CSRs in UPI mode.

## 6.1 Why CSR Approval is Required

In UPI mode, the Machine API controllers are disabled (`platform: none: {}`). Without the Machine API, CSRs for new nodes are not automatically approved.

**You must approve CSRs within 1 hour** or the certificates will expire and generate new CSRs, creating a cascade of certificate issues.

## 6.2 Bootstrap CSRs

After bootstrap completes, approve the bootstrap kubelet and kube-proxy CSRs:

```bash
export KUBECONFIG=~/openshift-baremetal/install/auth/kubeconfig

# List all pending CSRs
oc get csr

# Approve bootstrap CSRs
oc get csr -ojson |   jq -r '.items[] | select(.spec.signer == "kubernetes.io/kube-apiserver-client-kubelet" and (.status.conditions[]?.approved // false) == false) | .metadata.name' |   xargs -r oc adm certificate approve

# Verify
oc get csr
```

## 6.3 Worker Node CSRs

As worker nodes join, approve their CSRs:

```bash
# Approve kubelet CSRs for workers
oc get csr -ojson |   jq -r '.items[] | select(.spec.signer == "kubernetes.io/kube-apiserver-client-kubelet" and (.status.conditions[]?.approved // false) == false) | .metadata.name' |   xargs -r oc adm certificate approve

# Approve serving CSRs (for kubelet serving certificates)
oc get csr -ojson |   jq -r '.items[] | select(.spec.signer == "kubernetes.io/kubelet-serving" and (.status.conditions[]?.approved // false) == false) | .metadata.name' |   xargs -r oc adm certificate approve
```

## 6.4 Automated CSR Approval Script

For recurring certificate rotations (every 24 hours), create a monitoring script:

```bash
#!/bin/bash
# approve-csrs.sh — Run every 5 minutes via cron

KUBECONFIG="${KUBECONFIG:-/home/user/openshift-baremetal/install/auth/kubeconfig}"

# Approve pending CSRs for known signers
oc get csr -ojson |   jq -r '.items[] | select(
    (.status.conditions[]?.approved // false) == false and
    (.spec.signer == "kubernetes.io/kube-apiserver-client-kubelet" or
     .spec.signer == "kubernetes.io/kubelet-serving" or
     .spec.signer == "kubernetes.io/kube-apiserver-client" or
     .spec.signer == "kubernetes.io/legacy-unknown")
  ) | .metadata.name' |   while read -r csr; do
    echo "Approving CSR: $csr"
    oc adm certificate approve "$csr"
  done

echo "CSR approval complete at $(date)"
```

```bash
# Make executable
chmod +x approve-csrs.sh

# Add to cron (every 5 minutes)
echo '*/5 * * * * /home/user/openshift-baremetal/approve-csrs.sh >> /home/user/logs/csr-approve.log 2>&1' | crontab -l - >> /tmp/crontab
crontab /tmp/crontab
```

## 6.5 Verify All Nodes Are Ready

```bash
# Check all nodes are Ready
oc get nodes

# Expected output:
# NAME      STATUS   ROLES           AGE   VERSION
# master-0  Ready    master,worker   30m   v1.31.0+...
# master-1  Ready    master,worker   30m   v1.31.0+...
# master-2  Ready    master,worker   30m   v1.31.0+...
# worker-0  Ready    worker          20m   v1.31.0+...
# worker-1  Ready    worker          20m   v1.31.0+...

# Check all CSRs are approved
oc get csr
# All should show "Approved" in the conditions

# Check pod certificates
oc get pods -n kube-system | grep kube-proxy
oc get pods -n openshift-apiserver | grep apiserver
```

> **Next:** [Step 7: Post-Installation Verification](07-verification.md)
