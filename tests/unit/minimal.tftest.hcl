# Minimal configuration tests for terraform-k8s-zcompute module
# Verifies the simplest working configuration creates expected resources:
# - Single control plane ASG
# - No worker ASGs
# - Load balancer for API access
# - Security group

mock_provider "aws" {
  source = "tests/unit/mocks"
}

# Common variables for minimal configuration
variables {
  vpc_id          = "vpc-12345678"
  subnets         = ["subnet-12345678"]
  cluster_name    = "test-minimal"
  cluster_version = "1.31.2"
  cluster_token   = "test-token-minimum-16-chars"
  node_group_defaults = {
    iam_instance_profile = "test-profile"
  }
  node_groups = {
    control = {
      role         = "control"
      min_size     = 1
      max_size     = 1
      desired_size = 1
    }
  }
}

# =============================================================================
# Minimal configuration creates exactly one control plane ASG
# =============================================================================

run "minimal_creates_one_control_plane_asg" {
  command = plan

  assert {
    condition     = length(aws_autoscaling_group.control) == 1
    error_message = "Expected exactly one control plane ASG, got ${length(aws_autoscaling_group.control)}"
  }

  assert {
    condition     = aws_autoscaling_group.control["control"].min_size == 1
    error_message = "Expected min_size == 1, got ${aws_autoscaling_group.control["control"].min_size}"
  }

  assert {
    condition     = aws_autoscaling_group.control["control"].max_size == 1
    error_message = "Expected max_size == 1, got ${aws_autoscaling_group.control["control"].max_size}"
  }
}

# =============================================================================
# Minimal configuration creates no worker ASGs when not configured
# =============================================================================

run "minimal_creates_no_worker_asgs" {
  command = plan

  assert {
    condition     = length(aws_autoscaling_group.worker) == 0
    error_message = "Expected no worker ASGs, got ${length(aws_autoscaling_group.worker)}"
  }
}

# =============================================================================
# Minimal configuration creates NLB for Kubernetes API access
# =============================================================================

run "minimal_creates_load_balancer" {
  command = plan

  assert {
    condition     = aws_lb.kube_api.load_balancer_type == "network"
    error_message = "Expected network load balancer type"
  }

  assert {
    condition     = aws_lb_target_group.kube_api.port == 6443
    error_message = "Expected target group port 6443, got ${aws_lb_target_group.kube_api.port}"
  }

  assert {
    condition     = aws_lb_target_group.kube_api.protocol == "TCP"
    error_message = "Expected TCP protocol for target group"
  }
}

# =============================================================================
# Minimal configuration creates security group for cluster
# =============================================================================

run "minimal_creates_security_group" {
  command = plan

  assert {
    condition     = aws_security_group.k8s.name == "test-minimal_k8s"
    error_message = "Expected security group named test-minimal_k8s"
  }
}
