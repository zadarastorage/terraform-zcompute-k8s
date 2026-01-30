locals {
  garage_name = "test-k8s-${var.run_id}-garage"

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

  garage_security_group_rules = {
    ingress_s3_api = {
      description              = "Allow S3 API access from K8s cluster"
      protocol                 = "tcp"
      from_port                = 3900
      to_port                  = 3900
      type                     = "ingress"
      source_security_group_id = var.cluster_security_group_id
    }
    ingress_ssh = {
      description = "Allow SSH for credential extraction"
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

# --- AMI Lookup ---

data "aws_ami_ids" "garage_ubuntu" {
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

resource "aws_security_group" "garage" {
  name        = local.garage_name
  description = "GarageHQ S3-compatible storage for etcd backup testing"
  vpc_id      = var.vpc_id

  # No tags - zCompute CreateSecurityGroup rejects tags at creation time
}

resource "aws_security_group_rule" "garage" {
  for_each = {
    for k, v in local.garage_security_group_rules :
    k => v if !(k == "ingress_s3_api" && var.cluster_security_group_id == "")
  }

  type                     = try(each.value.type, null)
  description              = try(each.value.description, null)
  from_port                = try(each.value.from_port, null)
  to_port                  = try(each.value.to_port, null)
  protocol                 = try(each.value.protocol, null)
  cidr_blocks              = try(each.value.cidr_blocks, null)
  source_security_group_id = try(each.value.source_security_group_id, null)
  security_group_id        = aws_security_group.garage.id
}

# --- Cloud-Init ---

data "cloudinit_config" "garage" {
  gzip          = false
  base64_encode = false

  dynamic "part" {
    for_each = var.debug_ssh_public_key != "" ? [1] : []
    content {
      filename     = "debug-ssh-key.yaml"
      content_type = "text/cloud-config"
      content      = <<-YAML
        #cloud-config
        ssh_authorized_keys:
          - ${var.debug_ssh_public_key}
      YAML
    }
  }

  part {
    filename     = "setup-garage.sh"
    content_type = "text/x-shellscript"
    content      = <<-SHELL
      #!/bin/bash
      set -euo pipefail

      # Configuration
      GARAGE_VERSION="v1.0.0"
      GARAGE_DATA="/var/lib/garage"
      GARAGE_CONFIG="/etc/garage.toml"
      RUN_ID="${var.run_id}"
      BUCKET_NAME="etcd-backup-$${RUN_ID}"
      KEY_NAME="ci-$${RUN_ID}"

      # Get instance private IP from metadata
      VM_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

      # Install Docker
      apt-get update
      apt-get install -y docker.io jq
      systemctl enable docker
      systemctl start docker

      # Create data directories
      mkdir -p "$${GARAGE_DATA}/meta" "$${GARAGE_DATA}/data"

      # Generate secrets
      RPC_SECRET=$(openssl rand -hex 32)
      ADMIN_TOKEN=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)

      # Create garage configuration
      cat > "$${GARAGE_CONFIG}" << EOF
      metadata_dir = "$${GARAGE_DATA}/meta"
      data_dir = "$${GARAGE_DATA}/data"
      db_engine = "sqlite"
      replication_factor = 1

      rpc_bind_addr = "[::]:3901"
      rpc_public_addr = "$${VM_IP}:3901"
      rpc_secret = "$${RPC_SECRET}"

      [s3_api]
      s3_region = "garage"
      api_bind_addr = "[::]:3900"

      [admin]
      api_bind_addr = "[::]:3903"
      admin_token = "$${ADMIN_TOKEN}"
      EOF

      # Start GarageHQ container
      docker run -d \
        --name garage \
        --restart unless-stopped \
        -p 3900:3900 -p 3901:3901 -p 3903:3903 \
        -v "$${GARAGE_CONFIG}:/etc/garage.toml" \
        -v "$${GARAGE_DATA}:/var/lib/garage" \
        "dxflrs/garage:$${GARAGE_VERSION}"

      # Wait for GarageHQ to start
      echo "Waiting for GarageHQ to start..."
      for i in $(seq 1 30); do
        if docker exec garage /garage status 2>/dev/null | grep -q "Local node ID"; then
          echo "GarageHQ is running"
          break
        fi
        sleep 2
      done

      # Get node ID and apply layout
      NODE_ID=$(docker exec garage /garage status | grep "Local node ID" | awk '{print $NF}' | cut -c1-16)
      echo "Node ID: $${NODE_ID}"

      docker exec garage /garage layout assign -z dc1 -c 10G "$${NODE_ID}"
      docker exec garage /garage layout apply --version 1

      # Wait for layout to be applied
      sleep 5

      # Create bucket
      echo "Creating bucket: $${BUCKET_NAME}"
      docker exec garage /garage bucket create "$${BUCKET_NAME}"

      # Create access key and capture output
      echo "Creating access key: $${KEY_NAME}"
      KEY_OUTPUT=$(docker exec garage /garage key create "$${KEY_NAME}" 2>&1)
      ACCESS_KEY=$(echo "$${KEY_OUTPUT}" | grep "Key ID" | awk '{print $NF}')
      SECRET_KEY=$(echo "$${KEY_OUTPUT}" | grep "Secret key" | awk '{print $NF}')

      # Grant permissions
      docker exec garage /garage bucket allow \
        --read --write --owner \
        "$${BUCKET_NAME}" \
        --key "$${KEY_NAME}"

      # Write credentials to file for extraction via SSH
      cat > /tmp/garage-credentials.json << EOF
      {
        "endpoint": "$${VM_IP}:3900",
        "bucket": "$${BUCKET_NAME}",
        "access_key": "$${ACCESS_KEY}",
        "secret_key": "$${SECRET_KEY}",
        "region": "garage"
      }
      EOF
      chmod 644 /tmp/garage-credentials.json

      # Signal readiness
      touch /tmp/garage-ready

      echo "GarageHQ setup complete"
      echo "Endpoint: $${VM_IP}:3900"
      echo "Bucket: $${BUCKET_NAME}"
      echo "Credentials written to /tmp/garage-credentials.json"
    SHELL
  }
}

# --- Instance ---

resource "aws_instance" "garage" {
  instance_type = var.instance_type
  ami           = flatten(data.aws_ami_ids.garage_ubuntu[*].ids)[0]
  key_name      = var.ssh_key_name != "" ? var.ssh_key_name : null

  tags = { Name = local.garage_name }

  subnet_id = one(var.private_subnets)

  vpc_security_group_ids = [aws_security_group.garage.id]

  root_block_device {
    volume_size           = 32
    delete_on_termination = true
  }

  user_data = data.cloudinit_config.garage.rendered

  lifecycle {
    ignore_changes = [
      ami,
      tags["os_family_linux"],
    ]
  }
}
