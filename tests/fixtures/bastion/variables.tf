variable "run_id" {
  type        = string
  description = "Unique identifier for this test run (e.g., github.run_id)"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID from VPC fixture output"
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnet IDs from VPC fixture output"
}

variable "cluster_security_group_id" {
  type        = string
  default     = ""
  description = "Security group ID of the K8s cluster (allows bastion to reach the API server). Empty on first apply; set on update after K8s deploys."
}

variable "instance_type" {
  type        = string
  description = "Instance type for the bastion host"
}

variable "ssh_public_key" {
  type        = string
  default     = ""
  description = "SSH public key for bastion and cluster node access. When set, an AWS key pair is created."
}

variable "debug_ssh_public_key" {
  type        = string
  default     = ""
  description = "Optional SSH public key for manual debugging. Injected via cloud-init ssh_authorized_keys."
}
