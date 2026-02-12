terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.33.0, <= 3.35.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.0.0"
    }
  }
}
