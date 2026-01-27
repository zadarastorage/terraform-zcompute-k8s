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
  description = "Security group ID of the K8s cluster (allows bastion to reach the API server)"
}

variable "instance_type" {
  type        = string
  description = "Instance type for the bastion host"
}
