variable "run_id" {
  type        = string
  description = "Unique identifier for this test run (e.g., github.run_id)"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID from VPC fixture output"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnet IDs from VPC fixture output"
}

variable "iam_instance_profile" {
  type        = string
  description = "IAM instance profile name from IAM fixture output"
}

variable "cluster_token" {
  type        = string
  sensitive   = true
  description = "Token for cluster authentication and node join"
}

variable "default_instance_type" {
  type        = string
  description = "Default instance type for K8s node groups, provided by CI environment"
}

variable "ssh_key_name" {
  type        = string
  default     = ""
  description = "AWS key pair name for SSH access to cluster nodes (created by bastion fixture)."
}

variable "debug_ssh_public_key" {
  type        = string
  default     = ""
  description = "Optional SSH public key for manual debugging. Injected via cloud-init ssh_authorized_keys on all nodes."
}
