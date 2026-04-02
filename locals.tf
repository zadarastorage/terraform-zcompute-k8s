# Bootstrap loader configuration
locals {
  bootstrap_base_url = "https://raw.githubusercontent.com/${var.github_org}/${var.github_repo}/${var.module_version}/scripts"

  # Role name mapping for script directories
  # cloud-init cluster_role "control" -> script dir "control-plane"
  # cloud-init cluster_role "worker" -> script dir "worker"
  role_script_dir = {
    control = "control-plane"
    worker  = "worker"
  }

  # Rendered bootstrap loader for each node group
  bootstrap_loader = {
    for ng_key, ng in local.node_groups : ng_key => templatefile(
      "${path.module}/files/bootstrap-loader.tftpl.sh",
      {
        module_version = var.module_version
        cluster_role   = local.role_script_dir[try(ng.role, "worker")]
        github_org     = var.github_org
        github_repo    = var.github_repo
      }
    )
  }
}

locals {
  tags = merge(
    var.tags,
  )

  tags_list = [
    for k, v in local.tags :
    { "key" : k, "value" : v }
  ]

  # GPU instance type metadata map
  gpu_instance_types = {
    "zgl4.7large"     = { gpu_model = "NVIDIA-L4", gpu_count = 1, pci_device_id = "10de:27b8" }
    "zgl4.7xlarge"    = { gpu_model = "NVIDIA-L4", gpu_count = 2, pci_device_id = "10de:27b8" }
    "zgl4.14xlarge"   = { gpu_model = "NVIDIA-L4", gpu_count = 4, pci_device_id = "10de:27b8" }
    "zgl40s.7large"   = { gpu_model = "NVIDIA-L40S", gpu_count = 1, pci_device_id = "10de:26b9" }
    "zgl40s.7xlarge"  = { gpu_model = "NVIDIA-L40S", gpu_count = 2, pci_device_id = "10de:26b9" }
    "zgl40s.14xlarge" = { gpu_model = "NVIDIA-L40S", gpu_count = 4, pci_device_id = "10de:26b9" }
    "zga16.7large"    = { gpu_model = "NVIDIA-A16", gpu_count = 1, pci_device_id = "10de:25b6" }
    "zga16.7xlarge"   = { gpu_model = "NVIDIA-A16", gpu_count = 2, pci_device_id = "10de:25b6" }
    "zga16.14xlarge"  = { gpu_model = "NVIDIA-A16", gpu_count = 4, pci_device_id = "10de:25b6" }
    "zga40.7large"    = { gpu_model = "NVIDIA-A40", gpu_count = 1, pci_device_id = "10de:2235" }
    "zga40.7xlarge"   = { gpu_model = "NVIDIA-A40", gpu_count = 2, pci_device_id = "10de:2235" }
    "zga40.14xlarge"  = { gpu_model = "NVIDIA-A40", gpu_count = 4, pci_device_id = "10de:2235" }
  }

  node_group_defaults = {
    enabled              = true
    desired_capacity     = 0
    instance_type        = var.default_instance_type
    root_volume_size     = 40
    root_volume_type     = null
    key_name             = null
    tags                 = {}
    feature_gates        = []
    security_group_rules = {}
  }

  node_groups = {
    for k, v in var.node_groups :
    k => merge(
      local.node_group_defaults,
      var.node_group_defaults,
      v,
      { security_group_rules = merge(
        lookup(local.node_group_defaults, "security_group_rules", {}),
        lookup(var.node_group_defaults, "security_group_rules", {}),
        lookup(v, "security_group_rules", {}),
      ) },
      { tags = merge(
        lookup(local.node_group_defaults, "tags", {}),
        lookup(var.node_group_defaults, "tags", {}),
        lookup(v, "tags", {}),
      ) },
      { cloudinit_config = concat(
        lookup(local.node_group_defaults, "cloudinit_config", []),
        lookup(var.node_group_defaults, "cloudinit_config", []),
        lookup(v, "cloudinit_config", []),
      ) },
      # GPU auto-detection: inject labels and taints based on instance_type
      local._node_group_gpu_overrides[k],
    )
  }

  # Resolve instance_type per node group (before GPU detection)
  _node_group_instance_types = {
    for k, v in var.node_groups :
    k => lower(try(v.instance_type, try(var.node_group_defaults.instance_type, var.default_instance_type)))
  }

  # GPU lookup per node group
  _node_group_gpu = {
    for k, v in local._node_group_instance_types :
    k => lookup(local.gpu_instance_types, v, null)
  }

  # Whether GPU auto-setup is enabled per node group
  _node_group_gpu_enabled = {
    for k, v in var.node_groups :
    k => (
      local._node_group_gpu[k] != null &&
      try(v.gpu_auto_setup, try(var.node_group_defaults.gpu_auto_setup, var.gpu_auto_setup))
    )
  }

  # Computed label/taint/tag overrides per node group
  _node_group_gpu_overrides = {
    for k, v in var.node_groups : k => (
      local._node_group_gpu_enabled[k] ? {
        k8s_labels = merge(
          lookup(local.node_group_defaults, "k8s_labels", {}),
          lookup(var.node_group_defaults, "k8s_labels", {}),
          lookup(v, "k8s_labels", {}),
          {
            "k8s.amazonaws.com/accelerator" = local._node_group_gpu[k].gpu_model
            "nvidia.com/gpu.count"          = tostring(local._node_group_gpu[k].gpu_count)
            "nvidia.com/gpu.product"        = local._node_group_gpu[k].gpu_model
          },
        )
        k8s_taints = merge(
          lookup(local.node_group_defaults, "k8s_taints", {}),
          lookup(var.node_group_defaults, "k8s_taints", {}),
          lookup(v, "k8s_taints", {}),
          try(v.gpu_taint_enabled, try(var.node_group_defaults.gpu_taint_enabled, var.gpu_taint_enabled)) ? {
            "nvidia.com/gpu" = "NoSchedule"
          } : {},
        )
        } : {
        k8s_labels = merge(
          lookup(local.node_group_defaults, "k8s_labels", {}),
          lookup(var.node_group_defaults, "k8s_labels", {}),
          lookup(v, "k8s_labels", {}),
        )
        k8s_taints = merge(
          lookup(local.node_group_defaults, "k8s_taints", {}),
          lookup(var.node_group_defaults, "k8s_taints", {}),
          lookup(v, "k8s_taints", {}),
        )
      }
    )
  }

  # GPU tags for ASG (in addition to auto-propagated k8s_labels)
  node_group_gpu_tags = {
    for k, v in local.node_groups : k => (
      local._node_group_gpu_enabled[k] ? {
        "zadara.com/k8s/gpu"       = local._node_group_gpu[k].gpu_model
        "zadara.com/k8s/gpu-count" = tostring(local._node_group_gpu[k].gpu_count)
      } : {}
    )
  }

  node_groups_control = {
    for k, v in local.node_groups :
    k => v if v.enabled && v.role == "control"
  }
  node_groups_worker = {
    for k, v in local.node_groups :
    k => v if v.enabled && v.role == "worker"
  }
  flavor_defaults = {
    k3s-ubuntu = {
      image_id = flatten(data.aws_ami_ids.ubuntu[*].ids)[0]
    }
    k3s-debian = {
      image_id = flatten(data.aws_ami_ids.debian[*].ids)[0]
    }
  }
}
