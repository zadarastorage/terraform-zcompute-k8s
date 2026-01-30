# Helm Edge Cases Tests (MERGE-04)
# Purpose: Test edge case behaviors for Helm configuration merge
#
# These tests cover boundary conditions and special cases:
# - null values to disable charts
# - empty config blocks
# - enabled=false flag
# - adding new charts alongside defaults
# - type validation (expect_failures)

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

# Test Case 1: Setting chart to null disables it entirely
# null should remove the chart from the merged output
run "helm_null_in_user_config" {
  command = plan

  variables {
    test_cluster_helm = {
      # Disable flannel by setting to null
      flannel = null
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

  # Verify flannel is removed from merged output
  assert {
    condition     = !contains(keys(output.cluster_helm_merged), "flannel")
    error_message = "Chart set to null should be excluded from merged output"
  }

  # Verify other charts still present
  assert {
    condition     = contains(keys(output.cluster_helm_merged), "cluster-autoscaler")
    error_message = "Other charts should still be present when one is nulled"
  }
}

# Test Case 2: Empty config block should NOT wipe defaults
# User provides config = {} should preserve default config
run "helm_empty_config_override" {
  command = plan

  variables {
    test_cluster_helm = {
      cluster-autoscaler = {
        config = {}
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

  # Empty config should merge with defaults, preserving them
  assert {
    condition     = try(output.cluster_helm_merged["cluster-autoscaler"].config.awsRegion, null) != null
    error_message = "Empty config override should preserve default config.awsRegion"
  }

  assert {
    condition     = try(output.cluster_helm_merged["cluster-autoscaler"].config.autoDiscovery.clusterName, null) != null
    error_message = "Empty config override should preserve default config.autoDiscovery"
  }
}

# Test Case 3: enabled=false disables chart
# Chart with enabled=false should be excluded from merged output
run "helm_enabled_false" {
  command = plan

  variables {
    test_cluster_helm = {
      flannel = {
        enabled = false
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

  # Verify flannel is excluded when enabled=false
  assert {
    condition     = !contains(keys(output.cluster_helm_merged), "flannel")
    error_message = "Chart with enabled=false should be excluded from merged output"
  }

  # Verify other charts still present
  assert {
    condition     = contains(keys(output.cluster_helm_merged), "aws-ebs-csi-driver")
    error_message = "Other charts should still be present when one is disabled"
  }
}

# Test Case 4: Adding new chart with full config preserves all defaults
# New chart addition should not affect existing default charts
run "helm_add_new_chart_with_config" {
  command = plan

  variables {
    test_cluster_helm = {
      # Add a completely new chart
      custom-metrics-server = {
        order           = 20
        wait            = true
        repository_name = "metrics-server"
        repository_url  = "https://kubernetes-sigs.github.io/metrics-server/"
        chart           = "metrics-server"
        version         = "3.12.0"
        namespace       = "kube-system"
        config = {
          replicas = 2
          args     = ["--kubelet-insecure-tls"]
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

  # Verify new chart is present with all its properties
  assert {
    condition     = output.cluster_helm_merged["custom-metrics-server"].chart == "metrics-server"
    error_message = "New chart should be present in merged output"
  }

  assert {
    condition     = output.cluster_helm_merged["custom-metrics-server"].config.replicas == 2
    error_message = "New chart should have its config preserved"
  }

  # Verify ALL default charts are still present with their configs intact
  assert {
    condition     = output.cluster_helm_merged["flannel"].chart == "flannel"
    error_message = "Default flannel chart should still exist alongside new chart"
  }

  assert {
    condition     = output.cluster_helm_merged["cluster-autoscaler"].config.awsRegion == "us-east-1"
    error_message = "Default cluster-autoscaler config should be preserved when adding new chart"
  }

  assert {
    condition     = try(output.cluster_helm_merged["aws-ebs-csi-driver"].config.storageClasses, null) != null
    error_message = "Default aws-ebs-csi-driver config should be preserved when adding new chart"
  }
}

# Test Case 5: Verify calico is disabled by default (enabled=false in defaults)
# This confirms the enabled flag works in default configuration
run "helm_default_disabled_chart" {
  command = plan

  variables {
    test_cluster_helm = {}
    test_node_groups = {
      control = {
        role         = "control"
        min_size     = 1
        max_size     = 1
        desired_size = 1
      }
    }
  }

  # Calico has enabled=false in defaults, should not appear in merged output
  assert {
    condition     = !contains(keys(output.cluster_helm_merged), "calico")
    error_message = "Calico should be excluded by default (enabled=false in defaults)"
  }

  # Flannel should be present (enabled=true in defaults)
  assert {
    condition     = contains(keys(output.cluster_helm_merged), "flannel")
    error_message = "Flannel should be present (enabled=true in defaults)"
  }
}

# Test Case 6: User can enable a default-disabled chart
# Setting enabled=true on calico should include it
run "helm_enable_default_disabled_chart" {
  command = plan

  variables {
    test_cluster_helm = {
      calico = {
        enabled = true
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

  # Calico should now be included
  assert {
    condition     = contains(keys(output.cluster_helm_merged), "calico")
    error_message = "User should be able to enable calico by setting enabled=true"
  }

  # Calico should have its default config preserved
  assert {
    condition     = try(output.cluster_helm_merged["calico"].config.installation.calicoNetwork.bgp, null) == "Enabled"
    error_message = "Enabled calico should have its default config preserved"
  }
}
