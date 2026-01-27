module "vpc" {
  source = "github.com/zadarastorage/terraform-zcompute-vpc?ref=v1.0.0"

  name = "test-k8s-${var.run_id}"
  cidr = "10.200.0.0/16"

  # Create one public and one private subnet in the symphony AZ
  public_subnets  = ["10.200.0.0/17"]
  private_subnets = ["10.200.128.0/17"]

  # NAT gateway gives private-subnet nodes internet access for
  # apt-get, AWS CLI install, container image pulls, etc.
  enable_nat_gateway = true

  tags = {
    "managed-by" = "integration-test"
  }
}
