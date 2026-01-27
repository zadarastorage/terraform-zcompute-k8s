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
    ec2 = "${var.zcompute_endpoint_url}/api/v2/aws/ec2"
    sts = "${var.zcompute_endpoint_url}/api/v2/aws/sts"
  }

  region   = "us-east-1"
  insecure = "true"

  access_key = var.zcompute_access_key
  secret_key = var.zcompute_secret_key

  # No default_tags: zCompute RunInstances rejects TagSpecification for
  # resource type 'volume', which the provider sends when default_tags exist.
  # Tags are applied directly on each resource instead.
}

provider "tls" {}
