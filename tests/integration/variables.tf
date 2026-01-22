# Integration test configuration variables

# -----------------------------------------------------------------------------
# zCompute Connection
# -----------------------------------------------------------------------------

variable "zcompute_endpoint" {
  description = "zCompute API endpoint URL (e.g., https://compute-us-west-101.zadara.com)"
  type        = string
}

variable "zcompute_access_key" {
  description = "AWS-style access key for zCompute authentication"
  type        = string
}

variable "zcompute_secret_key" {
  description = "AWS-style secret key for zCompute authentication"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Network Configuration (self-contained)
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for test VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.0.10.0/24"
}

variable "availability_zone" {
  description = "Availability zone for subnets (must exist in zCompute region)"
  type        = string
  default     = "symphony"
}

# -----------------------------------------------------------------------------
# Cluster Configuration
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "Unique cluster name (should include GitHub run ID for uniqueness)"
  type        = string
}

variable "cluster_flavor" {
  description = "OS flavor for K3s nodes (k3s-ubuntu or k3s-debian)"
  type        = string
  default     = "k3s-ubuntu"
}

variable "cluster_token" {
  description = "Shared secret token for cluster join (min 16 chars)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "control_plane_count" {
  description = "Number of control plane nodes (1 for single-node, 3 for HA)"
  type        = number
  default     = 1
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 1
}

# -----------------------------------------------------------------------------
# Instance Configuration
# -----------------------------------------------------------------------------

variable "ssh_key_name" {
  description = "Name of existing SSH key pair for node access"
  type        = string
}

# -----------------------------------------------------------------------------
# Bastion Configuration
# -----------------------------------------------------------------------------

variable "bastion_enabled" {
  description = "Enable bastion host for kubectl access"
  type        = bool
  default     = true
}

variable "bastion_ssh_source_cidr" {
  description = "CIDR block allowed SSH access to bastion"
  type        = string
  default     = "0.0.0.0/0"
}
