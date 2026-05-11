# Step 7: Post-Installation Verification

## 7.1 Cluster Operator Status

```bash
export KUBECONFIG=~/openshift-baremetal/install/auth/kubeconfig

# All operators should show AVAILABLE=True, PROGRESSING=False, DEGRADED=False
watch -n5 oc get clusteroperators
```

Expected output:
```
NAME                                      VERSION   AVAILABLE   PROGRESSING   DEGRADED   SINCE
authentication                            4.21.0    True        False         False      30m
cloud-credential                          4.21.0    True        False         False      30m
cluster-version                           4.21.0    True        False         False      30m
dns                                       4.21.0    True        False         False      30m
image registry                            4.21.0    True        False         False      30m
ingress                                   4.21.0    True        False         False      30m
kube-apiserver                            4.21.0    True        False         False      30m
kube-controller-manager                   4.21.0    True        False         False      30m
kube-scheduler                            4.21.0    True        False         False      30m
kube-storage-version-migrator             4.21.0    True        False         False      30m
machine-approval                          4.21.0    True        False         False      30m
machine-config                            4.21.0    True        False         False      30m
network                                   4.21.0    True        False         False      30m
node-tuning                               4.21.0    True        False         False      30m
openshift-apiserver                       4.21.0    True        False         False      30m
openshift-controller-manager              4.21.0    True        False         False      30m
openshift-samples                         4.21.0    True        False         False      30m
operator-lifecycle-manager                4.21.0    True        False         False      30m
operator-lifecycle-manager-catalog        4.21.0    True        False         False      30m
service-ca                                4.21.0    True        False         False      30m
```

## 7.2 Node Status

```bash
oc get nodes -o wide

# Expected:
# NAME       STATUS   ROLES           AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE
# master-0   Ready    master,worker   30m   v1.31.x   10.0.1.12      <none>        Red Hat Enterprise Linux CoreOS 42100.x
# master-1   Ready    master,worker   30m   v1.31.x   10.0.1.13      <none>        Red Hat Enterprise Linux CoreOS 42100.x
# master-2   Ready    master,worker   30m   v1.31.x   10.0.1.14      <none>        Red Hat Enterprise Linux CoreOS 42100.x
# worker-0   Ready    worker          20m   v1.31.x   10.0.1.21      <none>        Red Hat Enterprise Linux CoreOS 42100.x
# worker-1   Ready    worker          20m   v1.31.x   10.0.1.22      <none>        Red Hat Enterprise Linux CoreOS 42100.x
```

## 7.3 Pod Status

```bash
# Check all pods in openshift namespaces
oc get pods -n openshift-apiserver
oc get pods -n openshift-authentication
oc get pods -n openshift-console
oc get pods -n openshift-ingress
oc get pods -n openshift-image-registry
oc get pods -n openshift-monitoring
oc get pods -n openshift-network-manager
oc get pods -n openshift-dns
oc get pods -n openshift-operator-lifecycle-manager
oc get pods -n openshift-storage

# All pods should be Running or Completed (not CrashLoopBackOff or Pending)
oc get pods -A --no-headers | awk '{print $3}' | sort | uniq -c
```

## 7.4 DNS Verification

```bash
# Verify cluster DNS resolution
oc debug node/master-0 -- chroot /host nslookup myservice.mynamespace.svc.cluster.local

# Verify external DNS
dig +noall +answer api.mycluster.example.com @10.0.0.11
dig +noall +answer api-int.mycluster.example.com @10.0.0.11
dig +noall +answer console-openshift-console.apps.mycluster.example.com @10.0.0.11
```

## 7.5 Web Console Access

```bash
# Get console URL
oc whoami --show-console

# Expected:
# https://console-openshift-console.apps.mycluster.example.com

# Login with kubeadmin
oc login -u kubeadmin -p $(cat ~/openshift-baremetal/install/auth/kubeadmin-password)
```

## 7.6 Image Registry Configuration

On bare metal, the image registry defaults to EmptyDir (ephemeral storage). Configure persistent storage:

```bash
# Check current storage
oc get configs.imageregistry.operator.openshift.io cluster -o yaml | grep -A5 storage

# Configure PVC storage (requires persistent volumes)
oc patch configs.imageregistry.operator.openshift.io cluster   --type merge   -p '{"spec":{"storage":{"pvc":{"claim":""}}}}'

# Or configure S3-compatible storage
oc patch configs.imageregistry.operator.openshift.io cluster   --type merge   -p '{"spec":{"storage":{"s3":{"region":"us-east-1","bucket":"my-registry","keyID":"AKIA...","keySecret":"secret"}}}}'
```

## 7.7 Dell R630-Specific Checks

```bash
# Check node conditions (from master node)
oc describe node worker-0 | grep -A10 "Conditions:"

# Verify NTP synchronization
ssh core@10.0.1.21 'chronyc tracking'

# Check disk utilization
ssh core@10.0.1.21 'df -h /var/lib/containers'

# Verify network interfaces
ssh core@10.0.1.21 'nmcli -t -f NAME,DEVICE,STATE con show'
```

## 7.8 Security Hardening

```bash
# Create a regular user (not kubeadmin)
oc adm create-user --display-name="Admin User" --password=somepassword --username=admin-user

# Assign cluster-admin role
oc adm policy add-cluster-role-to-user cluster-admin admin-user

# Disable kubeadmin (optional — after creating alternative admin)
oc adm policy remove-cluster-role-from-user cluster-admin kubeadmin

# Enable security context constraints audit
oc adm policy add-scc-to-user anyuid -z default -n openshift
```

## 7.9 Save Installer Files

**⚠️ CRITICAL:** Keep all installer files — they are required to delete the cluster:

```bash
# Back up the install directory
tar czf ~/openshift-install-backup.tar.gz -C ~/openshift-baremetal install/

# Verify
ls -lh ~/openshift-install-backup.tar.gz
```

## 7.10 Decommission Bootstrap Node

After confirming all cluster operators are healthy:

```bash
# Power off the bootstrap node
ipmitool -H <iDRAC_bootstrap> -U root -P <password> chassis power off

# Unmount virtual media
ipmitool -H <iDRAC_bootstrap> -U root -P <password>   raw 0x3a 0x01 0x04 0x01 0x00

# Reset boot order
ipmitool -H <iDRAC_bootstrap> -U root -P <password>   chassis bootdev disk
```

## 7.11 Final Checklist

- [ ] All cluster operators are AVAILABLE=True, PROGRESSING=False, DEGRADED=False
- [ ] All nodes show STATUS=Ready
- [ ] All pods in openshift namespaces are Running/Completed
- [ ] DNS resolution works for API and app routes
- [ ] Web console is accessible
- [ ] Image registry has persistent storage configured
- [ ] CSR approval script is running via cron
- [ ] Bootstrap node is decommissioned
- [ ] Installer files are backed up
- [ ] Regular admin user is created (kubeadmin password saved securely)

> **Congratulations! Your OpenShift 4.21 cluster on Dell R630 bare metal is fully operational.**
