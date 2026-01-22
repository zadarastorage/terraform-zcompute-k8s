# High Availability K3s Cluster Example

This example deploys a highly available K3s cluster on Zadara zCompute with 3 control plane nodes and optional etcd backup to S3-compatible storage.

## Features

- 3-node control plane for high availability (etcd quorum)
- 2 worker nodes (scalable 1-5)
- Optional automatic etcd backup to S3-compatible storage
- K3s version 1.31.2

## Why 3 Control Plane Nodes?

K3s uses embedded etcd for cluster state storage when running in HA mode. etcd requires a quorum (majority) of nodes to be available for the cluster to function:

| Nodes | Quorum | Fault Tolerance |
|-------|--------|-----------------|
| 1     | 1      | 0 failures      |
| 3     | 2      | 1 failure       |
| 5     | 3      | 2 failures      |

**3 nodes is recommended** for most production clusters because:
- Tolerates 1 node failure
- Lower resource cost than 5 nodes
- Odd number avoids split-brain scenarios

## etcd Backup

When enabled, K3s automatically creates snapshots of etcd data and uploads them to S3-compatible storage. This provides disaster recovery capability.

### Enabling etcd Backup

1. Set `etcd_backup_enabled = true`
2. Configure S3-compatible storage endpoint and credentials
3. The backup folder will be `<name_prefix>-cluster`

### S3-Compatible Storage Requirements

etcd backup works with any S3-compatible storage:
- Amazon S3
- MinIO
- Zadara Object Storage
- Any S3-compatible endpoint

### Backup Schedule

By default, K3s takes snapshots every 12 hours and retains 5 snapshots. These defaults can be customized via the root module's `etcd_backup` variable.

## Prerequisites

- Terraform >= 1.0
- Zadara zCompute account with API credentials
- Existing VPC with subnets across multiple availability zones
- IAM instance profile with required permissions
- SSH key pair
- (Optional) S3-compatible storage for etcd backups

## Usage

1. Copy the example files:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your values:
   - zCompute credentials
   - VPC and subnet IDs (use multiple AZs for HA)
   - Cluster token (generate with `openssl rand -hex 16`)
   - IAM instance profile name
   - SSH key pair name
   - (Optional) etcd backup configuration

3. Initialize and apply:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Node Configuration

| Node Group | Role    | Count | Instance Type | Notes |
|------------|---------|-------|---------------|-------|
| control    | control | 3     | z4.large      | HA control plane |
| worker     | worker  | 2     | z8.xlarge     | Scalable 1-5 |

## Accessing the Cluster

After deployment, configure kubectl:

```bash
# SSH to any control plane node
ssh -i <key> ubuntu@<node-ip>

# Copy kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml
```

Update the `server` URL in the kubeconfig to point to the load balancer endpoint.

## Cleanup

```bash
terraform destroy
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.33.0, <= 3.35.0 |
| <a name="requirement_cloudinit"></a> [cloudinit](#requirement\_cloudinit) | >= 2.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_k3s"></a> [k3s](#module\_k3s) | ../.. | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_token"></a> [cluster\_token](#input\_cluster\_token) | Shared secret token for node authentication and cluster join.<br>Must be at least 16 characters. Generate with: openssl rand -hex 16 | `string` | n/a | yes |
| <a name="input_iam_instance_profile"></a> [iam\_instance\_profile](#input\_iam\_instance\_profile) | Name of the IAM instance profile for K3s nodes | `string` | n/a | yes |
| <a name="input_key_pair_name"></a> [key\_pair\_name](#input\_key\_pair\_name) | Name of the SSH key pair for node access | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | List of subnet IDs for K3s nodes (use multiple AZs for HA) | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC where the K3s cluster will be deployed | `string` | n/a | yes |
| <a name="input_zcompute_access_key"></a> [zcompute\_access\_key](#input\_zcompute\_access\_key) | zCompute access key | `string` | n/a | yes |
| <a name="input_zcompute_secret_key"></a> [zcompute\_secret\_key](#input\_zcompute\_secret\_key) | zCompute secret key | `string` | n/a | yes |
| <a name="input_cluster_flavor"></a> [cluster\_flavor](#input\_cluster\_flavor) | Base OS flavor for K3s cluster nodes.<br>Options: "k3s-ubuntu" (Ubuntu 22.04 LTS), "k3s-debian" (Debian 12) | `string` | `"k3s-ubuntu"` | no |
| <a name="input_etcd_backup_access_key"></a> [etcd\_backup\_access\_key](#input\_etcd\_backup\_access\_key) | S3 access key for etcd backups | `string` | `""` | no |
| <a name="input_etcd_backup_bucket"></a> [etcd\_backup\_bucket](#input\_etcd\_backup\_bucket) | S3 bucket name for etcd backups | `string` | `""` | no |
| <a name="input_etcd_backup_enabled"></a> [etcd\_backup\_enabled](#input\_etcd\_backup\_enabled) | Enable automatic etcd backup to S3-compatible storage | `bool` | `false` | no |
| <a name="input_etcd_backup_endpoint"></a> [etcd\_backup\_endpoint](#input\_etcd\_backup\_endpoint) | S3-compatible endpoint URL for etcd backups (e.g., https://s3.example.com) | `string` | `""` | no |
| <a name="input_etcd_backup_secret_key"></a> [etcd\_backup\_secret\_key](#input\_etcd\_backup\_secret\_key) | S3 secret key for etcd backups | `string` | `""` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names | `string` | `"k3s-ha"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region for zCompute deployment | `string` | `"us-east-1"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_zcompute_endpoint"></a> [zcompute\_endpoint](#input\_zcompute\_endpoint) | Zadara zCompute API endpoint URL | `string` | `"https://cloud.zadara.com"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the K3s cluster |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | ID of the security group used for intra-cluster communication |
| <a name="output_cluster_version"></a> [cluster\_version](#output\_cluster\_version) | Kubernetes version of the cluster |
| <a name="output_control_plane_asg_names"></a> [control\_plane\_asg\_names](#output\_control\_plane\_asg\_names) | Auto Scaling Group names for control plane nodes |
| <a name="output_kube_api_endpoint"></a> [kube\_api\_endpoint](#output\_kube\_api\_endpoint) | Internal DNS name of the Kubernetes API load balancer |
| <a name="output_kube_api_port"></a> [kube\_api\_port](#output\_kube\_api\_port) | Port number for the Kubernetes API endpoint |
| <a name="output_worker_asg_names"></a> [worker\_asg\_names](#output\_worker\_asg\_names) | Auto Scaling Group names for worker nodes |
<!-- END_TF_DOCS -->
