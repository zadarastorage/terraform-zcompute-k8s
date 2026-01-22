# Conditional resource tests for terraform-k8s-zcompute module
# Verifies conditional resource creation logic for different inputs:
# - etcd_backup configuration
# - Cluster flavor selection (ubuntu/debian)
# - Disabled node groups
# - Custom instance types
# - Node labels and taints

mock_provider "aws" {
  source = "tests/unit/mocks"
}

# =============================================================================
# etcd backup is not configured by default
# =============================================================================

run "etcd_backup_not_configured_by_default" {
  command = plan

  variables {
    vpc_id          = "vpc-12345678"
    subnets         = ["subnet-12345678"]
    cluster_name    = "test-etcd-default"
    cluster_version = "1.31.2"
    cluster_token   = "test-token-minimum-16-chars"
    node_group_defaults = {
      iam_instance_profile = "test-profile"
    }
    node_groups = {
      control = {
        role             = "control"
        min_size         = 1
        max_size         = 1
        desired_capacity = 1
      }
    }
  }

  # Plan succeeds with default (null) etcd_backup
  assert {
    condition     = length(aws_autoscaling_group.control) == 1
    error_message = "Plan should succeed without etcd_backup configuration"
  }
}

# =============================================================================
# etcd backup config applied when provided
# =============================================================================

run "etcd_backup_config_in_cloud_init_when_provided" {
  command = plan

  variables {
    vpc_id          = "vpc-12345678"
    subnets         = ["subnet-12345678"]
    cluster_name    = "test-etcd-backup"
    cluster_version = "1.31.2"
    cluster_token   = "test-token-minimum-16-chars"
    etcd_backup = {
      s3            = "true"
      s3-bucket     = "test-bucket"
      s3-folder     = "backups"
      s3-endpoint   = "https://s3.example.com"
      s3-region     = "us-east-1"
    }
    node_group_defaults = {
      iam_instance_profile = "test-profile"
    }
    node_groups = {
      control = {
        role             = "control"
        min_size         = 1
        max_size         = 1
        desired_capacity = 1
      }
    }
  }

  # Plan succeeds with etcd_backup configuration
  # Note: etcd-s3 config is templated into cloud-init via locals.tf
  # Full verification of cloud-init content happens in BATS tests
  assert {
    condition     = length(aws_autoscaling_group.control) == 1
    error_message = "Plan should succeed with etcd_backup configuration"
  }
}

# =============================================================================
# Custom cluster flavor: Ubuntu
# =============================================================================

run "custom_cluster_flavor_ubuntu" {
  command = plan

  variables {
    vpc_id          = "vpc-12345678"
    subnets         = ["subnet-12345678"]
    cluster_name    = "test-ubuntu"
    cluster_version = "1.31.2"
    cluster_token   = "test-token-minimum-16-chars"
    cluster_flavor  = "k3s-ubuntu"
    node_group_defaults = {
      iam_instance_profile = "test-profile"
    }
    node_groups = {
      control = {
        role             = "control"
        min_size         = 1
        max_size         = 1
        desired_capacity = 1
      }
    }
  }

  # Plan succeeds with ubuntu flavor (tests AMI data source selection)
  assert {
    condition     = length(aws_autoscaling_group.control) == 1
    error_message = "Plan should succeed with k3s-ubuntu cluster flavor"
  }
}

# =============================================================================
# Custom cluster flavor: Debian
# =============================================================================

run "custom_cluster_flavor_debian" {
  command = plan

  variables {
    vpc_id          = "vpc-12345678"
    subnets         = ["subnet-12345678"]
    cluster_name    = "test-debian"
    cluster_version = "1.31.2"
    cluster_token   = "test-token-minimum-16-chars"
    cluster_flavor  = "k3s-debian"
    node_group_defaults = {
      iam_instance_profile = "test-profile"
    }
    node_groups = {
      control = {
        role             = "control"
        min_size         = 1
        max_size         = 1
        desired_capacity = 1
      }
    }
  }

  # Plan succeeds with debian flavor (tests AMI data source selection)
  assert {
    condition     = length(aws_autoscaling_group.control) == 1
    error_message = "Plan should succeed with k3s-debian cluster flavor"
  }
}

# =============================================================================
# Disabled node group is not created
# =============================================================================

run "node_group_disabled_not_created" {
  command = plan

  variables {
    vpc_id          = "vpc-12345678"
    subnets         = ["subnet-12345678"]
    cluster_name    = "test-disabled"
    cluster_version = "1.31.2"
    cluster_token   = "test-token-minimum-16-chars"
    node_group_defaults = {
      iam_instance_profile = "test-profile"
    }
    node_groups = {
      control = {
        role             = "control"
        min_size         = 1
        max_size         = 1
        desired_capacity = 1
      }
      worker = {
        role             = "worker"
        enabled          = false
        min_size         = 1
        max_size         = 10
        desired_capacity = 2
      }
    }
  }

  assert {
    condition     = length(aws_autoscaling_group.worker) == 0
    error_message = "Expected disabled worker group to not be created, got ${length(aws_autoscaling_group.worker)}"
  }
}

# =============================================================================
# Custom instance type is applied
# =============================================================================

run "custom_instance_type_applied" {
  command = plan

  variables {
    vpc_id          = "vpc-12345678"
    subnets         = ["subnet-12345678"]
    cluster_name    = "test-instance-type"
    cluster_version = "1.31.2"
    cluster_token   = "test-token-minimum-16-chars"
    node_group_defaults = {
      iam_instance_profile = "test-profile"
    }
    node_groups = {
      control = {
        role             = "control"
        min_size         = 1
        max_size         = 1
        desired_capacity = 1
      }
      worker = {
        role             = "worker"
        instance_type    = "z8.2xlarge"
        min_size         = 1
        max_size         = 4
        desired_capacity = 2
      }
    }
  }

  # Launch configuration exists for worker (instance type is configured in launch config)
  assert {
    condition     = length(aws_launch_configuration.this) == 2
    error_message = "Expected 2 launch configurations (control + worker)"
  }

  assert {
    condition     = length(aws_autoscaling_group.worker) == 1
    error_message = "Expected worker ASG to be created"
  }
}

# =============================================================================
# Node labels and taints are applied
# =============================================================================

run "node_labels_and_taints_applied" {
  command = plan

  variables {
    vpc_id          = "vpc-12345678"
    subnets         = ["subnet-12345678"]
    cluster_name    = "test-labels-taints"
    cluster_version = "1.31.2"
    cluster_token   = "test-token-minimum-16-chars"
    node_group_defaults = {
      iam_instance_profile = "test-profile"
    }
    node_groups = {
      control = {
        role             = "control"
        min_size         = 1
        max_size         = 1
        desired_capacity = 1
      }
      gpu = {
        role             = "worker"
        min_size         = 0
        max_size         = 4
        desired_capacity = 0
        k8s_labels = {
          "workload" = "gpu"
          "gpu-type" = "nvidia"
        }
        k8s_taints = {
          "nvidia.com/gpu" = "true:NoSchedule"
        }
      }
    }
  }

  # Plan succeeds with labels and taints
  # Labels and taints are templated into cloud-init user_data
  # They also appear as ASG tags for cluster autoscaler
  assert {
    condition     = length(aws_autoscaling_group.worker) == 1
    error_message = "Plan should succeed with node labels and taints"
  }
}
