locals {
  bastion_name = "test-k8s-${var.run_id}-bastion"

  ami_options = [
    {
      codename = "noble"
      year     = 2024
      regex    = "Public - Ubuntu Server 24.04"
    },
    {
      codename = "jammy"
      year     = 2022
      regex    = "Public - Ubuntu Server 22.04"
    },
    {
      codename = "focal"
      year     = 2020
      regex    = "Public - Ubuntu Server 20.04"
    },
    {
      codename = "bionic"
      year     = 2018
      regex    = "Public - Ubuntu Server 18.04"
    },
  ]

  bastion_security_group_rules = {
    ingress_ipv4_ssh = {
      description = "Allow all inbound SSH"
      protocol    = "tcp"
      from_port   = 22
      to_port     = 22
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
    }
    egress_ipv4 = {
      description = "Allow all outbound"
      protocol    = "all"
      from_port   = 0
      to_port     = 65535
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

# --- SSH Key ---

resource "tls_private_key" "bastion" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "bastion" {
  key_name   = local.bastion_name
  public_key = tls_private_key.bastion.public_key_openssh
}

# --- AMI Lookup ---

data "aws_ami_ids" "bastion_ubuntu" {
  count      = length(local.ami_options)
  owners     = ["*"]
  name_regex = "^${local.ami_options[count.index].regex}$"

  filter {
    name   = "is-public"
    values = ["true"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# --- Security Group ---

resource "aws_security_group" "bastion" {
  name        = local.bastion_name
  description = "Bastion SSH access for integration tests"
  vpc_id      = var.vpc_id

  # No tags — zCompute CreateSecurityGroup rejects tags at creation time
}

resource "aws_security_group_rule" "bastion" {
  for_each = local.bastion_security_group_rules

  type              = try(each.value.type, null)
  description       = try(each.value.description, null)
  from_port         = try(each.value.from_port, null)
  to_port           = try(each.value.to_port, null)
  protocol          = try(each.value.protocol, null)
  cidr_blocks       = try(each.value.cidr_blocks, null)
  security_group_id = aws_security_group.bastion.id
}

# --- Instance ---

resource "aws_instance" "bastion" {
  instance_type = var.instance_type
  ami           = flatten(data.aws_ami_ids.bastion_ubuntu[*].ids)[0]
  key_name      = aws_key_pair.bastion.key_name

  tags = { Name = local.bastion_name }

  subnet_id = one(var.public_subnets)

  vpc_security_group_ids = [
    aws_security_group.bastion.id,
    var.cluster_security_group_id,
  ]

  root_block_device {
    volume_size           = 32
    delete_on_termination = true
  }

  user_data = <<-CLOUDINIT
    #!/bin/bash
    set -euo pipefail

    # Install kubectl
    curl -fsSL "https://dl.k8s.io/release/v1.31.2/bin/linux/amd64/kubectl" \
      -o /usr/local/bin/kubectl
    chmod +x /usr/local/bin/kubectl

    # Signal readiness
    touch /tmp/bastion-ready
  CLOUDINIT

  lifecycle {
    ignore_changes = [
      ami,
      tags["os_family_linux"],
    ]
  }
}

# --- Elastic IP ---

resource "aws_eip" "bastion" {
  instance = aws_instance.bastion.id
  domain   = "vpc"
}
