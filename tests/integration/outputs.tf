# Integration test outputs for verification scripts

output "cluster_name" {
  description = "Name of the provisioned K3s cluster"
  value       = local.cluster_name
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host for SSH access"
  value       = var.bastion_enabled ? aws_eip.bastion[0].public_ip : null
}

output "control_plane_lb_dns" {
  description = "DNS name of the control plane load balancer for kubeconfig"
  value       = module.k3s.kube_api_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID for cluster communication"
  value       = module.k3s.cluster_security_group_id
}

output "expected_node_count" {
  description = "Expected total number of nodes (control + worker)"
  value       = var.control_plane_count + var.worker_count
}
