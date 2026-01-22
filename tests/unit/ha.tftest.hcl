# High-availability configuration tests for terraform-k8s-zcompute module
# Verifies HA configurations with multiple control plane nodes and worker groups

mock_provider "aws" {
  source = "tests/unit/mocks"
}

# =============================================================================
# HA control plane creates 3-node cluster
# =============================================================================

run "ha_control_plane_creates_three_nodes" {
  command = plan

  variables {
    vpc_id          = "vpc-12345678"
    subnets         = ["subnet-12345678"]
    cluster_name    = "test-ha"
    cluster_version = "1.31.2"
    cluster_token   = "test-token-minimum-16-chars"
    node_group_defaults = {
      iam_instance_profile = "test-profile"
    }
    node_groups = {
      control = {
        role             = "control"
        min_size         = 3
        max_size         = 3
        desired_capacity = 3
      }
    }
  }

  assert {
    condition     = aws_autoscaling_group.control["control"].min_size == 3
    error_message = "Expected min_size == 3, got ${aws_autoscaling_group.control["control"].min_size}"
  }

  assert {
    condition     = aws_autoscaling_group.control["control"].max_size == 3
    error_message = "Expected max_size == 3, got ${aws_autoscaling_group.control["control"].max_size}"
  }

  assert {
    condition     = aws_autoscaling_group.control["control"].desired_capacity == 3
    error_message = "Expected desired_capacity == 3, got ${aws_autoscaling_group.control["control"].desired_capacity}"
  }
}

# =============================================================================
# HA with workers creates both control plane and worker ASGs
# =============================================================================

run "ha_with_workers_creates_both_asgs" {
  command = plan

  variables {
    vpc_id          = "vpc-12345678"
    subnets         = ["subnet-12345678"]
    cluster_name    = "test-ha-workers"
    cluster_version = "1.31.2"
    cluster_token   = "test-token-minimum-16-chars"
    node_group_defaults = {
      iam_instance_profile = "test-profile"
    }
    node_groups = {
      control = {
        role             = "control"
        min_size         = 3
        max_size         = 3
        desired_capacity = 3
      }
      worker = {
        role             = "worker"
        min_size         = 2
        max_size         = 10
        desired_capacity = 2
      }
    }
  }

  assert {
    condition     = length(aws_autoscaling_group.control) == 1
    error_message = "Expected exactly one control plane ASG, got ${length(aws_autoscaling_group.control)}"
  }

  assert {
    condition     = length(aws_autoscaling_group.worker) == 1
    error_message = "Expected exactly one worker ASG, got ${length(aws_autoscaling_group.worker)}"
  }

  assert {
    condition     = aws_autoscaling_group.worker["worker"].desired_capacity == 2
    error_message = "Expected worker desired_capacity == 2, got ${aws_autoscaling_group.worker["worker"].desired_capacity}"
  }
}

# =============================================================================
# Multiple worker groups creates multiple ASGs
# =============================================================================

run "multiple_worker_groups_creates_multiple_asgs" {
  command = plan

  variables {
    vpc_id          = "vpc-12345678"
    subnets         = ["subnet-12345678"]
    cluster_name    = "test-multi-worker"
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
        min_size         = 1
        max_size         = 10
        desired_capacity = 3
      }
      gpu = {
        role             = "worker"
        min_size         = 0
        max_size         = 4
        desired_capacity = 0
      }
    }
  }

  assert {
    condition     = length(aws_autoscaling_group.worker) == 2
    error_message = "Expected two worker ASGs (worker + gpu), got ${length(aws_autoscaling_group.worker)}"
  }
}
