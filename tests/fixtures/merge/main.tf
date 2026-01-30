# Merge Test Fixture
# Purpose: Enable inspection of Helm merge and cloud-init concatenation behavior
# Usage: terraform plan -input=false tests/fixtures/merge (plan-only tests)

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.33.0, <= 3.35.0"
    }
  }
}

# Mock AWS provider for plan-only testing
provider "aws" {
  region = "us-east-1"

  # Skip credential validation and API calls - plan-only tests
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  access_key = "mock-access-key"
  secret_key = "mock-secret-key"
}

module "k8s" {
  source = "../../.."

  # Required inputs with mock values
  vpc_id  = "vpc-mock-12345"
  subnets = ["subnet-mock-a", "subnet-mock-b"]

  cluster_name    = "merge-test"
  cluster_version = "1.31.2"
  cluster_token   = "mock-cluster-token"

  default_instance_type = "z4.large"

  # Passthrough test variables for merge behavior testing
  cluster_helm = var.test_cluster_helm

  # Node groups with control plane for cloud-init testing
  node_groups = var.test_node_groups
}
