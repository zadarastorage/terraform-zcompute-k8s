output "cluster_name" {
  description = "Name of the K8s cluster"
  value       = module.k8s.cluster_name
}

output "load_balancer_dns" {
  description = "DNS name of the Kubernetes API load balancer"
  value       = data.aws_lb.kube_api.dns_name
}

output "cluster_token" {
  description = "Cluster token for kubeconfig generation"
  value       = var.cluster_token
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "ID of the cluster security group"
  value       = module.k8s.cluster_security_group_id
}

