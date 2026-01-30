# Merge Test Fixture Variables
# Purpose: Allow override of module inputs for merge behavior testing

variable "test_cluster_helm" {
  description = "Override cluster_helm to test Helm merge behavior"
  type        = any
  default     = {}
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
