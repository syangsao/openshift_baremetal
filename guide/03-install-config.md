# Step 3: OpenShift Installation Configuration

## 3.1 Create Installation Directory

```bash
INSTALL_DIR=~/openshift-baremetal/install
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Copy the installer
cp ~/openshift-installer/openshift-install .
```

## 3.2 Create install-config.yaml

```bash
# Generate a template (interactive mode)
./openshift-install create install-config --dir=$INSTALL_DIR
```

Or create manually:

```yaml
apiVersion: v1
baseDomain: example.com
compute:
- hyperthreading: Enabled
  name: worker
  replicas: 0    # MUST be 0 for UPI — you provision workers manually
controlPlane:
  hyperthreading: Enabled
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
  none: {}        # UPI uses no platform-specific configuration
pullSecret: '{"auths": {...}}'
sshKey: 'ssh-ed25519 AAAA... user@host'
```

### Critical UPI Settings

| Setting | Value | Reason |
|---------|-------|--------|
| `compute.replicas` | `0` | UPI — you provision compute nodes manually |
| `platform` | `none: {}` | UPI — no cloud provider |
| `networkType` | `OVNKubernetes` | Default for 4.21 |
| `hyperthreading` | `Enabled` or `Disabled` | Match your Dell R630 CPU config |

### Optional: Additional Compute

To add worker nodes, set `compute.replicas` to the desired count but keep it at `0` for pure UPI — the installer does NOT provision compute nodes in UPI mode.

## 3.3 Customize Manifests (Optional)

After generating manifests, you can customize them:

```bash
./openshift-install create manifests --dir=$INSTALL_DIR
```

The `manifests/` directory contains:
- `99_openshift-cluster-api_cluster-version.yaml`
- `99_cloud-creds-secret.yaml`
- `cluster-scheduler-02-config.yaml`
- Various MachineConfig objects

### Common Customizations

**Disable cluster autoscaler (bare metal):**
```yaml
# Edit manifests/cluster-scheduler-02-config.yaml
apiVersion: config.openshift.io/v1
kind: Scheduler
metadata:
  name: cluster
  annotations:
    exclude.release.openshift.io/internal-openshift-hosted: "true"
    exclude.release.openshift.io/openshift-hosted: "true"
```

**Set master-schedulable (for 3-node cluster):**
```yaml
# Add to manifests/
apiVersion: config.openshift.io/v1
kind: Scheduler
metadata:
  name: cluster
spec:
  mastersSchedulable: true
```

## 3.4 Generate Ignition Configs

```bash
# Generate manifests (if not already done)
./openshift-install create manifests --dir=$INSTALL_DIR

# Generate Ignition configs
./openshift-install create ignition-configs --dir=$INSTALL_DIR
```

This creates:
- `bootstrap.ign` — Bootstrap node configuration
- `master.ign` — Control plane node configuration
- `worker.ign` — Worker node configuration
- `auth/kubeconfig` — Kubernetes admin configuration
- `auth/kubeadmin-password` — Initial kubeadmin password
- `metadata.json` — Installation metadata

### ⚠️ CRITICAL: Use Within 12 Hours

Ignition configs contain certificates that expire after **24 hours**. Use them within **12 hours** of generation. If they expire, regenerate with `./openshift-install create ignition-configs`.

```bash
ls -la $INSTALL_DIR/*.ign
ls -la $INSTALL_DIR/auth/
cat $INSTALL_DIR/auth/kubeadmin-password
```

## 3.5 Serve Ignition Configs

Set up a temporary HTTP server to serve Ignition configs during RHCOS installation:

```bash
# On the provisioner/installer host
sudo dnf install -y python3-httpd  # or use nginx

# Serve from the install directory
cd $INSTALL_DIR
python3 -m http.server 8080 --bind 0.0.0.0 &

# Verify
curl http://localhost:8080/bootstrap.ign | head -5
curl http://localhost:8080/master.ign | head -5
curl http://localhost:8080/worker.ign | head -5

# Make accessible from all nodes
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

**Ignition config URLs:**
```
Bootstrap: http://<provisioner_ip>:8080/bootstrap.ign
Master:    http://<provisioner_ip>:8080/master.ign
Worker:    http://<provisioner_ip>:8080/worker.ign
```

## 3.6 Download RHCOS ISO

Download the matching RHCOS ISO for your OpenShift version:

```bash
# Get the RHCOS image info
# Check the installation program manifest
cat $INSTALL_DIR/metadata.json | jq '.image'

# Download RHCOS live ISO from Red Hat
# The exact URL depends on your OpenShift version
curl -L -o rhcos-live.x86_64.iso   "https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/<version>/<arch>/rhcos-<version>-live.x86_64.iso"

# Verify checksum
curl -sL "https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/<version>/<arch>/rhcos-<version>-live.x86_64.iso.SHA256" | sha256sum -c

# Serve the ISO for iDRAC virtual media mounting
python3 -m http.server 8081 --bind 0.0.0.0 &
```

> **Next:** [Step 4: RHCOS Installation via boot.iso on Dell R630](04-boot-iso.md)
