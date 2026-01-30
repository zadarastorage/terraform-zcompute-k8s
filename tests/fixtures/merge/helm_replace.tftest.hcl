# Helm Replace Behavior Tests (MERGE-04)
# Purpose: Document actual replacement behavior in Helm configuration merge
#
# NOTE: The _replace sentinel key was documented as a planned feature but NOT implemented
# due to Terraform type system limitations. These tests verify the actual merge behavior:
# - User values win at leaf level in merge conflicts
# - Chart-level properties can be overridden individually
# - Config keys are merged, not replaced wholesale

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

# Test Case 1: User config values win at leaf level
# When user provides same key as default, user value takes precedence
run "helm_user_config_wins_at_leaf" {
  command = plan

  variables {
    test_cluster_helm_yaml = <<-YAML
      cluster-autoscaler:
        config:
          # Override the default awsRegion (us-east-1 -> eu-central-1)
          awsRegion: "eu-central-1"
          # Override the default cloudConfigPath
          cloudConfigPath: "/custom/cloud.conf"
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

  # User's awsRegion should override default
  assert {
    condition     = output.cluster_helm_merged["cluster-autoscaler"].config.awsRegion == "eu-central-1"
    error_message = "User's awsRegion should override default value"
  }

  # User's cloudConfigPath should override default
  assert {
    condition     = output.cluster_helm_merged["cluster-autoscaler"].config.cloudConfigPath == "/custom/cloud.conf"
    error_message = "User's cloudConfigPath should override default value"
  }

  # Non-overridden keys should retain defaults
  assert {
    condition     = try(output.cluster_helm_merged["cluster-autoscaler"].config.autoDiscovery.clusterName, null) != null
    error_message = "Non-overridden config keys should retain default values"
  }

  assert {
    condition     = try(output.cluster_helm_merged["cluster-autoscaler"].config.nodeSelector, null) != null
    error_message = "Non-overridden config.nodeSelector should retain default value"
  }
}

# Test Case 2: Chart-level properties can be overridden individually
# User can override order, namespace, version without losing other properties
run "helm_chart_level_override" {
  command = plan

  variables {
    test_cluster_helm_yaml = <<-YAML
      flannel:
        # Override chart-level properties
        order: 99
        namespace: custom-flannel
        version: "v0.99.0"
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

  # User's order should override default
  assert {
    condition     = output.cluster_helm_merged["flannel"].order == 99
    error_message = "User's order should override default"
  }

  # User's namespace should override default
  assert {
    condition     = output.cluster_helm_merged["flannel"].namespace == "custom-flannel"
    error_message = "User's namespace should override default"
  }

  # User's version should override default
  assert {
    condition     = output.cluster_helm_merged["flannel"].version == "v0.99.0"
    error_message = "User's version should override default"
  }

  # Non-overridden chart properties should be preserved
  assert {
    condition     = output.cluster_helm_merged["flannel"].chart == "flannel"
    error_message = "Non-overridden chart property should retain default"
  }

  assert {
    condition     = output.cluster_helm_merged["flannel"].repository_url == "https://flannel-io.github.io/flannel"
    error_message = "Non-overridden repository_url should retain default"
  }

  # Config should still be present (not wiped by chart-level overrides)
  assert {
    condition     = try(output.cluster_helm_merged["flannel"].config.podCidr, null) != null
    error_message = "Config should be preserved when overriding chart-level properties"
  }
}

# Test Case 3: Config merge behavior - keys merge at first level
# The current implementation merges config keys at the first level
run "helm_config_first_level_merge" {
  command = plan

  variables {
    test_cluster_helm_yaml = <<-YAML
      aws-ebs-csi-driver:
        config:
          # Override controller block entirely (replaces nested keys)
          controller:
            region: "ap-south-1"
            logLevel: 5
          # Add new config key
          customKey: customValue
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

  # User's controller override should be applied
  assert {
    condition     = output.cluster_helm_merged["aws-ebs-csi-driver"].config.controller.region == "ap-south-1"
    error_message = "User's controller.region should be applied"
  }

  assert {
    condition     = output.cluster_helm_merged["aws-ebs-csi-driver"].config.controller.logLevel == 5
    error_message = "User's controller.logLevel should be applied"
  }

  # New config key should be added
  assert {
    condition     = output.cluster_helm_merged["aws-ebs-csi-driver"].config.customKey == "customValue"
    error_message = "New config key should be added to merged config"
  }

  # Sibling config keys should be preserved (sidecars, storageClasses)
  assert {
    condition     = try(output.cluster_helm_merged["aws-ebs-csi-driver"].config.sidecars, null) != null
    error_message = "Sibling config.sidecars should be preserved"
  }

  assert {
    condition     = try(output.cluster_helm_merged["aws-ebs-csi-driver"].config.storageClasses, null) != null
    error_message = "Sibling config.storageClasses should be preserved"
  }
}

# Test Case 4: Multiple charts overridden simultaneously
# User can override multiple charts in single cluster_helm_yaml input
run "helm_multiple_charts_override" {
  command = plan

  variables {
    test_cluster_helm_yaml = <<-YAML
      flannel:
        config:
          podCidr: "10.200.0.0/16"
      cluster-autoscaler:
        namespace: scaling
        config:
          awsRegion: "eu-west-2"
      aws-ebs-csi-driver:
        config:
          controller:
            region: "eu-west-2"
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

  # All overrides should be applied
  assert {
    condition     = output.cluster_helm_merged["flannel"].config.podCidr == "10.200.0.0/16"
    error_message = "Flannel podCidr override should be applied"
  }

  assert {
    condition     = output.cluster_helm_merged["cluster-autoscaler"].namespace == "scaling"
    error_message = "Cluster-autoscaler namespace override should be applied"
  }

  assert {
    condition     = output.cluster_helm_merged["cluster-autoscaler"].config.awsRegion == "eu-west-2"
    error_message = "Cluster-autoscaler awsRegion override should be applied"
  }

  assert {
    condition     = output.cluster_helm_merged["aws-ebs-csi-driver"].config.controller.region == "eu-west-2"
    error_message = "EBS CSI driver controller.region override should be applied"
  }

  # Non-overridden charts should be completely untouched
  assert {
    condition     = output.cluster_helm_merged["aws-load-balancer-controller"].config.clusterName != null
    error_message = "Non-overridden aws-load-balancer-controller should be completely untouched"
  }

  # Each overridden chart should still have its default siblings preserved
  assert {
    condition     = try(output.cluster_helm_merged["cluster-autoscaler"].config.autoDiscovery, null) != null
    error_message = "Cluster-autoscaler default config.autoDiscovery should be preserved"
  }
}
