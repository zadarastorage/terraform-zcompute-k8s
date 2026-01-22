# High Availability K3s Cluster Example
# 3-node control plane with optional etcd backup to S3-compatible storage

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

  # -----------------------------------------------------------------------------
  # etcd Backup Configuration (Optional)
  # When enabled, K3s automatically backs up etcd snapshots to S3-compatible storage
  # -----------------------------------------------------------------------------
  etcd_backup = var.etcd_backup_enabled ? {
    s3            = "true"
    s3-endpoint   = var.etcd_backup_endpoint
    s3-region     = var.region
    s3-bucket     = var.etcd_backup_bucket
    s3-folder     = "${var.name_prefix}-cluster"
    s3-access-key = var.etcd_backup_access_key
    s3-secret-key = var.etcd_backup_secret_key
  } : null

  # -----------------------------------------------------------------------------
  # Node Configuration
  # HA requires odd number of control plane nodes for etcd quorum (3 or 5)
  # -----------------------------------------------------------------------------
  node_group_defaults = {
    iam_instance_profile = var.iam_instance_profile
    key_name             = var.key_pair_name
    root_volume_size     = 64
  }

  node_groups = {
    control = {
      role          = "control"
      min_size      = 3
      max_size      = 3
      desired_size  = 3
      instance_type = "z4.large"
    }
    worker = {
      role          = "worker"
      min_size      = 1
      max_size      = 5
      desired_size  = 2
      instance_type = "z8.xlarge"
    }
  }

  # -----------------------------------------------------------------------------
  # Tags
  # -----------------------------------------------------------------------------
  tags = var.tags
}
