# Shared Terraform and provider configuration for all examples
# Each example directory inherits this configuration

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

  # Uncomment and customize for remote state
  # backend "s3" {
  #   bucket   = "my-terraform-state"
  #   key      = "k3s/examples/<example-name>/terraform.tfstate"
  #   region   = "us-east-1"
  #   endpoint = "https://cloud.zadara.com:1061/"
  # }
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
# Common variables for provider configuration
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
