variable "run_id" {
  description = "GitHub Actions run ID for resource naming"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to deploy into"
  type        = string
}

variable "private_subnets" {
  description = "Private subnet IDs (GarageHQ runs in private subnet)"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type for GarageHQ VM"
  type        = string
  default     = ""
}

variable "cluster_security_group_id" {
  description = "K8s cluster security group ID (to allow S3 API access)"
  type        = string
  default     = ""
}

variable "ssh_key_name" {
  description = "AWS key pair name for SSH access (created by bastion fixture)"
  type        = string
  default     = ""
}

variable "debug_ssh_public_key" {
  description = "Optional SSH public key for manual debugging"
  type        = string
  default     = ""
}
