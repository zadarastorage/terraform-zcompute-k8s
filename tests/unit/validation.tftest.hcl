# Variable validation tests for terraform-k8s-zcompute module
# Tests boundary conditions for input variables with validation rules

mock_provider "aws" {
  source = "tests/unit/mocks"
}

# =============================================================================
# trusted_ami_owners validation tests
# Variable accepts: 32-char hex (zCompute), 12-digit AWS account ID, or "self"
# =============================================================================

# Invalid value: neither 32-char hex, 12-digit number, nor "self"
run "invalid_ami_owner_rejected" {
  command = plan

  variables {
    vpc_id             = "vpc-12345678"
    subnets            = ["subnet-12345678"]
    cluster_name       = "test-cluster"
    cluster_version    = "1.31.2"
    cluster_token      = "test-token-minimum-16-chars"
    trusted_ami_owners = ["invalid-owner"]
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

  expect_failures = [var.trusted_ami_owners]
}

# Valid: 32-character hex string (Zadara zCompute format)
run "valid_zcompute_ami_owner_accepted" {
  command = plan

  variables {
    vpc_id             = "vpc-12345678"
    subnets            = ["subnet-12345678"]
    cluster_name       = "test-cluster"
    cluster_version    = "1.31.2"
    cluster_token      = "test-token-minimum-16-chars"
    trusted_ami_owners = ["1234a701473b61af498f633abdc8c113"]
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
}

# Valid: 12-digit AWS account ID
run "valid_aws_account_id_accepted" {
  command = plan

  variables {
    vpc_id             = "vpc-12345678"
    subnets            = ["subnet-12345678"]
    cluster_name       = "test-cluster"
    cluster_version    = "1.31.2"
    cluster_token      = "test-token-minimum-16-chars"
    trusted_ami_owners = ["123456789012"]
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
}

# Valid: "self" keyword for owner's own AMIs
run "self_ami_owner_accepted" {
  command = plan

  variables {
    vpc_id             = "vpc-12345678"
    subnets            = ["subnet-12345678"]
    cluster_name       = "test-cluster"
    cluster_version    = "1.31.2"
    cluster_token      = "test-token-minimum-16-chars"
    trusted_ami_owners = ["self"]
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
}

# Valid: Empty list (backward compatibility - defaults to wildcard)
run "empty_ami_owners_accepted" {
  command = plan

  variables {
    vpc_id             = "vpc-12345678"
    subnets            = ["subnet-12345678"]
    cluster_name       = "test-cluster"
    cluster_version    = "1.31.2"
    cluster_token      = "test-token-minimum-16-chars"
    trusted_ami_owners = []
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
}

# =============================================================================
# cluster_token validation tests
# Token must be at least 16 characters for security
# =============================================================================

# Invalid: Token too short (< 16 chars)
run "short_cluster_token_rejected" {
  command = plan

  variables {
    vpc_id          = "vpc-12345678"
    subnets         = ["subnet-12345678"]
    cluster_name    = "test-cluster"
    cluster_version = "1.31.2"
    cluster_token   = "short"
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

  expect_failures = [var.cluster_token]
}

# Valid: Token with exactly 16 characters (minimum)
run "valid_cluster_token_accepted" {
  command = plan

  variables {
    vpc_id          = "vpc-12345678"
    subnets         = ["subnet-12345678"]
    cluster_name    = "test-cluster"
    cluster_version = "1.31.2"
    cluster_token   = "exactly16chars!!"
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
}
