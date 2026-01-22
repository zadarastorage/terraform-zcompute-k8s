# Architecture

This document explains the internal architecture of the terraform-zcompute-k8s module, including how configuration flows from Terraform variables to a running K3s cluster.

## Overview

The module provisions a K3s Kubernetes cluster on Zadara zCompute (AWS-compatible) infrastructure. It creates:

- EC2 Auto Scaling Groups for control plane and worker nodes
- Internal Network Load Balancer for Kubernetes API access
- Security groups for intra-cluster communication
- Cloud-init configurations for automated node bootstrapping

## Module Layers

The module operates in four conceptual layers:

```
+---------------------------------------------------------------------+
|                        INPUT LAYER                                  |
|  variables.tf: User-provided configuration                          |
|  (cluster_name, node_groups, cluster_helm, etc.)                    |
+---------------------------------------------------------------------+
                                 |
                                 v
+---------------------------------------------------------------------+
|                    CONFIGURATION LAYER                              |
|  locals.tf: Merge defaults with user input                          |
|  locals_helm.tf: Default Helm chart configurations                  |
|  data_cloudinit.tf: Render cloud-init templates                     |
+---------------------------------------------------------------------+
                                 |
                                 v
+---------------------------------------------------------------------+
|                   INFRASTRUCTURE LAYER                              |
|  asg.tf: Auto Scaling Groups with launch configurations             |
|  load_balancer.tf: Internal NLB for Kubernetes API                  |
|  sg.tf: Security groups for cluster networking                      |
+---------------------------------------------------------------------+
                                 |
                                 v
+---------------------------------------------------------------------+
|                   INITIALIZATION LAYER                              |
|  cloud-init/: Cloud-config templates                                |
|  files/: Shell scripts executed on boot                             |
|  files/k3s/: K3s-specific installation and configuration            |
+---------------------------------------------------------------------+
```

### Input Layer

User configuration enters through `variables.tf`:

| Variable | Purpose |
|----------|---------|
| `cluster_name` | Cluster identifier used in resource naming |
| `cluster_version` | K3s/Kubernetes version to install |
| `node_groups` | Map defining control plane and worker ASGs |
| `node_group_defaults` | Default settings applied to all node groups |
| `cluster_helm` | Helm charts to deploy after cluster initialization |
| `etcd_backup` | Optional S3 backup configuration for etcd |

### Configuration Layer

`locals.tf` merges configuration with intelligent defaults:

```hcl
# Simplified view of merge logic
local.node_groups = {
  for k, v in var.node_groups :
  k => merge(
    local.node_group_defaults,  # Module defaults (instance_type, volume_size)
    var.node_group_defaults,    # User defaults
    v                           # Per-group overrides
  )
}
```

This allows users to set defaults once and override per node group.

`locals_helm.tf` defines default Helm charts (Flannel, Calico, AWS CCM, etc.) that can be enabled/disabled via `cluster_helm`.

### Infrastructure Layer

Creates the AWS/zCompute resources:

| Resource | File | Purpose |
|----------|------|---------|
| `aws_autoscaling_group.control` | asg.tf | Control plane node group ASGs |
| `aws_autoscaling_group.worker` | asg.tf | Worker node group ASGs |
| `aws_launch_configuration.this` | launch_configuration.tf | EC2 instance templates |
| `aws_lb.kube_api` | load_balancer.tf | Internal NLB for API |
| `aws_security_group.k8s` | sg.tf | Cluster networking |

### Initialization Layer

Cloud-init and shell scripts that run on each EC2 instance boot.

## Data Flow

```
User Variables
     |
     v
+------------+     +--------------------+
| locals.tf  |---->| Merged node_groups |
+------------+     +--------------------+
                            |
                            v
+-----------------------------------------------------------------+
|                    data_cloudinit.tf                            |
|  Renders cloud-init config for each node group:                 |
|  - /etc/zadara/k8s.json (cluster config)                        |
|  - /etc/zadara/k8s_helm.json (helm charts, control only)        |
|  - /etc/zadara/etcd_backup.json (backup config, control only)   |
|  - Shell scripts for OS setup, K3s install, Helm deploy         |
+-----------------------------------------------------------------+
                            |
                            v
+-----------------------------------------------------------------+
|                   aws_launch_configuration                      |
|  user_data_base64 = data.cloudinit_config.k8s[key].rendered     |
+-----------------------------------------------------------------+
                            |
                            v
+-----------------------------------------------------------------+
|                   EC2 Instance Boot                             |
|  cloud-init executes parts in order                             |
+-----------------------------------------------------------------+
```

### Configuration Files Written to Nodes

| Path | Content | Used By |
|------|---------|---------|
| `/etc/zadara/k8s.json` | Cluster name, version, token, role, CIDRs | setup-k3s.sh |
| `/etc/zadara/k8s_helm.json` | Helm chart configurations | setup-helm.sh |
| `/etc/zadara/etcd_backup.json` | S3 backup credentials and settings | setup-k3s.sh |
| `/etc/rancher/k3s/kubelet.config` | Kubelet configuration | K3s |

## Cloud-Init Process

Cloud-init executes parts in filename order. The module uses a numeric prefix scheme:

| Order | Filename | Type | Purpose |
|-------|----------|------|---------|
| 00 | write-files-*.yaml | cloud-config | Write configuration files |
| 05 | (user-provided) | varies | Custom user cloud-init parts |
| 10 | setup-os.sh | shell | Install OS dependencies (jq, yq, AWS CLI) |
| 19 | wait-for-instance-profile.sh | shell | Wait for IAM to be ready |
| 20 | setup-k3s.sh | shell | Install and configure K3s |
| 30 | setup-helm.sh | shell | Deploy Helm charts (control nodes only) |

### Script Details

#### setup-os.sh (Order 10)

Installs required utilities:
- `jq` - JSON processing for configuration parsing
- `yq` - YAML processing
- AWS CLI - For cloud provider integration
- CNI plugins - Network plugins for container networking
- Zadara disk mapper - For EBS CSI driver support

#### wait-for-instance-profile.sh (Order 19)

Polls the EC2 metadata service until IAM credentials are available. Required because IAM propagation can take several seconds after instance launch. Verifies both profile name and credentials are accessible.

#### setup-k3s.sh (Order 20)

Main K3s installation script:

1. **Parse configuration** from `/etc/zadara/k8s.json`
2. **Determine node role** (control plane or worker)
3. **Check for existing cluster** by querying the load balancer endpoint
4. **Initialize or join**:
   - First control node: Initialize new cluster with `--cluster-init`
   - Subsequent control nodes: Join via `--server https://<lb>:6443`
   - Worker nodes: Join via `--server https://<lb>:6443`
5. **Configure etcd backup** (control nodes with etcd_backup configured)

#### setup-helm.sh (Order 30)

Runs only on control plane nodes:

1. Install Helm if not present
2. Wait for Kubernetes API to be ready (both LB and local)
3. Use node label mutex to ensure only one node deploys charts
4. Add Helm repositories
5. Deploy Helm charts from `/etc/zadara/k8s_helm.json` in order

## Cluster Initialization Sequence

```
                    Control Node 1        Control Node 2        Worker Node
                         |                     |                     |
Boot                     |                     |                     |
  |                      |                     |                     |
  v                      v                     v                     v
Write configs      Write configs         Write configs         Write configs
  |                      |                     |                     |
  v                      v                     v                     v
Setup OS           Setup OS              Setup OS              Setup OS
  |                      |                     |                     |
  v                      v                     v                     v
Wait IAM           Wait IAM              Wait IAM              Wait IAM
  |                      |                     |                     |
  v                      v                     v                     v
Check LB:6443      Check LB:6443         Check LB:6443         Check LB:6443
  |                      |                     |                     |
  | (No response)        | (No response)      |                     |
  v                      v                     |                     |
Race to init       Race to init          |                     |
  |                      |                     |                     |
  v                      |                     |                     |
WIN: --cluster-init      |                     |                     |
  |                      v                     |                     |
  |                 LOSE: Wait                 |                     |
  |                      |                     |                     |
  v                      v                     v                     v
LB healthy         Join as control       Join as control       Join as worker
  |                      |                     |                     |
  v                      v                     v                     |
Helm deploy        Helm deploy           Helm deploy            |
  |                 (waits for API)       (waits for API)        |
  v                      v                     v                     v
READY              READY                 READY                 READY
```

### Leader Election

The first control node to initialize "wins" and becomes the initial leader:

1. All control nodes check if API is reachable at load balancer
2. If not reachable, nodes determine the oldest instance in the ASG via AWS API
3. Oldest instance becomes the "seed" node and initializes with `--cluster-init`
4. Other control nodes wait and then join via the load balancer
5. K3s uses embedded etcd for leader election

This coordination is deterministic - the oldest instance always seeds, avoiding race conditions.

## Security Considerations

### Sensitive Data

| Data | Protection | Location |
|------|------------|----------|
| `cluster_token` | Terraform sensitive, file permissions 0640 | `/etc/zadara/k8s.json` |
| etcd backup credentials | Terraform sensitive, file permissions 0640 | `/etc/zadara/etcd_backup.json` |
| Kubernetes secrets | Standard K8s RBAC | etcd (encrypted at rest optional) |

### Network Security

- Control plane API exposed only via internal NLB
- Security group restricts intra-cluster traffic
- Per-node-group security groups for additional rules
- No public IPs by default (depends on subnet configuration)

## Troubleshooting

### Cloud-Init Logs

```bash
# View cloud-init output
sudo cat /var/log/cloud-init-output.log

# View cloud-init status
cloud-init status --long
```

### K3s Logs

```bash
# Control plane / server logs
sudo journalctl -u k3s

# Worker / agent logs
sudo journalctl -u k3s-agent
```

### Common Issues

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| Nodes not joining | LB not healthy, token mismatch | Check LB target health, verify token |
| Helm charts not deploying | API not ready, RBAC issues | Check setup-helm.sh logs in cloud-init-output.log |
| IAM errors | Instance profile not attached | Check wait-for-instance-profile.sh logs |
| etcd backup failing | S3 credentials invalid | Verify etcd_backup configuration |
| K3s not starting | Configuration error | Check `/etc/rancher/k3s/config.yaml` |

### Configuration Verification

```bash
# Check cluster config was written
sudo cat /etc/zadara/k8s.json | jq .

# Check helm config (control nodes only)
sudo cat /etc/zadara/k8s_helm.json | jq .

# Check K3s configuration
sudo cat /etc/rancher/k3s/config.yaml

# Verify K3s is running
sudo systemctl status k3s  # or k3s-agent for workers

# Check node status
sudo kubectl get nodes
```

## File Reference

| File | Purpose |
|------|---------|
| `variables.tf` | Input variable definitions |
| `outputs.tf` | Module outputs |
| `locals.tf` | Configuration merging and defaults |
| `locals_helm.tf` | Default Helm chart configurations |
| `data_cloudinit.tf` | Cloud-init template rendering |
| `data_ami_ubuntu.tf` | Ubuntu AMI lookup |
| `data_ami_debian.tf` | Debian AMI lookup |
| `asg.tf` | Auto Scaling Group resources |
| `launch_configuration.tf` | EC2 launch configuration |
| `load_balancer.tf` | Internal NLB for Kubernetes API |
| `sg.tf` | Security group resources |
| `files/setup-os.sh` | OS dependency installation |
| `files/wait-for-instance-profile.sh` | IAM readiness check |
| `files/setup-helm.sh` | Helm chart deployment |
| `files/k3s/setup.sh` | K3s installation and configuration |
