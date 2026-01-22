# Variables for mixed flavor K3s cluster example
# Demonstrates per-node-group OS flavor override

# -----------------------------------------------------------------------------
# Network Variables
# -----------------------------------------------------------------------------

variable "vpc_id" {
  description = "ID of the VPC where the K3s cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for K3s nodes (private subnets recommended)"
  type        = list(string)
}

# -----------------------------------------------------------------------------
# Cluster Variables
# -----------------------------------------------------------------------------

variable "cluster_token" {
  description = <<-EOT
    Shared secret token for node authentication and cluster join.
    Must be at least 16 characters. Generate with: openssl rand -hex 16
  EOT
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Node Variables
# -----------------------------------------------------------------------------

variable "iam_instance_profile" {
  description = "Name of the IAM instance profile for K3s nodes"
  type        = string
}

variable "key_pair_name" {
  description = "Name of the SSH key pair for node access"
  type        = string
}

# -----------------------------------------------------------------------------
# Optional Variables
# -----------------------------------------------------------------------------

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "k3s-mixed"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
