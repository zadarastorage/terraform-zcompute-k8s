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
