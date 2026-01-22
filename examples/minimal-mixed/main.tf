# Mixed Flavor K3s Cluster Example
# Demonstrates per-node-group OS flavor override

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

  # Default cluster flavor (can be overridden per node group)
  cluster_flavor = "k3s-ubuntu"

  # -----------------------------------------------------------------------------
  # Node Configuration
  # Demonstrates mixed OS flavors with per-group override
  # -----------------------------------------------------------------------------
  node_group_defaults = {
    iam_instance_profile = var.iam_instance_profile
    key_name             = var.key_pair_name
  }

  node_groups = {
    # Control plane uses Ubuntu
    control = {
      role           = "control"
      cluster_flavor = "k3s-ubuntu" # Explicit for control plane
      min_size       = 1
      max_size       = 1
      desired_size   = 1
    }

    # Worker pool using Ubuntu
    worker-ubuntu = {
      role           = "worker"
      cluster_flavor = "k3s-ubuntu"
      min_size       = 0
      max_size       = 2
      desired_size   = 1
    }

    # Worker pool using Debian
    worker-debian = {
      role           = "worker"
      cluster_flavor = "k3s-debian" # Different OS flavor
      min_size       = 0
      max_size       = 2
      desired_size   = 1
    }
  }

  # -----------------------------------------------------------------------------
  # Tags
  # -----------------------------------------------------------------------------
  tags = var.tags
}
