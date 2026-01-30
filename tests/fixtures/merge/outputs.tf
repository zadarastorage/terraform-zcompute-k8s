# Merge Test Fixture Outputs
# Purpose: Expose module merge state for test assertions

output "cluster_helm_merged" {
  description = "Final merged Helm configuration from module"
  value       = try(module.k8s.cluster_helm_merged, null)
}

output "cloudinit_parts_debug" {
  description = "Cloud-init parts structure from module"
  value       = try(module.k8s.cloudinit_parts_debug, null)
}
