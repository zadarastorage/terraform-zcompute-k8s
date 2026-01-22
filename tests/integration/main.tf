# Integration test K3s cluster configuration
# Provisions a K3s cluster for end-to-end validation

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------

provider "aws" {
  endpoints {
    ec2         = "${var.zcompute_endpoint}/api/v2/aws/ec2"
    autoscaling = "${var.zcompute_endpoint}/api/v2/aws/autoscaling"
    elb         = "${var.zcompute_endpoint}/api/v2/aws/elbv2"
    s3          = "${var.zcompute_endpoint}:1061/"
    iam         = "${var.zcompute_endpoint}/api/v2/aws/iam"
    sts         = "${var.zcompute_endpoint}/api/v2/aws/sts"
  }

  region   = "us-east-1"
  insecure = true

  access_key = var.zcompute_access_key
  secret_key = var.zcompute_secret_key
}

# -----------------------------------------------------------------------------
# Random Resources
# -----------------------------------------------------------------------------

resource "random_id" "suffix" {
  byte_length = 4
}

resource "random_password" "cluster_token" {
  length  = 32
  special = false
}

# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------

locals {
  cluster_name  = "${var.cluster_name}-${random_id.suffix.hex}"
  cluster_token = var.cluster_token != "" ? var.cluster_token : random_password.cluster_token.result

  bastion_security_group_rules = {
    ingress_ssh = {
      description = "Allow SSH from specified CIDR"
      protocol    = "tcp"
      from_port   = 22
      to_port     = 22
      type        = "ingress"
      cidr_blocks = [var.bastion_ssh_source_cidr]
    }
    egress_all = {
      description = "Allow all outbound traffic"
      protocol    = "all"
      from_port   = 0
      to_port     = 65535
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

# -----------------------------------------------------------------------------
# VPC Infrastructure (self-contained)
# -----------------------------------------------------------------------------

module "vpc" {
  # tflint-ignore: terraform_module_pinned_source
  source = "github.com/zadarastorage/terraform-zcompute-vpc?ref=main"

  name = local.cluster_name
  cidr = var.vpc_cidr

  azs             = [var.availability_zone]
  public_subnets  = [var.public_subnet_cidr]
  private_subnets = [var.private_subnet_cidr]

  enable_nat_gateway      = true
  single_nat_gateway      = true
  enable_dns_hostnames    = true
  enable_dns_support      = true
  map_public_ip_on_launch = true

  tags = {
    Environment = "integration-test"
    TestRun     = var.cluster_name
  }
}

# -----------------------------------------------------------------------------
# IAM Instance Profile (self-contained)
# -----------------------------------------------------------------------------

module "iam_instance_profile" {
  # tflint-ignore: terraform_module_pinned_source
  source = "github.com/zadarastorage/terraform-zcompute-iam-instance-profile?ref=main"

  name = "${local.cluster_name}-k3s-node"

  policy_contents = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "autoscaling:*",
          "elasticloadbalancing:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# K3s Module
# -----------------------------------------------------------------------------

module "k3s" {
  source = "../.."

  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.private_subnets

  cluster_name    = local.cluster_name
  cluster_version = "1.31.2"
  cluster_token   = local.cluster_token
  cluster_flavor  = var.cluster_flavor

  # Simplified test configuration - no etcd backup
  etcd_backup = null

  node_group_defaults = {
    iam_instance_profile = module.iam_instance_profile.instance_profile_name
    key_name             = var.ssh_key_name
    root_volume_size     = 64
    security_group_rules = {
      egress_all = {
        description = "Allow all outbound traffic"
        protocol    = "all"
        from_port   = 0
        to_port     = 65535
        type        = "egress"
        cidr_blocks = ["0.0.0.0/0"]
      }
    }
  }

  node_groups = {
    control = {
      role         = "control"
      min_size     = var.control_plane_count
      max_size     = var.control_plane_count
      desired_size = var.control_plane_count
    }
    worker = {
      role         = "worker"
      min_size     = var.worker_count
      max_size     = var.worker_count
      desired_size = var.worker_count
    }
  }

  tags = {
    Environment = "integration-test"
    ManagedBy   = "terraform"
    TestRun     = var.cluster_name
  }
}

# -----------------------------------------------------------------------------
# Bastion Host (for kubectl access)
# -----------------------------------------------------------------------------

data "aws_ami" "bastion" {
  count       = var.bastion_enabled ? 1 : 0
  most_recent = true
  owners      = ["*"]

  filter {
    name   = "name"
    values = ["Public - Ubuntu Server 22.04*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "is-public"
    values = ["true"]
  }
}

resource "aws_security_group" "bastion" {
  count       = var.bastion_enabled ? 1 : 0
  name        = "${local.cluster_name}-bastion"
  description = "Bastion host security group for ${local.cluster_name}"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name        = "${local.cluster_name}-bastion"
    Environment = "integration-test"
  }
}

resource "aws_security_group_rule" "bastion" {
  for_each = var.bastion_enabled ? local.bastion_security_group_rules : {}

  security_group_id = aws_security_group.bastion[0].id
  type              = each.value.type
  description       = each.value.description
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
}

resource "aws_instance" "bastion" {
  count = var.bastion_enabled ? 1 : 0

  ami           = data.aws_ami.bastion[0].id
  instance_type = "z2.large"
  key_name      = var.ssh_key_name
  subnet_id     = module.vpc.public_subnets[0]

  vpc_security_group_ids = [
    aws_security_group.bastion[0].id,
    module.k3s.cluster_security_group_id,
  ]

  root_block_device {
    volume_size           = 32
    delete_on_termination = true
  }

  tags = {
    Name        = "${local.cluster_name}-bastion"
    Environment = "integration-test"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_eip" "bastion" {
  count    = var.bastion_enabled ? 1 : 0
  instance = aws_instance.bastion[0].id
  vpc      = true

  tags = {
    Name        = "${local.cluster_name}-bastion-eip"
    Environment = "integration-test"
  }
}
