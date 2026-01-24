output "instance_profile_name" {
  description = "Name of the IAM instance profile for K8s nodes"
  value       = module.iam_instance_profile.instance_profile_name
}
