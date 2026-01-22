# Terraform and provider version constraints
# Copy this file along with other *.tf files when using this example

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.33.0, <= 3.35.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.0"
    }
  }
}

provider "aws" {
  region = var.region

  # zCompute endpoint configuration
  endpoints {
    ec2         = "${var.zcompute_endpoint}/api/v2/aws/ec2"
    autoscaling = "${var.zcompute_endpoint}/api/v2/aws/autoscaling"
    elb         = "${var.zcompute_endpoint}/api/v2/aws/elbv2"
    iam         = "${var.zcompute_endpoint}/api/v2/aws/iam"
  }

  access_key = var.zcompute_access_key
  secret_key = var.zcompute_secret_key
  insecure   = true # zCompute uses self-signed certificates
}

# -----------------------------------------------------------------------------
# Provider Configuration Variables
# -----------------------------------------------------------------------------

variable "region" {
  description = "AWS region for zCompute deployment"
  type        = string
  default     = "us-east-1"
}

variable "zcompute_endpoint" {
  description = "Zadara zCompute API endpoint URL"
  type        = string
  default     = "https://cloud.zadara.com"
}

variable "zcompute_access_key" {
  description = "zCompute access key"
  type        = string
}

variable "zcompute_secret_key" {
  description = "zCompute secret key"
  type        = string
  sensitive   = true
}
