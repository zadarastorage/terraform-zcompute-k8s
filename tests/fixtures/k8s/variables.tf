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
