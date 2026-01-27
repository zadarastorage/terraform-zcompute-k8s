variable "zcompute_endpoint_url" {
  type        = string
  description = "IP/DNS of zCompute Region API Endpoint. ex: https://compute-us-west-101.zadara.com"
}

variable "zcompute_access_key" {
  type        = string
  description = "Amazon style zCompute access key"
}

variable "zcompute_secret_key" {
  type        = string
  sensitive   = true
  description = "Amazon style zCompute secret key"
}

provider "aws" {
  endpoints {
    iam = "${var.zcompute_endpoint_url}/api/v2/aws/iam"
    sts = "${var.zcompute_endpoint_url}/api/v2/aws/sts"
  }

  region   = "us-east-1"
  insecure = "true"

  access_key = var.zcompute_access_key
  secret_key = var.zcompute_secret_key

  # No default_tags — zCompute IAM does not support resource tagging.
}
