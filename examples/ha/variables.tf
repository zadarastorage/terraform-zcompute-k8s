# Variables for high-availability K3s cluster example
# Includes etcd backup configuration for disaster recovery

# -----------------------------------------------------------------------------
# Network Variables
# -----------------------------------------------------------------------------

variable "vpc_id" {
  description = "ID of the VPC where the K3s cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for K3s nodes (use multiple AZs for HA)"
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

variable "cluster_flavor" {
  description = <<-EOT
    Base OS flavor for K3s cluster nodes.
    Options: "k3s-ubuntu" (Ubuntu 22.04 LTS), "k3s-debian" (Debian 12)
  EOT
  type        = string
  default     = "k3s-ubuntu"
}

# -----------------------------------------------------------------------------
# etcd Backup Variables
# Configure to enable automatic etcd snapshots to S3-compatible storage
# -----------------------------------------------------------------------------

variable "etcd_backup_enabled" {
  description = "Enable automatic etcd backup to S3-compatible storage"
  type        = bool
  default     = false
}

variable "etcd_backup_endpoint" {
  description = "S3-compatible endpoint URL for etcd backups (e.g., https://s3.example.com)"
  type        = string
  default     = ""
}

variable "etcd_backup_bucket" {
  description = "S3 bucket name for etcd backups"
  type        = string
  default     = ""
}

variable "etcd_backup_access_key" {
  description = "S3 access key for etcd backups"
  type        = string
  default     = ""
  sensitive   = true
}

variable "etcd_backup_secret_key" {
  description = "S3 secret key for etcd backups"
  type        = string
  default     = ""
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
  default     = "k3s-ha"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
