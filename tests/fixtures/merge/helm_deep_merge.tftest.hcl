# Helm Deep Merge Regression Tests (MERGE-04)
# Purpose: Validate that deep merge correctly preserves nested configuration
#
# These tests would FAIL with shallow merge (pre-08-02 fix) but PASS with deep merge.
# They serve as regression tests to ensure the merge bug is not reintroduced.
#
# Requirements covered:
# - Partial overrides preserve sibling keys at all nesting levels
# - User values win at leaf level in merge conflicts
# - Default configuration is preserved when user provides partial overrides

mock_provider "aws" {
  # Mock AWS provider for plan-only testing - no real infrastructure

  # Mock Ubuntu AMI data - returns mock IDs for all 6 LTS versions
  override_data {
    target = module.k8s.data.aws_ami_ids.ubuntu[0]
    values = { ids = ["ami-mock-ubuntu-0"] }
  }
  override_data {
    target = module.k8s.data.aws_ami_ids.ubuntu[1]
    values = { ids = ["ami-mock-ubuntu-1"] }
  }
  override_data {
    target = module.k8s.data.aws_ami_ids.ubuntu[2]
    values = { ids = ["ami-mock-ubuntu-2"] }
  }
  override_data {
    target = module.k8s.data.aws_ami_ids.ubuntu[3]
    values = { ids = ["ami-mock-ubuntu-3"] }
  }
  override_data {
    target = module.k8s.data.aws_ami_ids.ubuntu[4]
    values = { ids = ["ami-mock-ubuntu-4"] }
  }
  override_data {
    target = module.k8s.data.aws_ami_ids.ubuntu[5]
    values = { ids = ["ami-mock-ubuntu-5"] }
  }

  # Mock Debian AMI data - returns mock IDs for all 4 LTS versions
  override_data {
    target = module.k8s.data.aws_ami_ids.debian[0]
    values = { ids = ["ami-mock-debian-0"] }
  }
  override_data {
    target = module.k8s.data.aws_ami_ids.debian[1]
    values = { ids = ["ami-mock-debian-1"] }
  }
  override_data {
    target = module.k8s.data.aws_ami_ids.debian[2]
    values = { ids = ["ami-mock-debian-2"] }
  }
  override_data {
    target = module.k8s.data.aws_ami_ids.debian[3]
    values = { ids = ["ami-mock-debian-3"] }
  }
}

# Test Case 1: Partial override preserves default sibling keys
# User provides only podCidr, namespace and repository_url should be preserved
run "helm_partial_override_preserves_defaults" {
  command = plan

  variables {
    test_cluster_helm = {
      flannel = {
        config = {
          podCidr = "10.0.0.0/8"
        }
      }
    }
    test_node_groups = {
      control = {
        role         = "control"
        min_size     = 1
        max_size     = 1
        desired_size = 1
      }
    }
  }

  # Verify user's podCidr override is applied
  assert {
    condition     = output.cluster_helm_merged["flannel"].config.podCidr == "10.0.0.0/8"
    error_message = "User's podCidr override should be applied"
  }

  # Verify default namespace is preserved (not wiped by partial config override)
  assert {
    condition     = output.cluster_helm_merged["flannel"].namespace == "kube-flannel"
    error_message = "REGRESSION: Default flannel.namespace was lost. Deep merge should preserve chart-level defaults when user provides partial config override."
  }

  # Verify default repository_url is preserved
  assert {
    condition     = output.cluster_helm_merged["flannel"].repository_url == "https://flannel-io.github.io/flannel"
    error_message = "REGRESSION: Default flannel.repository_url was lost. Deep merge should preserve chart-level defaults."
  }

  # Verify chart version preserved
  assert {
    condition     = output.cluster_helm_merged["flannel"].version == "v0.26.2"
    error_message = "REGRESSION: Default flannel.version was lost."
  }
}

# Test Case 2: Nested override preserves sibling config keys
# User provides controller.region, sidecars and storageClasses should be preserved
run "helm_nested_override_preserves_siblings" {
  command = plan

  variables {
    test_cluster_helm = {
      aws-ebs-csi-driver = {
        config = {
          controller = {
            region = "us-west-2"
          }
        }
      }
    }
    test_node_groups = {
      control = {
        role         = "control"
        min_size     = 1
        max_size     = 1
        desired_size = 1
      }
    }
  }

  # Verify user's region override is applied
  assert {
    condition     = output.cluster_helm_merged["aws-ebs-csi-driver"].config.controller.region == "us-west-2"
    error_message = "User's controller.region override should be applied"
  }

  # Verify sidecars config is preserved (sibling of controller)
  assert {
    condition     = try(output.cluster_helm_merged["aws-ebs-csi-driver"].config.sidecars.provisioner.additionalArgs, null) != null
    error_message = "REGRESSION: config.sidecars was lost when user overrode controller.region. Deep merge should preserve sibling keys."
  }

  # Verify storageClasses config is preserved (sibling of controller)
  assert {
    condition     = try(length(output.cluster_helm_merged["aws-ebs-csi-driver"].config.storageClasses), 0) > 0
    error_message = "REGRESSION: config.storageClasses was lost when user overrode controller.region. Deep merge should preserve sibling keys."
  }

  # Verify volumeSnapshotClasses is also preserved
  assert {
    condition     = try(length(output.cluster_helm_merged["aws-ebs-csi-driver"].config.volumeSnapshotClasses), 0) > 0
    error_message = "REGRESSION: config.volumeSnapshotClasses was lost when user overrode controller.region."
  }
}

# Test Case 3: Multiple level override - user overrides at chart level and config level
# Both levels should be correctly merged
run "helm_multiple_level_override" {
  command = plan

  variables {
    test_cluster_helm = {
      cluster-autoscaler = {
        # Chart-level override
        namespace = "autoscaler-ns"
        # Config-level override
        config = {
          awsRegion = "eu-west-1"
        }
      }
    }
    test_node_groups = {
      control = {
        role         = "control"
        min_size     = 1
        max_size     = 1
        desired_size = 1
      }
    }
  }

  # Verify chart-level override (namespace)
  assert {
    condition     = output.cluster_helm_merged["cluster-autoscaler"].namespace == "autoscaler-ns"
    error_message = "User's namespace override should be applied at chart level"
  }

  # Verify config-level override (awsRegion)
  assert {
    condition     = output.cluster_helm_merged["cluster-autoscaler"].config.awsRegion == "eu-west-1"
    error_message = "User's awsRegion override should be applied at config level"
  }

  # Verify default config keys preserved despite config override
  assert {
    condition     = try(output.cluster_helm_merged["cluster-autoscaler"].config.autoDiscovery.clusterName, null) != null
    error_message = "REGRESSION: config.autoDiscovery was lost when user overrode awsRegion. Deep merge should preserve sibling config keys."
  }

  # Verify default chart properties preserved despite namespace override
  assert {
    condition     = output.cluster_helm_merged["cluster-autoscaler"].chart == "cluster-autoscaler"
    error_message = "REGRESSION: chart name was lost when user overrode namespace."
  }

  # Verify other default config keys preserved
  assert {
    condition     = try(output.cluster_helm_merged["cluster-autoscaler"].config.nodeSelector, null) != null
    error_message = "REGRESSION: config.nodeSelector was lost during merge."
  }
}
