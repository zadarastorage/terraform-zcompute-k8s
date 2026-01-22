# Mixed Flavor K3s Cluster Example

This example deploys a K3s cluster on Zadara zCompute with mixed OS flavors, demonstrating per-node-group flavor override capability.

## Features

- Single control plane node (Ubuntu)
- Two worker pools with different OS flavors
- Demonstrates per-node-group `cluster_flavor` override
- K3s version 1.31.2

## How Node Group Flavor Override Works

The module supports setting OS flavor at two levels:

1. **Cluster level** (`cluster_flavor`): Default OS for all node groups
2. **Node group level** (`node_groups[].cluster_flavor`): Override for specific groups

```hcl
# Default cluster flavor
cluster_flavor = "k3s-ubuntu"

node_groups = {
  control = {
    role           = "control"
    cluster_flavor = "k3s-ubuntu"  # Explicit (same as default)
  }
  worker-debian = {
    role           = "worker"
    cluster_flavor = "k3s-debian"  # Override with Debian
  }
}
```

Groups without explicit `cluster_flavor` inherit from the cluster-level default.

## When to Use Mixed Flavors

Mixed OS environments are useful for:

- **Gradual migration**: Test new OS version on subset of workers
- **Workload requirements**: Some applications certified for specific OS
- **Legacy compatibility**: Run older OS for specific workloads
- **Testing**: Verify application compatibility across OS versions

## Prerequisites

- Terraform >= 1.0
- Zadara zCompute account with API credentials
- Existing VPC with private subnets
- IAM instance profile with required permissions
- SSH key pair

## Usage

1. Copy the example files:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your values:
   - zCompute credentials
   - VPC and subnet IDs
   - Cluster token (generate with `openssl rand -hex 16`)
   - IAM instance profile name
   - SSH key pair name

3. Initialize and apply:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Node Configuration

| Node Group     | Role    | Count | Instance Type | OS |
|----------------|---------|-------|---------------|-----|
| control        | control | 1     | z4.large      | Ubuntu 22.04 LTS |
| worker-ubuntu  | worker  | 1     | z4.large      | Ubuntu 22.04 LTS |
| worker-debian  | worker  | 1     | z4.large      | Debian 12 |

## Accessing the Cluster

After deployment, configure kubectl:

```bash
# SSH to control plane (Ubuntu)
ssh -i <key> ubuntu@<control-node-ip>

# SSH to Ubuntu worker
ssh -i <key> ubuntu@<ubuntu-worker-ip>

# SSH to Debian worker (uses 'admin' user)
ssh -i <key> admin@<debian-worker-ip>

# Copy kubeconfig from control plane
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
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | List of subnet IDs for K3s nodes (private subnets recommended) | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC where the K3s cluster will be deployed | `string` | n/a | yes |
| <a name="input_zcompute_access_key"></a> [zcompute\_access\_key](#input\_zcompute\_access\_key) | zCompute access key | `string` | n/a | yes |
| <a name="input_zcompute_secret_key"></a> [zcompute\_secret\_key](#input\_zcompute\_secret\_key) | zCompute secret key | `string` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names | `string` | `"k3s-mixed"` | no |
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
