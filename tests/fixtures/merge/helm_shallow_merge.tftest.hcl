# Helm Shallow Merge Limitation Tests (MERGE-01)
# Purpose: Document and demonstrate the shallow merge bug in Helm configuration
#
# These tests demonstrate that when users provide partial overrides to cluster_helm_yaml,
# the current two-level merge logic loses nested configuration keys.
#
# Expected behavior: Helm tests FAIL before fix, PASS after 08-02-PLAN fix
#
# Merge logic under test (data_cloudinit.tf line 57):
#   { for k, v in merge(local.cluster_helm_default, var.cluster_helm) :
#     k => merge(try(local.cluster_helm_default[k], {}), try(var.cluster_helm[k], {}))
#     if v != null && try(v.enabled, true) == true }
#
# Bug: Inner merge replaces entire sub-objects (like config) rather than deep merging

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

# Test Case 1: Overriding a nested config key loses sibling config keys
# Bug: User specifies custom awsRegion, loses autoDiscovery config
run "helm_override_loses_defaults" {
  command = plan

  variables {
    test_cluster_helm_yaml = <<-YAML
      cluster-autoscaler:
        config:
          awsRegion: "eu-west-1"
      YAML
    test_node_groups = {
      control = {
        role         = "control"
        min_size     = 1
        max_size     = 1
        desired_size = 1
      }
    }
  }

  # This assertion documents the BUG - the shallow merge replaces the entire config block
  # Default cluster-autoscaler has config.autoDiscovery.clusterName, but user only specifies awsRegion
  # With proper deep merge, autoDiscovery should be preserved
  # Current buggy behavior: entire config block replaced, autoDiscovery is lost
  assert {
    condition     = try(output.cluster_helm_merged["cluster-autoscaler"].config.autoDiscovery.clusterName, null) != null
    error_message = "MERGE-01 BUG CONFIRMED: cluster-autoscaler.config.autoDiscovery lost due to shallow merge. User's awsRegion override replaced the entire config block instead of deep merging."
  }

  # Additional assertion: verify user's override is present
  assert {
    condition     = try(output.cluster_helm_merged["cluster-autoscaler"].config.awsRegion, "") == "eu-west-1"
    error_message = "User's awsRegion override should be present in merged config"
  }

  # Verify other config keys also lost (nodeSelector, tolerations, etc.)
  assert {
    condition     = try(output.cluster_helm_merged["cluster-autoscaler"].config.nodeSelector, null) != null
    error_message = "MERGE-01 BUG CONFIRMED: cluster-autoscaler.config.nodeSelector lost due to shallow merge."
  }
}

# Test Case 2: Nested config object entirely replaced
# Bug: User specifies controller.region, loses sidecars, storageClasses, etc.
run "helm_override_nested_config_replaced" {
  command = plan

  variables {
    test_cluster_helm_yaml = <<-YAML
      aws-ebs-csi-driver:
        config:
          controller:
            region: "us-west-2"
      YAML
    test_node_groups = {
      control = {
        role         = "control"
        min_size     = 1
        max_size     = 1
        desired_size = 1
      }
    }
  }

  # This assertion documents the BUG - sidecars config is lost
  # With proper deep merge, sidecars should still contain provisioner and attacher config
  # Current buggy behavior: entire config block replaced, sidecars is null
  assert {
    condition     = try(output.cluster_helm_merged["aws-ebs-csi-driver"].config.sidecars.provisioner.additionalArgs, null) != null
    error_message = "MERGE-01 BUG CONFIRMED: aws-ebs-csi-driver.config.sidecars lost due to shallow merge. User's controller.region override replaced the entire config block instead of deep merging, losing sidecars configuration."
  }

  # Additional assertion: verify user's override is present
  assert {
    condition     = try(output.cluster_helm_merged["aws-ebs-csi-driver"].config.controller.region, "") == "us-west-2"
    error_message = "User's controller.region override should be present in merged config"
  }

  # Verify storageClasses also lost (another victim of shallow merge)
  assert {
    condition     = try(length(output.cluster_helm_merged["aws-ebs-csi-driver"].config.storageClasses), 0) > 0
    error_message = "MERGE-01 BUG CONFIRMED: aws-ebs-csi-driver.config.storageClasses lost due to shallow merge."
  }
}

# Test Case 3: Adding a new chart (positive test - should work correctly)
# This documents that adding new charts works fine - the bug only affects overrides
run "helm_add_new_chart" {
  command = plan

  variables {
    test_cluster_helm_yaml = <<-YAML
      custom-monitoring:
        order: 20
        wait: true
        repository_name: prometheus-community
        repository_url: "https://prometheus-community.github.io/helm-charts"
        chart: kube-prometheus-stack
        version: "45.0.0"
        namespace: monitoring
        config:
          prometheus:
            enabled: true
      YAML
    test_node_groups = {
      control = {
        role         = "control"
        min_size     = 1
        max_size     = 1
        desired_size = 1
      }
    }
  }

  # New charts should appear in merged result - this is expected to pass
  assert {
    condition     = try(output.cluster_helm_merged["custom-monitoring"].chart, "") == "kube-prometheus-stack"
    error_message = "New chart should appear in merged result"
  }

  # Verify the new chart has all its properties
  assert {
    condition     = try(output.cluster_helm_merged["custom-monitoring"].namespace, "") == "monitoring"
    error_message = "New chart should have its namespace preserved"
  }

  # Default charts should still exist
  assert {
    condition     = try(output.cluster_helm_merged.flannel.chart, "") == "flannel"
    error_message = "Default flannel chart should still exist alongside new chart"
  }
}
