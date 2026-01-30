# Cloud-init Concatenation Tests (MERGE-02)
# Purpose: Verify and document that cloud-init concatenation works correctly
#
# These tests confirm that cloud-init uses concatenation (not merge) which is
# the EXPECTED and CORRECT behavior. Unlike MERGE-01 (Helm), this is not a bug.
#
# Expected behavior: All cloud-init tests PASS (documenting working functionality)
#
# Cloud-init concatenation logic (data_cloudinit.tf lines 41-68):
#   concat(
#     [module-generated parts],
#     local.cloudinit_os["common"],
#     local.cloudinit_os[os],
#     local.cloudinit_flavor[flavor],
#     local.cloudinit_cfg[config],
#     try(each.value.cloudinit_config, [])  <- user parts appended here
#   )
#
# This is correct: user parts are ADDED to the list, not merged/replaced

mock_provider "aws" {
  # Mock AWS provider for plan-only testing - no real infrastructure

  # Mock Ubuntu AMI data - returns list with one AMI ID per LTS version (6 versions)
  override_data {
    target = module.k8s.data.aws_ami_ids.ubuntu[0]
    values = { ids = ["ami-mock-ubuntu-noble"] }
  }
  override_data {
    target = module.k8s.data.aws_ami_ids.ubuntu[1]
    values = { ids = ["ami-mock-ubuntu-jammy"] }
  }
  override_data {
    target = module.k8s.data.aws_ami_ids.ubuntu[2]
    values = { ids = ["ami-mock-ubuntu-focal"] }
  }
  override_data {
    target = module.k8s.data.aws_ami_ids.ubuntu[3]
    values = { ids = ["ami-mock-ubuntu-bionic"] }
  }
  override_data {
    target = module.k8s.data.aws_ami_ids.ubuntu[4]
    values = { ids = ["ami-mock-ubuntu-xenial"] }
  }
  override_data {
    target = module.k8s.data.aws_ami_ids.ubuntu[5]
    values = { ids = ["ami-mock-ubuntu-trusty"] }
  }

  # Mock Debian AMI data - returns list with one AMI ID per LTS version (4 versions)
  override_data {
    target = module.k8s.data.aws_ami_ids.debian[0]
    values = { ids = ["ami-mock-debian-bookworm"] }
  }
  override_data {
    target = module.k8s.data.aws_ami_ids.debian[1]
    values = { ids = ["ami-mock-debian-bullseye"] }
  }
  override_data {
    target = module.k8s.data.aws_ami_ids.debian[2]
    values = { ids = ["ami-mock-debian-buster"] }
  }
  override_data {
    target = module.k8s.data.aws_ami_ids.debian[3]
    values = { ids = ["ami-mock-debian-stretch"] }
  }
}

# Test Case 1: User cloud-init parts are appended alongside module parts
# Verifies that user-provided cloud-init config appears in final result
run "cloudinit_user_parts_appended" {
  command = plan

  variables {
    test_cluster_helm = {}
    test_node_groups = {
      control = {
        role         = "control"
        min_size     = 1
        max_size     = 1
        desired_size = 1
        cloudinit_config = [
          {
            order        = 50
            filename     = "custom-setup.sh"
            content_type = "text/x-shellscript"
            content      = "#!/bin/bash\necho 'Custom user setup script'"
          }
        ]
      }
    }
  }

  # Verify module parts are present (order 0 parts from module)
  assert {
    condition     = length([for p in output.cloudinit_parts_debug.control : p if p.source == "module-generated"]) > 0
    error_message = "Module-generated cloud-init parts should be present"
  }

  # Verify user parts are appended (source should be "user-provided")
  assert {
    condition     = length([for p in output.cloudinit_parts_debug.control : p if p.source == "user-provided"]) > 0
    error_message = "User-provided cloud-init parts should be appended to the list"
  }

  # Verify the specific user filename appears
  assert {
    condition     = length([for p in output.cloudinit_parts_debug.control : p if p.filename == "custom-setup.sh"]) > 0
    error_message = "User's custom-setup.sh should appear in cloud-init parts"
  }
}

# Test Case 2: Cloud-init parts respect ordering
# Verifies that the 'order' key controls sequencing of parts
run "cloudinit_order_respected" {
  command = plan

  variables {
    test_cluster_helm = {}
    test_node_groups = {
      control = {
        role         = "control"
        min_size     = 1
        max_size     = 1
        desired_size = 1
        cloudinit_config = [
          {
            order        = 5
            filename     = "early-setup.sh"
            content_type = "text/x-shellscript"
            content      = "#!/bin/bash\necho 'Runs early'"
          }
        ]
      }
    }
  }

  # Verify user part has order=5 as specified
  assert {
    condition     = length([for p in output.cloudinit_parts_debug.control : p if p.filename == "early-setup.sh" && p.order == 5]) > 0
    error_message = "User part should have order=5 as specified"
  }

  # Verify module parts with order=0 exist (they run before order=5)
  assert {
    condition     = length([for p in output.cloudinit_parts_debug.control : p if p.order == 0]) > 0
    error_message = "Module parts with order=0 should exist (run before user's order=5)"
  }

  # Verify there are parts with higher order (order=10, 19, 20, 30 from module)
  assert {
    condition     = length([for p in output.cloudinit_parts_debug.control : p if p.order > 5]) > 0
    error_message = "Module parts with order > 5 should exist (run after user's order=5)"
  }
}

# Test Case 3: Multiple user cloud-init parts all concatenated correctly
# Verifies that all user-provided parts are included
run "cloudinit_multiple_user_parts" {
  command = plan

  variables {
    test_cluster_helm = {}
    test_node_groups = {
      control = {
        role         = "control"
        min_size     = 1
        max_size     = 1
        desired_size = 1
        cloudinit_config = [
          {
            order        = 25
            filename     = "user-part-a.sh"
            content_type = "text/x-shellscript"
            content      = "#!/bin/bash\necho 'Part A'"
          },
          {
            order        = 26
            filename     = "user-part-b.sh"
            content_type = "text/x-shellscript"
            content      = "#!/bin/bash\necho 'Part B'"
          },
          {
            order        = 27
            filename     = "user-part-c.yaml"
            content_type = "text/cloud-config"
            content      = "#cloud-config\nruncmd:\n  - echo 'Part C'"
          }
        ]
      }
    }
  }

  # Count user-provided parts - should be exactly 3
  assert {
    condition     = length([for p in output.cloudinit_parts_debug.control : p if p.source == "user-provided"]) == 3
    error_message = "All 3 user-provided cloud-init parts should be present"
  }

  # Verify each specific part is present
  assert {
    condition     = length([for p in output.cloudinit_parts_debug.control : p if p.filename == "user-part-a.sh"]) == 1
    error_message = "user-part-a.sh should be present"
  }

  assert {
    condition     = length([for p in output.cloudinit_parts_debug.control : p if p.filename == "user-part-b.sh"]) == 1
    error_message = "user-part-b.sh should be present"
  }

  assert {
    condition     = length([for p in output.cloudinit_parts_debug.control : p if p.filename == "user-part-c.yaml"]) == 1
    error_message = "user-part-c.yaml should be present"
  }

  # Verify module parts are still present (concatenation, not replacement)
  assert {
    condition     = length([for p in output.cloudinit_parts_debug.control : p if p.source != "user-provided"]) > 0
    error_message = "Module cloud-init parts should still be present alongside user parts"
  }

  # Verify ordering is preserved (a=25, b=26, c=27)
  assert {
    condition     = length([for p in output.cloudinit_parts_debug.control : p if p.filename == "user-part-a.sh" && p.order == 25]) == 1
    error_message = "user-part-a.sh should have order=25"
  }

  assert {
    condition     = length([for p in output.cloudinit_parts_debug.control : p if p.filename == "user-part-b.sh" && p.order == 26]) == 1
    error_message = "user-part-b.sh should have order=26"
  }
}
