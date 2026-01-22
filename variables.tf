variable "zcompute_endpoint" {
  description = "zCompute API Endpoint"
  type        = string
  default     = "https://cloud.zadara.com"
}

variable "vpc_id" {
  description = "zCompute VPC ID"
  type        = string
}

variable "subnets" {
  description = "A list of (preferably private) subnets to place the K8s cluster and workers into."
  type        = list(string)
}

variable "trusted_ami_owners" {
  description = <<-EOT
    List of trusted AMI owner IDs for Ubuntu and Debian images.
    SECURITY WARNING: Empty list means no owner restriction (any AMI owner accepted).
    For Zadara zCompute, use: ["1234a701473b61af498f633abdc8c113"]
  EOT
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for id in var.trusted_ami_owners : can(regex("^[a-z0-9]{32}$", id)) || can(regex("^[0-9]{12}$", id)) || id == "self"
    ])
    error_message = "Each owner ID must be a 32-character hex string, 12-digit AWS account ID, or 'self'."
  }
}

variable "cluster_name" {
  description = "Name to be used to describe the k8s cluster"
  type        = string
}

variable "cluster_version" {
  description = "The k8s base version to use"
  type        = string
}

variable "cluster_token" {
  description = "Configure the node join token"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.cluster_token) >= 16
    error_message = "cluster_token must be at least 16 characters for security."
  }
}

variable "cluster_flavor" {
  description = "Default flavor of k8s cluster to deploy"
  type        = string
  default     = "k3s-ubuntu"
}

variable "cluster_helm" {
  description = "List of helmcharts to preload"
  type        = any
  default     = {}
}

variable "pod_cidr" {
  description = "Customize the cidr range used for k8s pods"
  type        = string
  default     = "10.42.0.0/16"
}

variable "service_cidr" {
  description = "Customize the cidr range used for k8s service objects"
  type        = string
  default     = "10.43.0.0/16"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "node_group_defaults" {
  description = "User-configurable defaults for all node groups"
  type        = any
  default     = {}
}

variable "node_groups" {
  description = "Configuration of scalable hosts with a designed configuration."
  type        = any
  default     = {}
}

variable "etcd_backup" {
  description = "Configuration to automatically backup etcd to object storage"
  type        = map(string)
  default     = null
  sensitive   = true
  ## Configuration is essentially key=value where the key matches the k3s flag with --etcd- removed. IE --etcd-s3-bucket=bucket would be configured here as { s3-bucket = "bucket" }
  # { s3 = true, s3-endpoint = "", s3-region = "", s3-access-key = "", s3-secret-key = "", s3-bucket = "", s3-folder = "" } ## https://docs.k3s.io/cli/etcd-snapshot#s3-compatible-object-store-support
  # { s3 = true, s3-config-secret=<secretName> } ## Using a k8s secret is not available for restore operations https://docs.k3s.io/cli/etcd-snapshot#s3-configuration-secret-support
}
