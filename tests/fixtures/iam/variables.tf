variable "run_id" {
  type        = string
  description = "Unique identifier for this test run (e.g., github.run_id)"
}

variable "cluster_version" {
  type        = string
  description = "K8s version under test, used to namespace IAM resources per matrix entry"
}
