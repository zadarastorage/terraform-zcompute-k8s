# Zadara zCompute K8s Terraform Module

Terraform module for provisioning production-ready K3s Kubernetes clusters on Zadara zCompute (AWS-compatible) infrastructure. Handles EC2 Auto Scaling Groups, internal load balancer, security groups, cloud-init provisioning, and optional Helm-managed add-ons.

## Features

- **K3s Kubernetes**: Lightweight, certified Kubernetes distribution
- **High Availability**: Multi-node control plane with automatic leader election
- **Auto Scaling**: Worker nodes scale via EC2 Auto Scaling Groups
- **Multi-Flavor**: Ubuntu and Debian base images supported
- **Helm Integration**: Automatic deployment of cluster add-ons (Flannel, Calico, AWS CCM, EBS CSI)
- **etcd Backup**: Optional automatic backup to S3-compatible storage

## Prerequisites

### Terraform Version

- Terraform >= 1.0
- AWS Provider >= 4.0

### Required Infrastructure

- **VPC**: Must exist with DNS hostnames and DNS resolution enabled
- **Subnets**: Private subnets recommended; must have outbound internet access (NAT Gateway or similar) for pulling container images and K3s binaries
- **SSH Key Pair**: Must exist in zCompute if you want SSH access to nodes

### Required IAM Permissions

The IAM instance profile attached to nodes requires these permissions for K3s cloud provider and cluster autoscaler functionality:

<details>
<summary>Click to expand IAM policy</summary>

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeTags",
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup",
        "ec2:DescribeInstances",
        "ec2:DescribeRegions",
        "ec2:DescribeRouteTables",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVolumes",
        "ec2:DescribeVpcs",
        "ec2:CreateSecurityGroup",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifyVolume",
        "ec2:AttachVolume",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:DeleteSecurityGroup",
        "ec2:DeleteVolume",
        "ec2:DetachVolume",
        "ec2:RevokeSecurityGroupIngress",
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:AttachLoadBalancerToSubnets",
        "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:CreateLoadBalancerPolicy",
        "elasticloadbalancing:CreateLoadBalancerListeners",
        "elasticloadbalancing:ConfigureHealthCheck",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:DeleteLoadBalancerListeners",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeLoadBalancerAttributes",
        "elasticloadbalancing:DetachLoadBalancerFromSubnets",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer"
      ],
      "Resource": "*"
    }
  ]
}
```

</details>

### External Dependencies

| Dependency | Purpose | Required |
|------------|---------|----------|
| IAM Instance Profile | Node permissions for AWS/zCompute API calls | Yes |
| SSH Key Pair | SSH access to nodes for debugging | No |
| S3 Bucket | etcd backup storage (if `etcd_backup` configured) | No |

## Usage

### Minimal Example

```hcl
module "k8s" {
  source = "github.com/zadarastorage/terraform-zcompute-k8s?ref=v2.0.0"

  vpc_id          = "vpc-12345678"
  subnets         = ["subnet-aaaa", "subnet-bbbb", "subnet-cccc"]
  cluster_name    = "my-cluster"
  cluster_version = "1.31.2"
  cluster_token   = var.cluster_token  # Sensitive - at least 16 characters

  node_group_defaults = {
    iam_instance_profile = aws_iam_instance_profile.k8s.name
  }

  node_groups = {
    control = {
      role         = "control"
      min_size     = 3
      max_size     = 3
      desired_size = 3
    }
    worker = {
      role         = "worker"
      min_size     = 1
      max_size     = 5
      desired_size = 2
    }
  }
}
```

### Complete Example with All Options

```hcl
module "k8s" {
  source = "github.com/zadarastorage/terraform-zcompute-k8s?ref=v2.0.0"

  # zCompute endpoint (default: https://cloud.zadara.com)
  zcompute_endpoint = "https://symphony.example.com"

  # Network configuration
  vpc_id  = data.aws_vpc.main.id
  subnets = data.aws_subnets.private.ids

  # AMI security - restrict to trusted owners
  # For zCompute: use 32-character hex ID from your environment
  # For AWS: use 12-digit account IDs like "099720109477" (Canonical)
  trusted_ami_owners = ["1234a701473b61af498f633abdc8c113"]

  # Cluster identity
  cluster_name    = "production-cluster"
  cluster_version = "1.31.2"
  cluster_token   = var.cluster_token
  cluster_flavor  = "k3s-ubuntu"  # or "k3s-debian"

  # Network CIDRs (ensure no overlap with VPC CIDR)
  pod_cidr     = "10.42.0.0/16"
  service_cidr = "10.43.0.0/16"

  # Resource tags applied to all AWS resources
  tags = {
    Environment = "production"
    Team        = "platform"
  }

  # Default settings for all node groups
  node_group_defaults = {
    iam_instance_profile = aws_iam_instance_profile.k8s.name
    key_name             = aws_key_pair.k8s.key_name
    root_volume_size     = 64
    instance_type        = "z4.large"
  }

  # Node group definitions
  node_groups = {
    control = {
      role         = "control"
      min_size     = 3
      max_size     = 3
      desired_size = 3
    }
    worker-general = {
      role             = "worker"
      min_size         = 2
      max_size         = 10
      desired_size     = 3
      instance_type    = "z8.2xlarge"
      root_volume_size = 256
      k8s_labels = {
        "workload-type" = "general"
      }
    }
    worker-gpu = {
      role         = "worker"
      min_size     = 0
      max_size     = 4
      desired_size = 0
      instance_type = "g4.xlarge"
      k8s_labels = {
        "workload-type" = "gpu"
      }
      k8s_taints = {
        "nvidia.com/gpu" = "true:NoSchedule"
      }
    }
  }

  # Optional: etcd backup to S3
  etcd_backup = {
    s3              = "true"
    s3-endpoint     = "https://s3.example.com"
    s3-region       = "us-east-1"
    s3-bucket       = "etcd-backups"
    s3-folder       = "production-cluster"
    s3-access-key   = var.etcd_backup_access_key
    s3-secret-key   = var.etcd_backup_secret_key
  }

  # Optional: Helm charts for cluster add-ons
  cluster_helm = {
    aws-cloud-controller-manager = {
      enabled = true
    }
    aws-ebs-csi-driver = {
      enabled = true
    }
  }
}
```

## Examples

- [k8s-simple](./examples/k8s-simple) - Complete working example with VPC data sources, IAM profile, and registry mirror configuration

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.33.0, <= 3.35.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 3.35.0 |
| <a name="provider_cloudinit"></a> [cloudinit](#provider\_cloudinit) | 2.3.7 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_attachment.control](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_attachment) | resource |
| [aws_autoscaling_group.control](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_autoscaling_group.worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_launch_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_configuration) | resource |
| [aws_lb.kube_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.k8s_api_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.kube_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_security_group.k8s](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.k8s_extra](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.k8s](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.k8s_extra](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [terraform_data.aws_launch_configuration](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_ami_ids.debian](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami_ids) | data source |
| [aws_ami_ids.ubuntu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami_ids) | data source |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |
| [cloudinit_config.k8s](https://registry.terraform.io/providers/hashicorp/cloudinit/latest/docs/data-sources/config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the K8s cluster. Used for resource naming and Kubernetes node identification.<br>- Must be unique within your AWS account/region<br>- Used as prefix for EC2 instances, security groups, and load balancers<br>- Applied as kubernetes.io/cluster/<name> tag for cloud provider integration | `string` | n/a | yes |
| <a name="input_cluster_token"></a> [cluster\_token](#input\_cluster\_token) | Shared secret token for node authentication and cluster join. Must be at least 16 characters. Keep this value secure and do not commit to version control. | `string` | n/a | yes |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | Kubernetes version to deploy (K3s distribution). Specify the minor version (e.g., "1.31.2").<br>- K3s versions track upstream Kubernetes releases<br>- See https://github.com/k3s-io/k3s/releases for available versions<br>- Tested versions: 1.28.x, 1.29.x, 1.30.x, 1.31.x | `string` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | List of subnet IDs for placing K8s nodes. Requirements:<br>- Private subnets are recommended for security<br>- Subnets must have outbound internet access (NAT Gateway) for pulling container images<br>- For high availability, use subnets across multiple availability zones | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC where the K8s cluster will be deployed. This VPC must have DNS hostnames and DNS resolution enabled. | `string` | n/a | yes |
| <a name="input_cluster_flavor"></a> [cluster\_flavor](#input\_cluster\_flavor) | Base OS flavor for K3s cluster nodes. Determines the AMI used for node instances.<br><br>Available flavors:<br>- "k3s-ubuntu": Ubuntu 22.04 LTS (recommended, most tested)<br>- "k3s-debian": Debian 12 (Bookworm) | `string` | `"k3s-ubuntu"` | no |
| <a name="input_cluster_helm"></a> [cluster\_helm](#input\_cluster\_helm) | Map of Helm charts to deploy during cluster initialization. Each key is a chart identifier<br>and value contains chart configuration.<br><br>Supported charts:<br>- aws-cloud-controller-manager: AWS/zCompute cloud provider integration<br>- aws-ebs-csi-driver: EBS volume provisioner for persistent storage<br><br>Structure:<pre>hcl<br>cluster_helm = {<br>  aws-cloud-controller-manager = {<br>    enabled = true<br>  }<br>  aws-ebs-csi-driver = {<br>    enabled = true<br>    values  = { ... }  # Optional: override default Helm values<br>  }<br>}</pre> | `any` | `{}` | no |
| <a name="input_etcd_backup"></a> [etcd\_backup](#input\_etcd\_backup) | Configuration for automatic etcd snapshots to S3-compatible object storage.<br>When configured, K3s automatically backs up etcd data on a schedule.<br><br>Configuration keys map to K3s etcd-snapshot flags (without --etcd- prefix):<br>- s3: Enable S3 backup (set to "true")<br>- s3-endpoint: S3 endpoint URL<br>- s3-region: S3 region<br>- s3-bucket: S3 bucket name<br>- s3-folder: Folder path within bucket<br>- s3-access-key: S3 access key<br>- s3-secret-key: S3 secret key<br>- snapshot-schedule-cron: Backup schedule (default: "0 */12 * * *")<br>- snapshot-retention: Number of snapshots to retain (default: 5)<br><br>Example:<pre>hcl<br>etcd_backup = {<br>  s3            = "true"<br>  s3-endpoint   = "https://s3.example.com"<br>  s3-region     = "us-east-1"<br>  s3-bucket     = "etcd-backups"<br>  s3-folder     = "my-cluster"<br>  s3-access-key = var.backup_access_key<br>  s3-secret-key = var.backup_secret_key<br>}</pre>See: https://docs.k3s.io/cli/etcd-snapshot#s3-compatible-object-store-support | `map(string)` | `null` | no |
| <a name="input_node_group_defaults"></a> [node\_group\_defaults](#input\_node\_group\_defaults) | Default settings applied to all node groups. Individual node group settings override these defaults.<br><br>Supported keys:<br>- instance\_type: EC2 instance type (default: "z4.large")<br>- root\_volume\_size: Root EBS volume size in GB (default: 40)<br>- root\_volume\_type: EBS volume type (default: null, uses AWS default)<br>- key\_name: SSH key pair name for node access<br>- iam\_instance\_profile: IAM instance profile name (required)<br>- tags: Additional tags for node group resources<br>- feature\_gates: List of Kubernetes feature gates to enable<br>- security\_group\_rules: Map of additional security group rules<br>- cloudinit\_config: List of additional cloud-init config parts<br><br>Example:<pre>hcl<br>node_group_defaults = {<br>  iam_instance_profile = "k8s-node-profile"<br>  key_name             = "my-ssh-key"<br>  instance_type        = "z8.xlarge"<br>  root_volume_size     = 100<br>}</pre> | `any` | `{}` | no |
| <a name="input_node_groups"></a> [node\_groups](#input\_node\_groups) | Map of node group configurations. Each entry creates an Auto Scaling Group.<br><br>Required keys:<br>- role: Node role, either "control" (control plane) or "worker"<br><br>Optional keys (defaults from node\_group\_defaults):<br>- enabled: Whether to create this node group (default: true)<br>- min\_size: Minimum ASG size (default: 0)<br>- max\_size: Maximum ASG size (default: 0)<br>- desired\_size: Initial/desired ASG size (default: 0)<br>- instance\_type: EC2 instance type (default: "z4.large")<br>- root\_volume\_size: Root EBS volume size in GB (default: 40)<br>- key\_name: SSH key pair name for node access<br>- iam\_instance\_profile: IAM instance profile name<br>- k8s\_labels: Map of Kubernetes node labels<br>- k8s\_taints: Map of Kubernetes node taints (format: "key" = "value:Effect")<br>- security\_group\_rules: Additional security group rules<br>- cloudinit\_config: Additional cloud-init config parts<br><br>Example:<pre>hcl<br>node_groups = {<br>  control = {<br>    role         = "control"<br>    min_size     = 3<br>    max_size     = 3<br>    desired_size = 3<br>  }<br>  worker = {<br>    role             = "worker"<br>    min_size         = 1<br>    max_size         = 10<br>    desired_size     = 3<br>    instance_type    = "z8.2xlarge"<br>    root_volume_size = 256<br>    k8s_labels = {<br>      "workload" = "general"<br>    }<br>  }<br>  gpu = {<br>    role          = "worker"<br>    min_size      = 0<br>    max_size      = 4<br>    desired_size  = 0<br>    instance_type = "g4.xlarge"<br>    k8s_taints = {<br>      "nvidia.com/gpu" = "true:NoSchedule"<br>    }<br>  }<br>}</pre> | `any` | `{}` | no |
| <a name="input_pod_cidr"></a> [pod\_cidr](#input\_pod\_cidr) | CIDR range for Kubernetes pod networking. Pods are assigned IPs from this range.<br>- Must not overlap with VPC CIDR or service\_cidr<br>- Default /16 provides ~65,000 pod IPs<br>- Adjust size based on expected cluster scale | `string` | `"10.42.0.0/16"` | no |
| <a name="input_service_cidr"></a> [service\_cidr](#input\_service\_cidr) | CIDR range for Kubernetes ClusterIP services. Services are assigned IPs from this range.<br>- Must not overlap with VPC CIDR or pod\_cidr<br>- Default /16 provides ~65,000 service IPs<br>- First IP (10.43.0.1) is reserved for kubernetes.default service | `string` | `"10.43.0.0/16"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_trusted_ami_owners"></a> [trusted\_ami\_owners](#input\_trusted\_ami\_owners) | List of trusted AMI owner IDs for Ubuntu and Debian images.<br>SECURITY WARNING: Empty list means no owner restriction (any AMI owner accepted).<br>For Zadara zCompute, use: ["1234a701473b61af498f633abdc8c113"] | `list(string)` | `[]` | no |
| <a name="input_zcompute_endpoint"></a> [zcompute\_endpoint](#input\_zcompute\_endpoint) | Zadara zCompute API endpoint URL. This is the base URL for all AWS-compatible API calls.<br><br>Example: "https://symphony.us-west-1.zadara.com"<br>Default: "https://cloud.zadara.com" | `string` | `"https://cloud.zadara.com"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the K8s cluster, as provided in the cluster\_name variable |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | ID of the security group used for intra-cluster communication. Add this to any resources that need to communicate with cluster nodes. |
| <a name="output_cluster_version"></a> [cluster\_version](#output\_cluster\_version) | Kubernetes version of the cluster, as provided in the cluster\_version variable |
| <a name="output_control_plane_asg_names"></a> [control\_plane\_asg\_names](#output\_control\_plane\_asg\_names) | List of Auto Scaling Group names for control plane nodes. Useful for monitoring and troubleshooting. |
| <a name="output_kube_api_endpoint"></a> [kube\_api\_endpoint](#output\_kube\_api\_endpoint) | Internal DNS name of the Kubernetes API load balancer. Use this endpoint for kubectl configuration within the VPC. |
| <a name="output_kube_api_port"></a> [kube\_api\_port](#output\_kube\_api\_port) | Port number for the Kubernetes API endpoint (always 6443) |
| <a name="output_worker_asg_names"></a> [worker\_asg\_names](#output\_worker\_asg\_names) | List of Auto Scaling Group names for worker nodes. Useful for monitoring, troubleshooting, and cluster autoscaler configuration. |
<!-- END_TF_DOCS -->

## Architecture

See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed documentation of module internals, data flow, and cloud-init process.

## Contributing

Contributions are welcome. Please ensure:

1. Code passes `terraform fmt -check`
2. Code passes `terraform validate`
3. Changes include appropriate documentation updates

## License

See [LICENSE](./LICENSE) for details.
