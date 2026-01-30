output "cluster_name" {
  value = try(var.cluster_name, null)
}
output "cluster_version" {
  value = try(var.cluster_version, null)
}
output "cluster_security_group_id" {
  description = "ID of the cluster security group"
  value       = try(aws_security_group.k8s.id, null)
}

# Debug outputs for testing merge behavior
output "cluster_helm_merged" {
  description = "Final merged Helm configuration after combining defaults with user overrides. Used for testing/debugging merge behavior."
  sensitive   = false
  value       = local.cluster_helm_merged
}

output "cloudinit_parts_debug" {
  description = "Cloud-init parts structure for each node group. Used for testing/debugging cloud-init concatenation behavior - shows the parts that will be combined for each node group"
  sensitive   = false
  value = {
    for k, v in local.node_groups :
    k => [
      for idx, obj in concat(
        [
          { order = 0, filename = "write-files-k8s-json.yaml", content_type = "text/cloud-config" },
        ],
        local.cloudinit_os["common"],
        local.cloudinit_os[split("-", try(v.cluster_flavor, var.cluster_flavor))[1]],
        local.cloudinit_flavor[split("-", try(v.cluster_flavor, var.cluster_flavor))[0]],
        local.cloudinit_cfg[try(v.cluster_flavor, var.cluster_flavor)],
        try(v.cloudinit_config, [])
      ) : {
        order        = try(obj.order, 99)
        filename     = obj.filename
        content_type = obj.content_type
        source       = idx < 1 ? "module-generated" : (idx < 1 + length(local.cloudinit_os["common"]) ? "cloudinit_os.common" : (idx < 1 + length(local.cloudinit_os["common"]) + length(local.cloudinit_os[split("-", try(v.cluster_flavor, var.cluster_flavor))[1]]) ? "cloudinit_os.${split("-", try(v.cluster_flavor, var.cluster_flavor))[1]}" : (idx < 1 + length(local.cloudinit_os["common"]) + length(local.cloudinit_os[split("-", try(v.cluster_flavor, var.cluster_flavor))[1]]) + length(local.cloudinit_flavor[split("-", try(v.cluster_flavor, var.cluster_flavor))[0]]) ? "cloudinit_flavor.${split("-", try(v.cluster_flavor, var.cluster_flavor))[0]}" : (idx < 1 + length(local.cloudinit_os["common"]) + length(local.cloudinit_os[split("-", try(v.cluster_flavor, var.cluster_flavor))[1]]) + length(local.cloudinit_flavor[split("-", try(v.cluster_flavor, var.cluster_flavor))[0]]) + length(local.cloudinit_cfg[try(v.cluster_flavor, var.cluster_flavor)]) ? "cloudinit_cfg" : "user-provided"))))
      } if try(obj.enabled, true) == true
    ]
  }
}
