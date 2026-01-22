output "cluster_name" {
  description = "Name of the K8s cluster, as provided in the cluster_name variable"
  value       = try(var.cluster_name, null)
}

output "cluster_version" {
  description = "Kubernetes version of the cluster, as provided in the cluster_version variable"
  value       = try(var.cluster_version, null)
}

output "cluster_security_group_id" {
  description = "ID of the security group used for intra-cluster communication. Add this to any resources that need to communicate with cluster nodes."
  value       = try(aws_security_group.k8s.id, null)
}

output "kube_api_endpoint" {
  description = "Internal DNS name of the Kubernetes API load balancer. Use this endpoint for kubectl configuration within the VPC."
  value       = try(aws_lb.kube_api.dns_name, null)
}

output "kube_api_port" {
  description = "Port number for the Kubernetes API endpoint (always 6443)"
  value       = 6443
}

output "control_plane_asg_names" {
  description = "List of Auto Scaling Group names for control plane nodes. Useful for monitoring and troubleshooting."
  value       = [for k, v in aws_autoscaling_group.control : v.name]
}

output "worker_asg_names" {
  description = "List of Auto Scaling Group names for worker nodes. Useful for monitoring, troubleshooting, and cluster autoscaler configuration."
  value       = [for k, v in aws_autoscaling_group.worker : v.name]
}
