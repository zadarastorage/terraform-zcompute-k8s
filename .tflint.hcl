# tflint configuration for terraform-k8s-zcompute
# https://github.com/terraform-linters/tflint

# Terraform language rules (built-in)
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# AWS-specific rules
plugin "aws" {
  enabled = true
  version = "0.45.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"

  # deep_check = false (default) - correct for zCompute
  # Deep check validates against AWS API which fails for
  # zCompute-specific instance types and regions
}
