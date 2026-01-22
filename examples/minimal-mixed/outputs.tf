# Outputs for mixed flavor K3s cluster example

output "cluster_name" {
  description = "Name of the K3s cluster"
  value       = module.k3s.cluster_name
}

output "cluster_version" {
  description = "Kubernetes version of the cluster"
  value       = module.k3s.cluster_version
}

output "kube_api_endpoint" {
  description = "Internal DNS name of the Kubernetes API load balancer"
  value       = module.k3s.kube_api_endpoint
}

output "kube_api_port" {
  description = "Port number for the Kubernetes API endpoint"
  value       = module.k3s.kube_api_port
}

output "cluster_security_group_id" {
  description = "ID of the security group used for intra-cluster communication"
  value       = module.k3s.cluster_security_group_id
}

output "control_plane_asg_names" {
  description = "Auto Scaling Group names for control plane nodes"
  value       = module.k3s.control_plane_asg_names
}

output "worker_asg_names" {
  description = "Auto Scaling Group names for worker nodes"
  value       = module.k3s.worker_asg_names
}
