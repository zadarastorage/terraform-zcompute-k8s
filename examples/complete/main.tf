# Complete K3s Cluster Example
# Full-featured configuration demonstrating all major options

# tflint-ignore: terraform_module_pinned_source
module "k3s" {
  source = "../.."

  # -----------------------------------------------------------------------------
  # Network Configuration
  # -----------------------------------------------------------------------------
  vpc_id  = var.vpc_id
  subnets = var.subnet_ids

  # -----------------------------------------------------------------------------
  # Cluster Configuration
  # -----------------------------------------------------------------------------
  cluster_name    = "${var.name_prefix}-cluster"
  cluster_version = "1.31.2"
  cluster_token   = var.cluster_token
  cluster_flavor  = var.cluster_flavor

  # Custom network CIDRs
  pod_cidr     = var.pod_cidr
  service_cidr = var.service_cidr

  # -----------------------------------------------------------------------------
  # Helm Add-ons
  # -----------------------------------------------------------------------------
  cluster_helm = {
    aws-cloud-controller-manager = {
      enabled = true
    }
    aws-ebs-csi-driver = {
      enabled = true
    }
  }

  # -----------------------------------------------------------------------------
  # Node Configuration
  # -----------------------------------------------------------------------------
  node_group_defaults = {
    iam_instance_profile = var.iam_instance_profile
    key_name             = var.key_pair_name
    instance_type        = "z4.large"
    root_volume_size     = 64
  }

  node_groups = {
    control = {
      role         = "control"
      min_size     = 3
      max_size     = 3
      desired_size = 3
    }
    worker = {
      role             = "worker"
      min_size         = 1
      max_size         = 10
      desired_size     = 3
      instance_type    = "z8.xlarge"
      root_volume_size = 128
      k8s_labels = {
        "workload-type" = "general"
      }
    }
  }

  # -----------------------------------------------------------------------------
  # Tags
  # -----------------------------------------------------------------------------
  tags = var.tags
}
