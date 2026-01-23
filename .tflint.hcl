# tflint configuration for terraform-zcompute-k8s
# Runs in CI to enforce Terraform best practices and AWS-specific rules

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.45.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Enforce snake_case naming for resources, variables, and outputs
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

# Require descriptions for all variables
rule "terraform_documented_variables" {
  enabled = true
}

# Require descriptions for all outputs
rule "terraform_documented_outputs" {
  enabled = true
}

# Flag deprecated interpolation syntax (e.g., "${var.foo}" should be var.foo)
rule "terraform_deprecated_interpolation" {
  enabled = true
}

# Configuration
config {
  # Do not enable deep checking (requires AWS credentials)
  # Deep checking validates actual AWS resources, which we skip in CI
}
