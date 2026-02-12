# Merge Test Fixture Variables
# Purpose: Allow override of module inputs for merge behavior testing

variable "test_cluster_helm_yaml" {
  description = "Override cluster_helm_yaml to test YAML merge behavior"
  type        = string
  default     = null
}

variable "test_cluster_helm_values_dir" {
  description = "Override cluster_helm_values_dir to test directory-based config"
  type        = string
  default     = null
}

variable "test_node_groups" {
  description = "Override node_groups to test cloud-init concatenation behavior"
  type        = any
  default = {
    control = {
      role         = "control"
      min_size     = 1
      max_size     = 1
      desired_size = 1
    }
  }
}
