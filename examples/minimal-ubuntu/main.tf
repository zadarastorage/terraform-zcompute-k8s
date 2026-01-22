# Minimal K3s Cluster Example - Ubuntu Flavor
# Single control plane node with explicit Ubuntu 22.04 LTS

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

  # Explicitly set Ubuntu flavor
  cluster_flavor = "k3s-ubuntu"

  # -----------------------------------------------------------------------------
  # Node Configuration
  # -----------------------------------------------------------------------------
  node_group_defaults = {
    iam_instance_profile = var.iam_instance_profile
    key_name             = var.key_pair_name
  }

  node_groups = {
    control = {
      role         = "control"
      min_size     = 1
      max_size     = 1
      desired_size = 1
    }
  }

  # -----------------------------------------------------------------------------
  # Tags
  # -----------------------------------------------------------------------------
  tags = var.tags
}
